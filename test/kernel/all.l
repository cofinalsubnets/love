; test/kernel/all.l -- the kernel corpus, fed off the ramfs through `reads`. the boot cmdline
; names this file (ktest.l's -append, or love.cmd beside love.elf); an empty line drops to the
; console shell. the roster is an ordering, not a set: 00-init, spec and uu first as common.mk's
; `t` has them (a locale sort would run uukind* before uu.l), and each kernel file after
; what it depends on (kore0.l pins `quit`).

; the optional layers the corpus asserts on, and only it: a booting kernel wants no
; random stream, no rationals and no unifier, so they are `borrow`d here rather
; than spliced at boot. baked modules, so `borrow` finds them without a filesystem read.
(borrow 'kanren)

; the driver's own doors: it reads the roster off the ramfs BEFORE it feeds 00-init.l,
; so the corpus's own splice is not yet standing when these are compiled.
(borrow 'posix)

; a member that will not open SCARES rather than skipping: a typo in the roster
; would otherwise drop a whole file's laws and leave the gate green.
; the roster is spelled from the tree's top, which is where the corpus runs: every
; member's relative path is a row under /proc/src
(chdir "/proc/src")
(: (feed p) (open p "r" @ q
                 (port? q ? (reads q, close q) (scare 'no-corpus-member p)))
   ; the host corpus is common.mk's `t`, held back exactly where `t` holds back --
   ; the three front-loads and the two glaze lanes -- plus zz-fin.l, which is the summary
   ; and rides at the foot. NOTHING ELSE: a file a seat cannot run guards itself, in its
   ; own text where the reason is readable (run.l is one whole `(? hosted ..)`), never in
   ; a roster over here that goes stale without saying so.
   apart '("00-init.l" "spec.l" "uu.l" "glaze-x86.l" "glaze-hook.l" "zz-fin.l")
   (law? n) (#n @ k (2 < k && ".l" = snip n (k - 2) k && nelem n apart))
   host (map (n \ ("test/" + n)) (filter law? (sort (readdir "test"))))
   roster (["test/00-init.l" "test/spec.l" "test/uu.l"] + host +
           ["test/kernel/ramfs.l" "test/kernel/fs.l" "test/kernel/wfs.l"
            "test/kernel/kore0.l"
            "src/apps/kore/text.l" "src/apps/kore/u.l" "src/apps/kore/core.l" "src/apps/kore/fs.l"
            "test/kernel/kore.l" "test/kernel/pipe.l" "test/kernel/pty.l"
            "test/kernel/sh0.l"
            "src/apps/lush.l"
            "test/kernel/sh.l"
            "test/kernel/disk.l" "test/kernel/svm.l" "test/kernel/vmx.l"
            "test/zz-fin.l"])
   (each roster feed))
