; the corpus mentions the frontend nifs (quit/open/close/run/getenv); a bare target
; (kernel, wasm) binds few of them, and an unbound mention raises missing at every
; define that names one. this file leads the corpus, so pin a no-op fallback for
; whichever are absent: every later mention compiles quiet, and absence answers ().
; the posix doors are a module of their own now (src/love/posix.c's rows name it) and the
; corpus is ONE scope, so splicing it here is what lets every later file spell `open`
; plainly -- and it must come before the fallbacks, which read what is in scope. a seat
; without posix has no such module, and those fallbacks still cover it.
(? (cite 'posix) (borrow 'posix) ())
(map (\ n (? (elem n (names ())) () (ev [': [n 'x] ()]))) '(quit close run getenv))
(? (elem 'open (names ())) () (ev '(: (open x y) ())))

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

   test_state (tablet 0)
   (test_set k v) (pin test_state k v)
   (test_get k) (peep test_state k 0)
   ; a failed test records and carries on, so one run shows every failure -- zz-fin.l
   ; prints the list and quits 1. a runner that does not end in zz-fin.l owes a
   ; (test_fin ()) of its own before it claims ok, or its failures exit 0 in silence.
   (test_fin u) (: f (test_get 'fail)
                   (? (two? f)
                      (do (puts "FAILED:") (putc 10)
                          (each f (\ x (do (puts "  ") (putx x) (putc 10))))
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
   files !(love-os = 'wasm))
; ports of this run's own: two runs at once, a gate's and a hand's, never share one. a
; process takes its ports in turn from a block its pid picks, never one twice, and steps
; past any already taken; a server another process opens is ready when it answers, not
; after a fixed nap
(: (test-next u) (: k (test_get 'port) _ (test_set 'port (k + 1)) (20000 + 64 * (getpid 0 % 600) + k))
   (test-seat f) (: (try n) (: p (test-next 0) s (f p) (? (!(nom? s) || n <= 0) [p s] (try (n - 1))))
                    (try 63))
   (test-listen u) (test-seat listen)                       ; [port listener]
   (test-bind u) (test-seat (\ p (bind ['udp p])))         ; [port socket]
   (test-free u) (: q (test-listen 0) _ (close (q 1)) <q)   ; a port nothing listens on, yet
   ; f again, a quarter second apart for up to ten, while (busy? answer) says not yet
   (test-until busy? f) (: (go n) (: r (f 0) (? (n < 40 && busy? r) (: _ (rest 250) (go (n + 1))) r))
                           (go 0))
   ; a server that takes many connections is up when one lands on loopback at port p
   (test-up p) (test-until nom? (\ _ (: c (connect ['tcp "127.0.0.1" p]) (? (nom? c) c (close c))))))

(:: 'test (\ l
(:
 (report x v) (do
  (test_set 'count (1 + test_get 'count))
   (? v (term_text green_dot)
    (do (term_text red_x)
       (test_set 'fail (x . (? (two? (test_get 'fail)) (test_get 'fail) ()))))))
 ('do . map (\ l [report ['\ l] l]) l))))

(hear test-strict)
