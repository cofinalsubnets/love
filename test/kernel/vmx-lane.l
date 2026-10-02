; test/kernel/vmx-lane.l -- test_kernel_vmx's roster: the harness, vmx.l and the summary, booted on
; a VT-x box. all.l carries vmx.l too, where a box without VT-x skips its laws
(borrow 'posix)
(chdir "/love")
(: (feed p) (open p "r" @ q (port? q ? (reads q, close q) (scare 'no-corpus-member p)))
 (each ["test/00-init.l" "test/kernel/vmx.l" "test/zz-fin.l"] feed))
