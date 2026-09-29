; apps/caja/doc.l -- lapiz under caja: a document's blocks set as pages, a DVI.
; `(borrow 'caja-doc)`. lapiz reads markdown, html and roff into one middle (apps/lapiz.l);
; this shower lays that middle out as caja tokens, in Computer Modern at plain TeX's sizes:
;
;   cd-fonts                  the TFM names, in the order cd-job wants their bytes
;   (cd-job tfms hyph date)   a job: tfms the TFM files' bytes, hyph a file like hyphen.tex,
;                             date [year month day minutes] for the DVI's comment
;   (cd-tokens J doc)         the document as tokens (apps/caja/par.l), a vbox's contents;
;                             J measures table cells
;   (cd-dvi J doc)            the document as a DVI: one vbox, \vsplit into pages, each page
;                             shipped with its number centred under it
;   (cd-tex J doc hyph)       the same document as -ini TeX, which sets the same DVI; hyph
;                             is the path TeX reads the patterns from
;
; the pages are \vsplit's, not the page builder's (that is rung 6): no marks, no inserts,
; the \vsize as it comes. text is OT1: what Computer Modern lacks is said in a near form --
; an accented letter as its base, a sign cmr does not have in typewriter type, another
; Latin-1 sign as ?, and a symbol past Latin-1 not at all.
(module (caja-doc cd-fonts cd-job cd-tokens cd-dvi cd-tex)
(borrow 'text)
(borrow 'tfm)
(borrow 'caja-box)
(borrow 'caja-par)
(borrow 'caja-page)
(:
   pt 65536
   fonts [["cmr10" -1000] ["cmbx10" -1000] ["cmti10" -1000] ["cmtt10" -1000] ["cmbx12" -1000]
          ["cmbx12" 943718] ["cmsy10" -1000]]
   cd-fonts (map (e \ e 0) fonts)
   rm 1 bf 2 it 3 tt 4 h2 5 h1 6 sy 7
   sfcodes [[46 3000] [63 3000] [33 3000] [58 2000] [59 1500] [44 1250] [41 0] [39 0] [93 0]]
   hsize (468 * pt)
   ; set outside the document's vbox: \pages reads them
   outer [['set 'hsize hsize] ['set 'vsize (648 * pt)] ['set 'splittopskip [(10 * pt) 0 0 0 0]]
          ['set 'splitmaxdepth (4 * pt)]]
   ; plain's paragraphs, looser: \tolerance 1000 and an emergency stretch, no indentation,
   ; space between paragraphs instead
   inner [['set 'pretolerance 100] ['set 'tolerance 1000] ['set 'emergencystretch (20 * pt)]
          ['set 'linepenalty 10] ['set 'hyphenpenalty 50] ['set 'exhyphenpenalty 50]
          ['set 'adjdemerits 10000] ['set 'doublehyphendemerits 10000]
          ['set 'finalhyphendemerits 5000] ['set 'clubpenalty 150] ['set 'widowpenalty 150]
          ['set 'brokenpenalty 100] ['set 'lefthyphenmin 2] ['set 'righthyphenmin 3]
          ['set 'uchyph 1] ['set 'hangafter 1] ['set 'parindent 0]
          ['set 'parskip [(6 * pt) (2 * pt) 0 pt 0]] ['set 'baselineskip [(12 * pt) 0 0 0 0]]
          ['set 'lineskip [pt 0 0 0 0]] ['set 'lineskiplimit 0] ['set 'parfillskip [0 65536 1 0 0]]]
   hss ['skip 0 65536 1 65536 1]

   (cd-job tfms hyph date)
    (: J (cp-setup (cb-job 0))
       _ (map (e \ pin (J 'sf) (e 0) (e 1)) sfcodes)
       _ (cp-hyphen-file J hyph)
       _ (map (k \ (: e (fonts k) f (cb-font J (e 0) "" (tfms k) (e 1))
                      (? (f = 'badtfm) (die ("caja: " + e 0 + ".tfm is not a TFM TeX would load")) f)))
              ^#fonts)
       _ (map (k \ pin (J 'fonts k) 'hyphenchar 45) (map (+ 1) ^#fonts))
       _ (map (i \ cb-set-param J (['year 'month 'day 'time] i) (date i)) ^4)
       J)
   (die m) (: _ (say err (m + "\n")) _ (flush err) (quit 1))

   ; --- text ----------------------------------------------------------------------------------
   ; a code point cmr has no slot for, as OT1 codes: the accented letters take their base
   near {8216 [96] 8217 [39] 8220 [96 96] 8221 [39 39] 8211 [45 45] 8212 [45 45 45]
         8230 [46 46 46] 223 [25] 230 [26] 339 [27] 248 [28] 198 [29] 338 [30] 216 [31]
         215 [120] 169 [40 67 41] 174 [40 82 41] 176 [111]}
   (base c)
    (? (192 <= c && c <= 197) 65 (c = 199) 67 (200 <= c && c <= 203) 69 (204 <= c && c <= 207) 73
       (c = 209) 78 (210 <= c && c <= 214) 79 (217 <= c && c <= 220) 85 (c = 221) 89
       (224 <= c && c <= 229) 97 (c = 231) 99 (232 <= c && c <= 235) 101 (236 <= c && c <= 239) 105
       (c = 241) 110 (242 <= c && c <= 246) 111 (249 <= c && c <= 252) 117 (c = 253 || c = 255) 121
       63)
   ; the ASCII signs cmr puts something else at: set in typewriter
   (tt-sign? c) (elem c [60 62 92 95 94 123 125 124 126])
   (space? c) (elem c [32 9 10 13 160])
   ; a string's tokens in font f: a run of spaces is one 'sp, a straight double quote opens
   ; after a space or a bracket and closes otherwise
   (text-toks f s)
    (: cs (cps s)
       (go l prev acc)
        (? (!(two? l)) (rev acc)
           (: c <l
              (? (space? c) (go >l 32 (? (prev = 32) acc ('sp . acc)))
                 (: ts (? (f = tt) (? (32 < c && c < 127) [['c c]] (c < 256) [['c 63]] [])
                          (c = 34) (? (elem prev [32 40 91 0]) [['c 96] ['c 96]] [['c 39] ['c 39]])
                          (tt-sign? c) [['f tt] ['c c] ['f f]]
                          (c < 127) [['c c]]
                          (: m (near c) (? (m != ()) (map (x \ ['c x]) m) (c < 256) [['c (base c)]] [])))
                    ; text says -- and !` as it spells them: a kern keeps cmr's ligature out
                    lig? (f != tt && ((prev = 45 && c = 45) || (c = 96 && (prev = 33 || prev = 63))))
                    (go >l c (rev ts + (? lig? (['kern 0] . acc) acc)))))))
       (go cs 0 ()))
   ; an inl's tokens in font f; a change of font comes back to f after
   (inl-toks f l)
    (cats (map (sp \ (sp 0 @
                      'text (text-toks f (sp 1))
                      'em (['f it] . inl-toks it (sp 1) + [['f f]])
                      'strong (['f bf] . inl-toks bf (sp 1) + [['f f]])
                      'code (['f tt] . text-toks tt (sp 1) + [['f f]])
                      'link (inl-toks f (sp 1))
                      'img (text-toks f ("[" + sp 1 + "]"))
                      []))
               l))

   ; --- blocks --------------------------------------------------------------------------------
   (skip w) ['vskip w 0 0 0 0]
   (glue0 w) [w 0 0 0 0]
   (para f ind l) (['set 'leftskip (glue0 ind)] . ['f f] . 'noindent . inl-toks f l + ['par])
   (head n l ind)
    (: f (? (n = 1) h1 (n = 2) h2 bf)
       ([['pen -100] (skip ((? (n = 1) 10 (n = 2) 8 4) * pt)) ['set 'rightskip [0 65536 1 0 0]]]
        + para f ind l + [['set 'rightskip (glue0 0)] ['pen 10000]]))
   ; an item: the label in a box as wide as the hanging indentation, then the text
   (item ind label l)
    (: w (20 * pt)
       ([['set 'leftskip (glue0 ind)] ['set 'hangindent w] ['f rm] 'noindent
         ['hbox w (hss . label + [['kern (5 * pt)]])]]
        + inl-toks rm l + ['par]))
   (digits n) (map (c \ ['c c]) (cps (show n)))
   (fence-line ind s)
    (: (detab cs col acc)
        (? (!(two? cs)) (rev acc)
           (<cs = 9) (: n (8 - (col % 8)) (detab >cs (col + n) (cats (map (_ \ ['xsp]) ^n) + acc)))
           (<cs = 32) (detab >cs (col + 1) ('xsp . acc))
           (detab >cs (col + 1) (? (32 < <cs && <cs < 127) (['c <cs] . acc) (['c 63] . acc))))
       ['hbox () ([['kern (ind + (10 * pt))] ['f tt]] + detab (cps s) 0 ())])
   (lines s) (: n #s
                (go i a acc) (? (i >= n) (rev (? (a < n) (snip s a n . acc) acc))
                                (s i = 10) (go (i + 1) (i + 1) (snip s a i . acc))
                                (go (i + 1) a acc))
                (go 0 0 ()))
   (cell-box J f w al toks)
    (? (al = 'r) ['hbox w (hss . toks)]
       (al = 'c) ['hbox w (hss . toks + [hss])]
       ['hbox w (toks + [hss])])
   (table J ind aligns head rows)
    (: cols #aligns
       hrow (map (c \ ['f bf] . inl-toks bf c + [['f rm]]) head)
       brows (map (r \ map (c \ inl-toks rm c) r) rows)
       (wd toks) (cp-hbox J rm () toks 'width)
       ws (map (k \ foldl max 0 (map (r \ wd (r k)) (hrow . brows))) ^cols)
       sep (12 * pt)
       (row r) ['hbox () ([['kern ind]]
                          + cats (map (k \ [(cell-box J rm (ws k) (aligns k) (r k))] + (? (k < cols - 1) [['kern sep]] []))
                                      ^cols))]
       total (+ws + sep * (cols - 1))
       ([(skip (4 * pt)) (row hrow) (skip (2 * pt)) ['hrule total 26214 0] (skip (3 * pt))]
        + map row brows + [(skip (4 * pt))]))
   (blocks J ind doc) (cats (map (b \ block J ind b) doc))
   (block J ind b)
    (b 0 @
     'meta (: kv (b 1) (get k) (: e (filter (p \ p 0 = k) kv) (? (two? e) (e 0 1) ""))
              t (get 'title) sec (get 'section)
              (? (#t = 0) [] (head 1 [['text (? (#sec = 0) t (t + "(" + sec + ")"))]] ind)))
     'head (head (b 1) (b 2) ind)
     'para (para rm ind (b 1))
     'fence (([(skip (3 * pt))] + map (fence-line ind) (lines (b 2))) + [(skip (3 * pt))])
     'quote (blocks J (ind + (20 * pt)) (b 1) + [['set 'leftskip (glue0 ind)]])
     'bullets (cats (map (l \ item ind [['f sy] ['c 15] ['f rm]] l) (b 1)))
     'numbers (: l (b 1) (cats (map (k \ item ind (digits (k + 1) + [['c 46]]) (l k)) ^#l)))
     'deflist (cats (map (e \ para bf ind (e 0) + ([['set 'hangindent (20 * pt)] ['set 'hangafter 0]]
                                                   + para rm ind (e 1)))
                         (b 1)))
     'rule [(skip (6 * pt)) ['hrule () 26214 0] (skip (6 * pt))]
     'table (table J ind (b 1) (b 2) (b 3))
     [])
   (cd-tokens J doc) (inner + blocks J 0 doc + [(skip 0) ['vskip 0 65536 1 0 0]])

   ; --- pages ---------------------------------------------------------------------------------
   (footer n) ['hbox hsize ([hss ['f rm]] + digits n + [hss])]
   (cd-dvi J doc)
    (: _ (cp-run J (cp-mode J) outer)
       ; the document's settings are its \vbox group's: restored when the box is made
       pr (J 'params) saved (: t {} _ (map (k \ pin t k (pr k)) (keys pr)) t)
       M (cp-run J (cp-mode J) (cd-tokens J doc))
       v0 (cp-node J (cb-vpackage J (cp-vlist J M) 0 'additional 0))
       _ (map (k \ pin pr k (saved k)) (keys saved))
       (go v n)
        (? (v != ())
           (: r (cg-vsplit J v (J 'params 'vsize))
              _ (pin (J 'count) 0 n)
              M2 (cp-run J (cp-mode J) [['box <r] (skip (24 * pt)) (footer n)])
              _ (cb-ship J (cb-vpackage J (cp-vlist J M2) 0 'additional 0))
              (go (r 1) (n + 1))))
       _ (go v0 1)
       (cb-dvi J))
   (cd-tex J doc hyph)
    (: d (map (k \ J 'params k) ['year 'month 'day 'time])
       ("\\catcode`\\{=1 \\catcode`\\}=2 \\batchmode\\year=" + show (d 0) + " \\month=" + show (d 1)
        + " \\day=" + show (d 2) + " \\time=" + show (d 3) + "\n"
        + "\\def\\sp{ }\\input " + hyph + "\n\\defaulthyphenchar=45\n"
        + cats (map (k \ (: e (fonts k)
                            ("\\font\\f" + string (97 + k) + "=" + (e 0)
                             + (? (e 1 = -1000) "" (" at " + show (e 1) + "sp")) + "\\relax\n")))
                    ^#fonts)
        + cats (map (e \ "\\sfcode" + show (e 0) + "=" + show (e 1) + "\\relax\n") sfcodes)
        + cp-tex outer + "\n"
        + "\\def\\pages{\\ifvoid0 \\else\\advance\\count0 by1 \\setbox1\\vsplit0 to\\vsize"
        + "\\shipout\\vbox{\\box1 \\vskip24pt\\hbox to\\hsize{\\hss\\fa\\number\\count0\\hss}}"
        + "\\expandafter\\pages\\fi}\n"
        + "\\setbox0\\vbox{" + cp-tex (cd-tokens J doc) + "}\n\\pages\\end\n")))
) ; module caja-doc
