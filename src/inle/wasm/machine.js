// src/inle/wasm/machine.js -- the machine island: love.wasm as inle, booted on the page.
// the kernel runs in a worker (cpu.mjs) because it never returns, the canvas is its
// framebuffer, the keyboard its serial line and an AudioWorklet its speaker; the two
// threads share one ring, which is what lets the kernel's idle really block. one island per .machine on
// the page, its parts found by class under it, so a page carries the markup (the
// island on index.html) and this script and no glue. the page's half of the machine is
// all here: the glass that sizes the canvas, the scan lane that sends keys as a keyboard,
// the hearing that starts the speaker, then the island itself. inle.mjs, node's terminal,
// and the gates import the first three without a page, so nothing above the island
// touches the document.
// a shared ring means the page must be CROSS-ORIGIN ISOLATED. a server that sends the
// two headers has it already (kiosko does); on a host that will not, coi.js asks for them
// with a service worker and one reload. no isolation, no machine -- said, not left blank.
// the module and its image are fetched from web/wasm/ -- where the tracked, committed
// pair lives -- unless data-wasm/data-image name them; data-boot is the boot line (default
// a login shell, which says its /etc/profile and waits; a program named instead is booted
// again when it exits, so `sh -c "tower; sh"` is a game and then a shell), data-ram the
// RAM in MiB, data-cols the most columns worth reading, which is what settles how large a
// glyph is drawn. a query string names the same four (?boot=tower) and wins where it
// does: the attributes are the page's and the link is the reader's. a link's module or
// image is taken only off this page's own origin; its boot line runs aboard as it stands.
//
// the machine takes its RAM at boot and never gives it back, so a default is a promise
// about what runs on it. 1024 is what the tower wants, measured: at 256 the walk answers a
// keypress in twenty-odd SECONDS, and the floor is somewhere under 512. `love seed` wants
// the same 1024 and ooms under 768, so one number covers both.
import { ctl_n, ring_n, ring_at, shared_n, scan_at, scan_n, c_sh, c_st,
         point_at, point_n, c_ph, c_pt, paste_at, paste_n, c_xh, c_xt,
         horn_at, horn_n, c_rate, c_wrote, c_played, c_live, pageurl } from './cpu.mjs';

// --- the glass: a canvas as REAL pixels ------------------------------------------------
// the backing store is the element's own box times a ratio settled here, and
// the zoom says how many of its pixels a glyph pixel gets. the ratio is held to what one
// frame is worth painting (frame_cap): past that the compositor does the last integer
// doubling, which is the same grid and costs the machine nothing. the machine is handed
// the size and the zoom and settles rows and columns itself (src/inle/wasm/arch.c's k_start,
// then kmain's fbscale and cbinit) -- which is why
// nothing here mentions a font size or an aspect ratio, and why a page cannot pick a
// shape the console then has to live inside.
//
// nothing here pins the box: the element's own CSS lays it out and this only follows,
// which is what lets a page re-measure on a reflow and hand the machine the new size.

// how many pixels the machine may have -- 32 MiB of framebuffer, which covers a retina
// 1440p canvas and a plain 4K one. a dense screen at full ratio can ask for more than the
// RAM the worker grows (cpu.mjs's `ram`, 256 MiB by default) wants to spare, and a frame
// is that many bytes to swizzle each time one goes out; the ratio is what gives, the
// layout being the reader's.
const pixel_cap = 8 << 20;

// ..and how many one FRAME is worth, which is a different question and a smaller number.
// every pixel above this is swizzled and handed over on the machine's own thread
// (cpu.mjs's blit), so a dense screen spends the guest's time on pixels instead of on the
// guest -- and on a floor that repaints whether or not you touch it, that is the guest's
// sound going with it. a console's glyphs are integer-scaled bitmaps and the canvas is
// `image-rendering: pixelated`, so halving the ratio and doubling the scale to match is
// THE SAME GRID, pixel for pixel: the compositor does the last doubling, for free and on
// the GPU, instead of the worker doing it per pixel in a loop.
const frame_cap = 2 << 20;

// the RESERVATION: the most this canvas can ever be, which is the screen it sits on. the
// paper is carved at it once, at boot, and the heap gets what is under it, so a later
// resize lands inside memory the kernel was never given. it is a whole-screen box because
// that is the largest layout any reflow can arrive at, and it is settled here because the
// screen is the reader's and not the kernel's.
const reservation = (r) => Math.min(pixel_cap,
  Math.round(screen.width * r) * Math.round(screen.height * r));

