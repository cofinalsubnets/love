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
  const ev   = M.cwrap('ai_eval', 'number', ['string']);
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

  // quay: the real engines (src/apps/rove, src/apps/ink) and the page's love side
  // (src/port/wasm/web.l), which puts each app on a quay screen of the box's size and
  // mirrors its frames out for cells.js to lay. (fetch fails on file://; then `rove ()`
  // just scares gracefully through the default help.)
  const mirror = M.cwrap('ai_mirror', 'number', []);
  const palette = M.cwrap('ai_palette', 'number', []);
  const unfold = M.cwrap('ai_unfold', 'number', ['number']);
  const face = cellsFace(M.HEAPU32.subarray(palette() >> 2, (palette() >> 2) + 256), unfold);
  try {
    const srcs = await Promise.all(
      ['src/apps/rove/rove.l', 'src/apps/ink/ink.l', 'src/port/wasm/web.l'].map(p => fetch(p).then(r => r.text())));
    for (const t of srcs) ev(t);
    q('[data-chip=rove]').style.display = 'inline-block';
    q('[data-chip=ink]').style.display = 'inline-block';
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
    const play = o.match(/\x1b_play:(\w+)\x1b\\/);
    if (play) { enterApp(play[1]); return; }   // a launch swallows its output
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

  root.querySelectorAll('.chip').forEach(ch =>
    ch.addEventListener('click', () => { run(ch.dataset.run); cmd.focus(); }));

  // --- the app screen: a quay tty app, driven one step per key ------------
  // the app draws into quay's screen (web.l); each step we read the mirror -- the
  // screen's head and cells -- and lay it as text. style.css owns only the container
  // chrome: the app owns every colour and glyph inside it, through the engine's tables.
  const app = q('.app');
  const screen = q('.screen');
  const appname = q('.appname');
  const apphint = q('.apphint');
  // 'key': step on each keydown, quit on the app's sentinel. 'anim': step on a
  // timer, any key steps ashore. what an app keeps for its chrome is its own affair
  // (web.l): the screen is the whole box.
  const APPS = {
    rove: { mode: 'key',  hint: ' · hjkl yubn/arrows move · > descend · q/esc ashore' },
    ink:  { mode: 'anim', fps: 20, hint: ' · any key steps ashore' },
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

  // arrows fold onto hjkl; every other single char rides its byte (h j k l y u
  // b n for moves, q quit, > descend, . wait); anything else is ignored.
  const ARROW = { ArrowLeft: 104, ArrowDown: 106, ArrowUp: 107, ArrowRight: 108, Escape: 27 };
  const keyByte = e => e.key in ARROW ? ARROW[e.key]
                     : e.key.length === 1 ? e.key.codePointAt(0) : -1;

  // the mirror, read after each step: rows cols cursor flag, then the cells
  const step = () => {
    const p = mirror() >> 2, hdr = Array.from(M.HEAPU32.subarray(p, p + 4));
    screen.innerHTML = cellsHtml(face, hdr, M.HEAPU32.subarray(p + 4, p + 4 + hdr[0] * hdr[1]));
  };

  let onKey = null, timer = null, onResize = null;
  function enterApp(name) {
    const spec = APPS[name] || { mode: 'key', hint: '' };
    appname.textContent = name;
    apphint.textContent = spec.hint || '';
    term.hidden = true; app.hidden = false; app.focus();
    const boot = () => {   // measure the now-visible box, then seed a fresh screen
      const { cols, rows } = fitGrid();
      ev(`(puts (${name}-web-boot ${cols} ${rows} ${Date.now() & 0x7fffffff}))`);
      step();
    };
    boot();
    if (spec.mode === 'anim') {
      timer = setInterval(() => { ev(`(puts (${name}-web-tick ()))`); step(); }, 1000 / spec.fps);
      onKey = e => { e.preventDefault(); exitApp(); };          // any key -> shore
      onResize = boot;   // stateless shimmer: re-fit and re-seed on a resize
      window.addEventListener('resize', onResize);
    } else {
      onKey = e => {
        const n = keyByte(e); if (n < 0) return;
        e.preventDefault();
        ev(`(puts (${name}-web-key ${n}))`);
        if (/\x1b_quit\x1b\\/.test(drain())) return exitApp();
        step();
      };
    }
    // defer past the launching keystroke: the Enter that ran `ink ()` is still
    // bubbling, and anim's "any key -> exit" would otherwise fire on it at once.
    setTimeout(() => { if (onKey) window.addEventListener('keydown', onKey); }, 0);
  }
  function exitApp() {
    if (timer) { clearInterval(timer); timer = null; }
    if (onResize) { window.removeEventListener('resize', onResize); onResize = null; }
    window.removeEventListener('keydown', onKey); onKey = null;
    app.hidden = true; term.hidden = false; cmd.focus();
  }
}

document.querySelectorAll('.repl').forEach(loveRepl);
