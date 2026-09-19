// test/gate/idle.mjs -- the machine at rest STAYS at rest, once it has been typed at.
// the page writes a key onto two lanes: the terminal's bytes, which the guest reads, and
// inle/wasm/scan.mjs's scancodes, which only a game ever asks for. the worker holds its
// sleep while a lane has something in it (cpu.mjs's idle), so a lane nobody reads is a
// spin for the life of the page -- one keystroke and the core never comes back. the
// kernel empties an unarmed tap's lane each idle (inle/wasm/arch.c's k_idle) and the
// worker only skips the sleep for a lane that is still growing; this weighs the answer
// the only way that cannot be argued with, which is the CPU the machine spends.
// the seat is booted, typed at, and then WATCHED: a machine that sleeps spends a few
// percent of a core on its 100 Hz tick, one that spins spends all of it.
// usage: node test/gate/idle.mjs MODULE IMAGE [LOG]
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const [wasm, image, log] = process.argv.slice(2);
const seat = join(here, '..', '..', 'inle', 'wasm', 'inle.mjs');
const nap = (ms) => new Promise((r) => setTimeout(r, ms));
const ceiling = 30;                    // per cent of one core: a sleeper is ~3, a spinner 100

// the child's own CPU, off /proc. a seat without one cannot be weighed, and says so
// rather than passing quietly.
const spent = (pid) => {
  const f = readFileSync(`/proc/${pid}/stat`, 'utf8').split(') ').pop().split(' ');
  return (Number(f[11]) + Number(f[12])) / 100; };                // utime + stime, seconds
try { readFileSync('/proc/self/stat'); }
catch { console.log('  idle: skipped (no /proc to weigh the machine with)'); process.exit(0); }

const child = spawn(process.execPath,
  [seat, '--fb', '1600x900', '--press', 'KeyA', '--after', '4', '--for', '14',
   '--image', image, wasm, 'sh', '--login'],
  { stdio: ['ignore', log ? (await import('node:fs')).openSync(log, 'w') : 'ignore', 'ignore'],
    env: { ...process.env, INLE_RAM: '256' } });

await nap(8000);                       // boot, the key, and a breath after it
const a = spent(child.pid), t0 = Date.now();
await nap(5000);
const pct = (spent(child.pid) - a) / ((Date.now() - t0) / 1000) * 100;
child.kill('SIGKILL');

const ok = pct < ceiling;
console.log(ok ? `  idle: ok -- ${pct.toFixed(1)}% of a core after a keystroke, so the machine still sleeps`
                : `FAIL idle: ${pct.toFixed(1)}% of a core after a keystroke -- a lane nobody reads is holding the sleep off`);
process.exit(ok ? 0 : 1);
