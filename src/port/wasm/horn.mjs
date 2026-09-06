// src/port/wasm/horn.mjs -- the horn under the loader: love writes PCM to a (horn ..)
// port, the sink taps its accepted frames (src/host/horn.c ai_horn_tap -> host.c's ring),
// and the loader drains that ring into WebAudio. node has no AudioContext, so this stubs
// one and proves the whole path: the tapped samples reach a scheduled buffer at the rate.
// usage: node src/port/wasm/horn.mjs [--love <love.wasm>]
import { pathToFileURL } from 'node:url';

const argv = process.argv.slice(2);
let mod = new URL('../../../out/wasm/love.wasm', import.meta.url).href;
if (argv[0] === '--love') mod = pathToFileURL(argv[1]).href;

// a minimal WebAudio, enough for loader.horn.pull to schedule into
let scheduled = [];
globalThis.AudioContext = class {
  constructor() { this.state = 'running'; this.currentTime = 0; this.destination = {}; }
  resume() { this.state = 'running'; }
  createBuffer(ch, frames, rate) { const d = Array.from({ length: ch }, () => new Float32Array(frames));
    return { numberOfChannels: ch, length: frames, sampleRate: rate, getChannelData: (c) => d[c] }; }
  createBufferSource() { return { buffer: null, connect() {}, start(at) { scheduled.push({ at, buf: this.buffer }); } }; }
};

const { default: Love } = await import('./loader.js');
const M = await Love({ wasm: new URL(mod) });
if (M.ccall('ai_init', 'number', [], []) !== 0) { console.error('ai_init failed'); process.exit(1); }
const ev = (s) => { const n = M.lengthBytesUTF8(s) + 1, p = M._malloc(n); M.stringToUTF8(s, p, n);
  M.ccall('ai_eval', 'number', ['number'], [p]); M._free(p);
  M.ccall('ai_out_reset', 'null', [], []); };

let fails = 0;
const ok = (c, what) => { if (!c) { fails++; console.error('  FAIL: ' + what); } };

M.horn.resume();
// a stereo horn at 8k, a plain ramp so the samples are recognisable, then flush
ev("(: h (horn 8000 2) _ (say h (string (map (\\ i (i % 251)) (jot 1600)))) (flush h))");
ok(M.ccall('ai_horn_rate', 'number', [], []) === 8000, 'the ring carries the rate');
ok(M.ccall('ai_horn_chans', 'number', [], []) === 2, 'and the channel count');
const frames = M.horn.pull();
ok(frames === 400, `the sink's accepted frames reach the buffer (got ${frames})`);   // 1600 bytes = 400 stereo frames
ok(scheduled.length === 1, `one buffer scheduled (got ${scheduled.length})`);
if (scheduled.length) { const b = scheduled[0].buf;
  ok(b.sampleRate === 8000 && b.numberOfChannels === 2 && b.length === 400, 'the buffer is 400 stereo frames at 8k');
  // channel 0, frame 3 is left sample 3: bytes 12,13 of the payload (12, 13) as int16 LE
  const c0 = b.getChannelData(0), want = (12 | (13 << 8)) / 32768;
  ok(Math.abs(c0[3] - want) < 1e-6, `the tapped samples are love's PCM (${c0[3]} vs ${want})`); }

if (fails) { console.error(`WASM HORN FAILED (${fails})`); process.exit(1); }
console.log('  horn: ok -- love writes PCM, the sink taps it, the loader plays it (WebAudio)');
