; roster -- the bake's roster by unit: which apps past kore's table this image bakes and which
; it leaves on /love, and a bake from the carried source that leaves some out or takes carried
; ones in. the provenance is the verbs module's, laid by the cat's marks; a left-out unit's
; verbs stay as stubs that raise it at the first call, and a verb miss on its name raises it,
; so leaving one out trades its start for its bytes.
;   love roster                                        the units, baked, left out or part
;   love roster bake [--with U,..] [--without U,..] [-o OUT]
; a unit's needs are the modules its files cite or borrow, held by another unit
(module '(roster roster-main roster-units roster-needs roster-lay)
(borrow 'posix)
(: V (cite 'verbs)
   kore "src/apps/kore/kore.l"
   (fs _) (rev (V 'ros 'files))                     ; (path . baked) in cat order
   (unit x) (V 'unit <x)
   ; kore's table names every applet's main, so what it and the files ahead of it hold stays
   (cut l h) (l @ () [h ()]
                  (x . r) (<x = kore ? [(x . h) r] (cut r (x . h))))
   (roster-units _)
    (cut (fs ()) () @ [h t]
       (: H (foldl (s \ x \ pin s (unit x) 1) {} h)
          (foldl (a \ x \ (unit x @ u (H u || elem u a ? a (a + [u])))) () t)))
   (ufiles u) (filter (x \ unit x = u) (fs ()))
   ; carry: left out by default (the Makefile's carryfiles); part: some files baked
   (state u) (: fs (ufiles u)
                (? (all (f \ >f = 1) fs) "baked "
                   (all (f \ >f = 0) fs) (all (f \ V 'carried <f) fs ? "carry " "left  ")
                   "part  "))
   (named T u) (sort (filter (k \ (T k @ p (string? p && V 'unit p = u))) (keys T)))
   (slurp1 p) (open ("/love/" + p) "r" @ q (hot? q ? (slurp q @ t (close q, t)) ""))
   ; the name after each "cite '" and "borrow '", to the first delimiter
   (word1 s) (: n #s
                (go i) (i < n && !(elem (s i) [32 9 10 40 41 39 34 59]) ? (go (i + 1)) (snip s 0 i))
                (go 0))
   (refs t) (catmap (k \ map (s \ name (word1 s)) >(split k t)) ["cite '" "borrow '"])
   (roster-needs u us)
    (: M (V 'mods)
       (dep m) (M m @ p (string? p ? (V 'unit p)))
       ws (catmap (x \ map dep (refs (slurp1 <x))) (ufiles u))
       (foldl (a \ w \ (string? w && w != u && elem w us && !(elem w a) ? (a + [w]) a)) () ws))
   (q l) ("(quote " + show l + ")")
   ; the cat: each file baked? keeps behind its mark, each other a lazy form with its
   ; verbs, modules, and on the unit's first, its needs
   (roster-lay o baked? us)
    (: P (V 'prov) M (V 'mods) seen {}
       (one x) (<x @ p
                  (baked? x ?
                     (say o "\n(cite (quote verbs) (quote mark) \(show p))\n", say o (slurp1 p))
                     (: u (V 'unit p)
                        ns (seen u ? () (pin seen u 1, roster-needs u us))
                        (say o "\n(cite (quote verbs) (quote lazy) \(show p) \(q (filter (k \ P k = p) (keys P))) \(q (filter (k \ M k = p) (keys M))) \(q ns))\n"))))
       (each (fs ()) one,
        each (sort (keys (V 'carried))) (p \ say o "\n(cite (quote verbs) (quote carry) \(show p))\n"),
        say o "\n(cite (quote verbs) (quote mark) ())\n"))
   (die s) (say err ("roster: " + s + "\n"), 2)
   (commas s) (filter (w \ 0 < #w) (split "," s))
   (list-units _)
    (: us (roster-units ())
       w (foldl (a \ u \ max a #u) 0 us)
       (each us (u \ (: ns (roster-needs u us) vs (map show (named (V 'prov) u))
                        (puts (u + " " * (w + 1 - #u) + state u
                               + join " " vs + (two? ns ? "  (needs " + join " " ns + ")" "") + "\n")))),
        flush out, 0))
   (bake as)
    (: us (roster-units ())
       (opts a t) (a @ () t
                     ("--with" . w . r)    (opts r (pin t 'with (t 'with + commas w)))
                     ("--without" . w . r) (opts r (pin t 'without (t 'without + commas w)))
                     ("-o" . o . r)        (opts r (pin t 'o o))
                     (x . _)               (pin t 'bad x))
       t (opts as {})
       odd (filter (u \ !(elem u us)) (t 'with + t 'without))
       ; a file stays as it is unless its unit is named
       (baked? x) (unit x @ u (elem u (t 'with) ? 1 (elem u (t 'without) ? 0 (>x = 1))))
       keep (filter (u \ any baked? (ufiles u)) us)
       miss (catmap (k \ map (d \ [k d]) (filter (d \ !(elem d keep)) (roster-needs k us))) keep)
       me (selfpath 0)
       dst (t 'o || me)
       cat (dst + ".roster." + show (getpid 0) + ".l")
       (? (t 'bad) (die "unknown option \(t 'bad)\nusage: love roster bake [--with U,..] [--without U,..] [-o OUT]")
          (two? odd) (die "no unit \(<odd): `love roster` lists them")
          (two? miss) (<miss @ [k d] (die "\(k) needs \(d): leave both out, or keep \(d)"))
          (: o (open cat "w")
             (!(hot? o) ? (die "cannot write \(cat)")
                (: _ (roster-lay o baked? us, close o)
                   r (spawn ([me "bake" "-l" cat] + (t 'o ? ["-o" (t 'o)] ())) @ p
                        (charm? p && 0 <= p ? (wait p) 127))
                   (unlink cat, charm? r ? r 1))))))
   (roster-main as)
    (as @ () (list-units ())
          ("bake" . r) (bake r)
          ("--help" . _) (puts "usage: love roster [bake [--with U,..] [--without U,..] [-o OUT]]\n", 0)
          (x . _) (die "unknown command \(x)"))
   _ (cite 'verbs 'enlist 'roster roster-main ())))
