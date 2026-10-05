// src/inle/wasm/hostring.mjs -- the shape of the host lane's shared ring, on its own so the
// three that share it (cpu.mjs, hostfs.mjs, and the terminal that makes it) can import it
// without starting either worker: Int32 [0] the state (0 idle, 1 asked, 2 answered), at
// host_f64 four Float64 -- the answer, then a stat's size, date and mode -- then host_win
// bytes of window, a read's bytes back and a write's in.
export const host_f64 = 16, host_win = 1 << 20, host_at = host_f64 + 32;
export const host_shared_n = host_at + host_win;
