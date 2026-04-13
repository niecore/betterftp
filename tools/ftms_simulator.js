#!/usr/bin/env node

/**
 * FTMS BLE Trainer Simulator
 *
 * Advertises as a Fitness Machine (FTMS) indoor bike trainer over real BLE.
 * Broadcasts Indoor Bike Data (power + cadence) and accepts Control Point
 * writes (Request Control, Set Target Power).
 *
 * Usage:
 *   node tools/ftms_simulator.js                    # interactive mode
 *   node tools/ftms_simulator.js --name "MyTrainer" # custom device name
 *
 * Keyboard controls:
 *   p/P  — decrease/increase power by 10W
 *   c/C  — decrease/increase cadence by 10 RPM
 *   q    — quit
 */

const bleno = require('@stoprocent/bleno');
const readline = require('readline');

const PrimaryService = bleno.PrimaryService;
const Characteristic = bleno.Characteristic;

// ── Parse CLI args ────────────────────────────────────────────────
const args = process.argv.slice(2);
const nameIdx = args.indexOf('--name');
const DEVICE_NAME = nameIdx >= 0 && args[nameIdx + 1] ? args[nameIdx + 1] : 'Zwack';

// ── FTMS UUIDs ────────────────────────────────────────────────────
const FTMS_SERVICE_UUID           = '1826';
const INDOOR_BIKE_DATA_UUID       = '2AD2';
const CONTROL_POINT_UUID          = '2AD9';
const FTMS_FEATURE_UUID           = '2ACC';
const SUPPORTED_POWER_RANGE_UUID  = '2AD8';

// ── Mutable state ─────────────────────────────────────────────────
let power = 100;
let cadence = 90;
let targetPower = null; // set by Control Point writes

// Subscribers for Indoor Bike Data notifications (handle → callback)
const bikeDataSubscribers = new Map();

// Subscribers for Control Point indications (handle → callback)
const controlPointSubscribers = new Map();

// ── Indoor Bike Data Characteristic (0x2AD2) ──────────────────────
// Notify-only. Broadcasts power + cadence per FTMS spec.
const indoorBikeDataChar = new Characteristic({
  uuid: INDOOR_BIKE_DATA_UUID,
  properties: ['notify'],
  descriptors: [],
  onSubscribe: (handle, maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Central subscribed to Indoor Bike Data (handle=${handle})`);
    bikeDataSubscribers.set(handle, updateValueCallback);
  },
  onUnsubscribe: (handle) => {
    console.log(`[BLE] Central unsubscribed from Indoor Bike Data (handle=${handle})`);
    bikeDataSubscribers.delete(handle);
  },
});

// ── FTMS Feature Characteristic (0x2ACC) ──────────────────────────
// Read-only. Reports supported features.
const ftmsFeatureChar = new Characteristic({
  uuid: FTMS_FEATURE_UUID,
  properties: ['read'],
  onReadRequest: (handle, offset, callback) => {
    // FTMS Feature (8 bytes): 4 bytes machine features + 4 bytes target setting features
    // Bit 6 of machine features = Power Measurement supported
    // Bit 2 of machine features = Cadence supported
    // Bit 1 of target setting = Target Power supported
    const buf = Buffer.alloc(8, 0);
    buf.writeUInt32LE(0x44, 0); // bits 2 (cadence) + 6 (power)
    buf.writeUInt32LE(0x02, 4); // bit 1 (target power)
    callback(Characteristic.RESULT_SUCCESS, buf.slice(offset));
  },
});

// ── Supported Power Range Characteristic (0x2AD8) ─────────────────
// Read-only. Min/Max/Step power values.
const supportedPowerRangeChar = new Characteristic({
  uuid: SUPPORTED_POWER_RANGE_UUID,
  properties: ['read'],
  onReadRequest: (handle, offset, callback) => {
    // 6 bytes: minPower (sint16 LE) + maxPower (sint16 LE) + step (uint16 LE)
    const buf = Buffer.alloc(6);
    buf.writeInt16LE(0, 0);     // min: 0W
    buf.writeInt16LE(2000, 2);  // max: 2000W
    buf.writeUInt16LE(1, 4);    // step: 1W
    callback(Characteristic.RESULT_SUCCESS, buf.slice(offset));
  },
});

// ── Control Point Characteristic (0x2AD9) ─────────────────────────
// Write + Indicate. Handles Request Control and Set Target Power.
const controlPointChar = new Characteristic({
  uuid: CONTROL_POINT_UUID,
  properties: ['write', 'indicate'],
  descriptors: [],
  onSubscribe: (handle, maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Central subscribed to Control Point (handle=${handle})`);
    controlPointSubscribers.set(handle, updateValueCallback);
  },
  onUnsubscribe: (handle) => {
    controlPointSubscribers.delete(handle);
  },
  onWriteRequest: (handle, data, offset, withoutResponse, callback) => {
    if (data.length < 1) {
      callback(Characteristic.RESULT_UNLIKELY_ERROR);
      return;
    }

    const opCode = data[0];

    switch (opCode) {
      case 0x00: // Request Control
        console.log('[FTMS] Control requested — granted');
        sendControlPointResponse(0x00, 0x01); // success
        callback(Characteristic.RESULT_SUCCESS);
        break;

      case 0x01: // Reset
        console.log('[FTMS] Reset');
        targetPower = null;
        sendControlPointResponse(0x01, 0x01);
        callback(Characteristic.RESULT_SUCCESS);
        break;

      case 0x05: // Set Target Power
        if (data.length >= 3) {
          targetPower = data.readInt16LE(1);
          console.log(`[FTMS] Target power set to ${targetPower}W`);
          sendControlPointResponse(0x05, 0x01);
        } else {
          sendControlPointResponse(0x05, 0x03); // invalid parameter
        }
        callback(Characteristic.RESULT_SUCCESS);
        break;

      default:
        console.log(`[FTMS] Unknown op code: 0x${opCode.toString(16)}`);
        sendControlPointResponse(opCode, 0x02); // not supported
        callback(Characteristic.RESULT_SUCCESS);
        break;
    }
  },
});

