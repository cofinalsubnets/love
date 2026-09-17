// inle/wasm/machine.js -- the machine island: love.wasm as inle, booted on the page.
// the kernel runs in a worker (cpu.mjs) because it never returns, the canvas is its
// framebuffer, the keyboard its serial line and an AudioWorklet its speaker; the two
// threads share one ring, which is what lets the kernel's idle really block. one island per .machine on
// the page, its parts found by class under it, so a page carries the markup (the
// island on index.html) and this script and no glue.
// a shared ring means the page must be CROSS-ORIGIN ISOLATED. a server that sends the
// two headers has it already (kiosko does); on a host that will not, coi.js asks for them
// with a service worker and one reload. no isolation, no machine -- said, not left blank.
// the module and its image are fetched from web/wasm/ -- where the tracked, committed
// pair lives -- unless data-wasm/data-image name them; data-boot is the boot line (default
// a login shell, which says its /etc/profile and waits; a program named instead is booted
// again when it exits, so `sh -c "tower; sh"` is a game and then a shell), data-ram the
// RAM in MiB, data-cols the most columns worth reading, which is what settles how large a
// glyph is drawn. a query string names the same four (?boot=tower) and wins where it
// does: the attributes are the page's and the link is the reader's.
//
// the machine takes its RAM at boot and never gives it back, so a default is a promise
// about what runs on it. 1024 is what the tower wants, measured: at 256 the walk answers a
// keypress in twenty-odd SECONDS, and the floor is somewhere under 512. `love seed` wants
// the same 1024 and ooms under 768, so one number covers both.
import { ctl_n, ring_n, ring_at, shared_n, scan_at, scan_n, c_sh, c_st } from './cpu.mjs';
import { scanning } from './scan.mjs';
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
  // a browser hands a page the memory the machine runs on only from a SECURE origin --
  // https, or localhost -- so over plain http from another box nothing on this side can
  // help, and the reader is told the two ways in. under a secure origin, coi.js reloads
  // once to get the headers, so a page that arrives here unisolated has already had its
  // turn: a service worker it could not install, or a file:// open.
  const port = location.port ? ':' + location.port : '';
  if (!window.isSecureContext)
    return halt(`the machine cannot run on this page: a browser only gives a page the memory it needs over https or from localhost. open it as http://localhost${port}/ -- from another machine an ssh tunnel gets you there (ssh -L ${location.port || 80}:127.0.0.1:${location.port || 80} ${location.hostname}) -- or serve it over https.`);
  if (!window.crossOriginIsolated)
    return halt('the machine cannot run on this page: it arrived without the two headers that give it its memory, and the helper that adds them could not be installed. reloading once usually mends it.');

  const link = new URLSearchParams(location.search);
  const at = (k, d) => link.get(k) ?? root.dataset[k] ?? d;
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

  // THE SOFT KEYBOARD: a phone raises one for a text field and never for a canvas, so
  // the keys are read off a field that is on the page and not seen, as well as off the
  // canvas. a finger's tap on the screen is the game's and leaves the field alone, so
  // no keyboard rises over the floor; the chip under the screen focuses the field, which
  // is what brings the keyboard up for the shell -- and a tap on the screen takes it
  // down again. a mouse click focuses the field too: a desktop has nothing to raise.
  const keys = document.createElement('textarea');
  keys.className = 'keys'; keys.setAttribute('aria-label', 'keyboard'); keys.rows = 1;
  for (const [k, v] of Object.entries({ autocapitalize: 'off', autocomplete: 'off', autocorrect: 'off', spellcheck: 'false' }))
    keys.setAttribute(k, v);
  const chip = document.createElement('button');
  chip.type = 'button'; chip.className = 'chip keys-chip'; chip.textContent = '\u2328 keyboard';
  canvas.after(keys, chip);
  // a soft keyboard's backspace says nothing over an empty field, so the field always
  // holds one character to delete, a zero-width space, with the caret after it
  const blank = '\u200b';
  const rearm = () => { keys.value = blank; keys.setSelectionRange(1, 1); };
  rearm();
  const coarse = matchMedia('(pointer: coarse)').matches;
  const refocus = () => (coarse ? canvas : keys).focus({ preventScroll: true });
  chip.addEventListener('click', () => { rearm(); keys.focus({ preventScroll: true }); });
  // a hardware key, off either element: the bytes a serial terminal sends
  const onkey = e => {
    let b = CSI[e.key];
    if (!b && e.key.length === 1) {
      const c = e.key.codePointAt(0);
      b = e.ctrlKey && c >= 64 && c < 128 ? [c & 31] : e.ctrlKey || e.metaKey || e.altKey ? null
        : [...new TextEncoder().encode(e.key)]; }
    if (!b) return;
    e.preventDefault(); push(b); };
  canvas.addEventListener('keydown', onkey);
  keys.addEventListener('keydown', onkey);
  // a soft key names no key, so it is read off what it did to the field: a delete is
  // caught before it lands, and anything typed is what the field holds after, less the
  // sentinel, with the newline a return. a composition (an IME's) is read when it ends.
  keys.addEventListener('beforeinput', e => {
    const b = e.inputType === 'deleteContentBackward' ? [127]
            : e.inputType === 'deleteContentForward' ? CSI.Delete : null;
    if (!b) return;
    e.preventDefault(); push(b); rearm(); });
  const typed = () => {
    const t = keys.value.split(blank).join('');
    if (t) push([...new TextEncoder().encode(t.replace(/\n/g, '\r'))]);
    rearm(); };
  keys.addEventListener('input', e => { if (!e.isComposing) typed(); });
  keys.addEventListener('compositionend', typed);
  // SOUND: the samples come out of the same ring and hear.mjs's worklet plays them, from
  // the first touch of the screen, which is the earliest a page is allowed to. no sound is
  // not the island failing, so a refusal goes to the console and the machine runs on.
  const hear = hearing(ring, ctl);
  canvas.addEventListener('pointerdown', hear);
  canvas.addEventListener('pointerup', hear);
  canvas.addEventListener('keydown', hear);
  keys.addEventListener('keydown', hear);
  chip.addEventListener('click', hear);
  scanning(ring, ctl, canvas, { scan_at, scan_n, c_sh, c_st });   // and as scancodes, for a game
  scanning(ring, ctl, keys, { scan_at, scan_n, c_sh, c_st });
  // a chip types its line at the machine, the way the repl island's chips ran theirs
  for (const ch of root.querySelectorAll('[data-type]'))
    ch.addEventListener('click', () => { push([...new TextEncoder().encode(ch.dataset.type), 13]);
                                         refocus(); });

  status.textContent = 'fetching the machine...';
  let wasm, image;
  try {
    wasm = await (await fetch(url(at('wasm', '../../web/wasm/love.wasm')))).arrayBuffer();
    image = await fetch(url(at('image', '../../web/wasm/love.image')))
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
  // ONLY THE NEWEST FRAME IS WORTH DRAWING. the worker posts as it paints and never waits
  // to be told the page kept up, so drawing them in order would queue: a page a few frames
  // behind stays behind, and every frame it owes is latency the reader reads as a machine
  // that answers late -- while the machine was current the whole time. the latch holds one
  // frame and the display's own clock takes it, so what is late is dropped, not shown.
  let woke = false, latest = null, due = 0;
  const draw = () => {
    due = 0;
    const m = latest;
    latest = null;
    if (!m) return;
    // the backing store follows the FRAME, never the measurement: the machine may refuse
    // a size (k_fb_reseat's bounds), and a canvas sized to what was asked for would then
    // show the frame in a corner of itself. resizing it also clears it, so only on a change.
    if (canvas.width !== m.w || canvas.height !== m.h) canvas.width = m.w, canvas.height = m.h;
    ctx.putImageData(new ImageData(new Uint8ClampedArray(m.frame), m.w, m.h), 0, 0);
    if (!woke) { woke = true; status.hidden = true; } };
  // a file the machine asked carried out (a path written to /proc/lift aboard) is
  // handed to the browser as a download under its own name
  const lifted = (m) => {
    if (m.error) { console.warn('lift ' + m.lift + ': errno ' + m.error); return; }
    const a = document.createElement('a'), url = URL.createObjectURL(new Blob([m.bytes], { type: 'application/octet-stream' }));
    a.href = url; a.download = m.lift.split('/').pop() || 'lift';
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000); };
  cpu.onmessage = ({ data: m }) => {
    if (m.frame) { latest = m; if (!due) due = requestAnimationFrame(draw); }
    else if (m.lift !== undefined) lifted(m);
    else if (m.fault) halt('the machine faulted: ' + m.fault); };
  cpu.onerror = e => halt('the machine stopped: ' + e.message);
  // the canvas measured as REAL pixels -- its own box times the device ratio -- and the
  // zoom a glyph pixel gets there. the kernel settles rows and columns from the two, so
  // the island's shape is a layout question and nothing the console has to live inside.
  const cols = Number(at('cols', 80));
  const fb = { ...glass(canvas, cols), post: true };
  // A TAP IS A PLACE. the report is xterm's SGR form (ESC [ < b ; col ; row M) -- what a
  // terminal sends an app that asked for one, and a key an app that did not reads as
  // unknown and drops. the PRESS only: nothing aboard drags, and the release is another
  // escape for the guest's key reader to wait a beat on and then throw away.
  // the cell is the canvas's own pixels over the glyph box, so it follows the zoom;
  // `zoom` is the last one this page handed the machine, which a /proc/vt/scale aboard
  // would leave behind until the next reflow.
  let zoom = fb.scale;
  canvas.style.touchAction = 'none';               // a finger on the screen steers, never scrolls
  const digits = n => [...String(n)].map(c => c.charCodeAt(0));
  const tap = e => {
    const box = canvas.getBoundingClientRect();
    if (box.width < 1 || box.height < 1) return;
    const x = (e.clientX - box.left) * canvas.width / box.width,
          y = (e.clientY - box.top) * canvas.height / box.height,
          col = 1 + Math.floor(x / (8 * zoom)), row = 1 + Math.floor(y / (16 * zoom));
    push([27, 91, 60, 48, 59, ...digits(col), 59, ...digits(row), 77]); };
  // a finger focuses the canvas (no keyboard over the floor), a mouse the field
  canvas.addEventListener('pointerdown', e => ((e.pointerType === 'touch' ? canvas : keys).focus({ preventScroll: true }), tap(e)));
  cpu.postMessage({ wasm, ring, ram: Number(at('ram', 1024)), cmd: at('boot', 'sh --login'), fb, image },
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
    zoom = g.scale;
    Atomics.store(ctl, 4, 1);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); };
  // a drag is hundreds of reflows and each one re-makes a console and frees a grid, so the
  // machine hears the size the reader stopped at rather than every size on the way there
  new ResizeObserver(() => { clearTimeout(pending); pending = setTimeout(ask, 150); })
    .observe(canvas);
  status.textContent = 'the machine is waking...';
  refocus();
}

document.querySelectorAll('.machine').forEach(loveMachine);
