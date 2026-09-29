; test/caja/boxes.l -- src/apps/caja/box.l held to TeX, a box at a time. a page is described
; once, as data, and said two ways: as plain -ini TeX input, and as caja's nodes. the
; shell (test/gate/caja.sh) runs TeX on the one and compares its DVI with the other's.
;
;   love test/caja/boxes.l OUT SEED N   OUT.tex and OUT.dvi: the fixed pages, then N more
;                                       drawn from SEED
;
; the forms, sizes in sp, stretch and shrink orders 0 (sp) .. 3 (filll):
;   ['c font code]              a character
;   ['k w]                      a kern
;   ['g w st sto sh sho]        glue
;   ['r w h d]                  a rule, () for a running dimension
;   ['h shift spec items]       an hbox; spec ['to w] | ['spread w] | ()
;   ['v shift spec items]       a vbox
;   ['l kind box g]             leaders: kind 100 \leaders 101 \cleaders 102 \xleaders
; characters stand apart (\relax and \noboundary about each), and each box in a vbox follows \prevdepth
; -1000pt, so TeX adds neither ligatures, kerns nor interline glue caja has not been told.
(: _ (borrow 'posix)
   _ (borrow "src/apps/tfm.l")
   _ (borrow "src/apps/caja/box.l")
   _ (borrow 'caja-box)
   (die m) (: _ (say err ("boxes: " + m + "\n")) _ (flush err) (quit 1))
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (spit p s) (: q (open p "w") (? (hot? q) (: _ (say q s) (close q)) (die ("cannot write " + p))))

   ; the fonts: TeX name, and size (-1000 the design size, else sp)
   fonts [["cmr10" -1000] ["cmbx12" -1000] ["cmr10" 478413] ["cmtt10" 1310720] ["cmsl9" -1000]
          ["ecrm1000" -1000]]
   (fname k) ("\\f" + string (97 + k))
   (tex-fonts _) (cats (map (k \ (: e (fonts k) sz (e 1)
                                    ("\\font" + fname k + "=" + (e 0)
                                     + (? (sz = -1000) "" (" at " + show sz + "sp")) + "\\relax\n")))
                             ^#fonts))

   ; --- the TeX side ---------------------------------------------------------------------
   (units o) (["sp" "fil" "fill" "filll"] o)
   ; a fil amount is written as a decimal of 65536ths; the generator keeps it exact
   (amt v o) (? (o = 0) (show v + "sp")
                (: whole (v // 65536) frac (v % 65536)
                   (? (frac = 0) (show whole + units o) (show whole + ".5" + units o))))
   (spec-tex sp) (? (!(two? sp)) "" (sp 0 = 'to) (" to " + show (sp 1) + "sp") (" spread " + show (sp 1) + "sp"))
   (dim-tex nm v) (? (v = ()) "" (" " + nm + " " + show v + "sp"))
   (item-tex mode it)                         ; mode 'h or 'v, the list the item stands in
    (it 0 @
     'c ("\\relax" + fname (it 1) + "\\noboundary\\char" + show (it 2) + "\\noboundary\\relax")
     'k ("\\kern" + show (it 1) + "sp\\relax")
     'g ((? (mode = 'h) "\\hskip" "\\vskip") + show (it 1) + "sp plus " + amt (it 2) (it 3)
         + " minus " + amt (it 4) (it 5) + "\\relax")
     'r ((? (mode = 'h) "\\vrule" "\\hrule") + dim-tex "width" (it 1) + dim-tex "height" (it 2)
         + dim-tex "depth" (it 3) + "\\relax")
     'l (["\\leaders" "\\cleaders" "\\xleaders"] (it 1 - 100) + box-tex mode (it 2) + item-tex mode (it 3))
     ('h || 'v) (box-tex mode it)
     (die ("no form " + show it)))
   ; a box, placed in a list of the given mode (a shift is \lower in an hlist, \moveright in a vlist)
   (box-tex mode it)
    (: kind (it 0)
       sh (it 1)
       body (cats (map (x \ (? (kind = 'v && elem (x 0) ['h 'v]) "\\prevdepth=-1000pt\\relax" "")
                            + item-tex kind x) (it 3)))
       b ((? (kind = 'h) "\\hbox" "\\vbox") + spec-tex (it 2) + "{" + body + "}")
       (? (it 0 = 'r) (item-tex mode it)
          (sh = 0) b
          (mode = 'h) ("\\lower" + show sh + "sp" + b)
          ("\\moveright" + show sh + "sp" + b)))

   ; --- the caja side --------------------------------------------------------------------
   (item-node J it)
    (it 0 @
     'c (cb-char J (J 'fmap (it 1)) (it 2))
     'k (: k (cb-kern (it 1)) _ (pin k 'sub 1) k)
     'g (cb-glue (it 1) (it 2) (it 3) (it 4) (it 5))
     'r (cb-rule (? (it 1 = ()) -1073741824 (it 1)) (? (it 2 = ()) -1073741824 (it 2))
                 (? (it 3 = ()) -1073741824 (it 3)))
     'l (cb-leaders (it 1) (item-node J (it 2)) (item-node J (it 3)))
     ('h || 'v) (box-node J it)
     (die ("no form " + show it)))
   (box-node J it)
    (: l (cb-list (map (item-node J) (it 3)))
       sp (it 2)
       m (? (two? sp) (? (sp 0 = 'to) 'exactly 'additional) 'additional)
       w (? (two? sp) (sp 1) 0)
       ; -ini TeX's \boxmaxdepth is 0: a vbox's depth goes into its height
       b (? (it 0 = 'h) (cb-hpack J l w m) (cb-vpackage J l w m 0))
       _ (pin b 'shift (it 1))
       b)

   ; --- the pages ------------------------------------------------------------------------
   ab ['c 0 65] ; a few pieces the fixed pages share
   fixed
    [['h 0 () [['c 0 65] ['c 0 86] ['c 0 97] ['c 0 121]]]
     ['h 0 () [['c 1 72] ['k 20000] ['c 0 105] ['g 200000 0 0 0 0] ['c 2 106] ['r 30000 () ()]]]
     ['h 0 ['to 3000000] [['c 0 65] ['g 100000 50000 0 20000 0] ['c 0 66] ['g 100000 70000 0 0 0] ['c 0 67]]]
     ['h 0 ['to 1000000] [['c 0 65] ['g 400000 0 0 90000 0] ['c 0 66] ['g 400000 0 0 30000 0] ['c 0 67]]]
     ['h 0 ['to 4000000] [['c 0 65] ['g 0 65536 1 0 0] ['c 0 66] ['g 0 131072 1 0 0] ['c 3 67] ['g 0 65536 2 0 0]]]
     ['h 0 ['spread 777777] [['c 4 97] ['g 12345 111 0 7 0] ['c 4 98] ['g 23456 222 0 9 0] ['c 4 99]]]
     ['v 0 () [['h 0 () [['c 0 65]]] ['g 300000 0 0 0 0] ['h 150000 () [['c 0 66]]] ['k 99999]
               ['r () 20000 0] ['h 0 () [['c 0 67]]]]]
     ['v 0 ['to 9000000] [['h 0 () [['c 0 65]]] ['g 100000 65536 1 0 0] ['h 0 () [['c 0 66]]]
                          ['g 100000 131072 1 0 0] ['h 0 () [['c 0 67]]]]]
     ['h 0 () [['h 50000 () [['c 0 97]]] ['v 0 () [['h 0 () [['c 0 98]]] ['h 0 () [['c 0 99]]]]]
               ['h -80000 () [['c 1 100]]]]]
     ['h 0 ['to 5000000] [['c 0 65] ['l 100 ['r () 20000 0] ['g 0 65536 1 0 0]] ['c 0 66]]]
     ['h 0 ['to 5000000] [['c 0 65] ['l 100 ['h 0 () [['c 0 46] ['k 100000]]] ['g 0 65536 1 0 0]] ['c 0 66]]]
     ['h 0 ['to 5000000] [['c 0 65] ['l 101 ['h 0 () [['c 0 46] ['k 100000]]] ['g 0 65536 1 0 0]] ['c 0 66]]]
     ['h 0 ['to 5000000] [['c 0 65] ['l 102 ['h 0 () [['c 0 46] ['k 100000]]] ['g 0 65536 1 0 0]] ['c 0 66]]]
     ['v 0 ['to 6000000] [['h 0 () [['c 0 65]]] ['l 100 ['h 0 () [['c 0 46]]] ['g 0 65536 1 0 0]]
                          ['l 102 ['v 0 () [['h 0 () [['c 0 45]]]]] ['g 0 65536 1 0 0]] ['h 0 () [['c 0 66]]]]]
     ['v 0 () (map (k \ ['h (k % 3 * 40000) () [['c 0 (65 + k % 26)] ['g (k % 4 * 70000) 0 0 0 0] ['c 0 97]]]) ^40)]
     ['h 0 () [['c 0 200] ['c 0 127] ['c 0 0] ['c 1 128]]]
     ['h 0 () (map (k \ ['c 5 (128 + k * 9)]) ^14)]]

   ; --- random pages: a small grammar, drawn from a seeded stream --------------------------
   (rnd st) (: x ((st 's * 1103515245 + 12345) % 2147483648) _ (pin st 's x) (x // 16))
   (pick st l) (l (rnd st % #l))
   (rand-item st mode depth)
    (: k (rnd st % (? (depth > 2) 5 7))
       (? (k = 0 || (k = 1 && mode = 'h)) (? (mode = 'h) ['c (rnd st % 2) (65 + rnd st % 26)] ['k (rnd st % 200000)])
          (k = 1) ['k (rnd st % 200000 - 50000)]
          (k = 2) (: o (pick st [0 0 0 1 2]) ['g (rnd st % 300000) (? (o = 0) (rnd st % 100000) (65536 * (1 + rnd st % 3))) o
                                              (rnd st % 50000) 0])
          (k = 3) (? (mode = 'h) ['r (rnd st % 50000) () ()] ['r () (rnd st % 40000) 0])
          (k = 4) ['k (rnd st % 100000)]
          (k = 5) (rand-box st 'h (depth + 1))
          (rand-box st 'v (depth + 1))))
   (rand-box st kind depth)
    (: n (1 + rnd st % 5)
       items (map (_ \ rand-item st kind depth) ^n)
       items2 (? (kind = 'v) (map (x \ (? (x 0 = 'c) ['h 0 () [x]] x)) items) items)
       sp (pick st [() () ['to (rnd st % 4000000)] ['spread (rnd st % 400000 - 100000)]])
       [kind (? (depth = 0) 0 (rnd st % 100000 - 30000)) sp items2])

   (main args)
    (: out (args 0) st {'s (read (args 1))} n (read (args 2))
       pages (fixed + map (_ \ rand-box st (pick st ['h 'v]) 0) ^n)
       J (cb-job 0)
       ; the fonts, loaded as TeX loads them, from the files kpathsea finds
       _ (pin J 'fmap (: m {} (go k) (? (k < #fonts)
                                         (: e (fonts k) p (args (3 + k))
                                            f (cb-font J (e 0) "" (slurpf p) (e 1))
                                            _ (? (f = 'badtfm) (die ("font " + p)))
                                            _ (pin m k f) (go (k + 1)))
                                         m)
                          (go 0)))
       _ (map (k \ cb-set-param J k ({'year 1776 'month 7 'day 4 'time 720} k)) ['year 'month 'day 'time])
       tex ("\\catcode`\\{=1 \\catcode`\\}=2 \\batchmode\\year=1776 \\month=7 \\day=4 \\time=720\n"
            + tex-fonts 0
            + cats (map (pg \ "\\shipout" + box-tex 'v pg + "\n") pages) + "\\end\n")
       _ (spit (out + ".tex") tex)
       _ (map (pg \ cb-ship J (box-node J pg)) pages)
       (spit (out + ".dvi") (cb-dvi J)))
   (main >argv))
