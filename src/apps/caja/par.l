; src/apps/caja/par.l -- caja's paragraphs: characters into an hlist, the hlist into lines.
; `(borrow 'caja-par)`. tex.web's main loop (part 46, 1034-1044), paragraph starts and
; ends (47, 1091-1096), line_break (parts 38-39) and hyphenation (40-43), section for
; section:
;
;   (cp-setup J)              -ini TeX's codes and parameters, on a job from cb-job
;   (cp-patterns J s)         the words of a \patterns{..} body
;   (cp-hyphenation J s)      the words of a \hyphenation{..} body
;   (cp-hyphen-file J s)      both, out of a file like hyphen.tex
;   (cp-mode J)               an empty internal vertical list, as \vbox{ opens one
;   (cp-run J M toks)         the tokens, in order (below); answers M
;   (cp-vlist J M)            ends a paragraph still open; the vlist's first node
;   (cp-hbox J f w toks)      \hbox{..} in font f, to w or natural (w ()); the box
;   (cp-tex toks)             the tokens as -ini TeX says them, the font k as \f and a letter
;   (cp-node J n)             n with an 'id, for a node made outside
;
; a token: ['c code] a character in the current font, 'sp a space, 'xsp a control space,
; ['f k] a font, ['pen n] (either mode), ['kern w] an explicit kern, ['skip glue] and
; ['vskip glue], 'dash for \-, ['rule w h d] a \vrule, ['hrule w h d] (a running width ()),
; ['hbox w toks], ['box b] a box node made already (from cp-node; cp-tex cannot say it), 'nb
; \noboundary, 'indent, 'noindent, 'par, ['set k v] a parameter. a glue is w st sto sh sho,
; flat after the head or as a list in 'set.
; nodes are box.l's; each carries an 'id, for where tex.web compares pointers.
(module (caja-par cp-setup cp-patterns cp-hyphenation cp-hyphen-file cp-mode cp-run cp-vlist
         cp-hbox cp-tex cp-node cp-spec)
(borrow 'tfm)
(borrow 'caja-box)
(:
   non 256                                    ; non_char
   awful 1073741823                           ; awful_bad
   maxhw 268435455                            ; TeX Live's max_halfword
   ignore-depth -65536000
   z7 (0 * iota 7)                            ; tex.web's six-word width arrays, as trays

   ; --- the job's codes and parameters ------------------------------------------------
   (cp-spec w st sto sh sho) {'width w 'stretch st 'sto sto 'shrink sh 'sho sho}
   (cp-setup J)
    (: lc {} sf {}
       _ (map (c \ (pin lc c (? (97 <= c && c <= 122) c (65 <= c && c <= 90) (c + 32) 0),
                    pin sf c (65 <= c && c <= 90 ? 999 1000))) ^256)
       pr (J 'params)
       (map (kv \ pin pr (kv 0) (kv 1))
            [['pretolerance 0] ['tolerance 10000] ['looseness 0] ['emergencystretch 0]
             ['hsize 0] ['hangindent 0] ['hangafter 1] ['parshape ()] ['parindent 0]
             ['linepenalty 0] ['hyphenpenalty 0] ['exhyphenpenalty 0] ['adjdemerits 0]
             ['doublehyphendemerits 0] ['finalhyphendemerits 0] ['interlinepenalty 0]
             ['clubpenalty 0] ['widowpenalty 0] ['brokenpenalty 0] ['lefthyphenmin 0]
             ['righthyphenmin 0] ['uchyph 0] ['language 0] ['lineskiplimit 0]
             ['leftskip ()] ['rightskip ()] ['parfillskip ()] ['baselineskip ()]
             ['lineskip ()] ['parskip ()] ['spaceskip ()] ['xspaceskip ()]],
        pin J 'lc lc, pin J 'sf sf,
        pin J 'pats {}, pin J 'pref {}, pin J 'langs {}, pin J 'exc {},
        pin J 'nid 0, pin J 'lp 0, pin J 'lft 0, pin J 'rt 0, pin J 'cbd 0,
        pin J 'insd 0,
        J))
   (P J k) (J 'params k)
   (zero? g) (g = () || g 'width = 0 && g 'stretch = 0 && g 'shrink = 0)
   (spec-of g) (g = () ? (cp-spec 0 0 0 0 0) g)

   ; --- nodes ---------------------------------------------------------------------------
   (nd J n) (pin J 'nid (J 'nid + 1), pin n 'id (J 'nid), n)
   (cp-node J n) (nd J n)
   (same? a b) (a != () && b != () && a 'id = b 'id)
   (char? n) (n != () && n 'type = 'char)
   (charnode J f c) (nd J {'type 'char 'font f 'char c 'link ()})
   (lignode J f c l) (nd J {'type 6 'sub 0 'font f 'char c 'lig l 'link ()})
   (kernnode J w s) (nd J {'type 11 'sub s 'width w 'link ()})
   (pennode J n) (nd J {'type 12 'sub 0 'penalty n 'link ()})
   (discnode J) (nd J {'type 7 'sub 0 'pre () 'post () 'link ()})
   (gluenode J g s) (nd J {'type 10 'sub s 'glue (spec-of g) 'leader () 'link ()})
   (to-end n) (n 'link = () ? n (to-end (n 'link)))
   ; the character field as tex.web reads it off any node: a non-character's subtype
   (charfield n) (char? n ? (n 'char) (n 'sub))

   ; --- fonts -----------------------------------------------------------------------------
   (tf J f) (J 'fonts f 'tfm)
   (ci J f c) (tf J f 'ci c)
   (exists J f c) (tf J f @ t (t 'bc <= c && c <= t 'ec && 0 < <(t 'ci c)))
   (cw J f c) (tf J f @ t (t 'wd <(t 'ci c)))
   (tag q) (q 2 % 4)
   (lk J f k) (tf J f 'lig k)
   (kn J f j) (tf J f 'kern (256 * (j 2 - 128) + j 3))
   (hychar J f) (peep (J 'fonts f) 'hyphenchar -1)
   (fparam J f k) (peep (tf J f 'param) k 0)
   (warn J f c) (pin J 'missing ([f c] . J 'missing))
   ; a width as line_break takes one: characters, ligatures, boxes, rules, kerns
   (wd J n) (char? n || n 'type = 6 ? (cw J (n 'font) (n 'char)) (n 'width))

   ; --- the lists of a mode: 'head a sentinel node, 'tail the last -------------------------
   (cp-mode J)
    (nd J {'type 'head 'link ()} @ v
       {'mode 'v 'vhead v 'vtail v 'pd ignore-depth 'vpg 0 'font 0 'hhead () 'tail () 'sf 1000
        'hpg 0 'restricted 0})
   (tail-append M n) (pin (M 'tail) 'link n, pin M 'tail n)
   (vappend M n) (pin (M 'vtail) 'link n, pin M 'vtail n)

   ; --- the main loop: a run of characters, ligatures and kerns (tex.web 1034-1040) --------
   (adjust-sf J M c)
    (J 'sf c @ s
       (? (s = 1000) (pin M 'sf 1000)
          (s < 1000) (s > 0 ? (pin M 'sf s))
          (M 'sf < 1000) (pin M 'sf 1000)
          (pin M 'sf s)))
   (ctok? t) (two? t && t 0 = 'c)
   ; the run starts at the character token first in toks; answers the tokens left
   (main-loop J M toks)
    (tf J (M 'font) 'nl = 0 ? (plain-run J M toks) (lig-run J M toks))
   ; a font with no lig/kern program has no boundary either, and the loop comes down to
   ; this: each character its node, a hyphen character a discretionary after it
   (plain-run J M toks)
    (: f (M 'font) t (tf J f) ci (t 'ci) hc (hychar J f)
       _ (pin J 'cbd 0)
       (go ts)
        (? (!(two? ts && ctok? <ts)) ts
           (<ts 1 @ c
              (adjust-sf J M c,
               t 'bc <= c && c <= t 'ec && 0 < <(ci c) ?
                 (tail-append M (charnode J f c),
                  (? (c = hc && !(M 'restricted)) (tail-append M (discnode J))),
                  go >ts)
                 (warn J f c, >ts))))
       (go toks))
   (lig-run J M toks)
    (: f (M 'font) t (tf J f)
       S {'in >toks 'c0 (<toks 1) 'bchar (t 'bchar) 'fb (t 'fbchar) 'cl non 'cr non 'cq ()
          'ls () 'k 0 'j ()}
       (item c) {'type 'item 'char c 'lig () 'link ()}
       (pack x)
        (lignode J f (S 'cl) (S 'cq 'link) @ p
           (J 'lft ? (pin p 'sub 2, pin J 'lft 0),
            x && S 'ls = () ? (pin p 'sub (p 'sub + 1), pin J 'rt 0),
            pin (S 'cq) 'link p, pin M 'tail p,
            pin J 'lp 0))
       (wrapup x)
        (S 'cl < non ?
           (S 'cq 'link != () && charfield (M 'tail) = hychar J f ? (pin J 'insd 1),
            J 'lp ? (pack x),
            J 'insd ? (pin J 'insd 0, (? (!(M 'restricted)) (tail-append M (discnode J))))))
       (step l)
        (l @
         'append
          (: c (S 'c0)
             _ (adjust-sf J M c)
             _ (pin S 'ls (charnode J f c)) _ (pin S 'cl c) _ (pin S 'cq (M 'tail))
             k (J 'cbd ? (pin J 'cbd 0, ()) (t 'blabel))
             (k = () ? 'move2
                (pin S 'k k, pin S 'cr c, pin S 'cl non, 'lig1)))
         'wrapup (wrapup (J 'rt), 'move)
         'move (S 'ls = () ? 'out
                  (pin S 'cq (M 'tail), pin S 'cl (S 'ls 'char), 'move1))
         'move1 (char? (S 'ls) ? 'move2 'movelig)
         'move2
          (S 'ls 'char @ c
             (? (!(exists J f c)) (warn J f c, pin S 'ls (), 'out)
                (tail-append M (S 'ls), 'look)))
         'look
          (: in (S 'in)
             (two? in && ctok? <in ? (pin S 'c1 (<in 1), pin S 'in >in, 'look1)
                (two? in && <in = 'nb ? (pin S 'bchar non),
                 pin S 'cr (S 'bchar), pin S 'ls (),
                 'lig)))
         'look1
          (S 'c1 @ c
             (adjust-sf J M c,
              pin S 'ls (charnode J f c), pin S 'cr c,
              c = S 'fb ? (pin S 'cr non),
              'lig))
         'lig
          (ci J f (S 'cl) @ q
             (tag q != 1 || S 'cr = non ? 'wrapup
                (: k (q 3) j (lk J f k)
                   (j 0 <= 128 ? (pin S 'k k, pin S 'j j, 'lig2)
                      (pin S 'k (256 * j 2 + j 3), 'lig1)))))
         'lig1 (pin S 'j (lk J f (S 'k)), 'lig2)
         'lig2
          (: j (S 'j)
             (? (j 1 = S 'cr && j 0 <= 128) 'dolig
                (j 0 = 0) (pin S 'k (S 'k + 1), 'lig1)
                (j 0 >= 128) 'wrapup
                (pin S 'k (S 'k + j 0 + 1), 'lig1)))
         'dolig
          (: j (S 'j) op (j 2) r (j 3)
             (op >= 128 ?
                (wrapup (J 'rt), tail-append M (kernnode J (kn J f j) 0), 'move)
                (: _ (? (S 'cl = non) (pin J 'lft 1) (S 'ls = ()) (pin J 'rt 1))
                   nx (? (op = 1 || op = 5) (pin S 'cl r, pin J 'lp 1, ())
                         (op = 2 || op = 6)
                          (: _ (pin S 'cr r) ls (S 'ls)
                             (? (ls = ()) (pin S 'ls (item r), pin S 'bchar non, ())
                                (char? ls) (item r @ it (pin it 'lig ls, pin S 'ls it, ()))
                                (pin ls 'char r, ())))
                         (op = 3)
                          (: _ (pin S 'cr r) it (item r) (pin it 'link (S 'ls), pin S 'ls it, ()))
                         (op = 7 || op = 11)
                          (wrapup 0, pin S 'cq (M 'tail), pin S 'cl r, pin J 'lp 1, ())
                         (pin S 'cl r, pin J 'lp 1, S 'ls = () ? 'wrapup 'move1))
                   (? (nx != ()) nx
                      (op > 4 && op != 7) 'wrapup
                      (S 'cl < non) 'lig
                      (pin S 'k (t 'blabel), 'lig1)))))
         'movelig
          (: ls (S 'ls) p (ls 'lig)
             (p != () ? (tail-append M p),
              pin S 'ls (ls 'link),
              pin J 'lp 1,
              S 'ls = () ? (p != () ? 'look (pin S 'cr (S 'bchar), 'lig))
                (pin S 'cr (S 'ls 'char), 'lig))))
       (run l) (l = 'out ? (S 'in) (run (step l)))
       (run 'append))

   ; --- spaces (tex.web 1041-1044) ----------------------------------------------------------
   (font-glue J f) (cp-spec (fparam J f 2) (fparam J f 3) 0 (fparam J f 4) 0)
   (normal-space J M)
    (P J 'spaceskip @ ss
       (tail-append M (zero? ss ? (gluenode J (font-glue J (M 'font)) 0) (gluenode J ss 12))))
   (app-space J M)
    (: sf (M 'sf) xs (P J 'xspaceskip) ss (P J 'spaceskip)
       (? (sf >= 2000 && !(zero? xs)) (tail-append M (gluenode J xs 13))
          (: b (zero? ss ? (font-glue J (M 'font)) ss)
             w (sf >= 2000 ? (b 'width + fparam J (M 'font) 7) (b 'width))
             g (cp-spec w (xn-over-d (b 'stretch) sf 1000) (b 'sto) (xn-over-d (b 'shrink) 1000 sf) (b 'sho))
             (tail-append M (gluenode J g 0)))))

   ; --- starting and ending paragraphs (tex.web 1091, 1096, 1070) ----------------------------
   (norm-min h) (? (h <= 0) 1 (h >= 63) 63 h)
   (cur-lang J) (P J 'language @ l (l <= 0 || l > 255 ? 0 l))
   (new-graf J M indented)
    (: _ (pin M 'vpg 0)
       _ (? (!(same? (M 'vhead) (M 'vtail))) (vappend M (gluenode J (P J 'parskip) 3)))
       h (nd J {'type 'head 'link ()})
       (pin M 'mode 'h, pin M 'hhead h, pin M 'tail h, pin M 'sf 1000,
        pin M 'hpg ((norm-min (P J 'lefthyphenmin) * 64 + norm-min (P J 'righthyphenmin)) * 65536
                    + cur-lang J),
        indented ? (nd J (cb-null-box 0) @ b (pin b 'width (P J 'parindent), tail-append M b))))
   (normal-paragraph J)
    (J 'params @ pr
       (pin pr 'looseness 0, pin pr 'hangindent 0, pin pr 'hangafter 1,
        pin pr 'parshape ()))
   (end-graf J M)
    (? (M 'mode = 'h && !(M 'restricted))
       (M 'hhead 'link != () ? (line-break J M (P J 'widowpenalty)),
        pin M 'mode 'v,
        normal-paragraph J))
   (append-to-vlist J M b)
    (M 'pd > ignore-depth ?
       (: bs (spec-of (P J 'baselineskip))
          d (bs 'width - M 'pd - b 'height)
          (vappend M (d < P J 'lineskiplimit ? (gluenode J (P J 'lineskip) 1)
                        (gluenode J (cp-spec d (bs 'stretch) (bs 'sto) (bs 'shrink) (bs 'sho)) 2)))),
     vappend M b,
     pin M 'pd (b 'depth))

   ; --- the tokens -----------------------------------------------------------------------------
   ; a glue in a token is [w st sto sh sho]; the parameters that take one
   glue-params ['leftskip 'rightskip 'parfillskip 'baselineskip 'lineskip 'parskip 'spaceskip
                'xspaceskip 'splittopskip]
   dimen-params ['hsize 'parindent 'emergencystretch 'hangindent 'lineskiplimit 'overfullrule
                 'vsize 'splitmaxdepth 'hfuzz 'vfuzz]
   (glue-of v) (cp-spec (v 0) (v 1) (v 2) (v 3) (v 4))
   (set-param J k v) (pin (J 'params) k (elem k glue-params ? (glue-of v) v))
   (vtok? t k) (two? t && t 0 = k)
   ; the contents of \hbox{..} or \hbox to w{..}, in restricted horizontal mode (tex.web 1083-1086)
   (cp-hbox J font w toks)
    (: h (nd J {'type 'head 'link ()})
       M {'mode 'h 'restricted 1 'font font 'hhead h 'tail h 'sf 1000 'hpg 0}
       (cp-run J M toks,
        nd J (cb-hpack J (h 'link) (w = () ? 0 w) (w = () ? 'additional 'exactly))))
   (cp-run J M toks)
    (: (go ts)
        (? (!(two? ts)) M
           (<ts @ t
              (M 'mode = 'v ?
                 (? (ctok? t) (new-graf J M 1, go ts)
                    (t = 'indent) (new-graf J M 1, go >ts)
                    (t = 'noindent) (new-graf J M 0, go >ts)
                    (vtok? t 'set) (set-param J (t 1) (t 2), go >ts)
                    (vtok? t 'f) (pin M 'font (t 1), go >ts)
                    (vtok? t 'vskip) (vappend M (gluenode J (glue-of >t) 0), go >ts)
                    (vtok? t 'pen) (vappend M (pennode J (t 1)), go >ts)
                    (vtok? t 'hrule)
                     (vappend M (nd J (cb-rule (t 1 = () ? -1073741824 (t 1)) (t 2) (t 3))),
                      pin M 'pd ignore-depth, go >ts)
                    (vtok? t 'hbox) (append-to-vlist J M (cp-hbox J (M 'font) (t 1) (t 2)), go >ts)
                    (vtok? t 'box) (append-to-vlist J M (t 1), go >ts)
                    (go >ts))
                 ; a vertical command ends an open paragraph, then runs in vertical mode
                 (? (!(M 'restricted) && (vtok? t 'vskip || vtok? t 'hrule)) (end-graf J M, go ts)
                    (ctok? t) (go (main-loop J M ts))
                    (t = 'nb) (two? >ts && ctok? <>ts ? (pin J 'cbd 1), go >ts)
                    (t = 'sp) (M 'sf = 1000 ? (normal-space J M) (app-space J M), go >ts)
                    (t = 'xsp) (normal-space J M, go >ts)
                    (t = 'par) (end-graf J M, go >ts)
                    (t = 'noindent) (go >ts)
                    (t = 'indent)
                     (nd J (cb-null-box 0) @ b (pin b 'width (P J 'parindent),
                                                pin M 'sf 1000, tail-append M b, go >ts))
                    (t = 'dash)
                     (: d (discnode J) _ (tail-append M d) c (hychar J (M 'font))
                        (0 <= c && c < 256 ?
                           (exists J (M 'font) c ? (pin d 'pre (charnode J (M 'font) c))
                              (warn J (M 'font) c)),
                         go >ts))
                    (t 0 @
                     'f (pin M 'font (t 1), go >ts)
                     'set (set-param J (t 1) (t 2), go >ts)
                     'pen (tail-append M (pennode J (t 1)), go >ts)
                     'kern (tail-append M (kernnode J (t 1) 1), go >ts)
                     'skip (tail-append M (gluenode J (glue-of >t) 0), go >ts)
                     'rule (tail-append M (nd J (cb-rule (t 1) (t 2) (t 3))), pin M 'sf 1000, go >ts)
                     'hbox (tail-append M (cp-hbox J (M 'font) (t 1) (t 2)), pin M 'sf 1000, go >ts)
                     'box (tail-append M (t 1), pin M 'sf 1000, go >ts)
                     (go >ts))))))
       (go toks))
   (cp-vlist J M) (end-graf J M, M 'vhead 'link)

   ; --- the tokens as TeX says them --------------------------------------------------------------
   ; the TeX side must \def\sp{ } (a space after a control word) and name font k \f and the k-th
   ; letter; a fil amount is said in halves, so a token's must be one
   (fname k) ("\\f" + string (96 + k))
   (units o) (["sp" "fil" "fill" "filll"] o)
   (amt v o) (o = 0 ? (show v + "sp")
                (: whole (v // 65536) frac (v % 65536)
                   (frac = 0 ? (show whole + units o) (show whole + ".5" + units o))))
   (glue-tex g) (show (g 0) + "sp plus " + amt (g 1) (g 2) + " minus " + amt (g 3) (g 4))
   (dim-tex nm v) (v = () ? "" (" " + nm + " " + show v + "sp"))
   (plain? b) (32 < b && b < 127 && nelem b [92 123 125 37])
   ; each token said, and whether it ended in a plain character (a space may follow it bare)
   (tok-tex t)
    (two? t ?
       (t 0 @
        'c (plain? (t 1) ? [(string (t 1)) 1] [("\\char" + show (t 1) + " ") 0])
        'f [(fname (t 1) + " ") 0]
        'pen [("\\penalty" + show (t 1) + " ") 0]
        'kern [("\\kern" + show (t 1) + "sp ") 0]
        'skip [("\\hskip" + glue-tex >t + "\\relax ") 0]
        'vskip [("\\vskip" + glue-tex >t + "\\relax ") 0]
        'rule [("\\vrule" + dim-tex "width" (t 1) + dim-tex "height" (t 2) + dim-tex "depth" (t 3) + "\\relax ") 0]
        'hrule [("\\hrule" + dim-tex "width" (t 1) + dim-tex "height" (t 2) + dim-tex "depth" (t 3) + "\\relax ") 0]
        'hbox [("\\hbox" + (t 1 = () ? "" (" to" + show (t 1) + "sp")) + "{" + cp-tex (t 2) + "}") 0]
        'set (: k (t 1) v (t 2) nm ("\\" + show k)
                [(? (k = 'parshape) (nm + " " + show #v + cats (map (e \ " " + show (e 0) + "sp " + show (e 1) + "sp") v) + "\\relax ")
                    (elem k glue-params) (nm + "=" + glue-tex v + "\\relax ")
                    (elem k dimen-params) (nm + "=" + show v + "sp\\relax ")
                    (nm + "=" + show v + "\\relax "))
                 0])
        ["" 0])
       (t @
        'sp ["\\sp " 0]
        'xsp ["\\ " 0]
        'nb ["\\noboundary " 0]
        'dash ["\\-" 0]
        'par ["\\par " 0]
        'indent ["\\indent " 0]
        'noindent ["\\noindent " 0]
        ["" 0]))
   ; a line ends where a space would: TeX reads the end of a line as that space
   (cp-tex ts)
    (: (put s col acc)
        (#s @ n
           (col + n > 72 && 1 < n && s (n - 1) = 32 && s (n - 2) != 92 ? [0 (snip s 0 (n - 1) + "\n" . acc)]
              [(col + n) (s . acc)]))
       (go ts bare col acc)
        (? (!(two? ts)) (cats (rev acc))
           (: t <ts
              r (t = 'sp && bare ? [" " 0] (tok-tex t))
              p (put (r 0) col acc)
              (go >ts (r 1) (p 0) (p 1))))
       (go ts 0 0 ()))

   ; --- \patterns and \hyphenation (tex.web 934-939, 960-965) ------------------------------
   ; a pattern is kept under its letters, the language's byte first, with its n0..nk; every
   ; prefix is kept too, so a lookup stops where the trie would
   (words s)
    (: n #s
       (go i a acc) (? (i >= n) (rev (a < n ? (snip s a n . acc) acc))
                       (s i <= 32) (go (i + 1) (i + 1) (a < i ? (snip s a i . acc) acc))
                       (go (i + 1) a acc))
       (go 0 0 ()))
   (cp-patterns J s)
    (: lang (cur-lang J)
       (one w)
        (: hc {} hy {0 0} St {'k 0 'ds 0}
           _ (map (i \ (: ch (w i) k (St 'k)
                          (St 'ds || ch < 48 || ch > 57 ?
                             (k < 63 ? ((ch = 46 ? 0 (J 'lc ch)) @ c
                                          (pin hc (k + 1) c, pin hy (k + 1) 0,
                                           pin St 'k (k + 1), pin St 'ds 0)))
                             (k < 63 ? (pin hy k (ch - 48), pin St 'ds 1)))))
                  ^#w)
           k (St 'k)
           (k > 0 ?
              (: _ (hc 1 = 0 ? (pin hy 0 0))
                 _ (hc k = 0 ? (pin hy k 0))
                 (grow i key) (i <= k ?
                                 (key + string (hc i) @ k2 (pin (J 'pref) k2 1, grow (i + 1) k2))
                                 key)
                 key (grow 1 (string lang))
                 (pin (J 'langs) lang 1,
                  pin (J 'pats) key (map (i \ peep hy i 0) ^(k + 1))))))
       (map one (words s),
        J))
   (cp-hyphenation J s)
    (: lang (cur-lang J)
       (one w)
        ({'n 0 'p () 'key ""} @ St
           (map (i \ (: ch (w i) n (St 'n)
                        (? (ch = 45) (n < 63 ? (pin St 'p (n . St 'p)))
                           (J 'lc ch = 0) ()
                           (n < 63) (pin St 'n (n + 1), pin St 'key (St 'key + string (J 'lc ch))))))
                ^#w,
            St 'n > 1 ? (pin (J 'exc) (St 'key + string lang) (St 'p))))
       (map one (words s),
        J))
   (cp-hyphen-file J s)
    (: n #s
       (skipc i) (i < n && s i != 10 ? (skipc (i + 1)) i)
       (body i acc) (? (i >= n) [(cats (rev acc)) i]
                       (s i = 37) (body (skipc i) acc)
                       (s i = 125) [(cats (rev acc)) (i + 1)]
                       (body (i + 1) (string (s i) . acc)))
       (letter? c) (65 <= c && c <= 90 || 97 <= c && c <= 122)
       (name j) (j < n && letter? (s j) ? (name (j + 1)) j)
       (blank j) (j < n && s j <= 32 ? (blank (j + 1)) j)
       (go i)
        (? (i >= n) J
           (s i = 37) (go (skipc i))
           (s i = 92)
            (: j (name (i + 1)) nm (snip s (i + 1) j) k (blank j)
               (k < n && s k = 123 ?
                  (body (k + 1) () @ b
                     ((? (nm = "patterns") (cp-patterns J <b) (nm = "hyphenation") (cp-hyphenation J <b)),
                      go (b 1)))
                  (go j)))
           (go (i + 1)))
       (go 0))

   ; --- line_break (tex.web 813-890) --------------------------------------------------------------
   ; the active list: A is both active and last_active; an active node has 'type 0 or 1
   ; (unhyphenated, hyphenated), a delta node 'type 2 and its widths in 'd. tex.web's six-word
   ; width arrays are trays of seven, slot 0 unused, so a delta is one add
   (at t k) (peep t k 0)
   (bump t k v) (pin t k (peep t k 0 + v))
   (spec-add t g) (bump (bump (bump t 1 (g 'width)) (2 + g 'sto) (g 'stretch)) 6 (g 'shrink))
   (spec-sub t g) (bump (bump (bump t 1 (0 - g 'width)) (2 + g 'sto) (0 - g 'stretch)) 6 (0 - g 'shrink))
   (line-break J M fwp)
    (: tl (M 'tail)
       _ (char? tl || tl 'type != 10 ? (tail-append M (pennode J 10000))
            (pin tl 'type 12, pin tl 'penalty 10000, pin tl 'glue ()))
       _ (tail-append M (gluenode J (P J 'parfillskip) 15))
       hpg (M 'hpg)
       L {'lang0 (hpg % 65536) 'lhyf0 (hpg // 4194304) 'rhyf0 (hpg // 65536 % 64)
          'head (M 'hhead) 'pg (M 'vpg) 'nse 1 'passive () 'dw 0 'cp ()
          'mind awful 'minimal {0 awful 1 awful 2 awful 3 awful} 'bp {} 'bpl {}
          'aw z7 'bg z7 'bw z7 'caw z7}
       _ (pin M 'mode 'v)
       ; check_shrinkage: infinite shrink is made finite
       (finite g) (g != () && g 'sho != 0 && g 'shrink != 0 ?
                     (pin L 'nse 0, cp-spec (g 'width) (g 'stretch) (g 'sto) (g 'shrink) 0) g)
       _ (pin (J 'params) 'leftskip (finite (P J 'leftskip)))
       _ (pin (J 'params) 'rightskip (finite (P J 'rightskip)))
       ls (spec-of (P J 'leftskip)) rs (spec-of (P J 'rightskip))
       _ (pin L 'bg (spec-add (spec-add z7 ls) rs))
       ps (P J 'parshape) hi (P J 'hangindent) ha (P J 'hangafter) hs (P J 'hsize)
       _ (ps = () ?
            (hi = 0 ? (pin L 'lsl 0, pin L 'sw hs, pin L 'si 0)
               (pin L 'lsl (abs ha),
                ha < 0 ?
                  (pin L 'fw (hs - abs hi), pin L 'fi (hi >= 0 ? hi 0),
                   pin L 'sw hs, pin L 'si 0)
                  (pin L 'fw hs, pin L 'fi 0,
                   pin L 'sw (hs - abs hi), pin L 'si (hi >= 0 ? hi 0))))
            (#ps @ n (pin L 'lsl (n - 1),
                      pin L 'sw (ps (n - 1) 1), pin L 'si (ps (n - 1) 0))))
       _ (pin L 'easy (P J 'looseness = 0 ? (L 'lsl) maxhw))
       A {'head 1 'type 1 'line maxhw 'link ()}
       _ (pin A 'link A)
       (lastp r) (r 'head = 1)
       (aw-add v) (pin L 'aw (bump (L 'aw) 1 v))
       (bw-add v) (pin L 'bw (bump (L 'bw) 1 v))

       ; try_break (829-860)
       (try-break pi0 bt)
        (abs pi0 >= 10000 && pi0 > 0 ? ()
           (: pi (abs pi0 >= 10000 ? -10000 pi0)
              T {'nby 1 'pr A 'ppr () 'oldl 0 'lw 0}
              _ (pin L 'caw (L 'aw))
              cp (L 'cp)
              (break-width _)
               (: _ (pin L 'bw (L 'bg))
                  s0 (bt > 0 && cp != () ?
                        (: (drop t v) (t > 0 ? (v 'link @ v2 (bw-add (0 - wd J v2), drop (t - 1) v2)) v)
                           v (drop (cp 'sub) cp)
                           (post s) (s != () ? (bw-add (wd J s), post (s 'link)))
                           (post (cp 'post),
                            bw-add (L 'dw),
                            cp 'post = () ? (v 'link)))
                        cp)
                  (strip s)
                   (s = () || char? s ? ()
                      (s 'type @ y
                         (? (y = 10) (pin L 'bw (spec-sub (L 'bw) (s 'glue)), strip (s 'link))
                            (y = 12) (strip (s 'link))
                            (y = 9) (bw-add (0 - s 'width), strip (s 'link))
                            (y = 11 && s 'sub = 1) (bw-add (0 - s 'width), strip (s 'link))
                            ())))
                  (strip s0))
              (create r)
               (: _ (T 'nby ? (pin T 'nby 0, break-width 0))
                  bw (L 'bw) caw (L 'caw) pr (T 'pr)
                  _ (? (pr 'type = 2) (pin pr 'd (pr 'd - caw + bw))
                       (lastp pr) (pin L 'aw bw)
                       ({'type 2 'd (bw - caw) 'link r} @ q
                          (pin pr 'link q, pin T 'ppr pr, pin T 'pr q)))
                  adj (P J 'adjdemerits)
                  (pin L 'mind (abs adj >= awful - L 'mind ? (awful - 1) (L 'mind + abs adj)),
                   map (fit \ (L 'minimal fit <= L 'mind ?
                                 (: q {'cb cp 'prev (L 'bp fit) 'link (L 'passive)}
                                    _ (pin L 'passive q)
                                    a {'type bt 'fit fit 'brk q 'line (L 'bpl fit + 1)
                                       'td (L 'minimal fit) 'link r}
                                    (pin (T 'pr) 'link a, pin T 'pr a)),
                               pin (L 'minimal) fit awful))
                       [0 1 2 3],
                   pin L 'mind awful,
                   (? (!(lastp r))
                      ({'type 2 'd (caw - bw) 'link r} @ q
                         (pin (T 'pr) 'link q, pin T 'ppr (T 'pr), pin T 'pr q)))))
              (record r b fit art l)
               (: d (art ? 0
                       (: d0 (P J 'linepenalty + b)
                          d1 (abs d0 >= 10000 ? 100000000 (d0 * d0))
                          d2 (? (pi > 0) (d1 + pi * pi) (pi < 0 && pi > -10000) (d1 - pi * pi) d1)
                          d3 (bt = 1 && r 'type = 1 ?
                                (cp != () ? (d2 + P J 'doublehyphendemerits) (d2 + P J 'finalhyphendemerits))
                                d2)
                          (abs (fit - r 'fit) > 1 ? (d3 + P J 'adjdemerits) d3)))
                  d2 (d + r 'td)
                  (d2 <= L 'minimal fit ?
                     (pin (L 'minimal) fit d2, pin (L 'bp) fit (r 'brk), pin (L 'bpl) fit l,
                      d2 < L 'mind ? (pin L 'mind d2))))
              (deactivate r)
               (: pr (T 'pr)
                  (pin pr 'link (r 'link),
                   (? (lastp pr)
                      (A 'link @ r2
                         (r2 'type = 2 ?
                            (pin L 'aw (L 'aw + r2 'd),
                             pin L 'caw (L 'aw),
                             pin A 'link (r2 'link))))
                      (pr 'type = 2)
                      (pr 'link @ r2
                         (? (lastp r2)
                            (pin L 'caw (L 'caw - pr 'd),
                             pin (T 'ppr) 'link A, pin T 'pr (T 'ppr))
                            (r2 'type = 2)
                            (pin L 'caw (L 'caw + r2 'd),
                             pin pr 'd (pr 'd + r2 'd),
                             pin pr 'link (r2 'link)))))))
              (consider r l)
               (: caw (L 'caw)
                  sf (T 'lw - at caw 1)
                  b (sf > 0 ?
                       (? (at caw 3 != 0 || at caw 4 != 0 || at caw 5 != 0) 0
                          (sf > 7230584 && at caw 2 < 1663497) 10000
                          (cb-badness sf (at caw 2)))
                       (0 - sf > at caw 6 ? 10001 (cb-badness (0 - sf) (at caw 6))))
                  ; the fitness class: very loose 0, loose 1, decent 2, tight 3
                  fit (sf > 0 ? (b > 12 ? (b > 99 ? 0 1) 2) (b > 12 ? 3 2))
                  (b > 10000 || pi = -10000 ?
                     (? (L 'final && L 'mind = awful && lastp (r 'link) && lastp (T 'pr))
                        (record r b fit 1 l, deactivate r, loop 0)
                        (b > L 'thr) (deactivate r, loop 0)
                        (record r b fit 0 l, deactivate r, loop 0))
                     (pin T 'pr r,
                      b > L 'thr ? (loop 0) (record r b fit 0 l, loop 0))))
              (loop _)
               (T 'pr 'link @ r
                  (r 'type = 2 ?
                     (pin L 'caw (L 'caw + r 'd),
                      pin T 'ppr (T 'pr), pin T 'pr r, loop 0)
                     (r 'line @ l
                        (l > T 'oldl ?
                           (L 'mind < awful && (T 'oldl != L 'easy || lastp r) ? (create r),
                            lastp r ? ()
                              (l > L 'easy ? (pin T 'lw (L 'sw), pin T 'oldl (maxhw - 1))
                                 (pin T 'oldl l,
                                  pin T 'lw (? (l > L 'lsl) (L 'sw) (ps = ()) (L 'fw) (ps (l - 1) 1))),
                               consider r l))
                           (consider r l)))))
              (loop 0)))

       ; the passes (863-873)
       (legal-glue prev) (char? prev || prev 'type < 9 || prev 'type = 11 && prev 'sub != 1)
       (kern-break cp)
        (cp 'link @ nx
           ((? (!(char? nx) && L 'auto && nx 'type = 10) (try-break 0 0)),
            aw-add (cp 'width)))
       (walk prev cp)
        (? (cp = () || lastp (A 'link)) cp
           (char? cp)
            (: (chars p n) (char? p ? (chars (p 'link) (n + wd J p)) (aw-add n, p))
               nx (chars cp 0)
               (pin L 'cp nx,
                walk cp nx))
           (cp 'type @ y (pin L 'cp cp,
                          y = 7 ?
                            (: pre (cp 'pre)
                               (dsum s) (s = () ? 0 (wd J s + dsum (s 'link)))
                               _ (pre = () ? (pin L 'dw 0, try-break (P J 'exhyphenpenalty) 1)
                                    (dsum pre @ dw (pin L 'dw dw,
                                                    aw-add dw, try-break (P J 'hyphenpenalty) 1,
                                                    aw-add (0 - dw))))
                               (skip n s) (n > 0 ? (aw-add (wd J s), skip (n - 1) (s 'link)) s)
                               nx (skip (cp 'sub) (cp 'link))
                               (pin L 'cp nx,
                                walk cp nx))
                            (: _ (? (y <= 2) (aw-add (cp 'width))
                                    (y = 10)
                                     (: _ (L 'auto && legal-glue prev ? (try-break 0 0))
                                        g (finite (cp 'glue)) (pin cp 'glue g,
                                                               pin L 'aw (spec-add (L 'aw) g),
                                                               L 'second && L 'auto ? (try-hyphenate cp)))
                                    (y = 11) (cp 'sub = 1 ? (kern-break cp) (aw-add (cp 'width)))
                                    (y = 6) (aw-add (wd J cp))
                                    (y = 9) (pin L 'auto (cp 'sub = 1), kern-break cp)
                                    (y = 12) (try-break (cp 'penalty) 0))
                               nx (cp 'link)
                               (pin L 'cp nx,
                                walk cp nx)))))
       (fewest _)
        (: (go r best fd) (lastp r ? best
                             (r 'type != 2 && r 'td < fd ? (go (r 'link) r (r 'td)) (go (r 'link) best fd)))
           b (go (A 'link) () awful)
           (pin L 'best b, pin L 'bline (b 'line)))
       (loose _)
        (: lo (P J 'looseness) bl (L 'bline)
           S {'al 0 'fd awful}
           (go r) (lastp r ? ()
                     (r 'type != 2 ?
                        (r 'line - bl @ d
                           (? (d < S 'al && lo <= d || d > S 'al && lo >= d)
                              (pin L 'best r, pin S 'al d, pin S 'fd (r 'td))
                              (d = S 'al && r 'td < S 'fd)
                              (pin L 'best r, pin S 'fd (r 'td)))),
                      go (r 'link)))
           (pin S 'fd (L 'best 'td),
            go (A 'link),
            pin L 'bline (L 'best 'line),
            S 'al))
       (pass _)
        (: _ (L 'thr > 10000 ? (pin L 'thr 10000))
           _ (L 'second ?
                (pin L 'lang (L 'lang0), pin L 'lhyf (L 'lhyf0), pin L 'rhyf (L 'rhyf0)))
           a {'type 0 'fit 2 'link A 'brk () 'line (L 'pg + 1) 'td 0}
           _ (pin A 'link a)
           _ (pin L 'aw (L 'bg))
           _ (pin L 'passive ())
           first (L 'head 'link)
           _ (pin L 'auto 1)
           cp (walk first first)
           done (cp = () ?
                   (pin L 'cp (),
                    try-break -10000 1,
                    lastp (A 'link) ? 0
                      (fewest 0,
                       P J 'looseness = 0 ? 1
                         (loose 0 @ al (al = P J 'looseness || L 'final))))
                   0)
           (done ? ()
              ((? (!(L 'second))
                  (pin L 'thr (P J 'tolerance), pin L 'second 1,
                   pin L 'final (P J 'emergencystretch <= 0))
                  (pin L 'bg (bump (L 'bg) 2 (P J 'emergencystretch)), pin L 'final 1)),
               pass 0)))
       _ (pin L 'thr (P J 'pretolerance))
       _ (L 'thr >= 0 ? (pin L 'second 0, pin L 'final 0)
            (pin L 'thr (P J 'tolerance), pin L 'second 1,
             pin L 'final (P J 'emergencystretch <= 0)))

       ; --- hyphenation (891-918, 923, 930-934) -----------------------------------------------
       H {'hu {} 'hc {} 'hyf {} 'hn 0}
       (lc c) (J 'lc c)
       (hu k) (H 'hu k) (hc k) (H 'hc k) (hyf k) (peep (H 'hyf) k 0)
       (odd? n) (n % 2 = 1)
       hold (nd J {'type 'head 'link ()})
       (try-hyphenate cp)
        (cp 'link @ s0
           (s0 = () ? ()
              (: ; skip to ha
                 (ha-scan prev s)
                  (: y (char? s ? 'c (s 'type))
                     cf (? (y = 'c) [(s 'char) (s 'font)]
                           (y = 6) (s 'lig = () ? 'cont [(s 'lig 'char) (s 'lig 'font)])
                           (y = 11 && s 'sub = 0) 'cont
                           (y = 8) 'cont
                           'fail)
                     (? (cf = 'fail) ()
                        (cf = 'cont) (ha-scan s (s 'link))
                        (<cf @ c
                           (lc c != 0 ?
                              (lc c = c || P J 'uchyph > 0 ? [prev s (cf 1)])
                              (ha-scan s (s 'link))))))
                 hs (ha-scan cp s0)
                 (hs = () ? ()
                    (: ha (hs 0) s1 (hs 1) hf (hs 2) hyc (hychar J hf)
                       (hyc < 0 || hyc > 255 || L 'lhyf + L 'rhyf > 63 ? ()
                          (: _ (pin H 'hn 0) _ (pin H 'hf hf) _ (pin H 'ha ha) _ (pin H 'hyc hyc)
                             bch (tf J hf)
                             ; skip to hb, letters into hu and hc
                             (hb-scan s)
                              (? (char? s)
                                 (s 'char @ c
                                    (s 'font != hf ? s
                                       (pin H 'hbc c,
                                        lc c = 0 || H 'hn = 63 ? s
                                          (H 'hn + 1 @ n (pin H 'hn n, pin H 'hb s,
                                                          pin (H 'hu) n c, pin (H 'hc) n (lc c),
                                                          pin H 'hbc non,
                                                          hb-scan (s 'link))))))
                                 (s 'type = 6)
                                  (s 'font != hf ? s
                                     (: q0 (s 'lig)
                                        _ (q0 != () ? (pin H 'hbc (q0 'char)))
                                        (lg q j) (q = () ? j
                                                    (q 'char @ c
                                                       (lc c = 0 || j = 63 ? 'stop
                                                          (pin (H 'hu) (j + 1) c, pin (H 'hc) (j + 1) (lc c),
                                                           lg (q 'link) (j + 1)))))
                                        j (lg q0 (H 'hn))
                                        (j = 'stop ? s
                                           (pin H 'hb s, pin H 'hn j,
                                            pin H 'hbc (odd? (s 'sub) ? (bch 'bchar) non),
                                            hb-scan (s 'link)))))
                                 (s 'type = 11 && s 'sub = 0)
                                  (pin H 'hb s, pin H 'hbc (bch 'bchar), hb-scan (s 'link))
                                 s)
                             s2 (hb-scan s1)
                             (H 'hn < L 'lhyf + L 'rhyf ? ()
                                (: (tail-ok s)
                                    (char? s ? (tail-ok (s 'link))
                                       (s 'type @ y
                                          (? (y = 6) (tail-ok (s 'link))
                                             (y = 11) (s 'sub != 0 ? 1 (tail-ok (s 'link)))
                                             (elem y [8 10 12 3 5 4]) 1
                                             0)))
                                   (tail-ok s2 ? (hyphenate cp)))))))))))
       (hyphenate cp)
        (: hn (H 'hn) hf (H 'hf) lang (L 'lang)
           _ (map (j \ pin (H 'hyf) j 0) ^(hn + 1))
           ek (cats (map (j \ string (hc (j + 1))) ^hn) + string lang)
           ex (peep (J 'exc) ek 'none)
           found (? (ex != 'none) (map (k \ pin (H 'hyf) k 1) ex, 1)
                    (!(J 'langs lang)) 0
                    (: _ (pin (H 'hc) 0 0) _ (pin (H 'hc) (hn + 1) 0)
                       (from j) (j <= hn - L 'rhyf + 1 ?
                                   (: (grow key l)
                                       (l > hn + 1 ? ()
                                          (key + string (hc l) @ k2
                                             (? (!(J 'pref k2)) ()
                                                (J 'pats k2 @ v
                                                   (v != () ?
                                                      (map (i \ (: n (v i) at (j - 1 + i)
                                                                   (n > hyf at ? (pin (H 'hyf) at n))))
                                                           ^#v),
                                                    grow k2 (l + 1))))))
                                      (grow (string lang) j,
                                       from (j + 1))))
                       (from 0,
                        1)))
           (found = 0 ? ()
              (map (j \ pin (H 'hyf) j 0) ^(L 'lhyf),
               map (j \ pin (H 'hyf) (hn - j) 0) ^(L 'rhyf),
               (? (!(any (j \ odd? (hyf j)) (map (+ (L 'lhyf)) ^(max 0 (hn - L 'rhyf - L 'lhyf + 1)))))
                  ()
                  (replace cp)))))

       ; reconstitute (905-911): hu[j..n] into nodes at hold's link; answers the cut
       (recon j0 n bchar0 hchar0)
        (: hf (H 'hf) t (tf J hf)
           R {'j j0 'bchar bchar0 'hchar hchar0 't hold 'w 0 'cl (hu j0) 'cq hold 'ls () 'cr non
              'crh non 'k 0 'q ()}
           _ (pin H 'hp 0) _ (pin hold 'link ())
           (app c) (charnode J hf c @ n (pin (R 't) 'link n, pin R 't n))
           (set-cur-r _)
            (: j (R 'j)
               (pin R 'cr (j < n ? (hu (j + 1)) (R 'bchar)),
                pin R 'crh (odd? (hyf j) ? (R 'hchar) non)))
           (wrap x)
            (J 'lp ?
               (lignode J hf (R 'cl) (R 'cq 'link) @ p
                  (J 'lft ? (pin p 'sub 2, pin J 'lft 0),
                   x && R 'ls = () ? (pin p 'sub (p 'sub + 1), pin J 'rt 0),
                   pin (R 'cq) 'link p, pin R 't p,
                   pin J 'lp 0)))
           (pop-ls _)
            (: ls (R 'ls)
               (ls 'lig != () ? (pin (R 't) 'link (ls 'lig), pin R 't (ls 'lig), pin R 'j (R 'j + 1)),
                pin R 'ls (ls 'link),
                R 'ls = () ? (set-cur-r 0) (pin R 'cr (R 'ls 'char))))
           ; set up with the cursor after j
           _ (? (j0 = 0)
                (: _ (pin J 'lp (H 'ilig))
                   _ (J 'lp ? (pin J 'lft (H 'ilft)))
                   (go p) (p != () ? (app (p 'char), go (p 'link)))
                   (go (H 'ilist)))
                (R 'cl < non) (app (R 'cl)))
           _ (set-cur-r 0)
           (step l)
            (l @
             'cont
              (: q (R 'cl = non ? (t 'blabel = () ? () (pin R 'k (t 'blabel), lk J hf (t 'blabel)))
                      (ci J hf (R 'cl) @ ci0
                         (tag ci0 != 1 ? ()
                            (: k (ci0 3) q (lk J hf k)
                               (q 0 > 128 ? (256 * q 2 + q 3 @ k2 (pin R 'k k2, lk J hf k2))
                                  (pin R 'k k, q))))))
                 (q = () ? 'done (pin R 'q q, 'scan)))
             'scan
              (: q (R 'q) tc (R 'crh < non ? (R 'crh) (R 'cr))
                 (? (q 1 = tc && q 0 <= 128)
                    (R 'crh < non ?
                       (pin H 'hp (R 'j), pin R 'hchar non, pin R 'crh non, 'cont)
                       (R 'hchar < non && odd? (hyf (R 'j)) ? (pin H 'hp (R 'j), pin R 'hchar non),
                        q 2 < 128 ? 'lig (pin R 'w (kn J hf q), 'done)))
                    (q 0 >= 128) (R 'crh = non ? 'done (pin R 'crh non, 'cont))
                    (pin R 'k (R 'k + q 0 + 1), pin R 'q (lk J hf (R 'k)), 'scan)))
             'lig
              (: q (R 'q) op (q 2) r (q 3) j (R 'j)
                 _ (R 'cl = non ? (pin J 'lft 1))
                 _ (j = n && R 'ls = () ? (pin J 'rt 1))
                 nx (? (op = 1 || op = 5) (pin R 'cl r, pin J 'lp 1, ())
                       (op = 2 || op = 6)
                        (pin R 'cr r,
                         R 'ls != () ? (pin (R 'ls) 'char r, ())
                           ({'type 'item 'char r 'lig () 'link ()} @ it (pin R 'ls it,
                                                                         j = n ? (pin R 'bchar non, ())
                                                                           (pin it 'lig (charnode J hf (hu (j + 1))), ()))))
                       (op = 3)
                        (: _ (pin R 'cr r) it {'type 'item 'char r 'lig () 'link (R 'ls)} (pin R 'ls it, ()))
                       (op = 7 || op = 11)
                        (wrap 0, pin R 'cq (R 't), pin R 'cl r, pin J 'lp 1, ())
                       (pin R 'cl r, pin J 'lp 1,
                        (? (R 'ls != ()) (pop-ls 0, ())
                           (j = n) 'done
                           (app (R 'cr), pin R 'j (j + 1), set-cur-r 0, ()))))
                 (? (nx != ()) nx (op > 4 && op != 7) 'done 'cont))
             'done
              (wrap (J 'rt),
               R 'w != 0 ? (kernnode J (R 'w) 0 @ kk (pin (R 't) 'link kk, pin R 't kk, pin R 'w 0)),
               R 'ls != () ?
                 (pin R 'cq (R 't), pin R 'cl (R 'ls 'char), pin J 'lp 1, pop-ls 0, 'cont)
                 'out))
           (run l) (l = 'out ? (R 'j) (run (step l)))
           (run 'cont))

       ; replace ha..hb by the word with its discretionaries (903, 913-918)
       (replace cp)
        (: hf (H 'hf) ha (H 'ha) hb (H 'hb) hn (H 'hn) t (tf J hf) hyc (H 'hyc)
           q (hb 'link) _ (pin hb 'link ())
           r0 (ha 'link) _ (pin ha 'link ())
           bchar (H 'hbc)
           (before n) (same? (n 'link) ha ? n (before (n 'link)))
           (found2 _) (pin (H 'hu) 0 non, pin H 'ilig 0, pin H 'ilist (), [ha 0])
           sj (? (char? ha)
                 (ha 'font != hf ? (found2 0)
                    (pin H 'ilist ha, pin H 'ilig 0, pin (H 'hu) 0 (ha 'char), [(before cp) 0]))
                 (ha 'type = 6)
                 (ha 'font != hf ? (found2 0)
                    (pin H 'ilist (ha 'lig), pin H 'ilig 1, pin H 'ilft (ha 'sub > 1),
                     pin (H 'hu) 0 (ha 'char),
                     ha 'lig = () && ha 'sub > 1 ? (pin (H 'hu) 0 non, pin H 'ilig 0),
                     [(before cp) 0]))
                 (? (!(char? r0) && r0 'type = 6 && r0 'sub > 1) (found2 0)
                       (pin H 'ilist (), [ha 1])))
           S {'s <sj 'j <>sj 'l 0 'mt () 'rc 0}
           (adv-major _) (S 'mt 'link != () ? (pin S 'mt (S 'mt 'link), pin S 'rc (S 'rc + 1), adv-major 0))
           ; one discretionary, then the branches until they agree (914-918)
           (disc _)
            (: r (discnode J)
               _ (pin r 'link (hold 'link))
               _ (pin S 'mt r) _ (pin S 'rc 0) _ (adv-major 0)
               i0 (H 'hp) _ (pin (H 'hyf) i0 0)
               ; the pre-break: hu[l..i] and a hyphen
               hy (exists J hf hyc)
               i (hy ? (i0 + 1) i0)
               c (hu i)
               _ (hy ? (pin (H 'hu) i hyc))
               (minor tail head k) ; appends hold's list; answers [tail head]
                (hold 'link = () ? [tail head]
                   ((tail = () ? (hold 'link) head) @ h2
                      (tail != () ? (pin tail 'link (hold 'link)),
                       [(to-end (hold 'link)) h2])))
               (pre th) (S 'l <= i ?
                           (pin S 'l (recon (S 'l) i (t 'bchar) non + 1),
                            pre (minor (th 0) (th 1) 0))
                           th)
               _ (pin r 'pre (pre [() ()] 1))
               _ (hy ? (pin (H 'hu) i c, pin S 'l i))
               ; the post-break: hu[i+1..], until the branches meet
               cl0 (t 'blabel != () ?
                      (: _ (pin S 'l (S 'l - 1)) c2 (hu (S 'l)) (pin (H 'hu) (S 'l) non, [(S 'l) c2]))
                      [0 0])
               C {'cloc <cl0 'c <>cl0 'th [() ()]}
               (post-rep _)
                (pin S 'l (recon (S 'l) hn bchar non + 1),
                 C 'cloc > 0 ? (pin (H 'hu) (C 'cloc) (C 'c), pin C 'cloc 0),
                 pin C 'th (minor (C 'th 0) (C 'th 1) 0),
                 S 'l < S 'j ? (post-rep 0))
               (major _) (S 'l > S 'j ?
                            (pin S 'j (recon (S 'j) hn bchar non + 1),
                             pin (S 'mt) 'link (hold 'link),
                             adv-major 0,
                             major 0))
               (post _) (S 'l < S 'j ? (post-rep 0, major 0, post 0))
               (post 0,
                pin r 'post (C 'th 1),
                S 'rc > 127 ? (pin (S 's) 'link (r 'link), pin r 'link ())
                  (pin (S 's) 'link r, pin r 'sub (S 'rc)),
                pin S 's (S 'mt),
                pin H 'hp (S 'j - 1), pin hold 'link (),
                odd? (hyf (S 'j - 1)) ? (disc 0)))
           (outer _)
            (pin S 'l (S 'j),
             pin S 'j (recon (S 'j) hn bchar hyc + 1),
             H 'hp = 0 ?
               (pin (S 's) 'link (hold 'link),
                pin S 's (to-end (S 's)),
                odd? (hyf (S 'j - 1)) ?
                  (pin S 'l (S 'j), pin H 'hp (S 'j - 1), pin hold 'link ())),
             H 'hp > 0 ? (disc 0),
             S 'j <= hn ? (outer 0))
           (outer 0,
            pin (S 's) 'link q))

       ; --- post_line_break (877-890) ----------------------------------------------------------
       (post-line-break fwp)
        (: head (L 'head)
           (rev q cp) (q = () ? cp (q 'prev @ nx (pin q 'prev cp, rev nx q)))
           cp0 (rev (L 'best 'brk) ())
           ps (P J 'parshape)
           (line cp cl)
            (: q (cp 'cb)
               D {'db 0 'pdb 0}
               (rskip-after q) (gluenode J (P J 'rightskip) 9 @ r (pin r 'link (q 'link), pin q 'link r, r))
               qe (? (q != () && q 'type = 10)
                     (pin q 'glue (spec-of (P J 'rightskip)), pin q 'sub 9, q)
                     (q != ())
                     (: q2 (q 'type = 7 ?
                              (: t (q 'sub)
                                 r0 (t = 0 ? (q 'link)
                                       (: (fwd r k) (k > 1 ? (fwd (r 'link) (k - 1)) r)
                                          r1 (fwd q t) s (r1 'link) r2 (s 'link) (pin s 'link (),
                                                                                  pin q 'sub 0,
                                                                                  r2)))
                                 r3 (q 'post != () ?
                                       (: s (to-end (q 'post)) _ (pin s 'link r0) p (q 'post)
                                          (pin q 'post (), pin D 'pdb 1, p))
                                       r0)
                                 q3 (q 'pre != () ?
                                       (: s (q 'pre) _ (pin q 'link s) e (to-end s) (pin q 'pre (), e))
                                       q)
                                 (pin q3 'link r3, pin D 'db 1,
                                  q3))
                              (q 'type = 9 || q 'type = 11 ? (pin q 'width 0), q))
                        (rskip-after q2))
                     (rskip-after (to-end head)))
               ; leftskip, and detach the line
               r (qe 'link) _ (pin qe 'link ())
               q4 (head 'link) _ (pin head 'link r)
               q5 (zero? (P J 'leftskip) ? q4 (gluenode J (P J 'leftskip) 8 @ g (pin g 'link q4, g)))
               wi (? (cl > L 'lsl) [(L 'sw) (L 'si)] (ps = ()) [(L 'fw) (L 'fi)]
                     [(ps (cl - 1) 1) (ps (cl - 1) 0)])
               b (nd J (cb-hpack J q5 <wi 'exactly))
               _ (pin b 'shift (wi 1))
               _ (append-to-vlist J M b)
               bl (L 'bline)
               _ (cl + 1 != bl ?
                    (: pen (P J 'interlinepenalty
                            + (cl = L 'pg + 1 ? (P J 'clubpenalty) 0)
                            + (cl + 2 = bl ? fwp 0)
                            + (D 'db ? (P J 'brokenpenalty) 0))
                       (pen != 0 ? (vappend M (pennode J pen)))))
               nx (cp 'prev)
               ((? (nx != () && !(D 'pdb))
                   (: nb (nx 'cb)
                      (prune r)
                       (r 'link @ q
                          (q = () || same? q nb || char? q || q 'type < 9 || q 'type = 11 && q 'sub != 1 ? [r q]
                             (prune q)))
                      rq (prune head)
                      (? (!(same? <rq head)) (pin <rq 'link (), pin head 'link (rq 1))))),
                nx != () ? (line nx (cl + 1))))
           (line cp0 (L 'pg + 1),
            pin M 'vpg (L 'bline - 1)))
       (pass 0,
        post-line-break fwp)))
) ; module caja-par
