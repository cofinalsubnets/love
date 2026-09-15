// inle/wasm/horn.js -- the machine's speaker: an AudioWorklet processor draining the horn's
// ring. the kernel's k_horn_write lands 16-bit stereo frames there (inle/wasm/horn.c, then
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
  // the context's: the step is their ratio, and a sample between two of the guest's is
  // the line between them. the step is exactly 1 where the two agree, and then frac
  // stays 0 and every sample is its own.
  process(_in, out) {
    // a processor that THROWS is never called again -- the node is disabled for the life
    // of the page, and the machine meets that as a device that stopped emptying. so the
    // shape of the block is asked rather than assumed.
    if (!out.length || !out[0].length) return true;
    const L = out[0][0], R = out[0][1] ?? out[0][0];
    const rate = Atomics.load(this.ctl, this.c_rate);
    if (!rate) { this.frac = 0; return true; }            // closed: the block is already silent
    const step = rate / sampleRate, w = Atomics.load(this.ctl, this.c_wrote);
    let p = Atomics.load(this.ctl, this.c_played);
    const pcm = this.pcm, mask = this.mask;
    for (let i = 0; i < L.length; i++) {
      const n = (w - p) | 0;
      if (n <= 0) { L[i] = 0, R[i] = 0; continue; }   // underrun: silence, and hold
      const j = (p & mask) * 2, k = n > 1 ? ((p + 1) & mask) * 2 : j, f = this.frac;
      L[i] = (pcm[j] + (pcm[k] - pcm[j]) * f) / 32768;
      R[i] = (pcm[j + 1] + (pcm[k + 1] - pcm[j + 1]) * f) / 32768;
      this.frac += step;
      const d = Math.floor(this.frac);
      this.frac -= d;
      p = (p + d) | 0; }
    Atomics.store(this.ctl, this.c_played, p);
    return true; } }

registerProcessor('horn', Horn);