function sendControlPointResponse(requestOpCode, resultCode) {
  // Response: [0x80, requestOpCode, resultCode]
  const buf = Buffer.from([0x80, requestOpCode, resultCode]);
  for (const cb of controlPointSubscribers.values()) {
    cb(buf);
  }
}

// ── FTMS Primary Service ──────────────────────────────────────────
const ftmsService = new PrimaryService({
  uuid: FTMS_SERVICE_UUID,
  characteristics: [
    ftmsFeatureChar,
    indoorBikeDataChar,
    controlPointChar,
    supportedPowerRangeChar,
  ],
});

// ── Build Indoor Bike Data packet ─────────────────────────────────
// Matches the parsing in trainer_repository.dart:_parseIndoorBikeData
function buildIndoorBikeData(watts, rpm) {
  // Flags: bit 2 (cadence present) + bit 6 (power present)
  // Bit 0 = 1 means speed NOT present (inverted flag per FTMS spec)
  const flags = 0x01 | 0x04 | 0x40; // no speed + cadence + power

  // Total: 2 (flags) + 2 (cadence) + 2 (power) = 6 bytes
  const buf = Buffer.alloc(6);
  buf.writeUInt16LE(flags, 0);
  buf.writeUInt16LE(rpm * 2, 2);  // cadence at 0.5 RPM resolution
  buf.writeInt16LE(watts, 4);      // instantaneous power (sint16)
  return buf;
}

// ── Notification loop ─────────────────────────────────────────────
let notifyInterval = null;

function startNotifying() {
  notifyInterval = setInterval(() => {
    const jitter = Math.floor(Math.random() * 6) - 3; // ±3W
    const w = Math.max(0, power + jitter);
    const buf = buildIndoorBikeData(w, cadence);

    for (const cb of bikeDataSubscribers.values()) {
      cb(buf);
    }
  }, 1000);
}

function stopNotifying() {
  if (notifyInterval) {
    clearInterval(notifyInterval);
    notifyInterval = null;
  }
}

// ── BLE lifecycle ─────────────────────────────────────────────────
bleno.on('stateChange', (state) => {
  console.log(`[BLE] Adapter state: ${state}`);
  if (state === 'poweredOn') {
    bleno.startAdvertising(DEVICE_NAME, [FTMS_SERVICE_UUID], (err) => {
      if (err) {
        console.error('[BLE] Advertising error:', err);
      }
    });
  } else {
    bleno.stopAdvertising();
    stopNotifying();
  }
});

bleno.on('advertisingStart', (err) => {
  if (err) {
    console.error('[BLE] Advertising failed:', err);
    return;
  }
  console.log(`[BLE] Advertising as "${DEVICE_NAME}" (FTMS 0x1826)`);
  bleno.setServices([ftmsService], (err) => {
    if (err) {
      console.error('[BLE] Set services error:', err);
    } else {
      console.log('[BLE] FTMS service registered');
      startNotifying();
      printStatus();
    }
  });
});

bleno.on('accept', (address) => {
  console.log(`[BLE] Central connected: ${address}`);
});

bleno.on('disconnect', (address) => {
  console.log(`[BLE] Central disconnected: ${address}`);
});

// ── Keyboard controls ─────────────────────────────────────────────
function printStatus() {
  process.stdout.write(
    `\r[SIM] Power: ${power}W | Cadence: ${cadence} RPM | Target: ${targetPower ?? '--'}W   `
  );
}

function printHelp() {
  console.log('\n  p/P — power -/+10W');
  console.log('  c/C — cadence -/+10 RPM');
  console.log('  q   — quit\n');
}

readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
}

process.stdin.on('keypress', (str, key) => {
  if (key.name === 'q' || (key.ctrl && key.name === 'c')) {
    console.log('\n[SIM] Shutting down...');
    stopNotifying();
    bleno.stopAdvertising();
    process.exit(0);
  }

  if (key.name === 'p') {
    power = key.shift ? Math.min(2000, power + 10) : Math.max(0, power - 10);
  } else if (key.name === 'c') {
    cadence = key.shift ? Math.min(200, cadence + 10) : Math.max(0, cadence - 10);
  } else {
    printHelp();
  }
  printStatus();
});

// ── Startup message ───────────────────────────────────────────────
console.log(`[SIM] FTMS Trainer Simulator — "${DEVICE_NAME}"`);
console.log('[SIM] Waiting for Bluetooth adapter...');
printHelp();

// ── Graceful shutdown ─────────────────────────────────────────────
process.on('SIGINT', () => {
  console.log('\n[SIM] Interrupted. Shutting down...');
  stopNotifying();
  bleno.stopAdvertising();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[SIM] Terminated. Shutting down...');
  stopNotifying();
  bleno.stopAdvertising();
  process.exit(0);
});

// ── Exports for programmatic use (by ftms_scenario.js) ────────────
module.exports = {
  setPower: (w) => { power = w; },
  setCadence: (c) => { cadence = c; },
  getPower: () => power,
  getCadence: () => cadence,
  getTargetPower: () => targetPower,
};
