; hearts' kbuild -- the kernel's build graph read by love, never run by make.
;
; kbuild's own make text is evaluated by cook's variable layer: the top Makefile once, as the
; final make of a `make O=..` sees it, then scripts/Makefile.build once per directory, as the
; recursive make would. what kbuild computes -- real-obj-y, lib-y, c_flags -- is read from
; those tablets; hearts owns the walk, the archives and the link, and its answers are held to
; a reference build's vmlinux.a and .cmd files.
;
; a hearts build is clean and one-shot: no fixdep, no .cmd, no if_changed, no recursion.
(module (hearts-kbuild hk-top hk-prepare hk-build hk-walk hk-vmlinux hk-cmd hk-path)
(borrow 'posix)
(borrow 'cook)
(borrow 'path)
(:
 hk-vars (cite 'cook 'cook-vars)
 hk-expand (cite 'cook 'cook-expand)
 ; GNU make 4.4's .FEATURES: the top Makefile refuses a make without output-sync
 hk-features "target-specific order-only second-expansion else-if shortest-stem undefine oneshell nocomment grouped-target extra-prereqs notintermediate shell-export output-sync check-symlink load dir"
 (hk-slurp p) (uread p @ [1 s] s ())
 (hk-copy t) (foldl (a \ k \ pin a k (t k)) {} (keys t))
 (hk-words t v) (words (hk-expand ("$(" + v + ")") t))
 (hk-pre? s p) (#p <= #s && snip s 0 #p = p)
 ; a member as ar names it: arch/arm64/kvm/../../../virt/kvm/x.o is virt/kvm/x.o
 (hk-path p) (join "/" (pclean (segs p) 0))

 ; the top Makefile evaluated as kbuild's final make sees it, in the output dir `cur`: cl holds
 ; the command line (ARCH, LLVM, ..) and sh answers every $(shell ..), so no probe reaches the
 ; host unasked. answers the tablet each directory's build starts from, its rules under " rules"
 (hk-top K cur cl sh)
  (: t (pins (hk-copy cl) "MAKE_VERSION" "4.4.1" ".FEATURES" hk-features
             "MAKEFLAGS" "rR --no-print-directory" "MAKECMDGOALS" "vmlinux"
             "MAKEFILE_LIST" (K + "/Makefile") "CURDIR" cur
             "sub_make_done" "1" "objtree" "." "KBUILD_EXTMOD" "" " shell" sh)
     (pin t " rules" (hk-vars (hk-slurp (K + "/Makefile")) t), t))

 ; the prepare chain's recipe lines that only $(eval) into the top's variables, run once the
 ; generated headers exist (arm64's stack_protector_prepare reads asm-offsets.h)
 (hk-prepare top)
  (: rules (top " rules")
     seen {}
     (ws s) (filter (w \ w != "|") (words (hk-expand s top)))
     (walk n) (peep seen n 0 ? ()
                (: rs (filter (r \ elem n (ws (r 0))) rules)
                   (pin seen n 1, catmap (r \ catmap walk (ws (r 1))) rs + catmap (r \ >>r) rs)))
     (each (filter (s \ hk-pre? (strip >>s) "$(eval") (walk "prepare")) (s \ hk-vars >>s top),
      top))

 ; scripts/Makefile.build over one directory, as `make $(build)=dir need-builtin=1` reads it
 (hk-build K top dir)
  (: t (pins (hk-copy top) "obj" dir "need-builtin" "1" "need-modorder" "1")
     (pin t " rules" (hk-vars (hk-slurp (K + "/scripts/Makefile.build")) t), t))

 ; can path be had: in the tree, or made by one of the directory's rules -- by name, or by a %
 ; pattern whose own % prerequisite can be had in turn, as make's implicit search asks (so
 ; Makefile.lib's match-anything `$(obj)/%: $(src)/%_shipped` claims nothing it has no file for)
 (hk-had? K t path n)
  (: (stem w) (: k (findsub w "%")
                 (k < 0 ? (w = path ? "" ())
                    (: pre (snip w 0 k) suf (snip w (k + 1) #w)
                       (#pre + #suf < #path && hk-pre? path pre && ends? path suf
                        ? (snip path #pre (#path - #suf)) ()))))
     (pq s r) (filter (p \ 0 <= findsub p "%") (words (hk-expand (r 1) t)) @
                (p . _) (findsub p "%" @ k (hk-had? K t (snip p 0 k + s + snip p (k + 1) #p) (n - 1)))
                1)
     (two? (stat path) || two? (stat (K + "/" + path))
      || 0 < n && any (r \ any (w \ stem w @ s (string? s && (s = "" || pq s r))) (words (hk-expand (r 0) t)))
                      (t " rules")))

 ; the descent, as the recursive make walks it: Makefile.build over dir, f handed (dir t us)
 ; with the directory's own units, then each subdirectory real-obj-y names, in place. a unit
 ; is [dir target], the target as make spells $@ there (arch/arm64/kvm/../../../virt/kvm/x.o).
 ; answers the built-in.a units, flattened; each directory's lib.a units land in libs
 (hk-walk K top dir f libs)
  (: t (hk-build K top dir)
     ro (hk-words t "real-obj-y")
     (sub? m) (ends? m "/built-in.a")
     us (map (m \ [dir m]) (filter (m \ !(sub? m)) ro))
     lu (map (m \ [dir m]) (hk-words t "lib-y"))
     ; a child make inherits the flags this one exported, subdir-ccflags-y and kin added
     fl ["KBUILD_CFLAGS" "KBUILD_AFLAGS" "KBUILD_RUSTFLAGS"]
     kid (all (v \ t v = top v) fl ? top (foldl (a \ v \ pin a v (t v)) (hk-copy top) fl))
     (pin libs dir lu, f dir t (us + lu),
      catmap (m \ sub? m ? (hk-walk K kid (hk-path (snip m 0 (#m - 11))) f libs) [[dir m]]) ro))

 ; vmlinux.a's units in member order: KBUILD_VMLINUX_OBJS (the root's built-in.a, then each
 ; libs-y directory's lib.a), a member's first unit kept, the head objects
 ; (scripts/head-object-list.txt, matched as grep -F does) hoisted ahead in archive order
 (hk-vmlinux K top f)
  (: libs {}
     root (hk-walk K top "." f libs)
     (lib d) (peep libs d 0 @ l
               (l ? l (: t (hk-build K top d) lu (map (m \ [d m]) (hk-words t "lib-y"))
                         (f d t lu, lu))))
     all (catmap (o \ o = "built-in.a" ? root (lib (hk-path (snip o 0 (#o - 6)))))
                 (hk-words top "KBUILD_VMLINUX_OBJS"))
     ; a member's first unit, as make's $^ keeps a repeated prerequisite's first place
     us (rev <(foldl (a \ u \ hk-path (u 1) @ p (peep (a 1) p 0 ? a [(u . (a 0)) (pin (a 1) p 1)]))
                     [() {}] all))
     heads (filter (l \ 0 < #l && l 0 != 35)
                   (map strip (lines (hk-slurp (K + "/scripts/head-object-list.txt") || ""))))
     (head? u) (hk-path (u 1) @ m (any (h \ 0 <= findsub m h) heads))
     (filter head? us + filter (u \ !(head? u)) us))

 ; one unit's compile command, kbuild's own cmd_cc_o_c or cmd_as_o_S expanded with $@ $< $*
 ; set; the source is the tree's, else one a rule of the directory generates in the output dir
 (hk-cmd K t u)
  (: d (u 0) tg (u 1) b (snip tg 0 (#tg - 2))
     stem (hk-pre? b (d + "/") ? (snip b (#d + 1) #b) b)
     sx (filter (x \ two? (stat (K + "/" + b + x))) [".c" ".S"])
     gx (filter (x \ hk-had? K t (b + x) 3) [".c" ".S"])
     src (two? sx ? (K + "/" + b + <sx) (b + (two? gx ? <gx ".c")))
     (pins t "@" tg "<" src "*" stem,
      hk-expand (ends? src ".S" ? "$(cmd_as_o_S)" "$(cmd_cc_o_c)") t)))
) ; module hearts-kbuild
