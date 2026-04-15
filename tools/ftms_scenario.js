#!/usr/bin/env node

/**
 * FTMS ERG + HR Simulator — BetterFTP Sim
 *
 * Simulates an ERG-mode indoor trainer (FTMS 0x1826) AND a heart rate
 * monitor (HR 0x180D) from a single BLE peripheral. Echoes back whatever
 * target power the app sets (via FTMS Set Target Power) with ±5W jitter,
 * at a steady cadence of 85 RPM. HR is derived from target power.
 * Emits Indoor Bike Data and HR Measurement every second.
 *
 * Usage:
 *   cd tools && npm install   (one-time)
 *   node tools/ftms_scenario.js
 */

const bleno = require('@stoprocent/bleno');
const PrimaryService = bleno.PrimaryService;
const Characteristic = bleno.Characteristic;

// ── FTMS UUIDs ────────────────────────────────────────────────────
const FTMS_SERVICE_UUID           = '1826';
const INDOOR_BIKE_DATA_UUID       = '2AD2';
const CONTROL_POINT_UUID          = '2AD9';
const FTMS_FEATURE_UUID           = '2ACC';
const SUPPORTED_POWER_RANGE_UUID  = '2AD8';

// ── HR Service UUIDs ──────────────────────────────────────────────
const HR_SERVICE_UUID             = '180D';
const HR_MEASUREMENT_UUID         = '2A37';

const DEVICE_NAME = 'BetterFTP Sim';

// ── Mutable state ─────────────────────────────────────────────────
let targetPower = 100;   // Updated by Set Target Power commands
const CADENCE = 85;      // Steady RPM

const bikeDataSubscribers = new Map();
const controlPointSubscribers = new Map();
const hrSubscribers = new Map();

// ── Build Indoor Bike Data packet ─────────────────────────────────
function buildIndoorBikeData(watts, rpm) {
  const flags = 0x01 | 0x04 | 0x40; // no speed + cadence + power
  const buf = Buffer.alloc(6);
  buf.writeUInt16LE(flags, 0);
  buf.writeUInt16LE(rpm * 2, 2);  // 0.5 RPM resolution
  buf.writeInt16LE(watts, 4);
  return buf;
}

function sendControlPointResponse(requestOpCode, resultCode) {
  const buf = Buffer.from([0x80, requestOpCode, resultCode]);
  for (const cb of controlPointSubscribers.values()) {
    cb(buf);
  }
}

function jitter(base) {
  return base + Math.floor(Math.random() * 10) - 5; // ±5W
}

// ── Characteristics ───────────────────────────────────────────────
const indoorBikeDataChar = new Characteristic({
  uuid: INDOOR_BIKE_DATA_UUID,
  properties: ['notify'],
  onSubscribe: (maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Subscribed to Indoor Bike Data (mtu=${maxValueSize})`);
    bikeDataSubscribers.set('bike', updateValueCallback);
    startEmitting();
  },
  onUnsubscribe: () => {
    bikeDataSubscribers.delete('bike');
    stopEmitting();
  },
});

const ftmsFeatureChar = new Characteristic({
  uuid: FTMS_FEATURE_UUID,
  properties: ['read'],
  onReadRequest: (offset, callback) => {
    const buf = Buffer.alloc(8, 0);
    buf.writeUInt32LE(0x44, 0); // cadence + power
    buf.writeUInt32LE(0x02, 4); // target power
    callback(Characteristic.RESULT_SUCCESS, buf.slice(offset));
  },
});

const supportedPowerRangeChar = new Characteristic({
  uuid: SUPPORTED_POWER_RANGE_UUID,
  properties: ['read'],
  onReadRequest: (offset, callback) => {
    const buf = Buffer.alloc(6);
    buf.writeInt16LE(0, 0);
    buf.writeInt16LE(2000, 2);
    buf.writeUInt16LE(1, 4);
    callback(Characteristic.RESULT_SUCCESS, buf.slice(offset));
  },
});

const controlPointChar = new Characteristic({
  uuid: CONTROL_POINT_UUID,
  properties: ['write', 'indicate'],
  onSubscribe: (maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Subscribed to Control Point (mtu=${maxValueSize})`);
    controlPointSubscribers.set('cp', updateValueCallback);
  },
  onUnsubscribe: () => { controlPointSubscribers.delete('cp'); },
  onWriteRequest: (data, offset, withoutResponse, callback) => {
    if (data.length < 1) { callback(Characteristic.RESULT_UNLIKELY_ERROR); return; }
    const opCode = data[0];
    switch (opCode) {
      case 0x00:
        console.log('[FTMS] Control requested — granted');
        sendControlPointResponse(0x00, 0x01);
        break;
      case 0x01:
        console.log('[FTMS] Reset');
        sendControlPointResponse(0x01, 0x01);
        break;
      case 0x05:
        if (data.length >= 3) {
          targetPower = data.readInt16LE(1);
          console.log(`[FTMS] Target power set: ${targetPower}W`);
          sendControlPointResponse(0x05, 0x01);
        }
        break;
      case 0x07:
        console.log('[FTMS] Start/Resume');
        sendControlPointResponse(0x07, 0x01);
        break;
      default:
        console.log(`[FTMS] Unknown opcode: 0x${opCode.toString(16)}`);
        sendControlPointResponse(opCode, 0x02);
    }
    callback(Characteristic.RESULT_SUCCESS);
  },
});

