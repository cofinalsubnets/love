; Port nifs that take an explicit port: get, unget, end?, put, say,
; flush. Sibling forms of the static-port (getc/putc/key?) nifs that
; dispatch via f->io. open/close round out the surface for heap-allocated
; stream ports backed by real OS file descriptors.

(assert
  ; The static frontend ports are globally bound to `in` and `out`.
  ; They are heap-shaped (lvm_port_io discriminator), so the default
  ; printer renders them as a hex address — non-empty and string-typed.
  (string? (show in))
  (string? (show out))
  (< 0 (sat (show in)))
  (< 0 (sat (show out)))

  ; unget + get roundtrip on stdin (within a single top-level form,
  ; otherwise the REPL parser would consume the pushed-back byte itself).
  (: (rt c) (: _ (unget in c) (get in))
   (do (= 65  (rt 65))
      (= 32  (rt 32))
      (= 255 (rt 255))))

  ; unget returns the byte it pushed.
  (: _ (get in)   ; pull and discard whatever's at the head
   (= 99 (unget in 99)))
  ; ...and the pushed byte is then the next read.
  (= 99 (get in))

  ; A non-port reads as an already-empty stream: (get x) is -1 (EOF), not the
  ; echoed x, so a read-until-(-1) loop over an absent or misused port terminates
  ; instead of spinning on a value that never equals -1. This is what keeps the
  ; file roundtrip below bounded on a host with no filesystem, where `open` is a
  ; missing name that resolves to a non-port.
  (= -1 (get 42))
  (= -1 (get "notaport"))

  ; File-I/O roundtrip: write a string to /tmp via say, read it back
  ; byte-by-byte via get, rebuild as a string with str, and compare.
  ; The payload is (show (clock 0)) so the bytes vary every run --
  ; a literal string would let a stale file from a previous run pass.
  ; the wasm shim has no filesystem (fd ports are stubbed to EOF/out-buffer), so
  ; real-file I/O can't round-trip there; gated to the hosted builds. The read
  ; loop is bounded everywhere now (get on a non-port is EOF), so the stubbed
  ; path no longer OOMs. In-memory ports (sip, below) still run on wasm.
  (? wint (: txt (show (clock 0))
     wp (open "/tmp/l-io-test" "w")
     _ (say wp txt)
     _ (close wp)
     rp (open "/tmp/l-io-test" "r")
     (slurp acc) (: c (get rp) (? (= c -1) (rev acc) (slurp (link c acc))))
     rd (string (slurp 0))
     _ (close rp)
     (= txt rd)) 1)

  ; --- sip: charlist-backed read-only synth port (fd=-4, ci) ---
  ; sip returns a port whose show rendering is a non-empty string.
  (string? (show (tap 0)))
  (< 0 (sat (show (tap 0))))
  ; Each call allocates a fresh port object.
  (: p (tap 0) q (tap 0) !(= p q))

  ; --- read: one datum per call from a port. ---
  ; read returns datum on success, the caller-supplied sentinel `e` on
  ; clean EOF, and the port itself on g_status_more (input ends inside an
  ; unfinished form). The port and `e` are distinct, so the caller can
  ; tell them apart by equality.
  ;
  ; Empty input: immediately hits EOF, returns the sentinel.
  (= 99 (scan (tap 0) 99))
  ; Caller chooses any sentinel value.
  (= 'eof (scan (tap 0) 'eof))

  ; Single datum: number, symbol, list, quoted form, string literal.
  (= 1 (scan (tap '(49)) 99))                          ; "1"
  (= 'a (scan (tap '(97)) 99))                         ; "a"
  (: r (scan (tap '(40 49 32 50 41)) 99)               ; "(1 2)"
     (do (two? r) (= 1 (cap r)) (= 2 (caup r))))
  (: r (scan (tap '(39 49)) 99)                        ; "'1" -> (` 1)
     (do (two? r) (= 1 (caup r))))
  ; "hi" -- string literal round-trip through the ci port.
  (= (string (link 104 (link 105 0))) (scan (tap '(34 104 105 34)) 99))

  ; Sequential reads: pull each datum in source order; final read returns e.
  (: p (tap '(49 32 50 32 51))                          ; "1 2 3"
     (do (= 1 (scan p 99))
        (= 2 (scan p 99))
        (= 3 (scan p 99))
        (= 99 (scan p 99))))

  ; Whitespace and ;-comments are skipped between datums.
  (= 1 (scan (tap '(32 32 49 32 32)) 99))              ; "  1  "
  (= 2 (scan (tap '(59 32 99 109 116 10 50)) 99))      ; "; cmt\n2"

  ; A bare close-paren at top level is treated as clean end-of-input.
  (= 99 (scan (tap '(41)) 99))                          ; ")"

  ; --- g_status_more cases: read returns the port itself, distinct from e ---
  ; Unclosed list.
  (: p (tap '(40)) r (scan p 99) (do (= r p) !(= r 99)))
  ; Unterminated string.
  (: p (tap '(34 97)) (= p (scan p 99)))                ; "\"a"
  ; Dangling quote.
  (: p (tap '(39)) (= p (scan p 99)))                   ; "'"

  ; After a g_status_more, the port's source is exhausted; the next read
  ; sees top-level EOF and returns the sentinel.
  (: p (tap '(40)) _ (scan p 99) (= 99 (scan p 99)))

  ; Caller may pass the port itself as the EOF sentinel to collapse
  ; EOF and more into one "no datum" case.
  (: p (tap 0)     (= p (scan p p)))                    ; clean EOF
  (: p (tap '(40)) (= p (scan p p)))                    ; more

  ; The port stays usable across complete forms in mixed sequences.
  (: p (tap '(40 41 32 49))                              ; "() 1"
     (do (= 0 (scan p 99))                                 ; () -> nil
        (= 1 (scan p 99))
        (= 99 (scan p 99))))

  ; Misuse: non-port first argument leaves the sentinel in place.
  (= 99 (scan 42 99))
  (= 'x (scan 'notaport 'x))

  ; `scan` reads one datum; `(scan in)` is a curried scan
  ; bound to the stdin port. Verify the binding is a function (callable
  ; closure), not the raw port or sentinel value.
  !(= scan in))
