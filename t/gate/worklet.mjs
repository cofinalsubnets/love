// t/gate/worklet.mjs -- the page's speaker, asked without a page. i/wasm/horn.js is an
// AudioWorklet processor and no lane in this tree has a browser, so its laws would
// otherwise be read by nobody: the three globals a worklet runs under are stubbed here,
// the ring is filled the way cpu.mjs's horn_write fills it, and the blocks are read back.
// what is asked is what a speaker can get wrong in silence -- the order, the two channels,
// the seam where the ring wraps, an empty ring, and the consumed count that IS k_horn_lag.
// usage: node t/gate/worklet.mjs
import { ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played, shared_n } from '../../i/wasm/cpu.mjs';

let made = null;
globalThis.AudioWorkletProcessor = class { constructor() { } };
globalThis.registerProcessor = (_name, k) => { made = k; };
globalThis.sampleRate = 48000;
await import('../../i/wasm/horn.js');

const ring = new SharedArrayBuffer(shared_n);
const ctl = new Int32Array(ring, 0, ctl_n);
const pcm = new Int16Array(ring, horn_at, horn_n * 2);
const horn = new made({ processorOptions: { ring, ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played } });

// one render quantum, and one guest write: the right channel is the left negated, so a
// block that has taken its channels from one place says so
const block = () => { const L = new Float32Array(128), R = new Float32Array(128);
                      horn.process([], [[L, R]]); return [L, R]; };
const write = (frames, f) => {
  const w = Atomics.load(ctl, c_wrote);
  for (let i = 0; i < frames; i++) {
    const j = ((w + i) & (horn_n - 1)) * 2;
    pcm[j] = f(i), pcm[j + 1] = -f(i); }
  Atomics.store(ctl, c_wrote, (w + frames) | 0); };
const run = (rate, frames, f) => {
  Atomics.store(ctl, c_wrote, 0), Atomics.store(ctl, c_played, 0);
  Atomics.store(ctl, c_rate, rate);
  write(frames, f); };

let bad = 0;
const law = (ok, m) => { if (ok) console.log('  ' + m); else bad++, console.log('FAIL worklet: ' + m); };
const s16 = (x) => Math.round(x * 32768);

// a horn nobody opened plays nothing, and takes nothing
write(256, (i) => 1000 + i);
let [L] = block();
law(L.every((x) => x === 0) && !Atomics.load(ctl, c_played), 'a closed horn plays nothing');

// the ordinary case: the context at the guest's own rate, one sample for one
run(48000, 256, (i) => 1000 + i);
let R;
[L, R] = block();
law(L.every((x, i) => s16(x) === 1000 + i), 'the ramp comes back sample for sample');
law(Atomics.load(ctl, c_played) === 128, 'and the block consumed 128 source frames');
[L, R] = block();
law(R.every((x, i) => s16(x) === -(1128 + i)), 'the right channel is its own');

// past the writer: silence, and the count stops where the samples do
block();
law(block()[0].every((x) => x === 0), 'an empty ring is silence, not the last block again');
law(Atomics.load(ctl, c_played) === 256, 'and nothing past the writer is played');

// the seam: a block that starts 64 frames from the end of the ring
Atomics.store(ctl, c_wrote, horn_n - 64), Atomics.store(ctl, c_played, horn_n - 64);
write(128, (i) => 3000 + i);
law(block()[0].every((x, i) => s16(x) === 3000 + i), 'a block across the wrap is whole');

// and a context faster than the guest, which is any browser that would not take the rate
run(24000, 256, (i) => 5000 + i);
[L] = block();
law(s16(L[0]) === 5000 && s16(L[2]) === 5001 && Atomics.load(ctl, c_played) === 64,
    'half the rate takes half the frames');

// ..and a third of it, which is the rate the walk's song writes at. the line between two
// source samples is walked rather than the near one held: at a third the second output
// sits a third of the way up and the third two thirds, so a ramp climbs by thirds. the
// ratio is not a whole number of output frames, so the accumulator carries the remainder:
// 128 out at a third is 42 source frames and two thirds of a third left over.
run(16000, 256, (i) => 7000 + i);
[L] = block();
law(s16(L[0]) === 7000 && s16(L[1]) === 7000 && s16(L[2]) === 7001 && s16(L[3]) === 7001,
    'a third of the rate walks the line between samples');
law(Atomics.load(ctl, c_played) === 42, '..and takes a third of them, remainder carried');

console.log(bad ? `FAIL worklet: ${bad} of the speaker's laws` : '  worklet: ok -- i/wasm/horn.js without a page');
process.exitCode = bad ? 1 : 0;
