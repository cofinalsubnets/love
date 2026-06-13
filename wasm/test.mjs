// wasm test harness: run the love test corpus through the emscripten build
// and gate on the zz-fin summary, the same contract as the native test_host
// (`cat $t | love` then grep "tests pass"). A third runtime after the host
// binary and the love0 bootstrap -- this one exercises wasm's <data.h>
// override (sentinel-ap data kinds, no flat code-address space).
//
// Usage: node wasm/test.mjs <corpus.l...>   (the Makefile passes $t, in order)
import Love from './love.js';
import { readFileSync } from 'node:fs';

const files = process.argv.slice(2);
if (!files.length) { console.error('usage: test.mjs <corpus.l...>'); process.exit(2); }
// The shim bakes only prelude+ev (the page feeds the REPL through love_eval),
// but the native runner has repl.l baked too -- and the corpus tests its surface
// (zev/charms in zev.l). Load it first so the wasm test sees the same full stack.
const src = [readFileSync('love/repl.l', 'utf8'),
             ...files.map(f => readFileSync(f, 'utf8'))].join('\n');

const m = await Love();
const init = m.ccall('love_init', 'number', [], []);
if (init !== 0) { console.error(`love_init failed (code ${init})`); process.exit(1); }

m.ccall('love_out_reset', 'null', [], []);
// Marshal the corpus through the HEAP, not ccall('string') -- that copies onto
// the wasm stack, and the ~350K corpus overflows it ("memory access out of
// bounds"). love_eval takes a const char*, so pass a malloc'd pointer.
const nbytes = m.lengthBytesUTF8(src) + 1;
const ptr = m._malloc(nbytes);
m.stringToUTF8(src, ptr, nbytes);
let code = 0;
try {
  code = m.ccall('love_eval', 'number', ['number'], [ptr]);
} catch (e) {
  // a failing assert calls (exit 1); under emscripten that throws to unwind.
  // Fall through to the output check, which won't find the pass summary.
  code = (e && typeof e.status === 'number') ? e.status : 1;
}
m._free(ptr);

const out = m.UTF8ToString(m.ccall('love_out_ptr', 'number', [], []),
                           m.ccall('love_out_len', 'number', [], []));
process.stdout.write(out.endsWith('\n') ? out : out + '\n');

// "tests pass" appears once, in the final zz-fin summary -- so a truncated or
// aborted run fails here loudly rather than passing by accident.
const clean = out.replace(/\x1b\[[0-9;]*m/g, '');
if (code === 0 && /tests pass/.test(clean) && !/assert failed/.test(clean)) process.exit(0);
console.error(`WASM TEST FAILED (eval code ${code})`);
process.exit(1);
