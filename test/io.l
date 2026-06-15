; Port nifs that take an explicit port: fgetc, fungetc, feof, fputc, fputs,
; fflush. Sibling forms of the static-port (getc/putc/key?) nifs that
; dispatch via f->io. open/close round out the surface for heap-allocated
; stream ports backed by real OS file descriptors.

(assert
  ; The static frontend ports are globally bound to `in` and `out`.
  ; They are heap-shaped (lvm_port_io discriminator), so the default
  ; printer renders them as a hex address — non-empty and string-typed.
  (strp (show in))
  (strp (show out))
  (< 0 (sat (show in)))
  (< 0 (sat (show out)))

  ; fungetc + fgetc roundtrip on stdin (within a single top-level form,
  ; otherwise the REPL parser would consume the pushed-back byte itself).
  (: (rt c) (: _ (fungetc in c) (fgetc in))
   (do (= 65  (rt 65))
      (= 32  (rt 32))
      (= 255 (rt 255))))

  ; fungetc returns the byte it pushed.
  (: _ (fgetc in)   ; pull and discard whatever's at the head
   (= 99 (fungetc in 99)))
  ; ...and the pushed byte is then the next read.
  (= 99 (fgetc in))

  ; A non-port reads as an already-empty stream: (fgetc x) is -1 (EOF), not the
  ; echoed x, so a read-until-(-1) loop over an absent or misused port terminates
  ; instead of spinning on a value that never equals -1. This is what keeps the
  ; file roundtrip below bounded on a host with no filesystem, where `open` is a
  ; missing name that resolves to a non-port.
  (= -1 (fgetc 42))
  (= -1 (fgetc "notaport"))

  ; File-I/O roundtrip: write a string to /tmp via fputs, read it back
  ; byte-by-byte via fgetc, rebuild as a string with str, and compare.
  ; The payload is (show (clock 0)) so the bytes vary every run --
  ; a literal string would let a stale file from a previous run pass.
  ; the wasm shim has no filesystem (fd ports are stubbed to EOF/out-buffer), so
  ; real-file I/O can't round-trip there; gated to the hosted builds. The read
  ; loop is bounded everywhere now (fgetc on a non-port is EOF), so the stubbed
  ; path no longer OOMs. In-memory ports (sip, below) still run on wasm.
  (? w64 (: txt (show (clock 0))
     wp (open "/tmp/l-io-test" "w")
     _ (fputs wp txt)
     _ (close wp)
     rp (open "/tmp/l-io-test" "r")
     (slurp acc) (: c (fgetc rp) (? (= c -1) (rev acc) (slurp (cons c acc))))
     rd (string (slurp 0))
     _ (close rp)
     (= txt rd)) 1)

  ; --- sip: charlist-backed read-only synth port (fd=-4, ci) ---
  ; sip returns a port whose show rendering is a non-empty string.
  (strp (show (sip 0)))
  (< 0 (sat (show (sip 0))))
  ; Each call allocates a fresh port object.
  (: p (sip 0) q (sip 0) !(= p q))

  ; --- read: one datum per call from a port. ---
  ; read returns datum on success, the caller-supplied sentinel `e` on
  ; clean EOF, and the port itself on g_status_more (input ends inside an
  ; unfinished form). The port and `e` are distinct, so the caller can
  ; tell them apart by equality.
  ;
  ; Empty input: immediately hits EOF, returns the sentinel.
  (= 99 (read (sip 0) 99))
  ; Caller chooses any sentinel value.
  (= 'eof (read (sip 0) 'eof))

  ; Single datum: number, symbol, list, quoted form, string literal.
  (= 1 (read (sip '(49)) 99))                          ; "1"
  (= 'a (read (sip '(97)) 99))                         ; "a"
  (: r (read (sip '(40 49 32 50 41)) 99)               ; "(1 2)"
     (do (twop r) (= 1 (cap r)) (= 2 (caup r))))
  (: r (read (sip '(39 49)) 99)                        ; "'1" -> (` 1)
     (do (twop r) (= 1 (caup r))))
  ; "hi" -- string literal round-trip through the ci port.
  (= (string (cons 104 (cons 105 0))) (read (sip '(34 104 105 34)) 99))

  ; Sequential reads: pull each datum in source order; final read returns e.
  (: p (sip '(49 32 50 32 51))                          ; "1 2 3"
     (do (= 1 (read p 99))
        (= 2 (read p 99))
        (= 3 (read p 99))
        (= 99 (read p 99))))

  ; Whitespace and ;-comments are skipped between datums.
  (= 1 (read (sip '(32 32 49 32 32)) 99))              ; "  1  "
  (= 2 (read (sip '(59 32 99 109 116 10 50)) 99))      ; "; cmt\n2"

  ; A bare close-paren at top level is treated as clean end-of-input.
  (= 99 (read (sip '(41)) 99))                          ; ")"

  ; --- g_status_more cases: read returns the port itself, distinct from e ---
  ; Unclosed list.
  (: p (sip '(40)) r (read p 99) (do (= r p) !(= r 99)))
  ; Unterminated string.
  (: p (sip '(34 97)) (= p (read p 99)))                ; "\"a"
  ; Dangling quote.
  (: p (sip '(39)) (= p (read p 99)))                   ; "'"

  ; After a g_status_more, the port's source is exhausted; the next read
  ; sees top-level EOF and returns the sentinel.
  (: p (sip '(40)) _ (read p 99) (= 99 (read p 99)))

  ; Caller may pass the port itself as the EOF sentinel to collapse
  ; EOF and more into one "no datum" case.
  (: p (sip 0)     (= p (read p p)))                    ; clean EOF
  (: p (sip '(40)) (= p (read p p)))                    ; more

  ; The port stays usable across complete forms in mixed sequences.
  (: p (sip '(40 41 32 49))                              ; "() 1"
     (do (= 0 (read p 99))                                 ; () -> nil
        (= 1 (read p 99))
        (= 99 (read p 99))))

  ; Misuse: non-port first argument leaves the sentinel in place.
  (= 99 (read 42 99))
  (= 'x (read 'notaport 'x))

  ; `read` in the prel is defined as (read in) -- a curried read
  ; bound to the stdin port. Verify the binding is a function (callable
  ; closure), not the raw port or sentinel value.
  !(= read in))
