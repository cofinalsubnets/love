; leads the corpus: posix first, then a no-op for each frontend nif a bare target
; (kernel, wasm) lacks, so later mentions compile and answer ()
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

; the reader under test, for every print->read differential:
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
   ; a runner not ending in zz-fin.l owes its own (test_fin ()), or failures exit 0
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
; cost growth: (f (4 * n)) under 8x (f n) after a warm run (linear ~4, quadratic 16).
; counts evaluator ticks (gauge [16]), never the clock; -words counts words allocated
(: (test-turns f n) (: p (twirl (_ \ (rest 1000000000)) ()) _ (rest 0)
     t0 (peep (gauge 0) 16 0) _ (f n) t1 (peep (gauge 0) 16 0) _ (freeze p)
     (t1 - t0))
   (test-words f n) (: _ (please 1) w0 (peep (gauge 0) 6 0) _ (f n) _ (please 1)   ; [6] sums each nursery's fill
                      (peep (gauge 0) 6 0 - w0))
   (test-grows c f n) (: _ (f n) a (c f n) b (c f (4 * n)) (b < 8 * a))
   (test-linear f n) (test-grows test-turns f n)
   (test-linear-words f n) (test-grows test-words f n))

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
