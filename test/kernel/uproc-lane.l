; test/kernel/uproc-lane.l -- test_kernel_uproc's roster: the harness, uproc.l, the process laws
; the wasm lane boots one at a time, and the summary, booted with hello at /proc/initrd
(borrow 'posix)
(chdir "/love")
; whole paths: a law may leave the cwd where it ran
(: (feed p) (open ("/love/" + p) "r" @ q (port? q ? (reads q, close q) (scare 'no-corpus-member p)))
 (each ["test/00-init.l" "test/kernel/uproc.l" "test/kernel/proc.l" "test/kernel/spawn.l"
        "test/zz-fin.l"] feed))
