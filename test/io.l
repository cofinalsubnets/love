; Port nifs that take an explicit port: fgetc, fungetc, feof, fputc, fputs,
; fflush. Sibling forms of the static-port (getc/putc/key?) nifs that
; dispatch via f->io. open/close round out the surface for heap-allocated
; stream ports backed by real OS file descriptors.

(assert
  ; The static frontend ports are globally bound to `in` and `out`.
  ; They are heap-shaped (g_vm_port_io discriminator), so the default
  ; printer renders them as a hex address — non-empty and string-typed.
  (strp (inspect in))
  (strp (inspect out))
  (< 0 (hash (inspect in)))
  (< 0 (hash (inspect out)))

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

  ; File-I/O roundtrip: write a string to /tmp via fputs, read it back
  ; byte-by-byte via fgetc, rebuild as a string with str, and compare.
  ; The payload is (inspect (clock 0)) so the bytes vary every run --
  ; a literal string would let a stale file from a previous run pass.
  (: txt (inspect (clock 0))
     wp (open "/tmp/ll-io-test" "w")
     _ (fputs wp txt)
     _ (close wp)
     rp (open "/tmp/ll-io-test" "r")
     (slurp acc) (: c (fgetc rp) (? (= c -1) (rev acc) (slurp (X c acc))))
     rd (string (slurp 0))
     _ (close rp)
     (= txt rd))

  ; --- strin: charlist-backed read-only synth port (fd=-4, ci) ---
  ; strin returns a port whose inspect rendering is a non-empty string.
  (strp (inspect (strin 0)))
  (< 0 (hash (inspect (strin 0))))
  ; Each call allocates a fresh port object.
  (: p (strin 0) q (strin 0) !(= p q))

  ; --- fread: one datum per call from a port. ---
  ; fread returns datum on success, the caller-supplied sentinel `e` on
  ; clean EOF, and the port itself on g_status_more (input ends inside an
  ; unfinished form). The port and `e` are distinct, so the caller can
  ; tell them apart by equality.
  ;
  ; Empty input: immediately hits EOF, returns the sentinel.
  (= 99 (fread (strin 0) 99))
  ; Caller chooses any sentinel value.
  (= 'eof (fread (strin 0) 'eof))

  ; Single datum: number, symbol, list, quoted form, string literal.
  (= 1 (fread (strin '(49)) 99))                          ; "1"
  (= 'a (fread (strin '(97)) 99))                         ; "a"
  (: r (fread (strin '(40 49 32 50 41)) 99)               ; "(1 2)"
     (do (twop r) (= 1 (A r)) (= 2 (AB r))))
  (: r (fread (strin '(39 49)) 99)                        ; "'1" -> (` 1)
     (do (twop r) (= 1 (AB r))))
  ; "hi" -- string literal round-trip through the ci port.
  (= (string (X 104 (X 105 0))) (fread (strin '(34 104 105 34)) 99))

  ; Sequential reads: pull each datum in source order; final read returns e.
  (: p (strin '(49 32 50 32 51))                          ; "1 2 3"
     (do (= 1 (fread p 99))
        (= 2 (fread p 99))
        (= 3 (fread p 99))
        (= 99 (fread p 99))))

  ; Whitespace and ;-comments are skipped between datums.
  (= 1 (fread (strin '(32 32 49 32 32)) 99))              ; "  1  "
  (= 2 (fread (strin '(59 32 99 109 116 10 50)) 99))      ; "; cmt\n2"

  ; A bare close-paren at top level is treated as clean end-of-input.
  (= 99 (fread (strin '(41)) 99))                          ; ")"

  ; --- g_status_more cases: fread returns the port itself, distinct from e ---
  ; Unclosed list.
  (: p (strin '(40)) r (fread p 99) (do (= r p) !(= r 99)))
  ; Unterminated string.
  (: p (strin '(34 97)) (= p (fread p 99)))                ; "\"a"
  ; Dangling quote.
  (: p (strin '(39)) (= p (fread p 99)))                   ; "'"

  ; After a g_status_more, the port's source is exhausted; the next read
  ; sees top-level EOF and returns the sentinel.
  (: p (strin '(40)) _ (fread p 99) (= 99 (fread p 99)))

  ; Caller may pass the port itself as the EOF sentinel to collapse
  ; EOF and more into one "no datum" case.
  (: p (strin 0)     (= p (fread p p)))                    ; clean EOF
  (: p (strin '(40)) (= p (fread p p)))                    ; more

  ; The port stays usable across complete forms in mixed sequences.
  (: p (strin '(40 41 32 49))                              ; "() 1"
     (do (= 0 (fread p 99))                                 ; () -> nil
        (= 1 (fread p 99))
        (= 99 (fread p 99))))

  ; Misuse: non-port first argument leaves the sentinel in place.
  (= 99 (fread 42 99))
  (= 'x (fread 'notaport 'x))

  ; `read` in the prelude is defined as (fread in) -- a curried fread
  ; bound to the stdin port. Verify the binding is a function (callable
  ; closure), not the raw port or sentinel value.
  !(= read in))
