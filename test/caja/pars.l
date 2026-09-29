; test/caja/pars.l -- src/apps/caja/par.l held to TeX, a paragraph at a time. a page's paragraphs
; are tokens, said twice: as -ini TeX input (with hyphen.tex's patterns and plain's space
; factors), and through caja's main loop and line breaker. test/gate/caja.sh compares the DVI.
;
;   love test/caja/pars.l OUT SEED N hyphen.tex fontpaths..   OUT.tex and OUT.dvi: the
;                                                             fixed pages, then N from SEED
;
; the fonts are boxes.l's and cajalig, test/caja/cajalig.pl through pltotf, which TeX must
; find beside OUT.tex
;
; the tokens are par.l's, and so is their TeX spelling (cp-tex)
(: _ (borrow 'posix)
   _ (borrow "src/apps/tfm.l")
   _ (borrow "src/apps/caja/box.l")
   _ (borrow 'caja-box)
   _ (borrow "src/apps/caja/par.l")
   _ (borrow 'caja-par)
   _ (borrow "src/apps/caja/page.l")
   _ (borrow 'caja-page)
   (die m) (: _ (say err ("pars: " + m + "\n")) _ (flush err) (quit 1))
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (spit p s) (: q (open p "w") (? (hot? q) (: _ (say q s) (close q)) (die ("cannot write " + p))))

   fonts [["cmr10" -1000] ["cmbx12" -1000] ["cmr10" 478413] ["cmtt10" 1310720] ["cmsl9" -1000]
          ["ecrm1000" -1000] ["cajalig" -1000]]
   (fname k) ("\\f" + string (96 + k))
   sfcodes [[46 3000] [63 3000] [33 3000] [58 2000] [59 1500] [44 1250] [41 0] [39 0] [93 0]]
   ; --- words -------------------------------------------------------------------------------
   vocab ["the" "of" "and" "a" "to" "in" "is" "that" "it" "for" "as" "with" "was" "on" "be"
          "by" "this" "which" "or" "from" "at" "an" "are" "not" "but" "have" "all" "one" "their"
          "difficult" "hyphenation" "paragraph" "typesetting" "algorithm" "mathematical"
          "effluent" "affliction" "officially" "shuffling" "baffled" "waffle" "fjord" "offer"
          "office" "efficient" "sufficiently" "flight" "fluffier" "affirmative" "buffalo"
          "associate" "associates" "declination" "obligatory" "philanthropic" "present"
          "presents" "project" "projects" "reciprocity" "recognizance" "reformation"
          "retribution" "table" "demonstration" "encyclopaedia" "characteristically"
          "incomprehensibilities" "electroencephalograph" "unquestionably" "compositor"
          "justification" "ligature" "boundary" "discretionary" "consideration" "whatsoever"
          "nevertheless" "approximately" "preliminary" "extraordinary" "communication"
          "Knuth" "Plass" "Liang" "Stanford" "TeXbook" "American" "Mathematical" "Society"
          "breakpoints" "demerits" "looseness" "tolerance" "stretchability" "shrinkability"
          "badness" "penalty" "glue" "kerning" "fitness" "classification" "infinity"
          "well-known" "so-called" "self-reproducing" "x" "I" "O" "AV" "WAVE" "Tofu" "VAT"]
   letters (map (+ 97) ^26 + map (+ 65) ^26)
   prefixes ["" "" "" "" "" "" "(" "``" "`" "["]
   suffixes ["" "" "" "" "" "" "" "," "," "." "." ";" ":" "!" "?" ")" "''" "'" "--" "---" "?`" "!`"]
   (word-toks w dash)
    (: n #w
       (go i acc) (? (i >= n) (rev acc)
                     (: c ['c (w i)]
                        (? (dash && 1 < i && i < n - 1 && i % 3 = 0) (go (i + 1) (c . 'dash . acc))
                           (go (i + 1) (c . acc)))))
       (go 0 ()))

   ; --- the pages ---------------------------------------------------------------------------------
   pt 65536
   ; plain.tex's settings, as tokens
   plain [['set 'pretolerance 100] ['set 'tolerance 200] ['set 'linepenalty 10]
          ['set 'hyphenpenalty 50] ['set 'exhyphenpenalty 50] ['set 'adjdemerits 10000]
          ['set 'doublehyphendemerits 10000] ['set 'finalhyphendemerits 5000]
          ['set 'clubpenalty 150] ['set 'widowpenalty 150] ['set 'brokenpenalty 100]
          ['set 'lefthyphenmin 2] ['set 'righthyphenmin 3] ['set 'uchyph 1]
          ['set 'hsize (390 * pt)] ['set 'parindent (20 * pt)]
          ['set 'baselineskip [(12 * pt) 0 0 0 0]] ['set 'lineskip [pt 0 0 0 0]]
          ['set 'parskip [0 pt 0 0 0]] ['set 'parfillskip [0 pt 1 0 0]] ['set 'hangafter 1]]
   text1 "In olden times when wishing still helped one, there lived a king whose daughters were all beautiful; and the youngest was so beautiful that the sun itself, which has seen so much, was astonished whenever it shone in her face. Close by the king's castle lay a great dark forest, and under an old lime-tree in the forest was a well, and when the day was very warm, the king's child went out into the forest and sat down by the side of the cool fountain; and when she was bored she took a golden ball, and threw it up on high and caught it; and this ball was her favorite plaything."
   text2 "The affluent officials of the fjord's efficient office offered sufficient coffee to the baffled buffalo, whose difficult affliction--an ``ineffable'' waffle--was unquestionably characteristically incomprehensible; nevertheless, the compositor's justification of the paragraph, with its ligatures, discretionaries and kerning, remained (approximately) extraordinary!"
   (str-toks s) (: n #s (map (i \ (? (s i = 32) 'sp ['c (s i)])) ^n))
   (with-font k ts) (['f k] . ts)
   (para settings text) (settings + ['noindent] + str-toks text + ['par])
   (ipara settings text) (settings + ['indent] + str-toks text + ['par])
   fixed
    [(with-font 1 (plain + ipara [] text1 + ipara [] text2))
     (with-font 1 (plain + [['set 'hsize (150 * pt)]] + ipara [] text1))
     (with-font 1 (plain + [['set 'hsize (110 * pt)] ['set 'pretolerance -1] ['set 'tolerance 10000]] + ipara [] text2))
     (with-font 1 (plain + [['set 'rightskip [0 (20 * pt) 0 0 0]] ['set 'hsize (200 * pt)]] + ipara [] text1))
     (with-font 1 (plain + ipara [['set 'looseness 1]] text1 + ipara [['set 'looseness -1]] text1))
     (with-font 1 (plain + ipara [['set 'hangindent (40 * pt)] ['set 'hangafter -3]] text1
                   + ipara [['set 'hangindent (-60 * pt)] ['set 'hangafter 2]] text2))
     (with-font 1 (plain + ipara [['set 'parshape [[0 (300 * pt)] [(20 * pt) (250 * pt)] [(40 * pt) (200 * pt)] [(10 * pt) (330 * pt)]]]] text1))
     (with-font 1 (plain + [['set 'hsize (80 * pt)] ['set 'emergencystretch (30 * pt)] ['set 'overfullrule (5 * pt)]] + ipara [] text2))
     (with-font 1 (plain + [['set 'hsize (60 * pt)] ['set 'overfullrule (5 * pt)] ['set 'tolerance 100]] + ipara [] text1))
     (with-font 4 (plain + [['set 'hsize (200 * pt)] ['set 'spaceskip [(4 * pt) pt 0 pt 0]] ['set 'xspaceskip [(8 * pt) (2 * pt) 0 0 0]]] + ipara [] text2))
     (with-font 6 (plain + [['set 'hsize (180 * pt)]] + ipara [] text2 + ipara [['set 'lefthyphenmin 1] ['set 'righthyphenmin 1]] text1))
     (with-font 2 (plain + [['set 'hsize (170 * pt)] ['set 'uchyph 0] ['set 'leftskip [(10 * pt) 0 0 0 0]]] + ipara [] text2))
     ; every pair of letters in the torture font, each a word of its own
     (with-font 7 (plain + [['set 'hsize (300 * pt)] ['set 'tolerance 10000]]
                   + ipara [] (cats (map (a \ cats (map (b \ string a + string b + " ") letters)) letters))))]

   ; --- random pages ------------------------------------------------------------------------------
   (rnd st) (: x ((st 's * 1103515245 + 12345) % 2147483648) _ (pin st 's x) (x // 16))
   (pick st l) (l (rnd st % #l))
   (chance st n) (rnd st % n = 0)
   ; a fil amount is drawn in halves, which the TeX side says exactly
   (rand-glue st w) (: o (? (chance st 4) (pick st [1 1 2]) 0)
                       [(rnd st % (w + 1)) (? (o = 0) (rnd st % (w // 2 + 1)) (32768 * (1 + rnd st % 4)))
                        o (rnd st % (w // 3 + 1)) 0])
   (rand-settings st)
    (: hs ((40 + rnd st % 360) * pt)
       s [['set 'hsize hs] ['set 'parindent (rnd st % (25 * pt))]
          ['set 'pretolerance (pick st [-1 100 100 200 1000 0])]
          ['set 'tolerance (pick st [200 200 500 1000 10000 100 5000])]
          ['set 'emergencystretch (? (chance st 3) (rnd st % (40 * pt)) 0)]
          ['set 'linepenalty (pick st [10 10 0 100 -50 5000])]
          ['set 'hyphenpenalty (pick st [50 50 0 -100 500 10000 1000])]
          ['set 'exhyphenpenalty (pick st [50 50 0 1000 10000])]
          ['set 'adjdemerits (pick st [10000 0 100000 1073741823])]
          ['set 'doublehyphendemerits (pick st [10000 0 1000000])]
          ['set 'finalhyphendemerits (pick st [5000 0 100000])]
          ['set 'interlinepenalty (pick st [0 0 100 -50])]
          ['set 'clubpenalty (pick st [150 0 10000 -20])]
          ['set 'widowpenalty (pick st [150 0 10000 300])]
          ['set 'brokenpenalty (pick st [100 0 500])]
          ['set 'lefthyphenmin (pick st [2 2 1 3 0 5 70])]
          ['set 'righthyphenmin (pick st [3 3 1 2 4 0])]
          ['set 'uchyph (pick st [1 0 -1])]
          ['set 'baselineskip [((8 + rnd st % 8) * pt) (? (chance st 3) pt 0) 0 0 0]]
          ['set 'lineskip [(rnd st % (2 * pt)) 0 0 0 0]]
          ['set 'lineskiplimit (rnd st % (3 * pt) - pt)]
          ['set 'parskip (rand-glue st (4 * pt))]
          ['set 'leftskip (? (chance st 3) (rand-glue st (20 * pt)) [0 0 0 0 0])]
          ['set 'rightskip (? (chance st 3) (rand-glue st (20 * pt)) [0 0 0 0 0])]
          ['set 'parfillskip (pick st [[0 65536 1 0 0] [0 65536 1 0 0] [0 0 0 0 0] [(10 * pt) (20 * pt) 0 0 0]])]
          ['set 'spaceskip (? (chance st 4) (rand-glue st (6 * pt)) [0 0 0 0 0])]
          ['set 'xspaceskip (? (chance st 4) (rand-glue st (8 * pt)) [0 0 0 0 0])]
          ['set 'overfullrule (pick st [0 0 (5 * pt)])]]
       s)
   (rand-word st)
    (: w (? (chance st 4) (cats (map (_ \ string (pick st letters)) ^(1 + rnd st % 10))) (pick st vocab))
       w2 (? (chance st 8) (: u (w 0) (? (97 <= u && u <= 122) (string (u - 32) + snip w 1 #w) w)) w)
       p (pick st prefixes) x (pick st suffixes)
       (str-toks p + word-toks w2 (chance st 12) + str-toks x))
   ; a box in a paragraph or between them: its own words, spaces, a stretch, maybe a hyphen
   (rand-hbox st)
    (: n (1 + rnd st % 4)
       body (cats (map (_ \ rand-word st + (pick st [['sp] ['sp] [['skip 0 65536 1 65536 1]] ['dash] [['c 45]]])) ^n))
       ['hbox (pick st [() () (rnd st % (200 * pt)) (rnd st % (20 * pt))]) (? (chance st 3) (['f (1 + rnd st % 7)] . body) body)])
   (rand-vert st)
    (: k (rnd st % 6)
       (? (k = 0) [('vskip . rand-glue st (8 * pt))]
          (k = 1) [['pen (pick st [-10000 0 150 10000 -50])]]
          (k = 2) [['hrule (pick st [() (rnd st % (100 * pt))]) (rnd st % pt) (rnd st % (pt // 2))]]
          (k = 3) [(rand-hbox st)]
          (k = 4) [['vskip (rnd st % (3 * pt)) 0 0 0 0] (rand-hbox st)]
          []))
   (rand-between st)
    (: k (rnd st % 42)
       (? (k < 30) ['sp] (k = 30) ['xsp] (k = 31) [['pen (rnd st % 400 - 150)] 'sp]
          (k = 32) [['kern (rnd st % (3 * pt) - pt)]]
          (k = 33) [['skip (rnd st % (6 * pt)) (rnd st % (3 * pt)) 0 (rnd st % pt) 0]]
          (k = 34) ['sp ['f (1 + rnd st % 7)]]
          (k = 35) ['sp 'nb]
          (k = 36) [['rule (rnd st % pt) (rnd st % (8 * pt)) (rnd st % (2 * pt))]]
          (k = 37) [['pen -10000]]
          (k = 38) ['sp (rand-hbox st) 'sp]
          (k = 39) [(rand-hbox st)]
          (k = 40) ['sp ['vskip (rnd st % (4 * pt)) 0 0 0 0] 'noindent]
          ['sp]))
   (rand-para st)
    (: n (5 + rnd st % 90)
       per (pick st [[] [] [] [['set 'looseness (pick st [1 -1 2])]]
                     [['set 'hangindent (rnd st % (60 * pt) - 30 * pt)] ['set 'hangafter (rnd st % 5 - 2)]]
                     [['set 'parshape (map (_ \ [(rnd st % (30 * pt)) ((30 + rnd st % 250) * pt)]) ^(1 + rnd st % 4))]]])
       (go k acc) (? (k >= n) acc (go (k + 1) (acc + rand-word st + (? (k < n - 1) (rand-between st) []))))
       (rand-vert st + per + [(pick st ['indent 'indent 'noindent])] + go 0 [] + ['par]))
   (rand-page st)
    (: np (1 + rnd st % 3)
       (['f (1 + rnd st % 7)] . plain + rand-settings st + cats (map (_ \ rand-para st) ^np)))
   (hyph-chars st) (map (_ \ pick st [45 45 45 -1 127 256]) ^#fonts)

   ; CAJA_PAGE=k keeps page k alone, and says its lines as TeX's \showbox would, roughly
   (pscaled s0)
    (: a (abs s0)
       (go s d acc) (: s1 (? (d > 65536) (s + 32768 - 50000) s)
                       acc2 (acc + string (48 + s1 // 65536))
                       s2 (10 * (s1 % 65536))
                       (? (s2 <= d * 10) acc2 (go s2 (d * 10) acc2)))
       ((? (s0 < 0) "-" "") + show (a // 65536) + "." + go (10 * (a % 65536) + 5) 10 ""))
   (glue-str g) (: (o v k) (? (k = 0) (pscaled v) (pscaled v + ["" "fil" "fill" "filll"] k))
                   ("glue " + pscaled (g 'width)
                    + (? (g 'stretch != 0) (" plus " + o (g 'stretch) (g 'sto)) "")
                    + (? (g 'shrink != 0) (" minus " + o (g 'shrink) (g 'sho)) "")))
   (dump l)
    (? (l != ())
       (: _ (? (l 'type = 0)
               (: _ (say err ("hbox(" + pscaled (l 'height) + "+" + pscaled (l 'depth) + ")x" + pscaled (l 'width)
                               + " set " + show (l 'gsign) + " " + show (l 'gset) + " " + show (l 'gorder) + "\n"))
                  (go n) (? (n != ())
                            (: _ (? (n 'type = 10) (say err (". " + glue-str (n 'glue) + "\n"))
                                    (n 'type = 'char || n 'type = 6) (say err (". " + string (n 'char) + "\n"))
                                    (n 'type = 7) (say err (". disc " + show (n 'sub) + "\n"))
                                    (n 'type = 11) (say err (". kern " + pscaled (n 'width) + "\n")))
                               (go (n 'link))))
                  (go (l 'list)))
               (l 'type = 10) (say err ("glue " + glue-str (l 'glue) + "\n"))
               (l 'type = 12) (say err ("penalty " + show (l 'penalty) + "\n")))
          (dump (l 'link))))

   (main args)
    (: out (args 0) st {'s (read (args 1))} n (read (args 2))
       hyph (slurpf (args 3))
       only (getenv "CAJA_PAGE")
       one? (string? only && 0 < #only)
       ; a page is [tokens hyphenchars split]: split () ships the vbox, else [h topskip maxdepth]
       ; builds it in box 0 and ships \vsplit0 to h until the box is void
       pages0 (map (p \ [p (map (_ \ 45) ^#fonts) ()]) fixed
              + map (_ \ (: p (rand-page st) hc (hyph-chars st)
                            sp (? (chance st 3) [((30 + rnd st % 300) * pt) (rand-glue st (15 * pt)) (rnd st % (6 * pt) - pt)] ())
                            [p hc sp]))
                    ^n)
       pages (? one? [(pages0 (read only))] pages0)
       J (cp-setup (cb-job 0))
       _ (map (e \ pin (J 'sf) (e 0) (e 1)) sfcodes)
       _ (cp-hyphen-file J hyph)
       fm (: m {} (go k) (? (k < #fonts)
                              (: e (fonts k) f (cb-font J (e 0) "" (slurpf (args (4 + k))) (e 1))
                                 _ (? (f = 'badtfm) (die ("font " + (e 0))))
                                 _ (pin m (k + 1) f) (go (k + 1)))
                              m)
             (go 0))
       _ (map (k \ cb-set-param J k ({'year 1776 'month 7 'day 4 'time 720} k)) ['year 'month 'day 'time])
       base (: t {} _ (map (k \ pin t k (J 'params k)) (keys (J 'params))) t)
       tex ("\\catcode`\\{=1 \\catcode`\\}=2 \\batchmode\\year=1776 \\month=7 \\day=4 \\time=720\n"
            + "\\def\\sp{ }\\input " + args 3 + "\n\\defaulthyphenchar=45\n"
            + "\\def\\pages{\\ifvoid0 \\else\\setbox1\\vsplit0 to\\dimen0 \\shipout\\box1 \\expandafter\\pages\\fi}\n"
            + cats (map (k \ (: e (fonts k) sz (e 1)
                                ("\\font" + fname (k + 1) + "=" + (e 0)
                                 + (? (sz = -1000) "" (" at " + show sz + "sp")) + "\\relax\n")))
                        ^#fonts)
            + cats (map (e \ "\\sfcode" + show (e 0) + "=" + show (e 1) + "\\relax\n") sfcodes)
            + cats (map (pg \ cats (map (k \ "\\hyphenchar" + fname (k + 1) + "=" + show (pg 1 k) + "\\relax ") ^#fonts)
                              + (: sp (pg 2)
                                   (? (sp != ())
                                      ("\n\\setbox0\\vbox{" + cp-tex (pg 0) + "}"
                                       + cp-tex [['set 'splittopskip (sp 1)] ['set 'splitmaxdepth (sp 2)]]
                                       + "\\dimen0=" + show (sp 0) + "sp\\relax\\pages\n")
                                      one? ("\n\\showboxdepth=100 \\showboxbreadth=1000000 \\setbox1\\vbox{"
                                            + cp-tex (pg 0) + "}\\showbox1 \\shipout\\box1\n")
                                      ("\n\\shipout\\vbox{" + cp-tex (pg 0) + "}\n"))))
                        pages)
            + "\\end\n")
       _ (spit (out + ".tex") tex)
       _ (map (pg \ (: _ (map (k \ pin (J 'params) k (base k)) (keys base))
                       _ (map (k \ pin (J 'fonts (fm (k + 1))) 'hyphenchar (pg 1 k)) ^#fonts)
                       M (cp-run J (cp-mode J) (pg 0))
                       l (cp-vlist J M)
                       _ (? one? (dump l))
                       b (cb-vpackage J l 0 'additional 0)
                       sp (pg 2)
                       (? (sp = ()) (cb-ship J b)
                          (: _ (cp-run J M [['set 'splittopskip (sp 1)] ['set 'splitmaxdepth (sp 2)]])
                             (go v) (? (v != ()) (: r (cg-vsplit J v (sp 0)) _ (cb-ship J <r) (go (r 1))))
                             (go (cp-node J b))))))
              pages)
       (spit (out + ".dvi") (cb-dvi J)))
   (main >argv))
