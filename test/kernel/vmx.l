; test/kernel/vmx.l -- the intel twin of svm.l: one guest, one exit. the nom is in the book only on
; x64 and the cpu may be amd's, so both are asked. a refused entry falls through with a number,
; so the fourth field is the VM-instruction error and must be 0. the guest runs under ept at
; guest-physical 0, so a 0x1234 sentinel can only come from the page the ept points at.
(elem 'vmx (names ()) @ had
   (!(had ? (vmx ())) ?
      (puts "vmx: no VT-x here, laws skipped\n", ())
      (vmx-run () @ r
       (test (4 = #r)          ; (reason rax rip err) -- a refusal answers ()
             (0 = <>>>r)              ; the VM-instruction error: the entry was taken
             (10 = <r)                ; exit_reason_cpuid
             (4660 = <>r)             ; 0x1234, the sentinel the guest loaded
             (5 = <>>r),             ; the cpuid's own address, one instruction in
        (puts "vmx: guest ran, cpuid exited\n", ())))))
