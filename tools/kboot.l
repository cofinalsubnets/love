; Driver for `make test_kboot` (inle rung 3): boot the shipped x64 kernel
; direct (`qemu -kernel`, the PVH door) with a boot command line, capture the
; serial console, and ask that every expected substring made it out. The seated
; tool runs off the baked kore cat and quits -- the reset door, which -no-reboot
; turns into a qemu exit; a boot that reaches the shell instead just times out
; and reports. Run on the host love (the `hark` nif). argv = (this elf append expect..).

; the helpers keep their own form: folding them into the driver's `:` below blows
; the C stack on the host, so sub-at and has? may not share a letrec with it.
(: (sub-at s i t j) (? (j >= #t) 1                           ; does t occur in s at index i?
       (s (i + j) = t j ? (sub-at s i t (j + 1)) 0))
   (has? s t) ((: (g i) (? (i + #t > #s) 0
       (sub-at s i t 0 ? 1 (g (i + 1))))) 0))

(: a    >argv
   elf  <a
   app  <>a
   want >>a
   ; kvm where the host can back it -- this lane is x64 only, so the arch
   ; question is just the host's. Without /dev/kvm it falls to tcg, same verdict.
   mach (hark ["uname" "-m"])
   kvm  (two? (stat "/dev/kvm") && has? >mach "x86_64"
         ? ["-enable-kvm" "-cpu" "host"] ())
   ; 768M for the same reason as ktest.l's: the major pool's contiguous 2x
   ; grow wants a hole the old pair fragments, and margin is the mitigation.
   r    (hark (["timeout" "420" "qemu-system-x86_64" "-m" "768M" "-M" "q35"]
               + kvm
               + ["-kernel" elf "-append" app
                  "-serial" "stdio" "-display" "none" "-no-reboot"]))
   out  >r
   miss ((: (g w acc) (one? w ? (rev acc)
                       (g >w (has? out <w ? acc (<w . acc))))) want ())
   (one? miss
    ? (puts ("kboot ok: " + app), putc 10)
      (say err ("test_kboot FAILED: " + app), put err 10,
       each miss (m \ (say err ("  missing: " + m), put err 10)),
       say err out, put err 10, quit 1)))
