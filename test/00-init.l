; this file leads the corpus: splice posix first, then a no-op for each frontend nif
; a bare target (kernel, wasm) lacks, so later mentions compile quiet and answer ()
(cite 'posix ? (borrow 'posix))
(map (n \ elem n (names ()) ? () (ev [': [n 'x] ()])) '(quit close run getenv))
(elem 'open (names ()) ? () (ev '(: (open x y) ())))

; a test that cannot run here says why; on a strict box (LOVE_GATE_STRICT) a skip is red
(: (gate-strict? _) (? (getenv "LOVE_GATE_STRICT")
                      1 (open ((getenv "HOME") + "/.love/etc/gate-strict") "r" @ q (hot? q ? (close q, 1) 0)))
   (gate-skip m) (gate-strict? 0 ? (puts (m + " -- REFUSED: a strict box runs every lane\n"), quit 1)
                  (puts (m + "\n"), quit 0))
   (gate-partly m) (gate-strict? 0 ? (puts (m + " -- REFUSED: a strict box runs every leg\n"), quit 1)
                    (puts (m + "\n"))))

; the reader under test: every print->read differential reads through this one binding.
; (r text) answers the datum consed onto the rest, () at a clean end, `torn` if cut short
(: rd-test sound)

(: test_t0 (clock 0)
 ; a missing name ends the run unless a welp window makes the miss the subject
 (test-strict a b) (say err (";; " + show a + " " + show b), put err 10,
                      flush err, quit 1, welp a b)
 (term_esc string) (do (putc 27) (puts string))
 green_dot "[32m."
 red_x "[31mX"
 reset "[0m"
 (term_text s)
  (do (putc 27)
     (puts s)
     (putc 27)
     (puts reset))

   test_state {}
   (test_set k v) (pin test_state k v)
   (test_get k) (peep test_state k 0)
   ; a failed test records and carries on; a runner not ending in zz-fin.l owes its own
   ; (test_fin ()), or its failures exit 0 in silence
   (test_fin u) (test_get 'fail @ f
                 (? (two? f)
                    (do (puts "FAILED:") (putc 10)
                        (each f (x \ do (puts "  ") (putx x) (putc 10)))
                        (quit 1))
                    0))
   ; a 64-bit-word build: f64 reals, full-width rng
   word (32 2 < max-charm)
   ; a host os underneath (processes, environ); false on inle and in the browser
   hosted (love-os @ ('linux || 'freebsd || 'netbsd) 1 0)
   ; the gc-stress runtime: collects at every call that may, so growth timings skip
   gcstress (: c (peep (gauge 0) 3 0) _ (map show ^64) (peep (gauge 0) 3 0 - c > 32))
   ; a real filesystem: native and inle (ramfs), not the browser
   files !(love-os = 'wasm)
   ; (f 0) with stdout to /dev/null, so a terminal's answers don't land on the command line
   (test-mute f) (!(hosted && elem 'openfd (names ())) ? (f 0)
                    (: _ (flush out) s (dup 1) n (openfd "/dev/null" 1) ((dup2 n 1, close n),
                                                                         mind f () (_ \ (flush out, dup2 s 1, close s))))))
; ports from a block the pid picks, never one twice, so concurrent runs never share one
(: (test-next u) (test_get 'port @ k (test_set 'port (k + 1), 20000 + 64 * (getpid 0 % 600) + k))
   (test-seat f) (: (try n) (: p (test-next 0) s (f p) (!(nom? s) || n <= 0 ? [p s] (try (n - 1))))
                    (try 63))
   (test-listen u) (test-seat listen)                       ; [port listener]
   (test-bind u) (test-seat (p \ bind ['udp p]))           ; [port socket]
   (test-free u) (test-listen 0 @ q (close (q 1), <q))      ; a port nothing listens on, yet
   ; f again, a quarter second apart for up to ten, while (busy? answer) says not yet
   (test-until busy? f) (: (go n) (f 0 @ r (n < 40 && busy? r ? (rest 250, go (n + 1)) r))
                           (go 0))
   ; a server that takes many connections is up when one lands on loopback at port p
   (test-up p) (test-until nom? (_ \ connect ['tcp "127.0.0.1" p] @ c (nom? c ? c (close c)))))
; best-of-five (f (4 * n)) under 8x (f n): linear sits near 4, quadratic at 16.
; answers 1 untimed off-host (coarse clock) and under gcstress
(: (test-took f n) (: t0 (nclock 0) _ (f n) (nclock t0))
   (test-best f n) (foldl min (test-took f n) (map (u \ test-took f n) ^4))
   (test-linear f n) (!hosted || gcstress || (: _ (f n) a (test-best f n) b (test-best f (4 * n)) (b < 8 * a))))

(:: 'test (l \
               (:
                (report x v) (do
                 (test_set 'count (1 + test_get 'count))
                  (v ? (term_text green_dot)
                   (do (term_text red_x)
                      (test_set 'fail (x . (two? (test_get 'fail) ? (test_get 'fail)))))))
                ('do . map (l \ [report ['\ l] l]) l))))

; codec test reads: a whole file ("" for none), s16le samples, and full accuracy
; (rms under 1/sqrt 12 of a step, none off by more than two)
(: (av-t-rd p) (open p "r" @ q (hot? q ? (: s (slurp q) (close q, s)) ""))
   (av-t-s16 s) ((cite 'guts 'peepv) (: c (cask #s) (pour c 0 s 0 #s, c)) 0 2 2 (#s // 2) @ t (t - 65536 * (t >= 32768)))
   (av-t-full a b) (? (#a != #b || #a < 2) 0
                      (: d (av-t-s16 a - av-t-s16 b) (net (d * d) / (#a // 2) < 1 / 12 && aall (d <= 2) && aall (d >= -2)))))

(hear test-strict)
