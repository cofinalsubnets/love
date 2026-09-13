// i/wasm/machine.js -- the machine island: love-wasm.wasm as inle, booted on the page.
// the kernel runs in a worker (cpu.mjs) because it never returns, the canvas is its
// framebuffer, the keyboard its serial line and an AudioWorklet its speaker; the two
// threads share one ring, which is what lets the kernel's idle really block. one island per .machine on
// the page, its parts found by class under it, so a page carries the markup
// (i/wasm/machine.html) and this script and no glue.
// a shared ring means the page must be CROSS-ORIGIN ISOLATED. a server that sends the
// two headers has it already (kiosko does); on a host that will not, coi.js asks for them
// with a service worker and one reload. no isolation, no machine -- said, not left blank.
// the module and its image are fetched from w/wasm/ -- where the tracked, committed
// pair lives -- unless data-wasm/data-image name them; data-boot is the boot line (default
// the shell), data-ram the RAM in MiB, data-cols the most columns worth reading, which
// is what settles how large a glyph is drawn. the machine takes its RAM at boot and never
// gives it back, so the default is a shell's and not a build's: `love seed` wants
// data-ram="1024", and ooms under 768.
import { ctl_n, ring_n, ring_at, shared_n } from './cpu.mjs';
import { glass } from './glass.mjs';
import { hearing } from './hear.mjs';

// the module is wasm64: an engine without memory64 says so instead of failing in silence
const memory64 = () => WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 5, 3, 1, 4, 0]));

// a key as the bytes a serial terminal sends: CR for Enter, DEL for Backspace, ESC
// sequences for the arrows and home/end, the control letters as themselves
const CSI = { Enter: [13], Backspace: [127], Tab: [9], Escape: [27], Delete: [27, 91, 51, 126],
              ArrowUp: [27, 91, 65], ArrowDown: [27, 91, 66], ArrowRight: [27, 91, 67], ArrowLeft: [27, 91, 68],
              Home: [27, 91, 72], End: [27, 91, 70], PageUp: [27, 91, 53, 126], PageDown: [27, 91, 54, 126] };

