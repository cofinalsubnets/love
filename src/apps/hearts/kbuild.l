; hearts' kbuild -- the kernel's build graph read by love, never run by make.
;
; kbuild's own make text is evaluated by cook's variable layer: the top Makefile once, as the
; final make of a `make O=..` sees it, then scripts/Makefile.build once per directory, as the
; recursive make would. what kbuild computes -- real-obj-y, lib-y, c_flags -- is read from
; those tablets; hearts owns the walk, the archives and the link, and its answers are held to
; a reference build's vmlinux.a and .cmd files.
;
; a hearts build is clean and one-shot: no fixdep, no .cmd, no if_changed, no recursion.
(module (hearts-kbuild hk-top hk-prepare hk-build hk-walk hk-vmlinux hk-rule hk-unit hk-plan hk-path)
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

 ; a word against a path: a % pattern's stem, "" for the very path, else ()
 (hk-stem w path)
  (: k (findsub w "%")
     (k < 0 ? (w = path ? "" ())
        (: pre (snip w 0 k) suf (snip w (k + 1) #w)
           (#pre + #suf < #path && hk-pre? path pre && ends? path suf
            ? (snip path #pre (#path - #suf)) ()))))
 (hk-sub p s) (findsub p "%" @ k (k < 0 ? p (snip p 0 k + s + snip p (k + 1) #p)))
 ; prerequisite words, the order-only ones past | left out
 (hk-pre s) ((: (g l) (atom? l || <l = "|" ? () (<l . g >l))) (words s))
 (hk-lastsl p) ((: (g i) (i < 0 ? -1 (p i = 47 ? i (g (i - 1))))) (#p - 1))

 ; the directory's rules, targets and prerequisites expanded once: [targets prereqs steps
 ; pattern], a static pattern rule (`$(objs): %.o: %.c`) keeping its target pattern apart
 (hk-rx t)
  (peep t " rx" 0 @ x (x ? x
     (: (one r) (: ts (words (hk-expand (r 0) t)) ps (hk-expand (r 1) t) k (findsub ps ":")
                   (0 < k ? [ts (hk-pre (snip ps (k + 1) #ps)) >>r (strip (snip ps 0 k))]
                      [ts (hk-pre (k = 0 ? (snip ps 1 #ps) ps)) >>r ""]))
        rs (map one (t " rules"))
        (pin t " rx" rs, rs))))

 ; can path be had: in the tree, or made here (n bounds the search)
 (hk-had? K t path n)
  (two? (stat path) || two? (stat (K + "/" + path)) || 0 < n && two? (hk-rule K t path (n - 1)))

 ; how make makes path here: [steps prereqs stem], () when no rule does. an explicit rule with
 ; a recipe wins (the last, as make's override); else the pattern rule of shortest stem whose
 ; % prerequisites can be had -- so Makefile.lib's match-anything `$(obj)/%: $(src)/%_shipped`
 ; claims nothing it has no file for. recipe-less rules naming path add their prerequisites
 (hk-rule K t path n)
  (: rx (hk-rx t)
     ex (filter (r \ elem path (r 0)) rx)
     xp (catmap (r \ r 1) (filter (r \ atom? (r 2)) ex))
     rec (filter (r \ two? (r 2)) ex)
     (has% p) (0 <= findsub p "%")
     (two? rec
      ? (: r <(rev rec) s ((r 3) = "" ? "" (hk-stem (r 3) path))
           [(r 2) (map (p \ hk-sub p s) (r 1) + xp) s])
        (: (fit r w) (hk-stem w path @ s
                       (string? s && s != "" && all (p \ !(has% p) || hk-had? K t (hk-sub p s) n) (r 1)
                        ? [[s r]] ()))
           cs (catmap (r \ catmap (w \ fit r w) (r 0)) (filter (r \ two? (r 2) && (r 3) = "") rx))
           best (foldl (a \ c \ atom? a || #(c 0) < #(a 0) ? c a) () cs)
           (two? best ? [(best 1 2) (map (p \ hk-sub p (best 0)) (best 1 1) + xp) (best 0)] ()))))

 ; the target- and pattern-specific assignments for path, in the order they were written
 (hk-tv t path)
  (filter (v \ any (w \ string? (hk-stem w path)) (words (v 0))) (rev (peep t " tvars" ())))

 ; the cmd_ names a recipe text runs, in order: [name saved?], saved? for the one kbuild
 ; records in the .cmd (if_changed, cmd_and_fixdep, ..); if_changed_rule reads rule_NAME
 (hk-calls t s)
  (: k (findsub s "$(call ")
     (k < 0 ? ()
        (: r (snip s (k + 7) #s) c (findsub r ",") e (findsub r ")")
           (c < 0 || e < c ? (hk-calls t r)
              (: nm (strip (snip r 0 c)) a (strip (snip r (c + 1) e)) rest (snip r (e + 1) #r)
                 (? (elem nm ["if_changed" "if_changed_dep" "cmd_and_savecmd" "cmd_and_fixdep"])
                     ([a 1] . hk-calls t rest)
                    (nm = "cmd") ([a 0] . hk-calls t rest)
                    (nm = "if_changed_rule") (hk-calls t (peep t ("rule_" + a) "") + hk-calls t rest)
                    (hk-calls t rest)))))))

 ; one unit made as make would: the directory's tablet (a copy when target-specific variables
 ; apply), the automatic variables pinned, the prerequisites found through VPATH. answers
 ; [cmds prereqs], cmds [text saved?] in order with the empty ones dropped, or () with no rule
 (hk-unit K t u)
  (: tg (u 1) r (hk-rule K t tg 3)
     (atom? r ? ()
        (: tv (hk-tv t tg)
           ut (two? tv ? (hk-copy t) t)
           _ (each tv (v \ hk-vars (v 1) ut))
           (vp p) (two? (stat p) || !(two? (stat (K + "/" + p))) ? p (K + "/" + p))
           ps (map vp (r 1))
           ap (join " " (uniq ps))
           k (hk-lastsl tg)
           _ (pins ut "@" tg "<" (two? ps ? <ps "") "^" ap "?" ap "*" (r 2)
                      "@D" (k < 0 ? "." (snip tg 0 k)) "@F" (snip tg (k + 1) #tg))
           body (join "\n" (map (s \ >>s) (r 0)))
           cs (hk-calls ut body)
           cmds (two? cs ? (map (c \ [(hk-expand ("$(cmd_" + c 0 + ")") ut) (c 1)]) cs)
                   (map (s \ [(hk-expand >>s ut) 0]) (r 0)))
           [(filter (c \ 0 < #(strip (c 0))) cmds) ps])))

 ; a unit after the units its prerequisites need made here first: [[unit cmds] ..], build
 ; order, each target once
 (hk-plan K t u seen)
  (peep seen (u 1) 0 ? ()
     (: x (hk-unit K t u)
        (pin seen (u 1) 1,
         atom? x ? [[u ()]]
           (: ph (hk-words t "PHONY")
              (mine? p) (!(elem p ph) && !(hk-pre? p K) && two? (hk-rule K t p 3))
              (catmap (p \ hk-plan K t [(u 0) p] seen) (filter mine? (x 1)) + [[u (x 0)]])))))

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
     (filter head? us + filter (u \ !(head? u)) us)))
) ; module hearts-kbuild
