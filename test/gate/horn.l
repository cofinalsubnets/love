; test/gate/horn.l -- what the machine played, read back on this side. test/kernel/horn.l writes
; a ramp through the horn port; inle.mjs's --horn takes what is played off the shared ring
; at the rate and lays it in the file named here. these bytes are the whole seam at once:
; the port, inle/wasm/horn.c's hypercall, the worker's ring and the wrap in it, and the
; drainer that an AudioWorklet is in a page. nothing else in the tree reads that path back.
; usage: love test/gate/horn.l <raw>
(borrow 'kore)
(: p (cap >argv)
   r (uread p)
   want (string (map (\ i (i % 251)) (jot 80000)))
   got (two? r ? <>r "")
   bad (? !(two? r) (p + ": cannot read")
          (#got != #want) (p + ": " + show #got + " bytes, wanted " + show #want)
          (got != want) (p + ": the ramp came back changed")
          ())
   _ (puts (0 < #bad ? ("FAIL horn: " + bad + "\n")
                       "  horn: ok -- the ramp out of the machine, whole and in order\n"))
   (quit (0 < #bad ? 1 0)))
