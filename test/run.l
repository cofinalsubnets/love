; Subprocess capability (host-only nifs `run` and `getenv`).
;
; (run argv) takes a LIST of strings and spawns the program named by its head
; (PATH-resolved via execvp). It returns:
;   (status . output)  -- a PAIR -- when the process ran: status is the exit
;                         code (or 128+signal if killed), output is the child's
;                         captured stdout as one string;
;   a positive fixnum  -- the OS errno -- when the program couldn't be spawned;
;   a negative fixnum  -- our-side misuse (empty argv / a non-string element).
; So `twop` is the success/failure discriminator. stderr is inherited, not
; captured. (getenv name) -> string, or nil when unset.
;
; These children are chosen so none reads stdin: under the test harness the
; child inherits l's stdin (the test-corpus pipe), and a reader would eat it.

; run/getenv are host-only (subprocess + environment); the browser shim has
; neither, so skip the whole file there (w64 = the hosted builds).
(? w64 (assert
  ; --- ran successfully: a pair, exit 0, and (here) no output ---
  (twop (run (L "true")))
  (= 0 (cap (run (L "true"))))
  (= 0 (sat (cup (run (L "true")))))            ; `true` writes nothing

  ; --- a nonzero exit code is reported as-is ---
  (= 1 (cap (run (L "false"))))

  ; --- stdout is captured (echo appends a newline) ---
  (: r (run (L "echo" "hi")) (&& (= 0 (cap r)) (= "hi\n" (cup r))))

  ; --- multiple args are marshalled in order, with no shell in between ---
  (: r (run (L "printf" "%s-%s" "ab" "cd")) (= "ab-cd" (cup r)))

  ; --- a program that can't be spawned -> positive errno fixnum, NOT a pair ---
  (: r (run (L "/no/such/prog-xyzzy")) (&& (fixp r) (< 0 r)))   ; abs path: ENOENT
  (: r (run (L "no-such-prog-xyzzy"))  (&& (fixp r) (< 0 r)))   ; PATH miss: ENOENT

  ; --- our-side misuse -> -1 (a negative fixnum, distinct from any errno) ---
  (= -1 (run 0))                                ; empty argv (nil)
  (= -1 (run (L "echo" 5)))                     ; 5 is not a string

  ; --- output larger than the initial buffer exercises the grow path ---
  (: r (run (L "seq" "20000")) (&& (= 0 (cap r)) (< 65536 (sat (cup r)))))

  ; --- getenv: PATH is set (a string); a bogus name is unset (nil) ---
  (strp (getenv "PATH"))
  (= 0 (getenv "GWEN_DEFINITELY_UNSET_12345"))) 0)