// `cols` is the MOST columns worth reading: the zoom is the smallest that keeps the grid
// inside it, so a wide box gets bigger text rather than more of it. a cap and not a floor
// -- a box one glyph short of the next zoom would otherwise carry twice the columns asked
// for at half the size, which is the reading kmain's fbscale gives and a page can better,
// the pixels being the part a page knows and the kernel does not. /proc/vt/scale retunes
// it aboard, so this is the opening zoom and not a ceiling on one.
// a page may also ASK for fewer pixels than its screen has (`ratio`): halving the ratio
// doubles the zoom to match, which is the same grid, and the frame the machine swizzles
// each time is a quarter the bytes. on a phone that is the difference between a floor
// that repaints and a horn that keeps up
export function glass(canvas, cols = 80, ratio = 0) {
  const n = cols > 0 ? cols : 80;             // a query string's nonsense falls back, never NaN
  const box = canvas.getBoundingClientRect();
  // the floor is a floor and not the column target: a narrow screen gets FEWER columns,
  // never a canvas wider than the box it was laid in
  const w = Math.max(64, Math.round(box.width)), h = Math.max(16, Math.round(box.height));
  let r = Math.max(1, Math.round(ratio > 0 ? ratio : (window.devicePixelRatio || 1)));
  const cap = reservation(r);
  while (r > 1 && w * h * r * r > Math.min(cap, frame_cap)) r--;
  // 1..8 is the kernel's own range for a glyph scale (kmain's fbscale, and what
  // k_fb_reseat will take): past it a huge screen would be refused outright
  const scale = Math.min(8, Math.max(1, Math.ceil(w / (8 * n))) * r);
  return { w: w * r, h: h * r, scale, cap }; }

// --- the scan lane: the keyboard as a keyboard -----------------------------------------
// into the shared ring's scan lane as PS/2 set 1 make and break codes, the bytes the
// kernel's scancode tap reads (kmain's k_scan_pop) and a game asks for -- a held key is a
// make with no break behind it, which no serial byte can say. the terminal lane beside it
// still carries the key as text, so the shell sees a line and a game sees a key at once.
// physical keys (e.code), so a layout does not move the game's hands.
export const codes = {
  Escape: 0x01, Digit1: 0x02, Digit2: 0x03, Digit3: 0x04, Digit4: 0x05, Digit5: 0x06,
  Digit6: 0x07, Digit7: 0x08, Digit8: 0x09, Digit9: 0x0a, Digit0: 0x0b, Minus: 0x0c,
  Equal: 0x0d, Backspace: 0x0e, Tab: 0x0f, KeyQ: 0x10, KeyW: 0x11, KeyE: 0x12, KeyR: 0x13,
  KeyT: 0x14, KeyY: 0x15, KeyU: 0x16, KeyI: 0x17, KeyO: 0x18, KeyP: 0x19, BracketLeft: 0x1a,
  BracketRight: 0x1b, Enter: 0x1c, ControlLeft: 0x1d, KeyA: 0x1e, KeyS: 0x1f, KeyD: 0x20,
  KeyF: 0x21, KeyG: 0x22, KeyH: 0x23, KeyJ: 0x24, KeyK: 0x25, KeyL: 0x26, Semicolon: 0x27,
  Quote: 0x28, Backquote: 0x29, ShiftLeft: 0x2a, Backslash: 0x2b, KeyZ: 0x2c, KeyX: 0x2d,
  KeyC: 0x2e, KeyV: 0x2f, KeyB: 0x30, KeyN: 0x31, KeyM: 0x32, Comma: 0x33, Period: 0x34,
  Slash: 0x35, ShiftRight: 0x36, NumpadMultiply: 0x37, AltLeft: 0x38, Space: 0x39,
  CapsLock: 0x3a, F1: 0x3b, F2: 0x3c, F3: 0x3d, F4: 0x3e, F5: 0x3f, F6: 0x40, F7: 0x41,
  F8: 0x42, F9: 0x43, F10: 0x44, NumLock: 0x45, ScrollLock: 0x46, NumpadSubtract: 0x4a,
  NumpadAdd: 0x4e, F11: 0x57, F12: 0x58,
  // the extended keys wear the 0xe0 prefix, folded onto 0x100 here and unfolded when sent
  ControlRight: 0x11d, AltRight: 0x138, ArrowUp: 0x148, ArrowLeft: 0x14b, ArrowRight: 0x14d,
  ArrowDown: 0x150, Home: 0x147, End: 0x14f, PageUp: 0x149, PageDown: 0x151, Insert: 0x152,
  Delete: 0x153, NumpadEnter: 0x11c, NumpadDivide: 0x135 };

