// test/holo/wasm.mjs -- the other half of test/holo/wasm.l: instantiate the module love laid
// under node (V8's validator and engine, not ours) and hold every export to its answer.
// usage: node test/holo/wasm.mjs [out/.holo.wasm]
import { readFileSync } from 'node:fs';

const path = process.argv[2] ?? 'out/.holo.wasm';
const seen = [];
const { instance } = await WebAssembly.instantiate(readFileSync(path),
  { env: { sys: (x) => { seen.push(x); return x + 1n; } } });
const e = instance.exports;

let pass = 0, fail = 0;
const chk = (name, ok) => { if (ok) pass++; else { fail++; console.log(`FAIL ${name}`); } };

chk('start ran the import', seen.length === 1 && seen[0] === 7n);
chk('add', e.add(2n, 3n) === 5n);
chk('add wraps', e.add(9223372036854775807n, 1n) === -9223372036854775808n);
chk('dispatch loop sum', e.sum(100n) === 5050n);
chk('dispatch loop sum 0', e.sum(0n) === 0n);
chk('data segment', new TextDecoder().decode(new Uint8Array(e.mem.buffer, 8, 2)) === 'hi');
chk('store then load at a 64-bit address', e.poke(4096n, -5n) === -5n && e.peek(4096n) === -5n);
chk('call_indirect', e.call2(40n, 2n) === 42n);
// a 64-bit memory's grow speaks BigInt: the engine's own word that the address type is i64
chk('memory64 grow answers pages as i64', e.mem.grow(1n) === 1n && e.mem.buffer.byteLength === 131072);

// rung 1: functions lowered from holo's IR by wasm-fn
chk('ir loop: isum', e.isum(100n) === 5050n && e.isum(0n) === 0n);
chk('ir recursion: fib through call', e.fib(20n) === 6765n && e.fib(1n) === 1n);
chk('ir labels fall through: classify', e.classify(-7n) === -1n && e.classify(0n) === 0n && e.classify(9n) === 1n);
chk('ir sized memory ops', e.memops(8192n) === 8589934689n);
chk('ir flags: set, test, unsigned', e.bits(-1n, 1n) === 1110n && e.bits(1n, 2n) === 1011n);

// rung 2: the second module, laid whole by wasm-program -- doubles ride as their bits
const path2 = process.argv[3] ?? 'out/.holo2.wasm';
const m2 = (await WebAssembly.instantiate(readFileSync(path2), {})).instance.exports;
const f64 = new Float64Array(1), i64 = new BigInt64Array(f64.buffer);
const bits = (x) => { f64[0] = x; return i64[0]; };
const dbl = (b) => { i64[0] = b; return f64[0]; };
const NaNb = bits(NaN);

chk('double loop: dsum', dbl(m2.dsum(100n)) === 5050 && dbl(m2.dsum(0n)) === 0);
chk('double ops: a*b - a/b', dbl(m2.dops(bits(3.5), bits(2))) === 5.25);
// bit i: above be ae below eq ne p np -- rv64's law, so be/below fire on NaN
chk('float conditions', m2.dcmp(bits(3), bits(2)) === 165n && m2.dcmp(bits(2), bits(2)) === 150n
                       && m2.dcmp(bits(2), bits(3)) === 170n && m2.dcmp(NaNb, bits(2)) === 106n);
chk('float branch: dabs', dbl(m2.dabs(bits(-2.5))) === 2.5 && dbl(m2.dabs(bits(4))) === 4
                        && Number.isNaN(dbl(m2.dabs(NaNb))));
chk('conversions saturate', m2.dcvt(5n) === 10n && m2.dcvt(-1n) === -2n && m2.dcvt(-7n) === -8n);
const u32 = new Uint32Array(m2.mem.buffer), f32 = new Float32Array(m2.mem.buffer);
const r = m2.fimg(1024n, bits(0.1));
chk('float image: narrowed, stored, its bits, widened', f32[256] === Math.fround(0.1)
    && u32[258] === new Uint32Array(new Float32Array([0.1]).buffer)[0] && dbl(r) === Math.fround(0.1));
chk('adds/subs overflow flag', m2.addo(1n, 2n) === 3n && m2.addo(9223372036854775807n, 1n) === 7777n
    && m2.subo(-9223372036854775808n, 1n) === 7777n && m2.subo(5n, 7n) === -2n);
chk('test after ucomisd reads the ALU flags', m2.fthen(bits(-1), 0n) === 0n && m2.fthen(bits(-1), 1n) === 1n);
chk('mulo overflow branch', m2.mulo(3n, 4n) === 12n && m2.mulo(4611686018427387904n, 4n) === 7777n
    && m2.mulo(-1n, -9223372036854775808n) === 7777n && m2.mulo(-9223372036854775808n, 1n) === -9223372036854775808n
    && m2.mulo(0n, -9223372036854775808n) === 0n);

console.log(`test/holo/wasm: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
