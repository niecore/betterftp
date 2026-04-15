#!/usr/bin/env node

/**
 * FTMS Scripted Scenario — Ramp Test Simulation
 *
 * Runs the FTMS simulator with a pre-defined power/cadence curve
 * that mimics a short ramp test (~55s). Used for automated E2E tests.
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

const DEVICE_NAME = 'BetterTrainerSimulator';

// ── Scenario Definition ───────────────────────────────────────────
const SCENARIO = [
  { name: 'Warmup',  durationMs: 10000, power: 100, cadence: 85 },
  { name: 'Stage 1', durationMs: 10000, power: 120, cadence: 88 },
  { name: 'Stage 2', durationMs: 10000, power: 140, cadence: 90 },
  { name: 'Stage 3', durationMs: 10000, power: 160, cadence: 92 },
  { name: 'Stage 4', durationMs: 10000, power: 180, cadence: 94 },
  { name: 'Exhaust', durationMs: 5000,  power: 60,  cadence: 0  },
];

// ── Mutable state ─────────────────────────────────────────────────
let power = SCENARIO[0].power;
let cadence = SCENARIO[0].cadence;

const bikeDataSubscribers = new Map();
const controlPointSubscribers = new Map();

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

// ── Characteristics ───────────────────────────────────────────────
const indoorBikeDataChar = new Characteristic({
  uuid: INDOOR_BIKE_DATA_UUID,
  properties: ['notify'],
  onSubscribe: (maxValueSize, updateValueCallback) => {
    console.log(`[BLE] Subscribed to Indoor Bike Data (mtu=${maxValueSize})`);
    bikeDataSubscribers.set('bike', updateValueCallback);
    // Start the scenario once the central is ready to receive data
    setTimeout(() => startScenario(), 500);
  },
  onUnsubscribe: () => { bikeDataSubscribers.delete('bike'); },
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
          const tp = data.readInt16LE(1);
          console.log(`[FTMS] Target power: ${tp}W`);
          sendControlPointResponse(0x05, 0x01);
        }
        break;
      default:
        sendControlPointResponse(opCode, 0x02);
    }
    callback(Characteristic.RESULT_SUCCESS);
  },
});

const ftmsService = new PrimaryService({
  uuid: FTMS_SERVICE_UUID,
  characteristics: [ftmsFeatureChar, indoorBikeDataChar, controlPointChar, supportedPowerRangeChar],
});

// ── BLE lifecycle ─────────────────────────────────────────────────
let scenarioStarted = false;

bleno.on('stateChange', (state) => {
  console.log(`[BLE] Adapter state: ${state}`);
  if (state === 'poweredOn') {
    bleno.startAdvertising(DEVICE_NAME, [FTMS_SERVICE_UUID], (err) => {
      if (err) console.error('[BLE] Advertising error:', err);
    });
  } else {
    bleno.stopAdvertising();
  }
});

bleno.on('advertisingStart', (err) => {
  if (err) { console.error('[BLE] Advertising failed:', err); return; }
  console.log(`[BLE] Advertising as "${DEVICE_NAME}" (FTMS 0x1826)`);
  bleno.setServices([ftmsService], (err) => {
    if (err) { console.error('[BLE] Set services error:', err); return; }
    console.log('[BLE] FTMS service registered');
    console.log('[Scenario] Waiting for central to connect...\n');
  });
});

bleno.on('accept', (address) => {
  console.log(`[BLE] Central connected: ${address}`);
});

bleno.on('disconnect', (address) => {
  console.log(`[BLE] Central disconnected: ${address}`);
});

// ── Scenario Runner ───────────────────────────────────────────────
let phaseIndex = 0;
let phaseStartTime = 0;
let scenarioTimer = null;

function jitter(base) {
  return base + Math.floor(Math.random() * 10) - 5; // ±5W
}

function tick() {
  const phase = SCENARIO[phaseIndex];
  if (!phase) {
    console.log('\n[Scenario] All phases complete. Waiting for next connection...');
    scenarioStarted = false;
    return;
  }

  const elapsed = Date.now() - phaseStartTime;

  // Advance to next phase?
  if (elapsed >= phase.durationMs) {
    phaseIndex++;
    phaseStartTime = Date.now();
    const next = SCENARIO[phaseIndex];
    if (next) {
      power = next.power;
      cadence = next.cadence;
      console.log(`\n[Scenario] >> ${next.name}: ${next.power}W @ ${next.cadence} RPM (${next.durationMs / 1000}s)`);
    }
    scenarioTimer = setTimeout(tick, 1000);
    return;
  }

  // Emit data
  const w = cadence > 0 ? jitter(power) : power;
  const buf = buildIndoorBikeData(w, cadence);
  for (const cb of bikeDataSubscribers.values()) {
    cb(buf);
  }

  const remaining = Math.ceil((phase.durationMs - elapsed) / 1000);
  process.stdout.write(
    `\r[${phase.name}] ${w}W @ ${cadence} RPM — ${remaining}s left   `
  );

  scenarioTimer = setTimeout(tick, 1000);
}

function startScenario() {
  if (scenarioStarted) return;
  scenarioStarted = true;

  // Reset state for a fresh run
  phaseIndex = 0;
  power = SCENARIO[0].power;
  cadence = SCENARIO[0].cadence;
  if (scenarioTimer) clearTimeout(scenarioTimer);

  console.log(`[Scenario] Starting (${SCENARIO.length} phases):`);
  SCENARIO.forEach((p, i) => {
    console.log(`  ${i + 1}. ${p.name}: ${p.power}W @ ${p.cadence} RPM for ${p.durationMs / 1000}s`);
  });

  const first = SCENARIO[0];
  console.log(`\n[Scenario] >> ${first.name}: ${first.power}W @ ${first.cadence} RPM (${first.durationMs / 1000}s)`);
  phaseStartTime = Date.now();
  tick();
}

// ── Startup ───────────────────────────────────────────────────────
console.log(`[Scenario] FTMS Trainer "${DEVICE_NAME}" — Scripted Ramp Test`);
console.log('[Scenario] Waiting for Bluetooth adapter...\n');

// ── Graceful shutdown ─────────────────────────────────────────────
function shutdown() {
  console.log('\n[Scenario] Shutting down...');
  if (scenarioTimer) clearTimeout(scenarioTimer);
  bleno.stopAdvertising();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