// the lane as a function: (name, up) -> the code sent, or nothing for a name that is not a
// key. ctl and its constants are cpu.mjs's. a full lane drops the code, as the key lane
// drops a byte.
export function scanlane(ring, ctl, { scan_at, scan_n, c_sh, c_st }) {
  const lane = new Uint8Array(ring, scan_at, scan_n);
  const push = (bytes) => {
    let tail = Atomics.load(ctl, c_st);
    for (const b of bytes) {
      const n = (tail + 1) % scan_n;
      if (n === Atomics.load(ctl, c_sh)) break;
      lane[tail] = b; tail = n; }
    Atomics.store(ctl, c_st, tail);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); };
  return (name, up) => {
    const c = codes[name];
    if (c === undefined) return false;
    push(c & 0x100 ? [0xe0, (c & 0x7f) | (up ? 0x80 : 0)] : [c | (up ? 0x80 : 0)]);
    return true; }; }

// wire the element's keys into the lane; a repeat is not a second make
export function scanning(ring, ctl, el, k) {
  const send = scanlane(ring, ctl, k);
  el.addEventListener('keydown', (e) => { if (!e.repeat && send(e.code, 0)) e.preventDefault(); });
  el.addEventListener('keyup', (e) => { if (send(e.code, 1)) e.preventDefault(); }); }

// --- the pointer and the clipboard: lanes of their own ---------------------------------
// a pointer event is a record the kernel takes whole (src/inle/wasm/arch.c): how (0 a press, 1
// a release, 2 a move), the button (0 1 2, 64 65 the wheel, 3 none held) with modifiers 4
// shift 8 meta 16 ctrl, and the cell, 0-based. what it MEANS is the console's to say: a
// program that asked for the mouse gets a report, and otherwise a drag selects, the release
// comes back as { copy } and the wheel scrolls the history. a paste is its text, which the
// console lays as a paste (bracketed when the program asked). full lanes drop the rest.
export function pointlane(ring, ctl) {
  const lane = new Uint8Array(ring, point_at, point_n);
  return (how, b, row, col) => {
    const tail = Atomics.load(ctl, c_pt), n = (tail + 8) % point_n;
    if (n === Atomics.load(ctl, c_ph)) return false;
    lane.set([how, b, 0, 0, row & 255, row >> 8, col & 255, col >> 8], tail);
    Atomics.store(ctl, c_pt, n);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2);
    return true; }; }
export function pastelane(ring, ctl) {
  const lane = new Uint8Array(ring, paste_at, paste_n);
  return (text) => {
    let tail = Atomics.load(ctl, c_xt);
    for (const b of new TextEncoder().encode(text)) {
      const n = (tail + 1) % paste_n;
      if (n === Atomics.load(ctl, c_xh)) break;
      lane[tail] = b; tail = n; }
    Atomics.store(ctl, c_xt, tail);
    Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); }; }

// --- hearing: letting the machine be heard ---------------------------------------------
// ring by the time this matters (src/inle/wasm/horn.c, then cpu.mjs); what is left is the
// AudioWorklet that plays them, and a page may not start one until it has been touched.
// so the island hangs `hearing` off the touches that focus the screen: it makes the
// context once and resumes it on every touch until it runs -- a finger grants nothing on
// the way down, only on the way up, so the press that builds it cannot always start it.
// until then cpu.mjs drains the ring off its own clock -- a machine that plays before the
// reader touches is never blocked, only unheard.
// c_live is what says which of the two is draining, and it follows the context's state:
// a suspended context plays nothing and must not be counted on to empty the ring.

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

// --- the island ----------------------------------------------------------------------

// the module is wasm64: an engine without memory64 says so instead of failing in silence
const memory64 = () => WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 5, 3, 1, 4, 0]));

// a key as the bytes a serial terminal sends: CR for Enter, DEL for Backspace, ESC
// sequences for the arrows and home/end, the control letters as themselves
const CSI = { Enter: [13], Backspace: [127], Tab: [9], Escape: [27], Delete: [27, 91, 51, 126],
              ArrowUp: [27, 91, 65], ArrowDown: [27, 91, 66], ArrowRight: [27, 91, 67], ArrowLeft: [27, 91, 68],
              Home: [27, 91, 72], End: [27, 91, 70], PageUp: [27, 91, 53, 126], PageDown: [27, 91, 54, 126] };
