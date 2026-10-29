; test/host/overlay.l -- the lux type overlay (src/apps/lux/sigs.l) and the baked uu book, end to end
; run: cat test/00-init.l test/host/overlay.l | out/love

(reads (open "src/apps/lux/sigs.l" "r"))
(reads (open "src/apps/lux/core.l" "r"))
(borrow 'lux)

(:    chk1 (overlay 'ov-check)
   ; opfix then unglue: a glued sigil factors to a value, which no checker matches by name
   (fix1 f) (unglue (opfix f))
   (sweep path) (foldl (a \ f \ (cat a (chk1 lux-dom lux-sigs (fix1 f)))) () (lux-peel (forms (open path "r"))))

 ; leg 1: the shipped sources check clean...
 _ (test !(sweep "src/apps/lux/core.l")
           !(sweep "src/apps/lux/layout.l"))
 ; ...and a wrong kind is caught: zins wants (window zipper), the wound hands it a tag and a sheaf
 hurt (chk1 lux-dom ('(oops (sheaf tag) top) . lux-sigs)
            '(: (oops s t) (zins (wstagof s t) s)))
 _ (test (two? hurt) ('oops = <<hurt))

 ; leg 2: the gradual laws
 sg2 ('(g1 (rect) window) . '(g2 (window) top) . lux-sigs)
 (test !(chk1 lux-dom sg2 '(: (g1 r) (zfoc (cap r))))       ; unknown arg: consistent
         !(chk1 lux-dom sg2 '(: (g2 w) (zins w)))             ; partial app: open, not a clash
         (two? (chk1 lux-dom sg2 '(: (g1 r) (zfoc r)))),           ; a rect in the zipper slot: flagged

  ; leg 3: uu, baked -- define, certify, compute
  uu 'defn 'boot-add '(pi m nat (pi n nat nat))
           '(lam m (lam n (nat_rect (lam q nat) n (lam k (lam r (succ r))) m))),
  test (3 = (uu 'vof) () '(boot-add 2 1))
         (5 = (uu 'vof) () '(boot-add 2 3))))

; the kernel refuses through the help cell: install the escape, probe, uninstall
(hear (p \ e \ (peep (uu 'HELPC) () 0 @ h (h ? (h p e) 0))))
(test ('rejected = uu 'rejects (z \ (uu 'defn) 'boot-bad 'nat '(lam x x))))
(hear 0)

; leg 4: the uu corpus, re-certified here, run against core.l on concrete stacks
(reads (open "test/uu.l" "r"))
(reads (open "test/uulay.l" "r"))
(reads (open "test/uuwm.l" "r"))
(reads (open "test/uuwmlaw.l" "r"))
(: (encl l) (two? l ? ['ncons <l (encl >l)] 'nnil)
   (encz z) ['zmk <z (encl <>z) (encl <>>z)]
   (decl v) (: (go vv acc) (two? vv ? (go (vv 2) (vv 1 . acc)) (rev acc))
              (go (v 2) ()))
   (decz v) (zmk (v 1) (decl (v 2 1)) (decl (v 2 2)))
 z0 (zmk 5 [2] [7 9])
 z1 (zmk 5 () [7 9])
 _ (test
    (zrow z0 = decl (vof 0 ['zrow (encz z0)]))
    (zrow (zins 4 z0) = decl (vof 0 ['zrow ['zins 4 (encz z0)]]))
    (#(zrow (zins 4 z0)) = vof 0 ['zcount ['zins 4 (encz z0)]])
    ; focus motion, both faces: the plain step and the wrap
    (<(zfocup z0) = vof 0 ['zfoc ['zfocup (encz z0)]])
    (zrow (zfocup z0) = decl (vof 0 ['zrow ['zfocup (encz z0)]]))
    (<(zfocup z1) = vof 0 ['zfoc ['zfocup (encz z1)]])
    (<(zfocdn z0) = vof 0 ['zfoc ['zfocdn (encz z0)]])
    (zrow (zmaster z0) = decl (vof 0 ['zrow ['zmaster (encz z0)]]))
    ; delete, through the model's Maybe (ii2 carries the survivor)
    (zdel 5 z0 = decz (vof 0 ['zdel 5 (encz z0)] 1))
    (zswapup z0 = decz (vof 0 ['zswapup (encz z0)]))))

; leg 5: seeded random walks through both worlds, compared each step; zsane checked
; every tenth stack. the model steps from the encoded core state, so a divergence names its op
(: (rnd s) ((s * 1103515245 + 12345) % 2147483648)
   (encl l) (two? l ? ['ncons <l (encl >l)] 'nnil)
   (encz z) ['zmk <z (encl <>z) (encl <>>z)]
   (decl v) (: (go vv acc) (two? vv ? (go (vv 2) (vv 1 . acc)) (rev acc))
              (go (v 2) ()))
   (decz v) (zmk (v 1) (decl (v 2 1)) (decl (v 2 2)))
   (mstep r w t) (? (r = 0) (vof 0 ['zins w t])
                    (r = 1) (vof 0 ['zfocup t])
                    (r = 2) (vof 0 ['zfocdn t])
                    (r = 3) (vof 0 ['zswapup t])
                    (r = 4) (vof 0 ['zswapdn t])
                    (r = 5) (vof 0 ['zmaster t])
                    (vof 0 ['zdel w t] 1))
   (cstep r w z) (? (r = 0) (zins w z)
                    (r = 1) (zfocup z)
                    (r = 2) (zfocdn z)
                    (r = 3) (zswapup z)
                    (r = 4) (zswapdn z)
                    (r = 5) (zmaster z)
                    (zdel w z))
   (fuzz i s z nid)
    (i < 1 ? 1 (: row (zrow z)
          r (s % 7 @ r0 ((r0 = 6 ? (#row < 2) 0) ? 1 r0))   ; no deletes below 2
          s2 (rnd s)
          w (? (r = 0) nid (r = 6) (row (s2 % #row)) 0)
          zc (cstep r w z)
          zm (decz (mstep r w (encz z)))
          (!(zc = zm) ? (dot [(\ fuzz-diverged) i r w zc zm], 0)
             (? (0 = i % 10)
                     (vof 0 'true = vof 0 ['zsane (encz zc)] ? 0 (dot [(\ fuzz-insane) i zc]))
                     0,
              fuzz (i - 1) (rnd s2) zc (r = 0 ? (nid + 1) nid)))))
 (test (fuzz 150 20260705 (zmk 0 () ()) 1),
  puts "overlay leg 5: ok"))

; leg 6: src/tools/wm2uu.l translates core.l's ops to uu terms, certified in gens' order,
; which must answer the fuzz exactly as core.l does
(reads (open "src/tools/wm2uu.l" "r"))
(:    cforms (map (f \ unglue (opfix f)) (forms (open "src/apps/lux/core.l" "r")))   ; the surface factored to the core, as above
   gens (wm2uu cforms lux-sigs)
 _ (test (10 = #gens))
 _ (map (g \ (uu 'defn) <g (g 1) (g 2)) gens)   ; the function: these args are computed
 _ (puts "overlay leg 6: translated + certified ")

 ; the idpath bridges: paths res (gen-op args..) (op args..), proved by (idpath (op args..)),
 ; checks iff the translation is convertible with the proved model
 amap '((zrow agree-zrow) (zrev agree-zrev)
        (zfocup agree-zfocup) (zfocdn agree-zfocdn) (zswapup agree-zswapup)
        (zswapdn agree-zswapdn) (zmaster agree-zmaster) (zins agree-zins)
        (znub agree-znub) (zdel agree-zdel))
 (mname nm) (nm = 'znub ? 'nfilt nm)                   ; znub's proved twin is nfilt
 _ (map (nm \ (: sg (w2-sigof lux-sigs nm)
                 ps ><(w2-find nm cforms)
                 ks <>sg
                 res (w2-mty (w2-rk nm (sg 2)))
                 (uu 'defn <>(assoc nm amap)
                  (w2-pi ps ks ['paths res (w2-gen nm . ps) (mname nm . ps)])
                  (w2-lams ps ['idpath (mname nm . ps)]))))
        w2-want)
 (puts "overlay stage 4: 10 idpath bridges -- the compiled ops ARE the proved model"))

; the same seeded walk, the model side now stepping through the translated ops
(: (rnd s) ((s * 1103515245 + 12345) % 2147483648)
   (encl l) (two? l ? ['ncons <l (encl >l)] 'nnil)
   (encz z) ['zmk <z (encl <>z) (encl <>>z)]
   (decl v) (: (go vv acc) (two? vv ? (go (vv 2) (vv 1 . acc)) (rev acc))
              (go (v 2) ()))
   (decz v) (zmk (v 1) (decl (v 2 1)) (decl (v 2 2)))
   (mstep r w t) (? (r = 0) (vof 0 ['gen-zins w t])
                    (r = 1) (vof 0 ['gen-zfocup t])
                    (r = 2) (vof 0 ['gen-zfocdn t])
                    (r = 3) (vof 0 ['gen-zswapup t])
                    (r = 4) (vof 0 ['gen-zswapdn t])
                    (r = 5) (vof 0 ['gen-zmaster t])
                    (vof 0 ['gen-zdel w t] 1))
   (cstep r w z) (? (r = 0) (zins w z)
                    (r = 1) (zfocup z)
                    (r = 2) (zfocdn z)
                    (r = 3) (zswapup z)
                    (r = 4) (zswapdn z)
                    (r = 5) (zmaster z)
                    (zdel w z))
   (fuzz i s z nid)
    (i < 1 ? 1 (: row (zrow z)
          r (s % 7 @ r0 ((r0 = 6 ? (#row < 2) 0) ? 1 r0))
          s2 (rnd s)
          w (? (r = 0) nid (r = 6) (row (s2 % #row)) 0)
          zc (cstep r w z)
          zm (decz (mstep r w (encz z)))
          (!(zc = zm) ? (dot [(\ genfuzz-diverged) i r w zc zm], 0)
             (fuzz (i - 1) (rnd s2) zc (r = 0 ? (nid + 1) nid)))))
 _ (test (fuzz 100 424242 (zmk 0 () ()) 1))
 ; the accessors/row through the translated lane, spot-checked
 z0 (zmk 5 [2] [7 9])
 (test (zrow z0 = decl (vof 0 ['gen-zrow (encz z0)]))
       (<(zrev z0) = vof 0 ['zfoc ['gen-zrev (encz z0)]])
       (znub 7 (zrow z0) = decl (vof 0 ['gen-znub 7 ['gen-zrow (encz z0)]])),
  puts "overlay: ok"))

; leg 7: test/uulay.l's tiling ledger vs layout.l's rt-tile on seeded rows: the placed
; windows, rtwins, and the row must be one list (rtwinsrow); geometry is not checked here
(reads (open "src/apps/lux/layout.l" "r"))
(: (rnd s) ((s * 1103515245 + 12345) % 2147483648)
   (encl l) (two? l ? ['ncons <l (encl >l)] 'nnil)
   (decl v) (: (go vv acc) (two? vv ? (go (vv 2) (vv 1 . acc)) (rev acc))
              (go (v 2) ()))
   (wincol ps) (two? ps ? (<<ps . wincol >ps) ())
   (iota n b) (n < 1 ? () (b . iota (n - 1) (b + 1)))
   (walk i s)
    (i < 1 ? 1 (: n (s % 7) nm (rnd s % 5) s2 (rnd (rnd s))
          ws (iota n (10 + i))
          z (zfrom ws)
          core (wincol <(lay-tile (resizable-tall nm 0.03 0.5) '(0 0 800 600) z))
          model (decl (vof 0 ['rtwins nm 'nnil 0 (encl ws)]))
          (!(core = ws && model = ws) ? (dot [(\ ledger-diverged) i nm ws core model], 0)
             (walk (i - 1) s2))))
 (test (walk 40 20260706),
  test_fin (),
  puts "overlay leg 7: the tiling ledger holds, model and metal"))
