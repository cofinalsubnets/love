// test/holo/loader.mjs -- src/port/wasm/loader.js over the mock artifact test/holo/wasm.l
// lays (out/.holo3.wasm): the page's own drive (test.mjs's shape -- init, a string through
// the heap, eval, drain the out buffer), the syscalls the kernel-in-JS answers, and exit.
// usage: node test/holo/loader.mjs [out/.holo3.wasm]
import Love, { ExitStatus } from '../../src/port/wasm/loader.js';

const path = process.argv[2] ?? 'out/.holo3.wasm';
const lines = [];
const M = await Love({ wasm: path, print: (s) => lines.push(s) });

let pass = 0, fail = 0;
const chk = (name, ok) => { if (ok) pass++; else { fail++; console.log(`FAIL ${name}`); } };

chk('the global', globalThis.Love === Love);
chk('ai_init: the clock and the kernel probe', M.ccall('ai_init', 'number', [], []) === 0);
const [sec, nsec] = new BigInt64Array(M.memory.buffer, 32, 2);   // monotonic: since the process began
chk('clock_gettime landed a timespec', sec >= 0n && sec < 100000n && nsec >= 0n && nsec < 1000000000n);
M.ccall('ai_out_reset', 'null', [], []);
const src = 'hello, môon';
const n = M.lengthBytesUTF8(src) + 1, p = M._malloc(n);
chk('malloc through the bump', p >= 65536 && M.stringToUTF8(src, p, n) === n - 1);
chk('ai_eval over a heap string', M.ccall('ai_eval', 'number', ['number'], [p]) === 0);
M._free(p);
const out = M.UTF8ToString(M.ccall('ai_out_ptr', 'number', [], []), M.ccall('ai_out_len', 'number', [], []));
chk('the out buffer drains', out === src);
chk('write(1) reached print', lines.length === 1 && lines[0] === src);
chk('cwrap', M.cwrap('ai_out_len', 'number', [])() === M.lengthBytesUTF8(src));
chk("ccall's own string marshalling", M.ccall('ai_eval', 'number', ['string'], ['!']) === 0
    && M.UTF8ToString(4096, M.lengthBytesUTF8(src) + 1) === src + '!');
chk('HEAPU8 is the live memory', M.HEAPU8[4096] === 'h'.charCodeAt(0) && M.HEAPU32.length * 4 === M.memory.buffer.byteLength);
const before = M.memory.buffer.byteLength;
chk('mmap grows the memory and the page is writable', M.ccall('ai_grow', 'number', [], []) === 77
    && M.memory.buffer.byteLength === before + 65536);
chk('a raw export speaks BigInt', M._ai_out_len() === BigInt(M.lengthBytesUTF8(src) + 1));
let status = -1;
try { M.ccall('ai_exit', 'null', ['number'], [3]); } catch (e) { if (e instanceof ExitStatus) status = e.status; }
chk('exit throws ExitStatus with its code', status === 3);

console.log(`test/holo/loader: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
