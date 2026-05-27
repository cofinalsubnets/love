; Phase-C port bifs: fgetc, fungetc, feof, fputc, fflush. Sibling forms of
; the static-port (getc/putc/key?) bifs that take an explicit port instead
; of dispatching via f->in/f->out.

(assert
  ; The static frontend ports are globally bound to `in` and `out`.
  ; They are heap-shaped (g_vm_port_in / g_vm_port_out discriminator), so the
  ; default printer renders them as a hex address — non-empty and string-typed.
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
  (= 99 (fgetc in)))
