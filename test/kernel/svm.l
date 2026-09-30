; test/kernel/svm.l -- the amd-v spike: one guest, one exit. the nom is in the book only on x64,
; so presence is asked of (names ()), never by a read; the cpu may lack the feature, so (svm ())
; answers for it, and either absence stays green. the laws: the entry was accepted (a refused one
; answers -1), a guest instruction retired (the sentinel in the guest's rax), and the intercept
; fired at the cpuid's own address, one instruction in.
(elem 'svm (names ()) @ had
   (! (had ? (svm ())) ?
      (puts "svm: no AMD-V here, laws skipped", putc 10, ())
      (svm-run () @ r
       (test (3 = #r)          ; (exitcode rax rip) -- a refusal answers ()
             (114 = <r)               ; 0x72, the cpuid intercept
             (4660 = <>r)             ; 0x1234, the sentinel the guest loaded
             (3 = <>>r),             ; the cpuid's own address
        puts "svm: guest ran, cpuid intercepted", putc 10,
        ()))))
