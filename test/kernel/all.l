; test/kernel/all.l -- the kernel corpus, driven off the ramfs.
;
; the initrd is the source blob, so every member is a file this machine can open:
; the driver spells the roster below and hands each member to `reads`, the same
; stream shell the host's stdin runner uses. kmain names this file at boot, and a
; boot cmdline naming another file replaces it -- which is the whole of the
; kernel's corpus wiring, there being no baked string and no second filesystem.
;
; ⚠ THE ROSTER IS AN ORDERING, NOT A SET. 00-init, spec and uu go first exactly as
; mk/common.mk's `t` front-loads them: a locale sort puts uukind* before uu.l and
; would run those laws against an unloaded kernel. the kernel half is a dependency
; order too -- kore0.l pins `quit` for every member behind it, and each crew file
; lands before the laws that ask about it.

; ⚠ a member that will not open SCARES rather than skipping: a typo in the roster
; would otherwise drop a whole file's laws and leave the gate green.
(: (feed p) (: q (open p "r")
                 (? (port? q) (: _ (reads q) (close q)) (scare 'no-corpus-member p)))
   ; the host corpus is mk/common.mk's `t`, less the three files wanting a seat
   ; this machine has not got: run.l a real process, bell.l a tty. zz-fin.l is
   ; held back because it is the summary and rides at the foot.
   apart '("00-init.l" "spec.l" "uu.l" "glaze-x86.l" "glaze-hook.l"
           "run.l" "bell.l" "zz-fin.l")
   (law? n) (: k #n (&& (2 < k) (= ".l" (snip n (k - 2) k)) !(member? n apart)))
   host (map (\ n ("test/" + n)) (filter law? (sort (readdir "test"))))
   roster (["test/00-init.l" "test/spec.l" "test/uu.l"] + host +
           ["test/kernel/ramfs.l" "test/kernel/fs.l" "test/kernel/wfs.l"
            "test/kernel/kore0.l"
            "crew/kore/text.l" "crew/kore/u.l" "crew/kore/core.l" "crew/kore/fs.l"
            "test/kernel/kore.l" "test/kernel/pipe.l"
            "test/kernel/sh0.l"
            "crew/lush/job.l" "crew/lush/lex.l" "crew/lush/gram.l"
            "crew/lush/glob.l" "crew/lush/word.l" "crew/lush/eval.l"
            "test/kernel/sh.l"
            "test/kernel/disk.l" "test/kernel/svm.l" "test/kernel/vmx.l"
            "test/zz-fin.l"])
   (each roster feed))
