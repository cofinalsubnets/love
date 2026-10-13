; test/kernel/uproc-lane.l -- test_kernel_uproc's roster: the harness, uproc.l and the summary,
; booted with hello at /proc/initrd
(borrow 'posix)
(chdir "/love")
(: (feed p) (open p "r" @ q (port? q ? (reads q, close q) (scare 'no-corpus-member p)))
 (each ["test/00-init.l" "test/kernel/uproc.l" "test/zz-fin.l"] feed))
