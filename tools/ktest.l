; Driver for `make test_kernel`: boot the headless serial test kernel under qemu,
; capture its serial console (the baked corpus runs at boot and prints the usual
; "N tests pass" summary, then (exit) quits qemu via isa-debug-exit), and report.
; Run on the host ai, which has the `run` subprocess nif. argv = (this iso ovmf).

(: (sub-at s i t j) (? (>= j (tally t)) 1                    ; does t occur in s at index i?
       (? (= (peep s (+ i j) 0) (peep t j 0)) (sub-at s i t (+ 1 j)) 0))
   (idx s t) ((: (g i) (? (> (+ i (tally t)) (tally s)) -1     ; first index of t in s, else -1
       (? (sub-at s i t 0) i (g (+ 1 i))))) 0)
   (has? s t) (< -1 (idx s t))
   (bol s i)  (? (< i 1) 0 (? (= 10 (peep s (- i 1) 0)) i (bol s (- i 1))))
   (eol s i)  (? (>= i (tally s)) i (? (= 10 (peep s i 0)) i (eol s (+ 1 i))))
   (lineof s t) (: i (idx s t) (? (< i 0) "" (snip s (bol s i) (eol s i)))))

(: a    (cup argv)
   iso  (cap a)
   ovmf (cap (cup a))
   r    (run `("timeout" "90" "qemu-system-x86_64" "-m" "256M" "-M" "q35"
                "-serial" "stdio" "-display" "none" "-no-reboot"
                "-drive" (+ "if=pflash,unit=0,format=raw,file=" (+ ovmf ",readonly=on"))
                "-cdrom" iso
                "-device" "isa-debug-exit,iobase=0xf4,iosize=0x04"))
   out  (cup r)
   ok   (&& (has? out "tests pass") (! (has? out "failed:")))
   (? ok (: _ (puts (lineof out "tests pass")) (putc 10))
         (: _ (say err "test_kernel: FAILED") _ (put err 10)
            _ (say err out) _ (put err 10) (nap 1))))
