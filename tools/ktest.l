; Driver for `make test_kernel`: boot the headless serial test kernel under qemu,
; capture its serial console (the baked corpus runs at boot and prints the usual
; "N tests pass" summary, then (exit) quits qemu via isa-debug-exit), and report.
; Run on the host ll, which has the `run` subprocess nif. argv = (this iso ovmf).

(: (sub-at s i t j) (? (>= j (pin t)) 1                    ; does t occur in s at index i?
       (? (= (get 0 (+ i j) s) (get 0 j t)) (sub-at s i t (+ 1 j)) 0))
   (idx s t) ((: (g i) (? (> (+ i (pin t)) (pin s)) -1     ; first index of t in s, else -1
       (? (sub-at s i t 0) i (g (+ 1 i))))) 0)
   (has? s t) (< -1 (idx s t))
   (bol s i)  (? (< i 1) 0 (? (= 10 (get 0 (- i 1) s)) i (bol s (- i 1))))
   (eol s i)  (? (>= i (pin s)) i (? (= 10 (get 0 i s)) i (eol s (+ 1 i))))
   (lineof s t) (: i (idx s t) (? (< i 0) "" (ssub s (bol s i) (eol s i)))))

(: a    (B argv)
   iso  (A a)
   ovmf (A (B a))
   r    (run (L "timeout" "90" "qemu-system-x86_64" "-m" "256M" "-M" "q35"
                "-serial" "stdio" "-display" "none" "-no-reboot"
                "-drive" (scat "if=pflash,unit=0,format=raw,file=" (scat ovmf ",readonly=on"))
                "-cdrom" iso
                "-device" "isa-debug-exit,iobase=0xf4,iosize=0x04"))
   out  (B r)
   ok   (&& (has? out "tests pass") (! (has? out "failed:")))
   (? ok (: _ (puts (lineof out "tests pass")) (putc 10))
         (: _ (fputs err "test_kernel: FAILED") _ (fputc err 10)
            _ (fputs err out) _ (fputc err 10) (exit 1))))