const ftmsService = new PrimaryService({
  uuid: FTMS_SERVICE_UUID,
  characteristics: [ftmsFeatureChar, indoorBikeDataChar, controlPointChar, supportedPowerRangeChar],
});

// ── HR Measurement Characteristic ────────────────────────────────
const hrMeasurementChar = new Characteristic({
  uuid: HR_MEASUREMENT_UUID,
  properties: ['notify'],
  onSubscribe: (maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Subscribed to HR Measurement (mtu=${maxValueSize})`);
    hrSubscribers.set('hr', updateValueCallback);
  },
  onUnsubscribe: () => {
    hrSubscribers.delete('hr');
  },
});

const hrService = new PrimaryService({
  uuid: HR_SERVICE_UUID,
  characteristics: [hrMeasurementChar],
});

// ── BLE lifecycle ─────────────────────────────────────────────────
bleno.on('stateChange', (state) => {
  console.log(`[BLE] Adapter state: ${state}`);
  if (state === 'poweredOn') {
    bleno.startAdvertising(DEVICE_NAME, [FTMS_SERVICE_UUID, HR_SERVICE_UUID], (err) => {
      if (err) console.error('[BLE] Advertising error:', err);
    });
  } else {
    bleno.stopAdvertising();
  }
});

bleno.on('advertisingStart', (err) => {
  if (err) { console.error('[BLE] Advertising failed:', err); return; }
  console.log(`[BLE] Advertising as "${DEVICE_NAME}" (FTMS 0x1826 + HR 0x180D)`);
  bleno.setServices([ftmsService, hrService], (err) => {
    if (err) { console.error('[BLE] Set services error:', err); return; }
    console.log('[BLE] FTMS + HR services registered');
    console.log('[Simulator] Waiting for central to connect...\n');
  });
});

bleno.on('accept', (address) => {
  console.log(`[BLE] Central connected: ${address}`);
});

bleno.on('disconnect', (address) => {
  console.log(`[BLE] Central disconnected: ${address}`);
  stopEmitting();
});

// ── Data emitter ─────────────────────────────────────────────────
let emitTimer = null;

function startEmitting() {
  if (emitTimer) return;
  console.log('[Simulator] Emitting Indoor Bike Data + HR every 1s');
  emitTimer = setInterval(() => {
    const w = jitter(targetPower);
    const rpm = jitter(CADENCE);
    const buf = buildIndoorBikeData(w, rpm);
    for (const cb of bikeDataSubscribers.values()) {
      cb(buf);
    }

    // Stagger HR notification by 500ms to avoid BLE transmit queue
    // overflow — back-to-back updateValue calls drop the second one.
    const baseHr = 70 + Math.floor(targetPower / 5);
    const hr = Math.min(200, Math.max(50, baseHr + Math.floor(Math.random() * 10) - 5));
    setTimeout(() => {
      const hrBuf = Buffer.from([0x00, hr]);
      for (const cb of hrSubscribers.values()) {
        cb(hrBuf);
      }
    }, 500);

    process.stdout.write(`\r[ERG] ${w}W (target: ${targetPower}W) @ ${rpm} RPM | HR ${hr} BPM   `);
  }, 1000);
}

function stopEmitting() {
  if (emitTimer) {
    clearInterval(emitTimer);
    emitTimer = null;
    console.log('\n[Simulator] Stopped emitting data');
  }
}

// ── Startup ───────────────────────────────────────────────────────
console.log(`[Simulator] FTMS ERG Trainer + HR Monitor "${DEVICE_NAME}"`);
console.log('[Simulator] Waiting for Bluetooth adapter...\n');

// ── Graceful shutdown ─────────────────────────────────────────────
function shutdown() {
  console.log('\n[Simulator] Shutting down...');
  stopEmitting();
  bleno.stopAdvertising();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