// a hardware key's bytes, or null for a key the terminal has no bytes for: ctrl with a
// letter is the control byte, alt with a character is an escape before it, as xterm
// sends meta and as the guest's readers take it, and meta or ctrl otherwise is nothing
export function keybytes(e) {
  const b = CSI[e.key];
  if (b || e.key.length !== 1) return b || null;
  const c = e.key.codePointAt(0), t = [...new TextEncoder().encode(e.key)];
  return e.ctrlKey && c >= 64 && c < 128 ? [c & 31] : e.ctrlKey || e.metaKey ? null
       : e.altKey ? [27, ...t] : t; }

export async function loveMachine(root) {
  const q = c => root.querySelector('.' + c);
  const status = q('status'), canvas = q('fb');
  // ONE CONSOLE DOOR: the canvas is it. the worker is handed the framebuffer and quay paints
  // the guest's own terminal into it, cursor and erases obeyed, so nothing on this side
  // re-renders the serial line -- a second reading of a stream whose control bytes ARE the
  // rendering can only disagree with the first. what is left for the page to say is the
  // machine failing to start or stopping, which the canvas cannot show.
  const halt = t => { status.textContent = t; status.hidden = false; canvas.hidden = true; };
  // a question for the reader, answered by a click: the text, two buttons. -> true for
  // the first. one at a time; a later one waits its turn.
  let asked = Promise.resolve();
  const offer = (text, yes, no) => asked = asked.then(() => new Promise(done => {
    const box = document.createElement('div'), p = document.createElement('p');
    box.className = 'ask'; p.textContent = text; box.append(p);
    const row = document.createElement('p');
    for (const [label, v] of [[yes, true], [no, false]]) {
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'chip'; b.textContent = label;
      b.addEventListener('click', () => { box.remove(); done(v); });
      row.append(b); }
    box.append(row); root.append(box); }));

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
  const url = p => new URL(p, import.meta.url);
  // a link's module or image is taken only off this origin; elsewhere it is the page's own
  const local = (k, v) => {
    if (v === null || !(k === 'wasm' || k === 'image') || pageurl(v, location.href)) return v;
    console.warn(`the link's ${k} is not this page's origin: ignored`);
    return null; };
  const at = (k, d) => local(k, link.get(k)) ?? root.dataset[k] ?? d;

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
  // a hardware key, off either element: the bytes a serial terminal sends -- but for the
  // clipboard's chords, ctrl+shift+C or cmd+C to copy the console's selection and
  // ctrl+shift+V or cmd+V to paste, which the browser's own paste event then carries in
  // the clipboard is written only in a gesture's wake: the chord and the copy event are
  // one, and a selection that came back is taken at once only when the reader's own
  // release sent it, a moment ago. anything else is kept for the chord.
  let copied = '', released = -1e9;
  const copy = () => { if (copied) navigator.clipboard?.writeText(copied).catch(() => {}); };
  const fresh = () => performance.now() - released < 1000 && (navigator.userActivation?.isActive ?? true);
  const chord = (e, k) => e.code === k && ((e.ctrlKey && e.shiftKey) || e.metaKey);
  const onkey = e => {
    if (chord(e, 'KeyC')) { e.preventDefault(); copy(); return; }
    if (chord(e, 'KeyV')) return;
    const b = keybytes(e);
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
  // SOUND: the samples come out of the same ring and `hearing`'s worklet plays them, from
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
    wasm = await (await fetch(url(at('wasm', '../../../web/wasm/love.wasm')))).arrayBuffer();
    image = await fetch(url(at('image', '../../../web/wasm/love.image')))
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
  // a file the machine asked carried out (a path written to /proc/lift aboard) is offered,
  // named and sized, and becomes a download under its own name only on the reader's click
  const lifted = (m) => {
    if (m.error) { console.warn('lift ' + m.lift + ': errno ' + m.error); return; }
    const name = m.lift.split('/').pop() || 'lift';
    offer(`the machine offers a file: ${name}, ${m.bytes.length} bytes.`, 'save', 'dismiss').then(yes => {
      if (!yes) return;
      const a = document.createElement('a'), url = URL.createObjectURL(new Blob([m.bytes], { type: 'application/octet-stream' }));
      a.href = url; a.download = name;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 10000); }); };
  // a selection the console made comes back as text: it is the clipboard's at once where
  // the browser lets a page write it after a gesture, and kept for the copy chord and the
  // browser's own copy event besides
  const paste = pastelane(ring, ctl);
  const ours = () => root.contains(document.activeElement);
  document.addEventListener('copy', e => {
    if (!copied || !ours()) return;
    e.clipboardData.setData('text/plain', copied); e.preventDefault(); });
  document.addEventListener('paste', e => {
    if (!ours()) return;
    const t = e.clipboardData?.getData('text/plain');
    if (t) paste(t);
    e.preventDefault(); });
  cpu.onmessage = ({ data: m }) => {
    if (m.frame) { latest = m; if (!due) due = requestAnimationFrame(draw); }
    else if (m.copy !== undefined) { copied = m.copy; if (fresh()) copy(); }
    else if (m.lift !== undefined) lifted(m);
    else if (m.fault) halt('the machine faulted: ' + m.fault); };
  cpu.onerror = e => halt('the machine stopped: ' + e.message);
  // the canvas measured as REAL pixels -- its own box times a ratio -- and the zoom a
  // glyph pixel gets there. the kernel settles rows and columns from the two, so the
  // island's shape is a layout question and nothing the console has to live inside.
  // the ratio is one: the console's glyphs are integer-scaled bitmaps, so the compositor's
  // doubling to the screen's density is the same grid, and the machine's thread swizzles a
  // box's worth of pixels a frame instead of the screen's. `ratio=0` asks for the device's
  const cols = Number(at('cols', 80));
  const ratio = Number(at('ratio', 1));
  const fb = { ...glass(canvas, cols, ratio), post: true };
  // A TAP IS A PLACE: the pointer goes to the console as the cell it is over, and the
  // console says what it means (pointlane above) -- a game that asked for the mouse gets
  // its report, a shell's screen is selected. the cell is the canvas's own pixels over the
  // glyph box, so it follows the zoom; `zoom` is the last one this page handed the machine,
  // which a /proc/vt/scale aboard would leave behind until the next reflow. a move goes
  // once per cell, and the wheel once per three lines' worth of scrolling
  let zoom = fb.scale;
  canvas.style.touchAction = 'none';               // a finger on the screen steers, never scrolls
  const point = pointlane(ring, ctl);
  const cell = e => {
    const box = canvas.getBoundingClientRect();
    if (box.width < 1 || box.height < 1) return null;
    const x = (e.clientX - box.left) * canvas.width / box.width,
          y = (e.clientY - box.top) * canvas.height / box.height;
    return [Math.max(0, Math.floor(y / (16 * zoom))), Math.max(0, Math.floor(x / (8 * zoom)))]; };
  const mods = e => (e.shiftKey ? 4 : 0) | (e.altKey || e.metaKey ? 8 : 0) | (e.ctrlKey ? 16 : 0);
  const button = n => n === 0 ? 0 : n === 1 ? 1 : n === 2 ? 2 : 3;
  let over = '', spun = 0;
  const send = (how, b, e) => { const c = cell(e); if (c) over = c.join(), point(how, b | mods(e), c[0], c[1]); };
  // a finger focuses the canvas (no keyboard over the floor), a mouse the field
  canvas.addEventListener('pointerdown', e => {
    (e.pointerType === 'touch' ? canvas : keys).focus({ preventScroll: true });
    canvas.setPointerCapture?.(e.pointerId);
    send(0, button(e.button), e); });
  canvas.addEventListener('pointerup', e => { released = performance.now(); send(1, button(e.button), e); });
  canvas.addEventListener('pointermove', e => {
    const c = cell(e);
    if (!c || c.join() === over) return;
    send(2, e.buttons & 1 ? 0 : e.buttons & 4 ? 1 : e.buttons & 2 ? 2 : 3, e); });
  canvas.addEventListener('wheel', e => {
    e.preventDefault();
    spun += e.deltaY * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? 400 : 1);
    for (; Math.abs(spun) >= 48; spun -= Math.sign(spun) * 48) send(0, spun < 0 ? 64 : 65, e); },
    { passive: false });
  cpu.postMessage({ wasm, ring, ram: Number(at('ram', 1024)), cmd: at('boot', 'sh --login'), fb, image },
                  image ? [wasm, image] : [wasm]);
  // the box reflowed -- the window resized, or the island's column did. the new size goes
  // into the ring and the kernel re-makes its console at it; the canvas itself is left
  // alone until a frame comes back at the size the machine actually took.
  let pending = 0;
  const ask = () => {
    const box = canvas.getBoundingClientRect();
    if (canvas.hidden || box.width < 1 || box.height < 1) return;
    const g = glass(canvas, cols, ratio);
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

if (typeof document !== 'undefined') document.querySelectorAll('.machine').forEach(loveMachine);
