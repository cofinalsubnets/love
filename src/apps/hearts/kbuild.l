; hearts' kbuild -- the kernel's build graph read by love, never run by make.
;
; kbuild's own make text is evaluated by cook's variable layer: the top Makefile once, as the
; final make of a `make O=..` sees it, then scripts/Makefile.build once per directory, as the
; recursive make would. what kbuild computes -- real-obj-y, lib-y, c_flags -- is read from
; those tablets; hearts owns the walk, the archives and the link, and its answers are held to
; a reference build's vmlinux.a and .cmd files.
;
; a hearts build is clean and one-shot: no fixdep, no .cmd, no if_changed. hk-make runs kbuild's
; own goals as make would, sub-makes and all; an earlier build's .cmd files are read only as the
; prior state a differential starts from.
(module (hearts-kbuild hk-top hk-topgoal hk-prepare hk-build hk-walk hk-vmlinux hk-rule hk-unit hk-plan hk-make hk-submake hk-envmake hk-path)
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
 ; host unasked. answers the tablet each directory's build starts from, its rules under " rules".
 ; cl's variables are exported, as the environment's are to make's recipes (the build's identity,
 ; KBUILD_BUILD_*, arrives there), and so is what the outer make of an O= build exports to it.
 ; goals are the command line's: a config goal (defconfig, syncconfig) reads the Makefile as
 ; kbuild's config-build pass does
 (hk-top K cur cl sh) (hk-topgoal K cur cl sh "vmlinux")
 (hk-topgoal K cur cl sh goals)
  (: t (pins (hk-copy cl) "MAKE_VERSION" "4.4.1" ".FEATURES" hk-features
             "MAKEFLAGS" "rR --no-print-directory" "MAKECMDGOALS" goals
             "MAKEFILE_LIST" (K + "/Makefile") "CURDIR" cur "LC_COLLATE" "C" "LC_NUMERIC" "C"
             "sub_make_done" "1" "objtree" "." "KBUILD_EXTMOD" "" " shell" sh "MAKE" "hk-make"
             " cl" (sort (keys cl))
             " exports" (sort (keys cl) + ["sub_make_done" "objtree" "srcroot" "LC_COLLATE" "LC_NUMERIC"]))
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
  (: t (pins (hk-copy top) "obj" dir "need-builtin" "1" "need-modorder" "1"
             "MAKEFILE_LIST" (K + "/scripts/Makefile.build"))
     (pin t " rules" (hk-vars (hk-slurp (K + "/scripts/Makefile.build")) t), t))

 ; a word against a path: a % pattern's stem, "" for the very path, else ()
 (hk-stem w path)
  (: k (findsub w "%")
     (k < 0 ? (w = path ? "" ())
        (: pre (snip w 0 k) suf (snip w (k + 1) #w)
           (#pre + #suf < #path && hk-pre? path pre && ends? path suf
            ? (snip path #pre (#path - #suf)) ()))))
 (hk-sub p s) (findsub p "%" @ k (k < 0 ? p (snip p 0 k + s + snip p (k + 1) #p)))
 ; a file name as make keeps it: ./foo is foo
 (hk-dot w) (hk-pre? w "./" && 2 < #w ? (snip w 2 #w) w)
 ; prerequisite words, the order-only ones past | left out
 (hk-pre s) ((: (g l) (atom? l || <l = "|" ? () (hk-dot <l . g >l))) (words s))
 (hk-lastsl p) ((: (g i) (i < 0 ? -1 (p i = 47 ? i (g (i - 1))))) (#p - 1))
 (hk-split s ch) ((: (g i st acc) (i >= #s ? (rev (snip s st i . acc))
                                     (s i = ch ? (g (i + 1) (i + 1) (snip s st i . acc)) (g (i + 1) st acc))))
                  0 0 ())

 ; the directory's rules, targets and prerequisites expanded once: [targets prereqs steps
 ; pattern], a static pattern rule (`$(objs): %.o: %.c`) keeping its target pattern apart
 (hk-rx t)
  (peep t " rx" 0 @ x (x ? x
     (: (one r) (: ts (map hk-dot (words (hk-expand (r 0) t))) ps (hk-expand (r 1) t) k (findsub ps ":")
                   (0 < k ? [ts (hk-pre (snip ps (k + 1) #ps)) >>r (hk-dot (strip (snip ps 0 k)))]
                      [ts (hk-pre (k = 0 ? (snip ps 1 #ps) ps)) >>r ""]))
        rs (map one (t " rules"))
        (pin t " rx" rs, rs))))

 ; rx by target, as make hashes its files: [{target -> its rules, in order} pattern-rules-with-recipes]
 (hk-ix t)
  (peep t " ix" 0 @ x (two? x ? x
     (: rx (hk-rx t)
        ix {}
        (one r) (: sn {} (each (r 0) (w \ peep sn w 0 ? 0 (pin sn w 1, pin ix w (r . peep ix w ())))))
        _ (each (rev rx) one)
        x [ix (filter (r \ two? (r 2) && (r 3) = "" && any (w \ 0 <= findsub w "%") (r 0)) rx)]
        (pin t " ix" x, x))))

 ; can path be had: in the tree, or made here (n bounds the search)
 (hk-had? K t path n)
  (two? (stat path) || two? (stat (K + "/" + path)) || 0 < n && two? (hk-rule K t path (n - 1)))

 ; how make makes path here: [steps prereqs stem siblings], () when no rule does -- siblings the
 ; other targets of the pattern rule that made it, which one run makes together. an explicit rule with
 ; a recipe wins (the last, as make's override); else the pattern rule of shortest stem whose
 ; % prerequisites can be had -- so Makefile.lib's match-anything `$(obj)/%: $(src)/%_shipped`
 ; claims nothing it has no file for. recipe-less rules naming path add their prerequisites,
 ; every explicit rule's in the order the rules were written
 (hk-rule K t path n)
  (: ix (hk-ix t)
     ex (peep (ix 0) path ())
     (st r) ((r 3) = "" ? "" (hk-stem (r 3) path))
     xp (catmap (r \ map (p \ hk-sub p (st r)) (r 1)) (filter (r \ atom? (r 2)) ex))
     rec (filter (r \ two? (r 2)) ex)
     (has% p) (0 <= findsub p "%")
     ; the recipe's rule leads, so its first prerequisite is $<, as make orders them
     (two? rec
      ? (: rr <(rev rec)
           [(rr 2) (catmap (r \ map (p \ hk-sub p (st r)) (r 1)) (rr . filter (r \ r != rr) ex)) (st rr) ()])
        (: (fit r w) (hk-stem w path @ s
                       (string? s && s != "" && all (p \ !(has% p) || hk-had? K t (hk-sub p s) n) (r 1)
                        ? [[s r]] ()))
           cs (catmap (r \ catmap (w \ fit r w) (r 0)) (ix 1))
           best (foldl (a \ c \ atom? a || #(c 0) < #(a 0) ? c a) () cs)
           ; no recipe anywhere: a target named only by recipe-less rules is still made -- its
           ; prerequisites, then nothing (prepare: prepare0)
           (? (two? best) [(best 1 2) (map (p \ hk-sub p (best 0)) (best 1 1) + xp) (best 0)
                           (filter (w \ w != path) (map (w \ hk-sub w (best 0)) (best 1 0)))]
              (two? ex) [() xp "" ()]
              ()))))

 ; the target- and pattern-specific assignments for path, in the order they were written
 (hk-tv t path)
  (filter (v \ any (w \ string? (hk-stem w path)) (words (v 0))) (rev (peep t " tvars" ())))

 ; the commands a recipe text calls, in order: [variable saved? kind args]. saved? marks the one
 ; kbuild records in the .cmd (if_changed, cmd_and_fixdep, ..); kind 'out is filechk's, whose
 ; stdout is the target; if_changed_rule reads rule_NAME; args bind $(1) $(2) .. as call does
 (hk-calls t s)
  (: k (findsub s "$(call ")
     (k < 0 ? ()
        (: r (snip s (k + 7) #s) c (findsub r ",") e (findsub r ")")
           (c < 0 || e < c ? (hk-calls t r)
              (: nm (strip (snip r 0 c)) as (map strip (hk-split (snip r (c + 1) e) 44)) a <as
                 rest (snip r (e + 1) #r)
                 (? (elem nm ["if_changed" "if_changed_dep" "cmd_and_savecmd" "cmd_and_fixdep"])
                     ([("cmd_" + a) 1 'run as] . hk-calls t rest)
                    (nm = "cmd") ([("cmd_" + a) 0 'run as] . hk-calls t rest)
                    (nm = "filechk") ([("filechk_" + a) 0 'out as] . hk-calls t rest)
                    (nm = "if_changed_rule") (hk-calls t (peep t ("rule_" + a) "") + hk-calls t rest)
                    (hk-calls t rest)))))))
 ; a recipe line's leading @ - + modifiers off
 (hk-mods s) ((: (g i) (i < #s && elem (s i) [64 45 43 32 9] ? (g (i + 1)) (snip s i #s))) 0)

 ; one unit made as make would: the directory's tablet (a copy when target-specific variables
 ; apply), the prerequisites found through VPATH. answers [cmds prereqs], () with no rule. a
 ; command is [kind saved? thunk], in recipe order, and the thunk expands it when called -- a
 ; recipe line is expanded as it runs, after the lines before it made what it reads (KERNELRELEASE
 ; read from the kernel.release just made). kind 'run, 'out (filechk: stdout is the target),
 ; 'make (a $(MAKE) line), 'eval (an $(eval ..) line, acting on this make's variables)
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
           (auto _) (pins ut "@" tg "<" (two? ps ? <ps "") "^" ap "?" ap "*" (r 2)
                             "@D" (k < 0 ? "." (snip tg 0 k)) "@F" (snip tg (k + 1) #tg))
           (call c) [(c 2) (c 1) (_ \ (auto 0, foldl (i \ a \ (pin ut (show i) a, i + 1)) 1 (c 3),
                                        hk-mods (hk-expand ("$(" + c 0 + ")") ut))) ut]
           (lit kd b) [kd 0 (_ \ (auto 0, hk-mods (hk-expand b ut))) ut]
           (line b) (? (hk-pre? (strip b) "$(eval") [['eval 0 (_ \ (hk-vars (strip b) t, "")) ut]]
                       (0 <= findsub b "$(MAKE)") [(lit 'make b)]
                       (: cs (hk-calls ut b) (two? cs ? (map call cs) [(lit 'run b)])))
           ; the prerequisites twice: found through VPATH (as $< $^ read them) and as named --
           ; the name is what gets made, and a phony one (scripts) is never searched for. and
           ; the unit's tablet: its prerequisites, sub-makes and environment see its variables
           [(catmap (s \ line >>s) (r 0)) ps (r 1) ut (r 3)])))
 ; a command's text, expanded now; `:` is nothing to run
 (hk-text c) (strip (c 2 0) @ x (x = ":" ? "" x))
 ; the environment a make hands its recipes: each exported variable's value now
 (hk-env t) (map (n \ [n (hk-expand ("$(" + n + ")") t)]) (rev (peep t " exports" ())))

 ; make a goal in tablet t as a serial make would: its prerequisites first, then its recipe line
 ; by line, each expanded as it runs -- a $(MAKE) line as the sub-make it starts. a file already
 ; there with nothing forcing it is up to date (conf's autoconf.h). run is handed (target kind
 ; saved? text env) -- env this make's exported [name value]s -- and answers 0 when it went
 ; well; made spans the run -- a file made once is not
 ; remade by a later sub-make, a failure sits under " failed" -- and seen is this make's own
 (hk-make K t goal made seen run)
  (: g (hk-dot goal)
     (peep seen g 0 || peep made g 0 || peep made " failed" 0 ? 0
        (: _ (pin seen g 1)
           ph (map hk-dot (hk-words t "PHONY"))
           x (hk-unit K t ["" g])
           ; made's " trace", when given, sees each goal with its tablet and unit
           _ (peep made " trace" 0 @ f (lit? f ? (f g t x) 0))
           (? (atom? x) 0
              (!(elem g ph) && two? (stat g) && !(any (p \ elem p ph) (x 2))) 0
              (: _ (each (x 2) (p \ hk-make K (x 3) p made seen run))
                 ; a runner that makes in parallel answers made's " wait": the prerequisites'
                 ; jobs are done before this recipe starts
                 _ (peep made " wait" 0 @ w (lit? w ? (each (x 2) (p \ w (hk-dot p))) 0))
                 ; an earlier build's state, when made carries one under " prior" (target -> the
                 ; command its .cmd saved): a target there, its saved command the same, and no
                 ; prerequisite remade this run is up to date -- if_changed's law, mtimes aside
                 pr (peep made " prior" 0)
                 sv (filter (c \ c 1) (x 0))
                 (new? p) (peep made (" new " + hk-dot p) 0)
                 ; compared as kbuild's cmd-check does, by words
                 fresh (lit? pr && two? (stat g) && two? sv && !(any new? (x 2))
                        && (pr g @ p (string? p && words p = words (hk-text <sv))))
                 ; run answers 0 when it went well, 'same when a filechk left the file as it was
                 (one c) (peep made " failed" 0 ? 0
                           (c 0 = 'make ? (hk-submake K (c 3) (hk-text c) made run)
                              (hk-text c @ s (0 < #s ? (run g (c 0) (c 1) s (hk-env (c 3)) @ st
                                                         (? (st = 0) (pin made (" new " + g) 1)
                                                            (st = 'same) 0
                                                            (pin made " failed" g)))
                                               0))))
                 (fresh ? 0 (each (x 0) one), elem g ph ? 0 (pin made g 1),
                  each (x 4) (w \ (pin made w 1, peep made (" new " + g) 0 ? (pin made (" new " + w) 1) 0)), 0))))))

 ; a recipe's $(MAKE) line as the sub-make it starts: -f FILE, VAR=VALUE, goals (else the file's
 ; first target). it starts as make's does: the variables this make exports, its command line's
 ; (under " cl", handed down as MAKEFLAGS hands them) and the line's own, and make's built-ins
 (hk-submake K t line made run)
  (: (aft l) (atom? l ? () (ends? <l "hk-make" ? >l (aft >l)))
     (g l f vs gs) (? (atom? l) [f (rev vs) (rev gs)]
                      (<l = "-f" || <l = "-C") (g >>l (<l = "-f" ? <>l f) vs gs)
                      (hk-pre? <l "-") (g >l f vs gs)
                      (0 < findsub <l "=") (g >l f (<l . vs) gs)
                      (g >l f vs (<l . gs)))
     a (g (aft (words line)) (K + "/Makefile") () ())
     ev (hk-env t)
     lv (map (v \ findsub v "=" @ k [(snip v 0 k) (snip v (k + 1) #v)]) (a 1))
     cl (uniq (peep t " cl" ()) + map (v \ v 0) lv)
     nt (foldl (n \ k \ pin n k (peep t k "")) {} ["MAKE_VERSION" ".FEATURES" "MAKEFLAGS" "MAKE" "CURDIR" " shell"])
     _ (each (ev + map (n \ [n (peep t n "")]) (peep t " cl" ()) + lv) (v \ pin nt (v 0) (v 1)))
     _ (pins nt "MAKEFILE_LIST" (a 0) "MAKECMDGOALS" (join " " (a 2)) " cl" cl " exports" (uniq (map (v \ v 0) ev + cl)))
     _ (pin nt " rules" (hk-vars (hk-slurp (a 0)) nt))
     ; the default goal: a special target (.PHONY) starts with a dot and holds no slash; ./ is
     ; Makefile.build's $(obj)/ with obj=.
     (first r) (filter (w \ !(hk-pre? w "." && findsub w "/" < 0) && findsub w "%" < 0) (r 0))
     gs (two? (a 2) ? (a 2) (take 1 (catmap first (hk-rx nt))))
     seen {}
     (each gs (x \ hk-make K nt x made seen run), 0))

 ; a make started from the environment, as a recipe's own script starts one (link-vmlinux.sh's
 ; ${MAKE} -f scripts/Makefile.build obj=init ..): each environment variable a variable, as
 ; make's are, then the command line read as a $(MAKE) line is. prior as hk-make's (or ()).
 ; answers the failed target or 0
 (hk-envmake K args sh run prior)
  (: t (foldl (a \ e \ findsub e "=" @ i (0 < i ? (pin a (snip e 0 i) (snip e (i + 1) #e)) a)) {} (environ 0))
     made (lit? prior ? (pins {} " prior" prior) {})
     (pull t "SHELL" 0, pins t " shell" sh "MAKE" "hk-make" " exports" (sort (filter (k \ !(hk-pre? k " ")) (keys t))),
      hk-submake K t (join " " ("hk-make" . args)) made run, peep made " failed" 0))

 ; a unit after the units its prerequisites need made here first: [[unit cmds] ..], build
 ; order, each target once, cmds [text saved? kind] expanded now (nothing in a directory's
 ; compiles reads what an earlier one made)
 (hk-plan K t u seen)
  (peep seen (u 1) 0 ? ()
     (: x (hk-unit K t u)
        (pin seen (u 1) 1,
         atom? x ? [[u ()]]
           (: ph (hk-words t "PHONY")
              (mine? p) (!(elem p ph) && !(hk-pre? p K) && two? (hk-rule K t p 3))
              cs (filter (c \ 0 < #(c 0)) (map (c \ [(hk-text c) (c 1) (c 0)]) (x 0)))
              (catmap (p \ hk-plan K t [(u 0) p] seen) (filter mine? (x 1)) + [[u cs]])))))

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
