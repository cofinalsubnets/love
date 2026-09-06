// src/port/wasm/repl.js -- the repl island: love.js's module driven from a page --
// the shell in .term, and the quay tty apps repainted into .app's cell grid.
// loveRepl(root) drives one island, its parts found by class under root: .status,
// .term (.scroll .out .row .cmd .clear), .app (.screen .appbar .appname .apphint) and
// the .chip spans. every .repl on the page mounts itself at load, so a page carries the
// markup and this script and no glue. index.html links it after love.js and cells.js.

async function loveRepl(root) {
  const q = s => root.querySelector(s);
  const status = q('.status');
  const out = q('.out');
  const cmd = q('.cmd');
  const term = q('.term');
  const scroll = q('.scroll');
  const clear = q('.clear');

  const t0 = performance.now();
  const M = await Love();
  const init = M.cwrap('ai_init', 'number', []);
  // through the heap, not ccall's 'string': that lands the text on the wasm stack, and
  // a frame or a fetched source is bigger than the stack cares to hold
  const evp = M.cwrap('ai_eval', 'number', ['number']);
  const ev = s => { const n = M.lengthBytesUTF8(s) + 1, p = M._malloc(n);
                    M.stringToUTF8(s, p, n); const r = evp(p); M._free(p); return r; };
  const optr = M.cwrap('ai_out_ptr', 'number', []);
  const olen = M.cwrap('ai_out_len', 'number', []);
  const dec = new TextDecoder();
  // slice, not subarray: firefox's TextDecoder refuses a view over the wasm
  // module's resizable memory; a fresh copy decodes everywhere
  const drain = () => dec.decode(M.HEAPU8.slice(optr(), optr() + olen()));

  if (init() !== 0) { status.textContent = 'the image failed to boot.'; return; }
  // the shell's default help: a condition prints ";; a b" and answers (), so
  // the session survives every raise -- the same law as the native shell.
  ev("(hear (\\ a b (: _ (puts \";; \") _ (putx a) _ (puts \" \") _ (putx b) _ (putc 10) ())))");
  // webln: bao's line protocol (parseall's law) for a STRING -- read every
  // top-level datum; ONE datum evaluates as-is, MANY become the application
  // (a b c).
  ev("(: webln (\\ s (: (go x acc) (: r (sound x) (? (two? r) (go (cup r) (link (cap r) acc)) (id? r 'torn) () (rev acc))) ds (go s ()) (? !(two? ds) () !(two? (cup ds)) (ev (cap ds)) (ev ds)))))");
  ev("(. love-version)");
  const ver = drain();
  status.style.display = 'none';
  put(`;3 love ${ver} ${(performance.now() - t0).toFixed(0)}ms`, 'cnd');
  cmd.disabled = false; cmd.focus({preventScroll: true});

  // the horn: a browser plays the PCM the sink taps. the AudioContext starts suspended
  // (autoplay), so resume on the first gesture, then pull the ring every frame.
  if (M.horn) {
    const wake = () => M.horn.resume();
    window.addEventListener('keydown', wake); window.addEventListener('pointerdown', wake);
    const draw = () => { M.horn.pull(); requestAnimationFrame(draw); };
    requestAnimationFrame(draw);
  }

  // quay: the page's love side (src/port/wasm/web.l: the tty words this seat has no
  // device for), then the real engines (src/apps/rove, ink) -- a closure captures its
  // free globals at creation. web.l puts each app on a quay screen of the box's size and
  // mirrors its frames out for cells.js to lay. (fetch fails on file://; then the app
  // chips stay hidden.)
  const mirror = M.cwrap('ai_mirror', 'number', []);
  const palette = M.cwrap('ai_palette', 'number', []);
  const unfold = M.cwrap('ai_unfold', 'number', ['number']);
  const face = cellsFace(M.HEAPU32.subarray(palette() >> 2, (palette() >> 2) + 256), unfold);
  try {
    const srcs = await Promise.all(
      ['src/apps/rove/story.l', 'src/apps/rove/levels/lighthouse.l', 'src/port/wasm/web.l', 'src/apps/rove/rove.l', 'src/apps/ink/ink.l']
        .map(p => fetch(p).then(r => r.text())));
    ev(srcs[0]);
    ev('(: lighthouse-data <(sound ' + aiStr(srcs[1]) + '))');   // the level's datum, read not run
    for (const t of srcs.slice(2)) ev(t);
    for (const ch of root.querySelectorAll('[data-app]')) ch.style.display = 'inline-block';
  } catch (e) {
  }

  const hist = []; let hi = 0;

  function balanced(s) {
    let d = 0, str = false;
    for (let i = 0; i < s.length; i++) {
      const c = s[i];
      if (str) { if (c === '\\') i++; else if (c === '"') str = false; continue; }
      if (c === '"') str = true;
      else if (c === ';') { while (i < s.length && s[i] !== '\n') i++; }
      else if (c === '(' || c === '[' || c === '{') d++;
      else if (c === ')' || c === ']' || c === '}') d--;
    }
    return !str && d <= 0;
  }

  function put(text, cls) {
    const d = document.createElement('div');
    d.className = cls; d.textContent = text;
    out.appendChild(d);
    scroll.scrollTop = scroll.scrollHeight;
  }

  // a love string literal for src: " and \ ride \xHH (the reader's byte escape),
  // control chars likewise; everything else passes through as utf-8.
  function aiStr(s) {
    let r = '"';
    for (const ch of s) {
      const o = ch.codePointAt(0);
      if (ch === '"' || ch === '\\' || o < 32 && ch !== '\n' && ch !== '\t')
        r += '\\x' + o.toString(16).padStart(2, '0');
      else if (ch === '\n') r += '\\n';
      else if (ch === '\t') r += '\\t';
      else r += ch;
    }
    return r + '"';
  }

  function run(src) {
    src = src.replace(/\s+$/, '');
    if (!src) return;
    put(src, 'in');
    hist.push(src); hi = hist.length;
    const s = ev('(puts (show (webln ' + aiStr(src) + ')))');
    const o = drain();
    for (const ln of o.split('\n')) if (ln.length) put(ln, ln.startsWith('# ') ? 'cnd' : 'ans');
    if (s !== 0) put('# the image stopped (status ' + s + ') -- reload to reboot', 'cnd');
    scroll.scrollTop = scroll.scrollHeight;
  }

  function fit() { cmd.style.height = 'auto'; cmd.style.height = cmd.scrollHeight + 'px'; }

  cmd.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) {
      if (balanced(cmd.value)) { e.preventDefault(); run(cmd.value); cmd.value = ''; fit(); }
    } else if (e.key === 'ArrowUp' && !cmd.value.includes('\n')) {
      if (hi > 0) { e.preventDefault(); cmd.value = hist[--hi] ?? ''; fit(); }
    } else if (e.key === 'ArrowDown' && !cmd.value.includes('\n')) {
      if (hi < hist.length) { e.preventDefault(); cmd.value = hist[++hi] ?? ''; fit(); }
    }
  });
  cmd.addEventListener('input', fit);

  clear.addEventListener('click', e => {
    e.stopPropagation(); out.textContent = ''; cmd.focus(); });

  term.addEventListener('click', () => {
    if (!String(getSelection()).length) cmd.focus(); });

  document.addEventListener('paste', e => {
    if (document.activeElement === cmd) return;
    const t = e.clipboardData.getData('text');
    if (t) { e.preventDefault(); cmd.focus();
             cmd.setRangeText(t, cmd.selectionStart, cmd.selectionEnd, 'end'); fit(); }
  });

  // a chip runs its line; an app chip opens its app on the screen instead
  root.querySelectorAll('.chip').forEach(ch =>
    ch.addEventListener('click', () => { ch.dataset.app ? enterApp(ch.dataset.app) : run(ch.dataset.run); cmd.focus(); }));

  // --- the app screen: a quay tty app, running as a task on the page's console ----
  // web.l puts the app on a quay screen and twirls it; we pump it -- a step yields it
  // the turn, whatever it drew is handed back to be scribed and mirrored -- and lay the
  // mirror as text. keys go into stdin's ring (ai_key) as the bytes a terminal would
  // send, so the app's own key decoding runs unchanged. style.css owns only the
  // container chrome: the app owns every colour and glyph inside it, through the
  // engine's tables.
  const app = q('.app');
  const screen = q('.screen');
  const appname = q('.appname');
  const apphint = q('.apphint');
  const key = M.cwrap('ai_key', 'number', ['number']);
  const runnable = M.cwrap('ai_runnable', 'number', []);
  const alive = M.cwrap('ai_alive', 'number', []);
  const HINTS = {
    rove: ' · hjkl yubn/arrows move · > descend · q/esc ashore',
    lighthouse: ' · hjkl move · walk into things · esc closes a window · :q leaves',
    ink:  ' · any key steps ashore',
  };

  // the grid, fit to the live box: measure one cell in the app font (a run of
  // full blocks), then divide .screen's client box by it.
  function measureCell() {
    const p = document.createElement('span');
    p.style.cssText = 'visibility:hidden;position:absolute;white-space:pre';
    p.textContent = '█'.repeat(20);
    screen.appendChild(p); const r = p.getBoundingClientRect(); p.remove();
    return { w: r.width / 20 || 16, h: r.height || 32 };
  }
  function fitGrid() {
    const { w, h } = measureCell();
    return { cols: Math.max(20, Math.floor(screen.clientWidth / w)),
             rows: Math.max(8, Math.floor(screen.clientHeight / h)) };
  }

  // a key as the bytes a terminal sends: arrows as CSI sequences, escape alone, a
  // printable as itself; anything else is not a key
  const CSI = { ArrowUp: 'A', ArrowDown: 'B', ArrowRight: 'C', ArrowLeft: 'D' };
  const keyBytes = e => e.key in CSI ? [27, 91, CSI[e.key].charCodeAt(0)]
                      : e.key === 'Escape' ? [27]
                      : e.key === 'Enter' ? [13]
                      : e.key.length === 1 ? [e.key.codePointAt(0)] : [];

  // the mirror, read after each step: rows cols cursor flag, then the cells
  const blit = () => {
    const p = mirror() >> 2, hdr = Array.from(M.HEAPU32.subarray(p, p + 4));
    screen.innerHTML = cellsHtml(face, hdr, M.HEAPU32.subarray(p + 4, p + 4 + hdr[0] * hdr[1]));
  };
  // one pump: the app's turns until it parks, sleeps or lands (a yield is one time
  // slice, so a frame may take several), everything it drew scribed and mirrored, and
  // whether it lives. an eval's out is drained right after it -- the next eval resets it,
  // and the app runs at any fair yield, so any eval's drain may be the app's
  const pump = () => {
    let acc = drain();
    // ..bounded twice: an app that never parks gets its slices on the next beat, and
    // what it drew meanwhile is shown as it goes rather than hoarded
    for (let n = 0; n < 256 && acc.length < 65536; n++) { ev('(web-step)'); acc += drain(); if (!runnable()) break; }
    for (let k = 0; acc && k < 4; k++) { ev('(web-show ' + aiStr(acc) + ')'); acc = drain(); }
    blit();
    return alive();
  };

  let onKey = null, timer = null;
  function enterApp(name) {
    appname.textContent = name;
    apphint.textContent = HINTS[name] || '';
    term.hidden = true; app.hidden = false; app.focus();
    const { cols, rows } = fitGrid();
    ev(`(web-boot ${JSON.stringify(name)} ${cols} ${rows})`);
    if (!pump()) return exitApp();
    // the clock: an app that rests between frames (ink's swim, rove's last look) wakes
    // on a pump, so the page pumps on a beat as well as on every key
    timer = setInterval(() => { if (!pump()) exitApp(); }, 50);
    onKey = e => {
      const bs = keyBytes(e); if (!bs.length) return;
      e.preventDefault();
      for (const b of bs) key(b);
      if (!pump()) exitApp();
    };
    // defer past the launching click or keystroke, still bubbling: ink's "any key ->
    // shore" would otherwise fire on it at once.
    setTimeout(() => { if (onKey) window.addEventListener('keydown', onKey); }, 0);
  }
  function exitApp() {
    if (timer) { clearInterval(timer); timer = null; }
    window.removeEventListener('keydown', onKey); onKey = null;
    app.hidden = true; term.hidden = false; cmd.focus();
  }
}

document.querySelectorAll('.repl').forEach(loveRepl);
