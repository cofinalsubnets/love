// i/wasm/horn.js -- the machine's speaker: an AudioWorklet processor draining the horn's
// ring. the kernel's k_horn_write lands 16-bit stereo frames there (i/wasm/horn.c, then
// cpu.mjs); this end takes them at the context's own rate and publishes how many SOURCE
// frames it has consumed, which is the whole of k_horn_lag's honesty -- the tower's loop
// uses that lag as its clock, so a synthetic one would drift the music against the game.
// an empty ring is silence, never a loop of the last block: a writer that stops stops.
//
// processorOptions carries the ring and the layout, cpu.mjs being the one file that
// spells it and a worklet having no import of its own worth paying for.
class Horn extends AudioWorkletProcessor {
  constructor(o) {
    super();
    const p = o.processorOptions;
    this.ctl = new Int32Array(p.ring, 0, p.ctl_n);
    this.pcm = new Int16Array(p.ring, p.horn_at, p.horn_n * 2);
    this.mask = p.horn_n - 1;
    this.c_rate = p.c_rate, this.c_wrote = p.c_wrote, this.c_played = p.c_played;
    this.frac = 0; }

  // the guest's rate and the context's need not agree, and a page does not get to pick
  // the context's: the step is their ratio, nearest-sample, and it is exactly 1 wherever
  // the two do agree -- which is every browser at 48k, the rate harp writes.
  process(_in, out) {
    const L = out[0][0], R = out[0][1] ?? out[0][0];
    const rate = Atomics.load(this.ctl, this.c_rate);
    if (!rate) { this.frac = 0; return true; }            // closed: the block is already silent
    const step = rate / sampleRate, w = Atomics.load(this.ctl, this.c_wrote);
    let p = Atomics.load(this.ctl, this.c_played);
    for (let i = 0; i < L.length; i++) {
      if (((w - p) | 0) <= 0) { L[i] = 0, R[i] = 0; continue; }   // underrun: silence, and hold
      const j = (p & this.mask) * 2;
      L[i] = this.pcm[j] / 32768, R[i] = this.pcm[j + 1] / 32768;
      this.frac += step;
      const k = Math.floor(this.frac);
      this.frac -= k;
      p = (p + k) | 0; }
    Atomics.store(this.ctl, this.c_played, p);
    return true; } }

registerProcessor('horn', Horn);