export async function loveMachine(root) {
  const q = c => root.querySelector('.' + c);
  const status = q('status'), canvas = q('fb');
  // ONE CONSOLE DOOR: the canvas is it. the worker is handed the framebuffer and quay paints
  // the guest's own terminal into it, cursor and erases obeyed, so nothing on this side
  // re-renders the serial line -- a second reading of a stream whose control bytes ARE the
  // rendering can only disagree with the first. what is left for the page to say is the
  // machine failing to start or stopping, which the canvas cannot show.
  const halt = t => { status.textContent = t; status.hidden = false; canvas.hidden = true; };

  if (!memory64()) return halt('this browser has no wasm memory64; the machine cannot boot here.');
  // coi.js reloads once to get the headers, so a page that arrives here unisolated has
  // already had its turn -- a service worker it could not install, or a file:// open.
  if (!window.crossOriginIsolated)
    return halt('this page is not cross-origin isolated, so there is no shared memory for the machine to run on. reloading usually fixes it.');

  const at = (k, d) => root.dataset[k] ?? d;
  const url = p => new URL(p, import.meta.url);

  // the ring: Int32 [0] the reader's head, [1] the writer's tail, [2] the wake count,
  // [3] a lift request (unused here), [4] a resize request and [5] [6] [7] its size,
  // [8]..[11] the horn's; then ring_n bytes of keys, and the horn's samples past those.
  // cpu.mjs reads it -- and it is the only door, the worker having no event loop to
  // deliver a postMessage to.
  const ring = new SharedArrayBuffer(shared_n);
  const ctl = new Int32Array(ring, 0, ctl_n), kb = new Uint8Array(ring, ring_at, ring_n);
  const push = bytes => {
    let tail = Atomics.load(ctl, 1);
    for (const b of bytes) {                       // full: the rest is dropped, as a uart's would be
      const n = (tail + 1) % ring_n;
      if (n === Atomics.load(ctl, 0)) break;
      kb[tail] = b; tail = n; }
    Atomics.store(ctl, 1, tail);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); };

  canvas.addEventListener('keydown', e => {
    let b = CSI[e.key];
    if (!b && e.key.length === 1) {
      const c = e.key.codePointAt(0);
      b = e.ctrlKey && c >= 64 && c < 128 ? [c & 31] : e.ctrlKey || e.metaKey || e.altKey ? null
        : [...new TextEncoder().encode(e.key)]; }
    if (!b) return;
    e.preventDefault(); push(b); });
  // SOUND: the samples come out of the same ring and hear.mjs's worklet plays them, from
  // the first touch of the screen, which is the earliest a page is allowed to. no sound is
  // not the island failing, so a refusal goes to the console and the machine runs on.
  const hear = hearing(ring, ctl);
  canvas.addEventListener('pointerdown', hear);
  canvas.addEventListener('keydown', hear);
  // a chip types its line at the machine, the way the repl island's chips ran theirs
  for (const ch of root.querySelectorAll('[data-type]'))
    ch.addEventListener('click', () => { push([...new TextEncoder().encode(ch.dataset.type), 13]);
                                         canvas.focus(); });

  status.textContent = 'fetching the machine...';
  let wasm, image;
  try {
    wasm = await (await fetch(url(at('wasm', '../../w/wasm/love-wasm.wasm')))).arrayBuffer();
    image = await fetch(url(at('image', '../../w/wasm/love-wasm.image')))
      .then(r => r.ok ? r.arrayBuffer() : null).catch(() => null);
  } catch (e) { return halt(`the machine did not load (${e.message}); the page needs to be served over http.`); }

  // the canvas stays on THIS thread and the worker sends frames (see cpu.mjs's blit): a
  // transferred canvas only reaches its placeholder at a task checkpoint, and the worker
  // never has one -- its idle is an Atomics.wait inside the boot's own task.
  const ctx = canvas.getContext('2d');
  const cpu = new Worker(url('cpu.mjs'), { type: 'module' });
  // the serial run is not rendered -- the canvas already shows it -- but its ARRIVAL is
  // the machine's proof of life, and the page owes the reader that: `status` stays up
  // until the machine has spoken once, so a machine that never boots says so instead of
  // leaving a black rectangle. a reset boots it again, which the canvas shows itself.
  let woke = false;
  cpu.onmessage = ({ data: m }) => {
    if (m.frame) {
      // the backing store follows the FRAME, never the measurement: the machine may refuse
      // a size (k_fb_reseat's bounds), and a canvas sized to what was asked for would then
      // show the frame in a corner of itself. resizing it also clears it, so only on a change.
      if (canvas.width !== m.w || canvas.height !== m.h) canvas.width = m.w, canvas.height = m.h;
      ctx.putImageData(new ImageData(new Uint8ClampedArray(m.frame), m.w, m.h), 0, 0);
      if (!woke) { woke = true; status.hidden = true; } }
    else if (m.fault) halt('the machine faulted: ' + m.fault); };
  cpu.onerror = e => halt('the machine stopped: ' + e.message);
  // the canvas measured as REAL pixels -- its own box times the device ratio -- and the
  // zoom a glyph pixel gets there. the kernel settles rows and columns from the two, so
  // the island's shape is a layout question and nothing the console has to live inside.
  const cols = Number(at('cols', 80));
  const fb = { ...glass(canvas, cols), post: true };
  cpu.postMessage({ wasm, ring, ram: Number(at('ram', 256)), cmd: at('boot', 'sh'), fb, image },
                  image ? [wasm, image] : [wasm]);
  // the box reflowed -- the window resized, or the island's column did. the new size goes
  // into the ring and the kernel re-makes its console at it; the canvas itself is left
  // alone until a frame comes back at the size the machine actually took.
  let pending = 0;
  const ask = () => {
    const box = canvas.getBoundingClientRect();
    if (canvas.hidden || box.width < 1 || box.height < 1) return;
    const g = glass(canvas, cols);
    Atomics.store(ctl, 5, g.w); Atomics.store(ctl, 6, g.h); Atomics.store(ctl, 7, g.scale);
    Atomics.store(ctl, 4, 1);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); };
  // a drag is hundreds of reflows and each one re-makes a console and frees a grid, so the
  // machine hears the size the reader stopped at rather than every size on the way there
  new ResizeObserver(() => { clearTimeout(pending); pending = setTimeout(ask, 150); })
    .observe(canvas);
  status.textContent = 'the machine is waking...';
  canvas.focus({ preventScroll: true });
}

document.querySelectorAll('.machine').forEach(loveMachine);
