// src/port/wasm/repl.js -- the front page's repl: love.js's module driven from the
// page -- the shell in #term, and the quay tty apps repainted into #app's cell grid.
// index.html links it after love.js; nothing here is generated.

(async () => {
  const status = document.getElementById('status');
  const out = document.getElementById('out');
  const cmd = document.getElementById('cmd');
  const term = document.getElementById('term');
  const scroll = document.getElementById('scroll');
  const clear = document.getElementById('clear');

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

  // quay: fetch the real engine (src/apps/rove/rove.l) and install a web driver.
  // the tty runner (rove/sail/helm) references host words that don't exist in
  // the browser image (winsize/raw/cue?/rest/flush ride pty.c + bao.l, absent
  // from egg+prel+ev+uu) -- and a closure captures its free globals AT CREATION,
  // so those defs would raise (scare 'missing ..) as they bind. stub the five
  // (we never call them); the pure engine (crawl-new/turn/frame + helm-dec) is
  // all the driver touches. then rebind `rove` to a launcher: `rove ()` at the
  // repl emits a play sentinel the run() loop catches. (fetch fails on file://;
  // then `rove ()` just scares gracefully through the default help.)
  try {
    const [roveSrc, inkSrc] = await Promise.all(
      ['src/apps/rove/rove.l', 'src/apps/ink/ink.l'].map(p => fetch(p).then(r => r.text())));
    ev('(: winsize (\\ _ ()) raw (\\ _ ()) cue? (\\ _ 0) rest (\\ _ ()) flush (\\ _ ()))');
    ev(roveSrc); ev(inkSrc);
    // the launch verb + the per-app step protocol the driver below pumps:
    //   <name>-web-boot cols rows seed  -> first frame
    //   <name>-web-key byte             -> next frame / quit sentinel  (key apps)
    //   <name>-web-tick ()              -> next frame                  (anim apps)
    ev('(: (play nm) (: _ (puts ("\\e_play:" + nm + "\\e\\\\")) ()) qbox #0 sbox #0 tbox #0'
     + ' (rove-web-boot c r sd) (: g (crawl-new (? (c < 100) c 100) r (wheel sd)) _ (pin qbox () g) (crawl-frame g))'
     + ' (rove-web-key n) (? (|| (n = 113) (n = 27)) "\\e_quit\\e\\\\"'
     + '                     (: g (peep qbox () 0) _ (crawl-turn g (helm-dec n -1 -1)) (crawl-frame g)))'
     + ' (ink-web-boot c r sd) (: _ (pin sbox () (ink-scene r c)) _ (pin tbox () 0) ((peep sbox () 0) 0.0))'
     + ' (ink-web-tick _) (: t (+ 1 (peep tbox () 0)) _ (pin tbox () t) ((peep sbox () 0) (* t 0.06))))');
    ev('(: rove (\\ _ (play "rove")) ink (\\ _ (play "ink")))');
    document.getElementById('rove_chip').style.display = 'inline-block';
    document.getElementById('ink_chip').style.display = 'inline-block';
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

  document.querySelectorAll('.chip').forEach(ch =>
    ch.addEventListener('click', () => { run(ch.dataset.run); cmd.focus(); }));

  // --- the app screen: a quay tty app, driven one step per key ------------
  // the frames are the app's own ANSI (256-color SGR + cursor home/erase); we
  // parse that into a cell grid. style.css owns only the container chrome --
  // the app owns every colour and glyph inside it.
  const app = document.getElementById('app');
  const screen = document.getElementById('screen');
  const appname = document.getElementById('appname');
  const apphint = document.getElementById('apphint');
  // 'key': step on each keydown, quit on the app's sentinel. 'anim': step on a
  // timer, any key steps ashore. reserve = rows the app spends on chrome (rove's
  // header + status bar), subtracted from the grid so the frame fits the box.
  const APPS = {
    rove: { mode: 'key',  reserve: 2, hint: ' · hjkl yubn/arrows move · > descend · q/esc ashore' },
    ink:  { mode: 'anim', reserve: 0, fps: 20, hint: ' · any key steps ashore' },
  };

  // the grid, fit to the live box: measure one cell in the app font (a run of
  // full blocks), then divide #screen's client box by it.
  function measureCell() {
    const p = document.createElement('span');
    p.style.cssText = 'visibility:hidden;position:absolute;white-space:pre';
    p.textContent = '█'.repeat(20);
    screen.appendChild(p); const r = p.getBoundingClientRect(); p.remove();
    return { w: r.width / 20 || 16, h: r.height || 32 };
  }
  function fitGrid(reserve) {
    const { w, h } = measureCell();
    return { cols: Math.max(20, Math.floor(screen.clientWidth / w)),
             rows: Math.max(8, Math.floor(screen.clientHeight / h) - (reserve || 0)) };
  }

  // xterm 256-colour -> css rgb: 16 system + a 6x6x6 cube + a 24-step ramp.
  const SYS = [[0,0,0],[128,0,0],[0,128,0],[128,128,0],[0,0,128],[128,0,128],
               [0,128,128],[192,192,192],[128,128,128],[255,0,0],[0,255,0],
               [255,255,0],[0,0,255],[255,0,255],[0,255,255],[255,255,255]];
  function pal256(n) {
    if (n < 16) { const [r,g,b] = SYS[n]; return `rgb(${r},${g},${b})`; }
    if (n < 232) { n -= 16; const c = v => v ? v*40+55 : 0;
      return `rgb(${c((n/36|0))},${c((n/6|0)%6)},${c(n%6)})`; }
    const v = 8 + (n-232)*10; return `rgb(${v},${v},${v})`; }

  const htmlEsc = s => s.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));

  // one full-repaint frame -> html. rove homes the cursor and repaints every
  // cell each frame, so we ignore cursor motion (H/K/J) and just lay text with
  // \n row breaks, honouring the SGR fg/bg spans.
  function ansiToHtml(frame) {
    let out = '', fg = null, bg = null, buf = '';
    const flush = () => { if (!buf) return;
      let st = ''; if (fg) st += 'color:'+fg+';'; if (bg) st += 'background:'+bg+';';
      out += st ? `<span style="${st}">${htmlEsc(buf)}</span>` : htmlEsc(buf); buf = ''; };
    for (let i = 0; i < frame.length; i++) {
      const c = frame[i];
      if (c === '\x1b') {
        const m = /^\x1b\[([0-9;]*)([A-Za-z])/.exec(frame.slice(i));
        if (m) { flush(); i += m[0].length - 1;
          if (m[2] === 'm') { const cs = m[1].split(';').map(Number);
            for (let j = 0; j < cs.length; j++) { const q = cs[j];
              if (q === 0) { fg = null; bg = null; }
              else if (q === 38 && cs[j+1] === 5) { fg = pal256(cs[j+2]); j += 2; }
              else if (q === 48 && cs[j+1] === 5) { bg = pal256(cs[j+2]); j += 2; } } }
          continue; } }
      if (c === '\r') continue;
      if (c === '\n') { flush(); out += '\n'; continue; }
      buf += c;
    }
    flush(); return out; }

  // arrows fold onto hjkl; every other single char rides its byte (h j k l y u
  // b n for moves, q quit, > descend, . wait); anything else is ignored.
  const ARROW = { ArrowLeft: 104, ArrowDown: 106, ArrowUp: 107, ArrowRight: 108, Escape: 27 };
  const keyByte = e => e.key in ARROW ? ARROW[e.key]
                     : e.key.length === 1 ? e.key.codePointAt(0) : -1;

  const step = frame => { screen.innerHTML = ansiToHtml(frame); };

  let onKey = null, timer = null, onResize = null;
  function enterApp(name) {
    const spec = APPS[name] || { mode: 'key', reserve: 0, hint: '' };
    appname.textContent = name;
    apphint.textContent = spec.hint || '';
    term.hidden = true; app.hidden = false; app.focus();
    const boot = () => {   // measure the now-visible box, then seed a fresh grid
      const { cols, rows } = fitGrid(spec.reserve);
      ev(`(puts (${name}-web-boot ${cols} ${rows} ${Date.now() & 0x7fffffff}))`);
      step(drain());
    };
    boot();
    if (spec.mode === 'anim') {
      timer = setInterval(() => { ev(`(puts (${name}-web-tick ()))`); step(drain()); }, 1000 / spec.fps);
      onKey = e => { e.preventDefault(); exitApp(); };          // any key -> shore
      onResize = boot;   // stateless shimmer: re-fit and re-seed on a resize
      window.addEventListener('resize', onResize);
    } else {
      onKey = e => {
        const n = keyByte(e); if (n < 0) return;
        e.preventDefault();
        ev(`(puts (${name}-web-key ${n}))`);
        const o = drain();
        if (/\x1b_quit\x1b\\/.test(o)) return exitApp();
        step(o);
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
})();
