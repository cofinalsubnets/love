; test/gate/tfm.l -- src/apps/tfm.l's half of test/gate/tfm.sh. one process walks a list of
; TFM files (one path a line) and writes what the shell holds to TeX Live's own programs:
;
;   pl LIST DIR           DIR/<k>.pl and DIR/<k>.msg, tfm-pl's text for the k-th file
;   read LIST SIZE OUT    OUT: every file loaded at SIZE, as the lines tfm.sh's TeX writes
;   tex LIST SIZE OUT     OUT: that TeX input -- \font each file, write its dimensions
;   fuzz LIST DIR SEED N  DIR/fz<k>.tfm: N copies of the files, a few bytes hit in each
;
; the read lines are e-TeX's: \fontdimen 1..np, then \fontcharwd/ht/dp/ic for codes 0..255,
; which answer a code's dimensions whenever it lies in bc..ec, extant or not.
(: _ (borrow 'posix)
   _ (borrow "src/apps/tfm.l")
   (die m) (say err ("tfm.l: " + m + "\n"), flush err, quit 1)
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (spit p s) (open p "w" @ q (hot? q ? (say q s, close q) (die ("cannot write " + p))))
   (paths l) (filter (p \ 0 < #p) (lines (slurpf l)))
   (np s) (24 <= #s ? (256 * s 22 + s 23) 0)
   (upto a b) (map (+ a) ^(max 0 (b - a + 1)))

   (read-lines k s sz)
    (: r (tfm-read s sz) tag ("F" + show k)
       (r = 'badtfm ? (tag + ":BAD\n")
        (: (dim t c j) (r 'bc <= c && c <= r 'ec ?
                          (: q (r 'ci c) i (? (j = 0) <q (j = 1) (<>q // 16) (j = 2) (<>q % 16) (<>>q // 4))
                             (t i))
                          0)
           (tag + "\n"
            + cats (map (i \ "P" + show i + ":" + show (r 'param i) + "\n") (upto 1 (np s)))
            + cats (map (c \ "C" + show c + ":" + show (dim (r 'wd) c 0) + "," + show (dim (r 'ht) c 1)
                              + "," + show (dim (r 'dp) c 2) + "," + show (dim (r 'ic) c 3) + "\n") ^256)))))

   ; the same, asked of TeX: \ifx after a refused \font finds \nullfont. a \par per font
   ; keeps a run of refusals under TeX's hundred-error stop
   (tex-for k p s spec)
    (: n (np s) tag ("F" + show k)
       nm (4 < #p && snip p (#p - 4) #p = ".tfm" ? (snip p 0 (#p - 4)) p)
       ("\\font\\f=" + nm + spec + "\\relax\\ifx\\f\\nullfont\\immediate\\write16{" + tag + ":BAD}\\else"
        + "\\immediate\\write16{" + tag + "}"
        + (0 < n ? ("\\count1=1 \\def\\p{\\immediate\\write16{P\\the\\count1:\\number\\fontdimen\\count1\\f}"
                    + "\\ifnum\\count1<" + show n + " \\advance\\count1 1 \\expandafter\\p\\fi}\\p") "")
        + "\\count1=0 \\c\\fi\\par\n"))
   tex-head ("\\catcode`\\{=1 \\catcode`\\}=2 \\catcode`\\#=6 \\batchmode\n"
             + "\\def\\c{\\immediate\\write16{C\\the\\count1:\\number\\fontcharwd\\f\\count1,"
             + "\\number\\fontcharht\\f\\count1,\\number\\fontchardp\\f\\count1,\\number\\fontcharic\\f\\count1}"
             + "\\ifnum\\count1<255 \\advance\\count1 1 \\expandafter\\c\\fi}\n")
   (spec sz) (? (sz = -1000) "" (sz < 0) (" scaled " + show (0 - sz)) (" at " + show sz + "sp"))

   ; a hit: one to four bytes set to a value a TFM reader has to think about
   (fuzz-one s x)
    (: (rnd x) ((x * 1103515245 + 12345) % 2147483648)
       vals [0 1 2 3 4 7 8 11 127 128 129 254 255]
       (hit b x m) (m < 1 ? x
                    (: x1 (rnd x) x2 (rnd x1) x3 (rnd x2)
                       i (x1 % 3 = 0 ? (x2 % 24) (x2 % #b))
                       v (x3 % 4 = 0 ? (x3 // 7 % 256) (vals (x3 // 7 % #vals)))
                       (pin b i v,
                        hit b x3 (m - 1))))
       b (cask #s) _ (pour b 0 s 0 #s)
       x1 (rnd x)
       x2 (hit b x1 (1 + x1 // 5 % 4))
       [(string b) x2])

   (main args)
    (: md (args 0) l (args 1)
       (? (md = "pl")
          (: d (args 2) ps (paths l)
             (go k ps) (two? ps ?
                          (tfm-pl (slurpf <ps) @ r
                           (spit (d + "/" + show k + ".pl") <r,
                            spit (d + "/" + show k + ".msg") <>r,
                            go (k + 1) >ps)))
             (go 0 ps))
          (md = "read")
          (: sz (read (args 2)) ps (paths l)
             (spit (args 3) (cats (map (k \ read-lines k (slurpf (ps k)) sz) ^#ps))))
          (md = "tex")
          (: sz (read (args 2)) ps (paths l)
             (spit (args 3) (tex-head + cats (map (k \ tex-for k (ps k) (slurpf (ps k)) (spec sz)) ^#ps) + "\\end\n")))
          (md = "fuzz")
          (: ps (paths l) d (args 2) cnt (read (args 4))
             (go k x) (k < cnt ?
                         (fuzz-one (slurpf (ps (x % #ps))) x @ r
                          (spit (d + "/fz" + show k + ".tfm") <r,
                           go (k + 1) <>r)))
             (go 0 (read (args 3))))
          (die "usage: pl LIST DIR | read LIST SIZE OUT | tex LIST SIZE OUT | fuzz LIST DIR SEED N")))
   (main >argv))
