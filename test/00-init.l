; the corpus mentions the frontend nifs (quit/open/close/run/getenv); a bare target
; (kernel, wasm) binds few of them, and an unbound mention raises missing at every
; define that names one. this file leads the corpus, so pin a no-op fallback for
; whichever are absent: every later mention compiles quiet, and absence answers ().
; the posix doors are a module of their own now (src/love/posix.c's rows name it) and the
; corpus is ONE scope, so splicing it here is what lets every later file spell `open`
; plainly -- and it must come before the fallbacks, which read what is in scope. a seat
; without posix has no such module, and those fallbacks still cover it.
(cite 'posix ? (borrow 'posix))
(map (n \ elem n (names ()) ? () (ev [': [n 'x] ()])) '(quit close run getenv))
(elem 'open (names ()) ? () (ev '(: (open x y) ())))

; test/gate/skip.sh's twin: a test that cannot run here says why through these, and on a
; box marked strict (~/.love/etc/gate-strict, or LOVE_GATE_STRICT) the skip is red
(: (gate-strict? _) (? (getenv "LOVE_GATE_STRICT")
                      1 (open ((getenv "HOME") + "/.love/etc/gate-strict") "r" @ q (hot? q ? (close q, 1) 0)))
   (gate-skip m) (gate-strict? 0 ? (puts (m + " -- REFUSED: a strict box runs every lane\n"), quit 1)
                  (puts (m + "\n"), quit 0))
   (gate-partly m) (gate-strict? 0 ? (puts (m + " -- REFUSED: a strict box runs every leg\n"), quit 1)
                    (puts (m + "\n"))))

; the reader under test -- the socket. every print->read
; differential in the tree reads through this one binding (test/roundtrip.l,
; test/fuzz.l, test/host/rdiff.l), so the whole set moves by rebinding it here
; and nowhere else. the protocol is `sound`'s: (r text) answers the datum consed
; onto the rest, () at a clean end, or `torn` where the shape ran out of text.
(: rd-test sound)

(: test_t0 (clock 0)
 ; a name the book lacks ends the run, file mode's law. a welp window says a miss is the
 ; subject; outside one, absence read as data is a bug the tally would otherwise hide.
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
   ; a failed test records and carries on, so one run shows every failure -- zz-fin.l
   ; prints the list and quits 1. a runner that does not end in zz-fin.l owes a
   ; (test_fin ()) of its own before it claims ok, or its failures exit 0 in silence.
   (test_fin u) (test_get 'fail @ f
                 (? (two? f)
                    (do (puts "FAILED:") (putc 10)
                        (each f (x \ do (puts "  ") (putx x) (putc 10)))
                        (quit 1))
                    0))
   ; word: a full 64-bit-word build (native, kernel) -- which is also where reals
   ; are f64, libm is glibc's, a filesystem exists, and the RNG runs full-width.
   ; false only on the 32-bit wasm shim; gates the asserts that need any of those.
   word (32 2 < max-charm)
   ; hosted: a kernel underneath -- processes (hark), an environ, a filesystem. false on
   ; inle and in the browser, where love-os says so; gates the laws that reach the OS.
   hosted (love-os @ ('linux || 'freebsd || 'netbsd) 1 0)
   ; files: a real filesystem underneath -- native AND inle (a ramfs), not the browser.
   ; word was this proxy while the wasm shim was 32-bit; the wasm64 module is 64-bit, so
   ; word is true there now and a filesystem law needs its own predicate.
   files !(love-os = 'wasm)
   ; (f 0) with stdout sent nowhere: the editor paints the terminal and asks it questions,
   ; whose answers would land on the command line after the run
   (test-mute f) (!(hosted && elem 'openfd (names ())) ? (f 0)
                    (: _ (flush out) s (dup 1) n (openfd "/dev/null" 1) ((dup2 n 1, close n),
                                                                         mind f () (_ \ (flush out, dup2 s 1, close s))))))
; ports of this run's own: two runs at once, a gate's and a hand's, never share one. a
; process takes its ports in turn from a block its pid picks, never one twice, and steps
; past any already taken; a server another process opens is ready when it answers, not
; after a fixed nap
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

(:: 'test (l \
               (:
                (report x v) (do
                 (test_set 'count (1 + test_get 'count))
                  (v ? (term_text green_dot)
                   (do (term_text red_x)
                      (test_set 'fail (x . (two? (test_get 'fail) ? (test_get 'fail)))))))
                ('do . map (l \ [report ['\ l] l]) l))))

; the codec tests' reads: a file whole ("" for none), s16le as signed numbers, and 11172-4's
; full accuracy -- the rms under 1/sqrt 12 of a step, none more than two
(: (av-t-rd p) (open p "r" @ q (hot? q ? (: s (slurp q) (close q, s)) ""))
   (av-t-s16 s) ((cite 'guts 'peepv) (: c (cask #s) (pour c 0 s 0 #s, c)) 0 2 2 (#s // 2) @ t (t - 65536 * (t >= 32768)))
   (av-t-full a b) (? (#a != #b || #a < 2) 0
                      (: d (av-t-s16 a - av-t-s16 b) (net (d * d) / (#a // 2) < 1 / 12 && aall (d <= 2) && aall (d >= -2)))))

(hear test-strict)
