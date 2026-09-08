// inle/wasm/machine.js -- the machine island: love-wasm.wasm as inle, booted on the page.
// the kernel runs in a worker (cpu.mjs) because it never returns, the canvas is its
// framebuffer and the keyboard its serial line; the two threads share one ring of key
// bytes, which is what lets the kernel's idle really block. one island per .machine on
// the page, its parts found by class under it, so a page carries the markup
// (inle/wasm/machine.html) and this script and no glue.
// ⚠ a shared ring means the page must be CROSS-ORIGIN ISOLATED. a server that sends the
// two headers has it already (kiosko does); on a host that will not, coi.js asks for them
// with a service worker and one reload. no isolation, no machine -- said, not left blank.
// the module and its image are fetched beside this file unless data-wasm/data-image name
// them; data-boot is the boot line (default the shell), data-ram the RAM in MiB.
import { ring_n, ring_at, shared_n } from './cpu.mjs';

// the module is wasm64: an engine without memory64 says so instead of failing in silence
const memory64 = () => WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 5, 3, 1, 4, 0]));

// a key as the bytes a serial terminal sends: CR for Enter, DEL for Backspace, ESC
// sequences for the arrows and home/end, the control letters as themselves
const CSI = { Enter: [13], Backspace: [127], Tab: [9], Escape: [27], Delete: [27, 91, 51, 126],
              ArrowUp: [27, 91, 65], ArrowDown: [27, 91, 66], ArrowRight: [27, 91, 67], ArrowLeft: [27, 91, 68],
              Home: [27, 91, 72], End: [27, 91, 70], PageUp: [27, 91, 53, 126], PageDown: [27, 91, 54, 126] };

export async function loveMachine(root) {
  const q = c => root.querySelector('.' + c);
  const status = q('status'), canvas = q('fb'), serial = q('serial');
  const say = s => { serial.textContent = (serial.textContent + s).slice(-4000);
                     serial.scrollTop = serial.scrollHeight; };
  const halt = t => { status.textContent = t; status.hidden = false; canvas.hidden = true; };

  if (!memory64()) return halt('this browser has no wasm memory64; the machine cannot boot here.');
  // coi.js reloads once to get the headers, so a page that arrives here unisolated has
  // already had its turn -- a service worker it could not install, or a file:// open.
  if (!window.crossOriginIsolated)
    return halt('this page is not cross-origin isolated, so there is no shared memory for the machine to run on. reloading usually fixes it.');

  const at = (k, d) => root.dataset[k] ?? d;
  const url = p => new URL(p, import.meta.url);

  // the ring: Int32 [0] the reader's head, [1] the writer's tail, [2] the wake count,
  // [3] a lift request (unused here); then ring_n bytes of keys. cpu.mjs reads it.
  const ring = new SharedArrayBuffer(shared_n);
  const ctl = new Int32Array(ring, 0, 4), kb = new Uint8Array(ring, ring_at, ring_n);
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
  // a chip types its line at the machine, the way the repl island's chips ran theirs
  for (const ch of root.querySelectorAll('[data-type]'))
    ch.addEventListener('click', () => { push([...new TextEncoder().encode(ch.dataset.type), 13]);
                                         canvas.focus(); });

  status.textContent = 'fetching the machine...';
  let wasm, image;
  try {
    wasm = await (await fetch(url(at('wasm', 'love-wasm.wasm')))).arrayBuffer();
    image = await fetch(url(at('image', 'love-wasm.image')))
      .then(r => r.ok ? r.arrayBuffer() : null).catch(() => null);
  } catch (e) { return halt(`the machine did not load (${e.message}); the page needs to be served over http.`); }

  const off = canvas.transferControlToOffscreen();
  const cpu = new Worker(url('cpu.mjs'), { type: 'module' });
  cpu.onmessage = ({ data: m }) => {
    if (m.serial !== undefined) say(m.serial);
    else if (m.reset) say('\n; reset\n');
    else if (m.fault) say('\n; fault: ' + m.fault + '\n'); };
  cpu.onerror = e => say('\n; worker: ' + e.message + '\n');
  cpu.postMessage({ wasm, ring, ram: Number(at('ram', 256)), cmd: at('boot', 'sh'),
                    fb: { w: canvas.width, h: canvas.height, canvas: off }, image },
                  image ? [wasm, off, image] : [wasm, off]);
  status.hidden = true;
  canvas.focus({ preventScroll: true });
}

document.querySelectorAll('.machine').forEach(loveMachine);
