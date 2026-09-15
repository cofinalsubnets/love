// inle/wasm/scan.mjs -- the keyboard as a keyboard: keydown and keyup on an element, sent
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
