// inle/wasm/hear.mjs -- letting the machine be heard. the samples are already in the shared
// ring by the time this matters (inle/wasm/horn.c, then cpu.mjs); what is left is the
// AudioWorklet that plays them, and a page may not start one until it has been touched.
// so both terminals hang `hearing` off the touches that focus the screen: it makes the
// context once and resumes it on every touch until it runs -- a finger grants nothing on
// the way down, only on the way up, so the press that builds it cannot always start it.
// until then cpu.mjs drains the ring off its own clock -- a machine that plays before the
// reader touches is never blocked, only unheard.
// c_live is what says which of the two is draining, and it follows the context's state:
// a suspended context plays nothing and must not be counted on to empty the ring.
import { ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played, c_live } from './cpu.mjs';

export function hearing(ring, ctl, said = (s) => console.warn(s)) {
  // the context AND the node are held here for the life of the page, and the node is why:
  // it takes no input, so nothing but this reference keeps it reachable, and a collected
  // worklet stops draining without saying so -- which the machine would meet as a device
  // that never empties. cpu.mjs survives that now; it should still not happen.
  let audio = null, horn = null, made = null, dead = false;
  const make = async () => {
    audio = new AudioContext();
    await audio.audioWorklet.addModule(new URL('./horn.js', import.meta.url));
    horn = new AudioWorkletNode(audio, 'horn', {
      numberOfInputs: 0, outputChannelCount: [2],
      processorOptions: { ring, ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played } });
    // the machine has been playing unheard, so the first sound lands mid-phrase: it comes
    // up over a second instead of all at once, and so does every return from a suspension
    const fade = audio.createGain();
    fade.gain.value = 0;
    horn.connect(fade).connect(audio.destination);
    let was = '';
    const state = () => {
      if (audio.state === was) return;
      was = audio.state;
      Atomics.store(ctl, c_live, was === 'running' ? 1 : 0);
      if (was !== 'running') return;
      const t = audio.currentTime;
      fade.gain.cancelScheduledValues(t);
      fade.gain.setValueAtTime(0, t);
      fade.gain.linearRampToValueAtTime(1, t + 1); };
    audio.addEventListener('statechange', state);
    state(); };                                       // a context born running raises no event
  return async () => {
    if (dead) return;
    try { if (!made) made = make(); await made; }
    catch (e) { dead = true; said('no sound: ' + e.message); return; }
    if (audio.state !== 'running') audio.resume().catch(() => {});   // not yet allowed: the next touch asks again
  }; }
