// wasm test harness: run the love test corpus through the emscripten build
// and gate on the zz-fin summary, the same contract as the native test_host
// (`cat $t | love` then grep "tests pass"). A third runtime after the host
// binary and the love0 bootstrap -- this one exercises wasm's <data.h>
// override (sentinel-ap data kinds, no flat code-address space).
//
// Usage: node src/port/wasm/test.mjs [--love <love.wasm | love.js>] <corpus.l...>
//   (the gate passes out/wasm/love.wasm and $t, in order)
//
// The module path is a PARAMETER: a .wasm rides loader.js (moon's own build, what the
// page ships as src/port/wasm/love.wasm), a .js is emcc's (out/wasm/love.js, `make
// wasm-emcc`) -- the same corpus over either, so the two builds can be held to each other.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const argv = process.argv.slice(2);
let mod = new URL('../../../out/wasm/love.js', import.meta.url).href, image = null;
if (argv[0] === '--love') {
  if (argv.length < 2) { console.error('--love wants a path'); process.exit(2); }
  mod = pathToFileURL(argv[1]).href;
  argv.splice(0, 2);
}
if (argv[0] === '--image') {                            // wake this heap image instead of booting the egg
  if (argv.length < 2) { console.error('--image wants a path'); process.exit(2); }
  image = readFileSync(argv[1]);
  argv.splice(0, 2);
}
const files = argv;
if (!files.length) { console.error('usage: test.mjs [--love <love.js>] <corpus.l...>'); process.exit(2); }
// The shim bakes post too, so the shell core the corpus tests (zev/charms) is already aboard.
const src = files.map(f => readFileSync(f, 'utf8')).join('\n');

// a .wasm path is moon's own module, run under loader.js; anything else is a love.js
const wasm = mod.endsWith('.wasm') ? mod : null;
const { default: Love } = await import(wasm ? new URL('./loader.js', import.meta.url).href : mod);
const m = await Love(wasm ? { wasm: new URL(wasm) } : {});
const t0 = performance.now();
if (image && !m.wake(image)) { console.error('the image was refused -- a stale bake?'); process.exit(1); }
const init = image ? 0 : m.ccall('ai_init', 'number', [], []);
if (init !== 0) { console.error(`ai_init failed (code ${init})`); process.exit(1); }
console.log(`${image ? 'woke' : 'booted'} in ${(performance.now() - t0).toFixed(0)} ms`);

m.ccall('ai_out_reset', 'null', [], []);
// Marshal the corpus through the HEAP, not ccall('string') -- that copies onto
// the wasm stack, and the ~350K corpus overflows it ("memory access out of
// bounds"). ai_eval takes a const char*, so pass a malloc'd pointer.
const nbytes = m.lengthBytesUTF8(src) + 1;
const ptr = m._malloc(nbytes);
m.stringToUTF8(src, ptr, nbytes);
let code = 0;
try {
  code = m.ccall('ai_eval', 'number', ['number'], [ptr]);
} catch (e) {
  // a failing assert calls (exit 1); under emscripten that throws to unwind.
  code = (e && typeof e.status === 'number') ? e.status : 1;
}
m._free(ptr);

const out = m.UTF8ToString(m.ccall('ai_out_ptr', 'number', [], []),
                           m.ccall('ai_out_len', 'number', [], []));
process.stdout.write(out.endsWith('\n') ? out : out + '\n');

// "tests pass" appears once, in the final zz-fin summary -- so a truncated or
// aborted run fails here loudly rather than passing by accident.
//
// ⚠ AND THE EXIT CODE IS NOT THE VERDICT. zz-fin calls (quit 1) when anything
// failed and test_host gates on exactly that, but nothing carries it out of
// ai_eval here -- no throw, no nonzero return. a red law rode a whole gate run
// out through this line, because the summary it printed still said "tests
// pass". so the OUTPUT decides: the summary must be there and zz-fin's failure
// block must not.
const clean = out.replace(/\x1b\[[0-9;]*m/g, '');
const failed = /^\s*\d+ failed:/m.test(clean) || /assert failed/.test(clean);
if (code === 0 && /tests pass/.test(clean) && !failed) process.exit(0);
console.error(`WASM TEST FAILED (eval code ${code}`
              + (failed ? ', the corpus reported failures)' : ')'));
process.exit(1);
