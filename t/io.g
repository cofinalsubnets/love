; Port bifs that take an explicit port: fgetc, fungetc, feof, fputc, fputs,
; fflush. Sibling forms of the static-port (getc/putc/key?) bifs that
; dispatch via f->io. open/close round out the surface for heap-allocated
; stream ports backed by real OS file descriptors.

(assert
  ; The static frontend ports are globally bound to `in` and `out`.
  ; They are heap-shaped (g_vm_port_io discriminator), so the default
  ; printer renders them as a hex address — non-empty and string-typed.
  (strp (inspect in))
  (strp (inspect out))
  (< 0 (len (inspect in)))
  (< 0 (len (inspect out)))

  ; fungetc + fgetc roundtrip on stdin (within a single top-level form,
  ; otherwise the REPL parser would consume the pushed-back byte itself).
  (: (rt c) (: _ (fungetc in c) (fgetc in))
   (, (= 65  (rt 65))
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
     wp (open "/tmp/gwen-io-test" "w")
     _ (fputs wp txt)
     _ (close wp)
     rp (open "/tmp/gwen-io-test" "r")
     (slurp acc) (: c (fgetc rp) (? (= c -1) (rev acc) (slurp (cons c acc))))
     rd (str (slurp 0))
     _ (close rp)
     (= txt rd)))
