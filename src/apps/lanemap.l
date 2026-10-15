; src/apps/lanemap.l -- the lanes a change owes, as data: which paths owe which lanes, how each
; lane runs beside the others, and AGENTS.md's table laid from them.
;
;   lanes-rules     [[label globs lanes tail] ..]: a change touching a glob owes the lanes. label is
;                   the table's words for the paths ("" lays the globs), tail follows the lanes there
;   lanes-heavy     the lanes that wait for a heavy ticket (locks.l)
;   lanes-cost      lane -> its wall seconds on a shared box, measured; it only orders lanes
;   lanes-chains    the lanes that share scratch or sub-build one tree, each chain run in its order
;   lanes-alone     the lanes that rebuild love0 under another cc or run their own fleet: alone
;   (lanes-doc _)   AGENTS.md's table, its lines (love bee --lanes-doc)
;   (lanes-map _)   lanes.sh's chains and alone set, `chain A,B,..` and `alone A B ..` lines
;                   (love bee --lanes-map)
;   (lanes-covers mk) test/test.mk's text -> lane -> the lanes it runs: its prerequisites and the
;                   targets of its recipe's $(MAKE) lines, read as written
;   (lanes-plan paths baked covers)  the lanes a change owes, in the order to run them:
;                   [[lane heavy? cost why] ..]. light before heavy, cheap first, a lane another
;                   owed lane runs dropped, test always and test_slow last. why is the paths that
;                   owed it
;   (lanes-lines plan)  the plan as `lane light|heavy cost why` lines (love bee --lanes)
;
; a glob's `*` crosses `/`; "baked" is the crew roster ($(ho)/.dist.list), not a glob. every
; change owes `make test` besides, and test_slow runs last on the tree that lands
(module (lanemap lanes-rules lanes-heavy lanes-cost lanes-chains lanes-alone lanes-doc lanes-map
                 lanes-covers lanes-plan lanes-lines)

(: moon-lanes ["test_moon" "test_clay" "test_cca64" "test_cci386" "test_ccarm" "test_ccrv64" "test_ccwasm"
               "test_ccthumb1" "test_ccthumb2" "test_fixpoint" "test_moonfuzz" "test_inle"]
   lanes-rules
    [["" ["src/apps/kore/*"] ["test_kore" "test_hostnif"] ""]
     ["" ["src/apps/lush.l" "src/apps/cook.l" "src/apps/bee.l" "src/apps/lanemap.l"] ["test_hostnif"] ""]
     ["" ["src/love/snap.c" "src/love/image.c" "Makefile" "src/tools/hotbake.sh"] ["test_ccwarn" "test_hdiff" "test_inle"] ""]
     ["the rest of the core, `src/love/*.c` and `src/love/boot/*.l`" ["src/love/*.c" "src/love/boot/*.l"] ["test_quick"] ""]
     ["the C core, `src/love/*.c` `src/love/*.h` `src/apps/moon/lib/moonlibc/*` and the `Makefile`"
      ["src/love/*.c" "src/love/*.h" "src/apps/moon/lib/moonlibc/*" "Makefile"] ["test_gcstress"]
      ", in the queue's union; a `.l`, doc, app or test diff never owes it"]
     ["what the bake runs, `src/love/{gc,snap,image,ev,io,love,map,tablet,alloc}.c` and the glaze"
      ["src/love/gc.c" "src/love/snap.c" "src/love/image.c" "src/love/ev.c" "src/love/io.c" "src/love/love.c"
       "src/love/map.c" "src/love/tablet.c" "src/love/alloc.c" "src/love/boot/glaze.l"] ["test_gcstress_bake"]
      ", which runs test_gcstress's shards as well: owing both runs it alone"]
     ["a crewfiles member, or anything else baked" ["baked"] ["test_fixpoint" "test_bakerep"]
      ", and `make hotprof` to write `src/tools/hot.prof` again (bakerep fails while it is stale)"]
     ["" ["src/apps/moon/*"] moon-lanes ""]
     ["" ["src/love/holo/*"] ["test_holo" "test_as" "test_holofuzz" "test_inle"] ""]
     ["" ["src/apps/sb/*"] ["test_sb"] ""]
     ["" ["src/apps/hearts/*"] ["test_hearts" "test_hearts_boot"] ""]]
   lanes-heavy ["test_slow" "test_extra" "test_inle" "test_kernel_%" "test_gcstress" "test_gcstress_bake" "test_boards" "test_hearts"
                "test_hearts_boot" "moon-flex" "moon-bison"]
   lanes-cost {"test" 195 "test_quick" 409 "test_hostnif" 380 "test_ccwarn" 165 "test_fixpoint" 266 "test_bakerep" 730
               "test_hdiff" 1421 "test_vec" 1679 "test_xfixpoint" 2365}
   lanes-chains
    [["test_extract" "test_big" "test_encver"]
     ["test_inle" "test_kernel_vmx" "test_disk" "test_uefi" "test_kboot" "test_kmitty" "test_kverb" "test_kernel_uproc"
      "test_kernel_a64" "test_uefi_a64" "test_kernel_rv64" "test_kernel_wasm" "test_seedwasm" "test_nestwasm"]
     ["test_doomx" "test_doomwasm"]
     ["test_elf32" "test_mps2_build" "test_virt_build" "test_mps2" "test_mps2_t1" "test_mps2_wake" "test_virt"
      "test_nucleo446" "test_nucleo446_smoke" "test_teensy41" "test_playdate" "test_rp2040" "test_boards"
      "test_objcopy" "test_links"]
     ["test_freebsd" "test_netbsd" "test_freebsd_a64" "test_netbsd_a64"]]
   ; test_inle's rv64 corpus nears its tcg ceiling beside any other boot
   lanes-alone ["test_hdiff" "test_ccwarn" "test_gcstress" "test_gcstress_bake" "test_gcstress_full" "test_inle" "test_kernel_rv64"]

   (lm-tick s) ("`" + s + "`")
   (lanes-doc _)
    (map (r \ r @ [label globs ls tail]
                ("- " + (#label > 0 ? label (join ", " (map lm-tick globs))) + " -> " + join " " (map lm-tick ls) + tail))
         lanes-rules)
   (lanes-map _)
    (map (c \ "chain " + join "," c) lanes-chains + [("alone " + join " " lanes-alone)])

   ; a glob's stars cross `/`: the first piece a prefix, the last a suffix, the rest in order between
   (lm-from s p i) (? (#s < i + #p) -1 (snip s i (i + #p) = p) i (lm-from s p (i + 1)))
   (lm-mid s ps i lim)
    (? (atom? ps) 1
       (: j (lm-from s <ps i) (? ((j < 0) || (lim < j + #<ps)) 0 (lm-mid s >ps (j + #<ps) lim))))
   (lm-glob? g s)
    (: ps (split "*" g) a <ps z (ps (#ps - 1))
       (? (#ps = 1) (g = s)
          (#s < #a + #z || !(starts? s a) || !(ends? s z)) 0
          (lm-mid s (take (#ps - 2) >ps) #a (#s - #z))))
   (lm-hit? baked p g) (g = "baked" ? (elem p baked) (lm-glob? g p))

   (lm-tests s) (filter (w \ starts? w "test_") (words s))
   (lm-joined ls)
    (rev (foldl (\ acc l (? (two? acc && ends? <acc "\\") ((snip <acc 0 (#<acc - 1) + " " + l) . >acc) (l . acc)))
                () ls))
   (lanes-covers mk)
    (: (add t ns s) (foldl (\ t n (pin t n (peep t n () + lm-tests s))) t ns)
       (step st l)
        (st @ [t cur]
         (? (starts? l "\t") (? (two? cur && 0 <= lm-from l "$(MAKE)" 0) [(add t cur l) cur] st)
            (#l = 0 || starts? l "#") st
            (: i (lm-from l ":" 0) ns (words (snip l 0 (i < 0 ? 0 i)))
               (? ((i < 0) || !(two? ns) || any (n \ !(starts? n "test")) ns || (0 <= lm-from l "=" 0)) [t ()]
                  [(add t ns (snip l (i + 1) #l)) ns]))))
       ; ..and what a recipe runs through a script, where no $(MAKE) says so: gcshard.sh under
       ; GCS_BAKE runs test_gcstress's shards, so owing both runs the bake alone
       cv (<(foldl step [{} ()] (lm-joined (lines mk))))   b (peep cv "test_gcstress_bake" ())
       (pin cv "test_gcstress_bake" (elem "test_gcstress" b ? b (b + ["test_gcstress"]))))
   ; every lane l runs, through its members' members too
   (lm-under covers l)
    (:- (go [l] ()) (go todo seen)
        (? (atom? todo) seen
           (elem <todo seen) (go >todo seen)
           (go (peep covers <todo () + >todo) (<todo . seen))))
   (lm-heavy? l) (any (h \ h = l || (ends? h "%" && starts? l (snip h 0 (#h - 1)))) lanes-heavy)
   (lanes-plan paths baked covers)
    (: owed (foldl (\ t p (foldl (\ t r (r @ [_ globs ls _]
                                          (? (any (lm-hit? baked p) globs)
                                             (foldl (\ t l (: o (peep t l ()) (pin t l (elem p o ? o (o + [p]))))) t ls) t)))
                                 t lanes-rules))
                   {} paths)
       ls (filter (l \ l != "test" && l != "test_slow") (keys owed))
       under (map (l \ [l (filter (m \ m != l) (lm-under covers l))]) ls)
       kept (filter (l \ !(any (u \ <u != l && elem l (u 1)) under)) ls)
       row (\ l why [l (lm-heavy? l) (peep lanes-cost l ()) why])
       by (sort (map (l \ [(lm-heavy? l) (peep lanes-cost l 900) l]) kept))
       ([(row "test" ["every change"])] + (map (k \ k @ [_ _ l] (row l (owed l))) by)
        + [(row "test_slow" ["last, on the tree that lands"])]))
   (lanes-lines plan)
    (map (r \ r @ [l h c why]
                (l + " " + (h ? "heavy" "light") + " " + (charm? c ? (show c + "s") "?") + " "
                 + join " " (take 3 why) + (#why > 3 ? (" +" + show (#why - 3)) "")))
         plan))
) ; module lanemap
