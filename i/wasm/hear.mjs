// i/wasm/hear.mjs -- letting the machine be heard. the samples are already in the shared
// ring by the time this matters (i/wasm/horn.c, then cpu.mjs); what is left is the
// AudioWorklet that plays them, and a page may not start one until it has been touched.
// so both terminals hang `hearing` off the click that focuses the screen and it does its
// work once. until then cpu.mjs drains the ring off its own clock -- a machine that plays
// before the reader clicks is never blocked, only unheard.
// c_live is what says which of the two is draining, and it follows the context's state:
// a suspended context plays nothing and must not be counted on to empty the ring.
import { ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played, c_live } from './cpu.mjs';

export function hearing(ring, ctl, said = (s) => console.warn(s)) {
  // the context AND the node are held here for the life of the page, and the node is why:
  // it takes no input, so nothing but this reference keeps it reachable, and a collected
  // worklet stops draining without saying so -- which the machine would meet as a device
  // that never empties. cpu.mjs survives that now; it should still not happen.
  let audio = null, horn = null;
  return async () => {
    if (audio) return;
    try {
      audio = new AudioContext();
      await audio.audioWorklet.addModule(new URL('./horn.js', import.meta.url));
      horn = new AudioWorkletNode(audio, 'horn', {
        numberOfInputs: 0, outputChannelCount: [2],
        processorOptions: { ring, ctl_n, horn_at, horn_n, c_rate, c_wrote, c_played } });
      horn.connect(audio.destination);
      const live = () => Atomics.store(ctl, c_live, audio.state === 'running' ? 1 : 0);
      audio.addEventListener('statechange', live);
      await audio.resume();
      live(); }
    catch (e) { said('no sound: ' + e.message); } }; }
