; apps/caja/cell.l -- caja on a terminal: lapiz's middle set in cells and shipped as text.
; `(borrow 'caja-cell)`. the blocks are ttyshow's (apps/lapiz.l), the lines caja's:
;
;   (cc-show d w)   the document d as ttyshow lays it at width w, each paragraph broken by
;                   line_break into a ragged right -- the fewest demerits, not the greedy fill
;
; a cell font is a TFM's shape: a character as wide as the cells wcwidth gives it, a space one
; cell that neither stretches nor shrinks, and \rightskip the only stretch in a line. caja
; codes a character in a byte, so a plane of fonts holds 255 of them: ASCII as itself, the
; rest in the order they come, and a new plane when one is full. a font is a plane and an SGR
; attribute. a fence, a table, a rule and the .th line are ttyshow's lines, set as boxes.
(module (caja-cell cc-show)
(borrow 'text)
(borrow 'lapiz)
(borrow 'caja-box)
(borrow 'caja-par)
(:
   U 65536                                    ; a cell
   L (12 * U)                                 ; a line, baseline to baseline
   NS 8                                       ; the attributes a plane has fonts for
   hss ['skip 0 65536 1 65536 1]
   gap ['vskip L 0 0 0 0]
   free (map (+ 128) ^128 + map (+ 1) ^31 + [127])
   ttoff (string 27 + "[0m")
   (tton a) (string 27 + "[" + a + "m")
   (ttadd a b) (? #a (a + ";" + b) b)
   (spaces n) (: (go k s) (? (k < 1) s (go (k - 1) (s + " "))) (go n ""))
   (lines s) (: n #s
                (go i a acc) (? (i >= n) (rev (? (a < n) (snip s a n . acc) acc))
                                (s i = 10) (go (i + 1) (i + 1) (snip s a i . acc))
                                (go (i + 1) a acc))
                (go 0 0 ()))

   ; --- the fonts ------------------------------------------------------------------------------
   (glyph t s c) (pin (t 'ci) s [(wcwidth c @ 1 1 2 2 3) 17 0 0])
   (plane J)
    (: n #(J 'planes)
       t {'check [0 0 0 0] 'dsize (10 * U) 'size (10 * U) 'bc 0 'ec 255 'ci {}
          'wd {0 0 1 U 2 (2 * U) 3 0} 'ht {0 0 1 (8 * U)} 'dp {0 0 1 (3 * U)} 'ic {0 0}
          'nl 0 'lig {} 'kern {} 'ext {} 'np 7 'param {1 0 2 U 3 0 4 0 5 (8 * U) 6 U 7 0}
          'bchar 256 'blabel () 'fbchar 256}
       _ (map (c \ glyph t c c) (map (+ 32) ^95))
       _ (map (s \ pin (J 'fonts) (1 + (NS * n) + s) {'tfm t 'name "cell" 'area "" 'used 0}) ^NS)
       _ (pin J 'nfonts (NS * (n + 1)))
       p {'t t 'cp {} 'free free 'n n}
       _ (pin J 'planes (J 'planes + [p]))
       p)
   ; [plane slot] for the code point c
   (slot J c)
    (? (32 <= c && c < 127) [(J 'cur) c]
       (: w (peep (J 'where) c ())
          (? (w != ()) w
             (: p0 (J 'planes (J 'cur))
                p (? (two? (p0 'free)) p0 (: q (plane J) _ (pin J 'cur (q 'n)) q))
                s <(p 'free) _ (pin p 'free >(p 'free))
                _ (glyph (p 't) s c) _ (pin (p 'cp) s c)
                r [(p 'n) s] _ (pin (J 'where) c r)
                r))))
   (sty J a)
    (: i (peep (J 'sty) a ())
       (? (i != ()) i
          (: n #(keys (J 'sty)) (? (n >= NS) 0 (: _ (pin (J 'sty) a n) _ (pin (J 'stys) n a) n)))))
   ; left to right: a character ['ch a c] its font and slot, a font token where it changes
   (resolve J ts)
    (: (go l acc)
        (? (!(two? l)) (rev acc)
           (: t <l
              (? (two? t && t 0 = 'ch)
                  (: ps (slot J (t 2)) f (1 + (NS * ps 0) + sty J (t 1))
                     a2 (? (f = J 'curf) acc (: _ (pin J 'curf f) (['f f] . acc)))
                     (go >l (['c (ps 1)] . a2)))
                 ; a box's font changes stay in the box
                 (two? t && t 0 = 'hbox)
                  (: f0 (J 'curf) b (resolve J (t 2)) _ (pin J 'curf f0) (go >l (['hbox (t 1) b] . acc)))
                 (go >l (t . acc)))))
       (go ts ()))

   ; --- text -------------------------------------------------------------------------------------
   (space? c) (elem c [32 9 10 13])
   (text-toks a s) (map (c \ (? (space? c) 'sp ['ch a c])) (cps s))
   ; spaces as a line wants them: none at either end, a run one
   (squeeze ts)
    (: (go l acc)
        (? (!(two? l)) (rev (? (two? acc && <acc = 'sp) >acc acc))
           (<l = 'sp) (go >l (? (!(two? acc) || <acc = 'sp) acc ('sp . acc)))
           (go >l (<l . acc)))
       (go ts ()))
   (inl a l)
    (cats (map (x \ (<x @ 'text (text-toks a <>x)
                         'code (text-toks a <>x)
                         'strong (inl (ttadd a "1") <>x)
                         'em (inl (ttadd a "4") <>x)
                         'link (inl a <>x + (? #<>>x ('sp . text-toks a ("<" + <>>x + ">")) []))
                         'img (? #<>x (text-toks a ("[" + <>x + "]")) [])
                         []))
               l))
   (cells ts) (net (map (t \ (? (t = 'sp) 1 (max 0 (wcwidth (t 2))))) ts))

   ; --- blocks -------------------------------------------------------------------------------------
   ; a paragraph at ind, its lines after the first hung by hang, the first led by a label box
   (par ind hang label body)
    (: b (squeeze body)
       (? (label = () && !(two? b)) []
          ([['set 'leftskip [(ind * U) 0 0 0 0]] ['set 'hangindent (hang * U)] 'noindent]
           + (? (label = ()) [] [['hbox (hang * U) (label + [hss])]])
           + b + ['par])))
   (verb ind s)
    ['hbox () ([['kern (ind * U)]] + map (c \ (? (c = 32) ['kern U] ['ch "" c])) (cps s))]
   (item ind mk l) (par ind (swidth mk) (text-toks "" mk) (inl "" l))
   (join-gap ls) (? (!(two? ls)) [] (!(two? >ls)) <ls (<ls + [gap] + join-gap >ls))
   ; a term short enough keeps its definition beside it
   (defs l ind)
    (join-gap (map (it \ (: tm (squeeze (inl "" <it)) df (inl "" <>it) n (cells tm)
                            (? (0 < n && n < 7 && two? (squeeze df)) (par ind 7 tm df)
                               (par ind 0 () tm + par (ind + 7) 0 () df))))
                   l))
   (unpad l) (? (5 <= #l) (snip l 5 #l) l)
   (blk x w ind)
    (<x @ 'meta    (map (verb 0) (lines (ttyshow [x] w)))
          'head    (par (? (<>x < 2) 0 3) 0 () (inl "1" <>>x))
          'para    (par ind 0 () (inl "" <>x))
          'fence   (map (verb ind) (lines <>>x))
          'quote   (doc <>x w (ind + 4))
          'bullets (cats (map (l \ item ind "• " l) <>x))
          'numbers (: l <>x (cats (map (k \ item ind (show (k + 1) + ". ") (l k)) ^#l)))
          'deflist (defs <>x ind)
          'table   (map (l \ verb ind (unpad l)) (lines (ttyshow [x] (w - ind + 5))))
          'rule    [(verb ind (: n (w - ind) (: (go k s) (? (k < 1) s (go (k - 1) (s + "-"))) (go (max 1 n) ""))))]
          [])
   ; one blank line between blocks, none after a heading
   (doc d w ind)
    (? (!(two? d)) []
       (: h (blk <d w ind) r (doc >d w ind)
          (? (!(two? h)) r (!(two? r)) h
             (<(<d) = 'head) (h + r)
             (h + [gap] + r))))

   ; --- the shipper ----------------------------------------------------------------------------------
   (glue-width b g)
    (: w (g 'width)
       (? (b 'gsign = 1 && g 'sto = b 'gorder) (w + int (b 'gset * g 'stretch + 0.5))
          (b 'gsign = 2 && g 'sho = b 'gorder) (w - int (b 'gset * g 'shrink + 0.5))
          w))
   ; a font's character as [bytes cells attribute width], kept once made
   (glyph-of J f s)
    (: k (f * 256 + s) g (peep (J 'gc) k ())
       (? (g != ()) g
          (: pl (J 'planes ((f - 1) // NS)) tf (pl 't)
             c (? (32 <= s && s < 127) s (pl 'cp s))
             g2 [(utf8 c) (max 0 (wcwidth c)) (J 'stys ((f - 1) % NS)) (tf 'wd <(tf 'ci s))]
             _ (pin (J 'gc) k g2)
             g2)))
   ; a line's text: each glyph at its cell, an attribute closed at every space
   (hline J b0)
    (: S {'col 0 'sty "" 'acc ()}
       (put s) (pin S 'acc (s . S 'acc))
       (plain _) (? #(S 'sty) (: _ (put ttoff) (pin S 'sty "")))
       (walk b x0)
        (: (go p x)
            (? (p = ()) x
               (: t (p 'type)
                  (? (t = 'char)
                      (: g (glyph-of J (p 'font) (p 'char)) a (g 2)
                         k ((x + (U // 2)) // U)
                         _ (? (S 'col < k) (: _ (plain 0) _ (put (spaces (k - S 'col))) (pin S 'col k)))
                         _ (? (a != S 'sty) (: _ (plain 0) _ (? #a (put (tton a))) (pin S 'sty a)))
                         _ (put (g 0))
                         _ (pin S 'col (S 'col + g 1))
                         (go (p 'link) (x + g 3)))
                     (t = 0) (: _ (walk p x) (go (p 'link) (x + p 'width)))
                     (t = 10) (: _ (plain 0) (go (p 'link) (x + glue-width b (p 'glue))))
                     (t = 11 || t = 2) (go (p 'link) (x + p 'width))
                     (go (p 'link) x))))
           (go (b 'list) x0))
       _ (walk b0 (b0 'shift))                ; a hung line is shifted
       _ (plain 0)
       (join "" (rev (S 'acc))))
   ; the vlist's lines, each [baseline text]
   (rows J p0)
    (: (go p y acc)
        (? (p = ()) (rev acc)
           (: t (p 'type)
              (? (t = 0) (: yb (y + p 'height) (go (p 'link) (yb + p 'depth) ([yb (hline J p)] . acc)))
                 (t = 1 || t = 2) (go (p 'link) (y + p 'height + p 'depth) acc)
                 (t = 10) (go (p 'link) (y + (p 'glue) 'width) acc)
                 (t = 11) (go (p 'link) (y + p 'width) acc)
                 (go (p 'link) y acc))))
       (go p0 0 ()))
   ; a line to each row, a blank row where no line fell
   (text rs)
    (? (!(two? rs)) ""
       (: y0 (<rs 0)
          (go l r acc)
           (? (!(two? l)) (join "" (rev acc))
              (: e <l k ((e 0 - y0 + (L // 2)) // L)
                 (go >l (k + 1) ((e 1 + "\n") . (map (_ \ "\n") ^(k - r) + acc)))))
          (go rs 0 ())))

   (cc-show d w0)
    (: w (? (w0 < 20) 20 w0)
       J (cp-setup (cb-job 0))
       _ (pin J 'planes ()) _ (pin J 'cur 0) _ (pin J 'where {}) _ (pin J 'curf ())
       _ (pin J 'sty {"" 0}) _ (pin J 'stys {0 ""}) _ (pin J 'gc {})
       _ (plane J)
       params [['set 'hsize (w * U)] ['set 'pretolerance 10000] ['set 'tolerance 10000]
               ['set 'linepenalty 10] ['set 'hangafter 1] ['set 'parindent 0]
               ['set 'rightskip [0 (max 8 (w // 3) * U) 0 0 0]] ['set 'parfillskip [0 65536 1 0 0]]
               ['set 'baselineskip [L 0 0 0 0]] ['set 'lineskip [0 0 0 0 0]] ['set 'parskip [0 0 0 0 0]]]
       M (cp-run J (cp-mode J) (resolve J (params + doc d w 5)))
       (text (rows J (cp-vlist J M)))))
) ; module caja-cell
