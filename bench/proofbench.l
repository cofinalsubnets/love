; proofbench: uu's kernel beside rocqchk and leanchecker, each checking the same terms.
;   dump DIR  loads and certifies the corpus, then for each workload writes DIR/W.uu, its
;             definitions as kernel calls, and DIR/W.v and DIR/W.lean, the exporters' DIR/all.v
;             and DIR/all.lean cut to the same declarations. a side missing one gets no file
;   run FILE  checks a W.uu in a fresh heap, as rocqchk checks a .vo: no elaborator, no laws
; proofbench.sh drives both and times the checkers.
(borrow 'posix)
(: K {'defn (cite 'uu 'defn) 'defq (cite 'uu 'defq) 'defvc (cite 'uu 'defvc)
      'axm (cite 'uu 'axm) 'defind (cite 'uu 'defind)}
   (kcall e) (<e @ 'axm ((K 'axm) (e 1) (e 2))
                    'defind ((K 'defind) (e 1) (e 2) (e 3) (drop 4 e))
                    ((K <e) (e 1) (e 2) (e 3))))
; run checks and quits before the dump's code is read: that code live in the heap doubled a run
(argv 1 = "run" ? (: es (forms (open (argv 2) "r")) _ (each es kcall) (puts (show #es), putc 10, quit 0)) 0)

(:: 'test (l \ (. 'assert l)))
(: (pb-die s) (puts "proofbench: \(s)\n", quit 1)
   (pb-read p) (: q (open p "r") (!(hot? q) ? (pb-die "cannot read \(p)") (slurp q)))
   (pb-write p s) (: q (open p "w") (!(hot? q) ? (pb-die "cannot write \(p)") (say q s, close q)))
   (cat l) (foldl (+) "" l)

   ; load order and gather order are uu2coq's: the exporters lay declarations in gather order
   loads ["test/uu.l" "test/uuhom.l" "test/uuhomgen.l" "test/uuhomlaw.l" "test/uuinf.l" "test/uuinfvc.l"
          "test/uuzb.l" "test/uuzbvc.l" "test/uuzx.l" "test/uuzxvc.l" "test/uumag.l" "test/uumagvc.l"
          "test/uusplgen.l" "test/uuspllaw.l" "test/uulay.l" "test/uuel.l" "test/uugc.l" "test/uuind.l"
          "test/uupatch.l" "test/uuwm.l" "test/uuwmlaw.l" "test/uukind.l" "test/uumx.l" "test/uumxlaw.l"
          "test/uuval.l" "test/uuvalband.l" "test/uuvallaw.l" "test/uukindlaw.l"]
   gathers ["test/uu.l" "test/uuind.l" "test/uuhom.l" "test/uuhomgen.l" "test/uuhomlaw.l" "test/uuinf.l"
            "test/uuinfvc.l" "test/uuzb.l" "test/uuzbvc.l" "test/uuzx.l" "test/uuzxvc.l" "test/uumag.l"
            "test/uumagvc.l" "test/uusplgen.l" "test/uuspllaw.l" "test/uulay.l" "test/uugc.l" "test/uupatch.l"
            "test/uuwm.l" "test/uuwmlaw.l" "test/uukind.l" "test/uukindlaw.l" "test/uumx.l" "test/uumxlaw.l"
            "test/uuval.l" "test/uuvalband.l" "test/uuvallaw.l"]

   ; an entry is the kernel call that certified it: [kind nm T t], [axm nm T], or the defind form
   (pb-dump dir)
    (: _ (each loads (f \ reads (open f "r")))
       bs (intern "\\") sugar (cite 'uu 'sugar) vcs-of (cite 'uu 'vcs-of) ELT (ev 'ELT)
       (unq x) (two? x && <x = bs ? (x 1) x)
       (ent c) (<c @ 'defn ['defn (unq (c 1)) (sugar (unq (c 2))) (sugar (unq (c 3)))]
                     'defq ['defq (unq (c 1)) (sugar (unq (c 2))) (sugar (unq (c 3)))]
                     'defvc ['defvc (unq (c 1)) (sugar (unq (c 2))) (sugar (unq (c 3)))]
                     'elq ['defq (unq (c 1)) (sugar (unq (c 2))) (ELT (unq (c 1)))]
                     'axm ['axm (unq (c 1)) (sugar (unq (c 2)))]
                     'defind c
                     ())
       (one c acc) (? (two? c && <c = 'defvcs) (foldl (a \ v \ ['defvc <v (sugar (v 1)) (sugar (v 2))] . a) acc (vcs-of >c))
                      (two? c) (ent c @ e (two? e ? (e . acc) acc))
                      acc)
       (top F acc) (two? F && <F = 'test ? (foldl (flip one) acc >F) (one F acc))
       fe (map (f \ [f (rev (foldl (flip top) () (forms (open f "r"))))]) gathers)
       ents (catmap (x \ x 1) fe)
       src (foldl (t \ x \ (each (x 1) (e \ pin t (e 1) <x), t)) {} fe)

       ; a name and what it lays: a family its recursor and constructors too
       (provs e) (<e = 'defind ? ((e 1) . ((intern "\(e 1)_rect") . map cap (drop 4 e))) [(e 1)])
       own (foldl (t \ e \ (each (provs e) (x \ pin t x (e 1)), t)) {} ents)
       byn (foldl (t \ e \ pin t (e 1) e) {} ents)
       (ment t acc) (? (nom? t) (own t @ o (o == () ? acc (pin acc o 1)))
                       (two? t) (foldl (flip ment) acc t)
                       acc)
       deps (foldl (t \ e \ pin t (e 1) (filter (o \ o != e 1) (keys (ment (drop 2 e) {})))) {} ents)
       (dep n) (peep deps n ())

       ; what uu refuses checked again with universes on (the canary ran with them off), and
       ; everything over it. a family cannot be laid twice, so it stands as loaded
       fails (foldl (t \ e \ (<e = 'defind || trap (_ \ (kcall e, 1)) 0 (a \ b \ 0) ? t (pin t (e 1) 1))) {} ents)
       bad (foldl (t \ e \ (peep fails (e 1) 0 || any (d \ peep t d 0) (dep (e 1)) ? (pin t (e 1) 1) t)) {} ents)

       ; the exporters' declarations: a block runs from its head line to a blank line or the next head
       (sanit s) (jug 0 @ j (each ^#s (i \ say j (string (s i @ 45 95 c c))), slurp j))
       (xn n) ("uu_" + sanit (string n))
       ; a head names a uu export: the preamble's own paths and total2 stay preamble
       (blocks txt heads) (: (bname l) (: w (split " " (snip l (l 0 = 64 ? 13 0) #l)) (w 1))
                             (head? l) (any (h \ #h <= #l && snip l 0 #h = h) heads && snip (bname l) 0 3 = "uu_")
                             (go ls pre cur acc) (ls @ (l . u)
                               (? (head? l) (go u pre [l] (two? cur ? (rev cur . acc) acc))
                                  (two? cur && (#l = 0 || l = "end")) (go u pre () (rev cur . acc))
                                  (two? cur) (go u pre (l . cur) acc)
                                  (two? acc) (go u pre cur acc)
                                  (go u (l . pre) cur acc))
                               [(rev pre) (rev (two? cur ? (rev cur . acc) acc))])
                           r (go (lines txt) () () ())
                           [<r (map (b \ [(bname <b) b]) (r 1))])
       rq (blocks (pb-read "\(dir)/all.v") ["Definition " "Axiom " "Inductive "])
       lq (blocks (pb-read "\(dir)/all.lean") ["def " "@[reducible] def " "inductive "])
       (names q) (foldl (t \ b \ pin t <b 1) {} (q 1))
       rn (names rq) ln (names lq)
       (has? tb e) (peep tb (xn (e 1)) 0)

       ; the workloads, each a set of entry names closed over what its members cite
       (close roots) (: S {}
                        (go n) (!(peep S n 0) ? (pin S n 1, each (dep n) go) 0)
                      (each roots go, S))
       inv (foldl (t \ e \ (<e = 'axm || any (d \ peep t d 0) (dep (e 1)) ? (pin t (e 1) 1) t)) {} ents)
       vc (filter (e \ src (e 1) = "test/uumagvc.l") ents)
       wls [['base {}]
            ['corpus (close (map (e \ e 1) (filter (e \ !(peep bad (e 1) 0) && has? rn e && has? ln e) ents)))]
            ['tower (close ['uu-app-tower])]
            ['ring (close (map (e \ e 1) (filter (e \ peep (ment (drop 2 e) {}) 'rex-eq 0) vc)))]
            ['ledger (close (map (e \ e 1) vc))]
            ['ua (close (map (e \ e 1) (filter (e \ peep inv (e 1) 0) ents)))]]

       (slice q tb es tail) (: want (foldl (t \ e \ (each (provs e) (x \ pin t (xn x) 1), t)) {} es)
                             ((all (e \ has? tb e) es) ? (unlines (<q + catmap (b \ (peep want <b 0 ? (b 1) ())) (q 1) + tail)) ()))
       (lay w) (w @ [W S]
                (: es (filter (e \ peep S (e 1) 0) ents) n (string W)
                   rv (slice rq rn es ()) lv (slice lq ln es ["" "end"])
                   nb #(filter (e \ peep bad (e 1) 0) es)
                   ry (rv == () ? "no" "yes") ly (lv == () ? "no" "yes")
                 (pb-write "\(dir)/\(n).uu" (unlines (map show es)),
                  (rv == () ? 0 (pb-write "\(dir)/\(n).v" rv)),
                  (lv == () ? 0 (pb-write "\(dir)/\(n).lean" lv)),
                  puts "\(n) \(#es) entries, rocq \(ry), lean \(ly), uu refuses \(nb)\n")))
     (puts "\(#ents) entries gathered, \(#(keys fails)) refused with universes on, \(#(keys bad)) over them\n",
      each wls lay, quit 0))

 (argv 1 @ "dump" (pb-dump (argv 2))
           (pb-die "usage: proofbench.l dump DIR | run FILE")))
