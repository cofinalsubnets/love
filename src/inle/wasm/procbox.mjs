// src/inle/wasm/procbox.mjs -- a process's mailbox, the shape proc.mjs (the process) and cpu.mjs
// (the kernel's worker) share. Int32 [0] 0 free, 1 asked, 2 answered; [1] which arguments are
// pointers; [2] the window's bytes in use. BigInt64 from byte 16: the number and six arguments,
// the answer at [7], a ppoll's deadline in ms at [8] (0 none). the window from byte box_at: a
// pointer argument carries its offset there, and the bytes ride to kernel memory and back.
export const box_at = 128, box_win = 65536, box_n = box_at + box_win;
// a process worker that died outside its own catch: the terminal says so for it, an exit with
// the status a fault leaves, so the kernel lets the process go and its waiter wakes
export const procdied = (boxb, ring) => {
  const st = new Int32Array(boxb, 0, 4), args = new BigInt64Array(boxb, 16, 9), ctl = new Int32Array(ring, 0, 4);
  args[0] = 231n, args[1] = 134n, st[1] = 0, st[2] = 0;
  Atomics.store(st, 0, 1);
  Atomics.add(ctl, 2, 1), Atomics.notify(ctl, 2); };
