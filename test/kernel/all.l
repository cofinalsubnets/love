; test/kernel/all.l -- the kernel corpus, fed off the ramfs through `reads`. the roster is an
; ordering: 00-init, spec and uu first as common.mk's `t` has them, each kernel file after what
; it depends on (kore0.l pins `quit`)

; layers only the corpus asserts on: borrowed here, not spliced at boot
(borrow 'kanren)

; the driver reads the roster before it feeds 00-init.l, so the corpus's splice is not standing yet
(borrow 'posix)

; a member that will not open scares: a roster typo would drop a file's laws and stay green.
; paths are from the tree's top, mounted at /love
(chdir "/love")
(: (feed p) (open p "r" @ q
                 (port? q ? (reads q, close q) (scare 'no-corpus-member p)))
   ; the host corpus is common.mk's `t`, held back where `t` holds back, plus zz-fin.l at the foot.
   ; a file a kernel cannot run guards itself in its own text, never in this roster
   apart '("00-init.l" "spec.l" "uu.l" "glaze-x86.l" "glaze-hook.l" "glaze-tail.l" "zz-fin.l")
   (law? n) (#n @ k (2 < k && ".l" = snip n (k - 2) k && nelem n apart))
   host (map (n \ ("test/" + n)) (filter law? (sort (readdir "test"))))
   roster (["test/00-init.l" "test/spec.l" "test/uu.l"] + host +
           ["test/kernel/ramfs.l" "test/kernel/fs.l" "test/kernel/wfs.l" "test/kernel/hostfs.l"
            "test/kernel/kore0.l"
            "src/apps/kore/text.l" "src/apps/kore/u.l" "src/apps/kore/core.l" "src/apps/kore/fs.l"
            "test/kernel/kore.l" "test/kernel/pipe.l" "test/kernel/pty.l" "test/kernel/pane.l"
            "test/kernel/sh0.l"
            "src/apps/lush.l"
            "test/kernel/sh.l"
            "test/kernel/disk.l" "test/kernel/svm.l" "test/kernel/vmx.l" "test/kernel/vecirq.l"])
   ; the free list after the busiest run: ffalloc's walk is linear, so its length matters
   (frees p) (open p "r" @ q (port? q ? (slurp q @ s (close q,
     each (filter (l \ "free-" = snip l 0 5) (split "\n" s)) (l \ puts (l + "\n"))))))
   (each roster feed, frees "/proc/meminfo", feed "test/zz-fin.l"))
