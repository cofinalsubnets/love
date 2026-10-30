; roster -- the bake's roster by unit: which apps past kore's table this image bakes and which
; it leaves on /love, and a bake from the carried source that leaves some out or takes carried
; ones in. the provenance is the verbs module's, laid by the cat's marks; a left-out unit's
; verbs stay as stubs that raise it at the first call, and a verb miss on its name raises it,
; so leaving one out trades its start for its bytes.
;   love roster                                        the units, baked, left out or part
;   love roster bake [--with U,..] [--without U,..] [-o OUT]
;   love roster pick [-o OUT]                          the same bake, chosen on a checklist
; a unit's needs are the modules its files cite or borrow, held by another unit
(module '(roster roster-main roster-units roster-needs roster-lay pick-new pick-step pick-flags pick-args pick-frame)
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
   ; --- the picker: the units on a checklist, its answer the bake's flags. a unit is on (1),
   ; off (0), or 'p, a part unit as it stands. its cost: ~2.2x its source baked
   (srcb x) (stat ("/love/" + <x) @ s (two? s ? <s 0))
   (now u) (state u @ "baked " 1 "part  " 'p 0)
   (pick-new _)
    (: us (roster-units ())
       (each1 f) (foldl (t \ u \ pin t u (f u)) {} us)
       ; [unbaked baked] source bytes
       (src u) (: fs (ufiles u) (bs b) (net (map srcb (filter (x \ >x = b) fs))) [(bs 0) (bs 1)])
       (pins {} 'us us 'cur 0 'top 0 'msg "" 'go 0 'over 0
                'ns (each1 (u \ roster-needs u us)) 'at (each1 now) 'on (each1 now) 'src (each1 src)))
   (kept pk u) (pk 'on u != 0)
   ; on takes along what it needs, off what needs it, each through the needs of the rest.
   ; a part unit turns whole, then off, then back as it stands
   (pick-flip pk u)
    (: c (pk 'on u) on (c = 0)
       (back w) (pk 'at w = 'p ? 'p 1)
       (next w) (on ? (pk 'ns w) (filter (k \ elem w (pk 'ns k)) (pk 'us)))
       (cl s w) (elem w s ? s (foldl cl (w . s) (next w)))
       more (filter (w \ w != u && (on ? !(kept pk w) (kept pk w))) (rev (cl () u)))
       (c = 'p ? (pins (pk 'on) u 1, pin pk 'msg "")
          (each (u . more) (w \ pin (pk 'on) w (on ? (back w) 0)),
           pin pk 'msg (two? more ? ("\(u) takes " + join " " more + (on ? " in" " out")) ""))))
   (pick-flags pk)
    (: (sel f) (filter f (pk 'us))
       [(sel (u \ pk 'on u = 1 && pk 'at u != 1)) (sel (u \ pk 'on u = 0 && pk 'at u != 0))])
   (pick-args f) ((two? <f ? ["--with" (join "," <f)] ()) + (two? <>f ? ["--without" (join "," <>f)] ()))
   ; the image's move in bytes: the unbaked source a --with takes in, the baked a --without drops
   (pick-delta pk) (: f (pick-flags pk) s (pk 'src)
                      (22 * (net (map (u \ <(s u)) <f) - net (map (u \ <>(s u)) <>f)) // 10))
   (pick-step pk c)
    (: n #(pk 'us) i (pk 'cur)
       (? (c = 106 || c = -9) (pin pk 'cur (min (n - 1) (i + 1)))
          (c = 107 || c = -8) (pin pk 'cur (max 0 (i - 1)))
          (c = 103 || c = -5) (pin pk 'cur 0)
          (c = 71 || c = -6) (pin pk 'cur (n - 1))
          (c = 32) (pick-flip pk (pk 'us i))
          (c = 13 || c = 10) (pins pk 'go 1 'over 1)
          (c = 113 || c = 27) (pin pk 'over 1)
          pk))
   (kb n) (show ((n + 512) // 1024) + "K")
   (lpad k s) (" " * max 0 (k - #s) + s)
   (pick-frame pk w h)
    (: us (pk 'us) n #us i (pk 'cur) b (max 1 (h - 4))
       top (? (i < pk 'top) i (pk 'top + b <= i) (i - b + 1) (pk 'top))
       _ (pin pk 'top top)
       nw (foldl (a \ u \ max a #u) 0 us)
       (cut s) (snip s 0 (min w #s))
       (row k) (: u (us k) c (pk 'on u) s (pk 'src u) ns (pk 'ns u)
                  t (" " + (c @ 1 "[x]" 0 "[ ]" "[~]") + (c = pk 'at u ? " " "*") + u
                     + " " * (nw + 1 - #u) + lpad 6 (kb (<s + <>s)) + " src  ~"
                     + lpad 6 (kb (22 * (<s + <>s) // 10)) + " baked"
                     + (two? ns ? ("  needs " + join " " ns) ""))
                  (k = i ? ("\e[7m" + cut t + "\e[0m\e[K") (cut t + "\e[K")))
       ks (filter (k \ k < n) (map (+ top) ^b))
       rows (map row ks + map (_ \ "\e[K") ^(b - #ks))
       f (pick-flags pk)
       cmd (two? <f || two? <>f ? ("love roster bake " + join " " (pick-args f)) "the roster as it stands")
       d (pick-delta pk)
       foot ("the image ~" + (d < 0 ? "-" "+") + kb (abs d) + " against this binary")
       ("\e[H\e[7m" + cut "love roster pick: space flips, enter bakes, q leaves" + "\e[0m\e[K\r\n"
        + join "\r\n" rows + "\r\n" + cut cmd + "\e[K\r\n" + cut (pk 'msg) + "\e[K\r\n" + cut foot + "\e[K"))
   (pick as)
    (: o (as @ () () ("-o" x) x _ 'bad)
       (? (o = 'bad) (die "usage: love roster pick [-o OUT]")
          (atom? (tty 1)) (die "pick wants a terminal; love roster bake takes the flags")
          (: pk (pick-new ())
             _ (stage (w \ h \ pick-frame pk w h) (pick-step pk) (_ \ pk 'over))
             f (pick-flags pk)
             (? !(pk 'go) 0
                !(two? <f || two? <>f) (puts "roster: as it stands, nothing to bake\n", 0)
                (: args (pick-args f + (o ? ["-o" o] ()))
                   (puts ("love roster bake " + join " " args + "\n"), flush out, bake args))))))
   (roster-main as)
    (as @ () (list-units ())
          ("bake" . r) (bake r)
          ("pick" . r) (pick r)
          ("--help" . _) (puts "usage: love roster [bake [--with U,..] [--without U,..] [-o OUT] | pick [-o OUT]]\n", 0)
          (x . _) (die "unknown command \(x)"))
   _ (cite 'verbs 'enlist 'roster roster-main ())))
