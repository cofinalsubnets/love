// port/wasm/run.mjs -- run a program mooncc built for wasm, the way a shell runs an
// executable: its _start under the loader's kernel, stdout and stderr through, the exit
// status as ours. usage: node port/wasm/run.mjs prog.wasm
import Love, { ExitStatus } from './loader.js';

const path = process.argv[2];
if (!path) { console.error('usage: run.mjs prog.wasm'); process.exit(2); }
const M = await Love({ wasm: path, print: (s) => process.stdout.write(s), printErr: (s) => process.stderr.write(s) });
try { M.ccall('_start', 'null', [], []); process.exitCode = 0; }
catch (e) { if (e instanceof ExitStatus) process.exitCode = e.status & 255; else throw e; }
