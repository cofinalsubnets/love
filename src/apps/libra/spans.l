; src/apps/libra/spans.l -- the slow reader: test/host/p1.l's grammar over a string by index,
; keeping where each form sits and the comments beside it. `sound` stays the fast one.
;
; (spans s)       s's forms as nodes, each [form [from to] notes]: from and to are byte
;                 offsets into s, to one past the form's end; a list's form is its nodes, a
;                 reader-made head (list, hash, tuple, mono, \, weave ..) a node over the sigil
;                 or bracket that made it. notes are [text [from to]] for the comments before
;                 the node, after the one before it, and one closing its line; a list keeps
;                 those before its closer, the last top form those at the end
; (spans-strip n) the form a node reads as: map spans-strip over spans equals sound's forms
; (spans-forms s) sound's forms of s, the law's other side
;
(module (spans spans spans-strip spans-forms)
(: ; char classes: 2 ws  4 opc  8 tend  16 open  32 close  64 sign  128 gstop
   (sp-in? s c) (: n #s (go k) (? (n <= k) () (s k = c) 1 (go (k + 1))) (go 0))
   (sp-bits c) (((c @ 12 1 (sp-in? " \t\n\r" c)) ? 2 0)
                + ((sp-in? "!#$%&*+-./:<=>?@\\^|~" c ? 4 0)
                + (((c @ 12 1 (sp-in? " \t\n\r;#()[]{}\"," c)) ? 8 0)
                + ((sp-in? "([{" c ? 16 0)
                + ((sp-in? ")]}" c ? 32 0)
                + ((sp-in? "+-" c ? 64 0)
                + ((c @ 12 1 (sp-in? " \t\n\r;)]}" c)) ? 128 0)))))))
   sp-cls (: (go k acc) (k < 0 ? (string acc) (go (k - 1) (sp-bits k . acc))) (go 255 ()))
   (sp-dig? c) (48 <= c && c <= 57)
   (sp-low c) (65 <= c && c <= 90 ? (c + 32) c)
   (sp-hex? c) (sp-dig? c || (97 <= sp-low c && sp-low c <= 102))
   (sp-oct? c) (48 <= c && c <= 55)
   (sp-dval c) (sp-dig? c ? (c - 48) (sp-low c - 87))
   (sp-hws? c) (c = 32 || c = 9)

   ; a token's chars -> its atom, as p1-atom: none of 0x, 08, 1e5 goes to the float lane
   (sp-all? p l) (? !(two? l) 1 (p <l) (sp-all? p >l) ())
   (sp-digits l radix v) (!(two? l) ? v (sp-digits >l radix (v * radix + sp-dval <l)))
   (sp-int l)
    (: sgn (? !(two? l) 0 (<l = 45) -1 (<l = 43) 1 0)
       b (sgn = 0 ? l >l)
       z (two? b && <b = 48 && two? >b)
       dec (two? b && !z && sp-all? sp-dig? b)
       hex (z && sp-low <>b = 120 && two? >>b && sp-all? sp-hex? >>b)
       oct (z && sp-all? sp-oct? >b)
       v (? dec (sp-digits b 10 0) hex (sp-digits >>b 16 0) oct (sp-digits >b 8 0) 0)
       (? !(dec || hex || oct) () (sgn < 0) (. 1 (0 - v)) (. 1 v)))
   (sp-atom l)
    (: v (sp-int l) s (string l)
       (? (two? v) >v
          (s = "infinity") (1.0 / 0.0)
          (s = "-infinity") (-1.0 / 0.0)
          (: lead (? !(two? l) 0 (sp-cls <l & 64) (two? >l ? <>l 0) <l)
             (sp-dig? lead || lead = 46 ? (gem s @ f (gem? f ? f (nom s))) (nom s)))))

   (sp-esc c) (c @ 110 10 116 9 114 13 101 27 48 0 c)
   (sp-u8 v acc)
    (v < 128 ? (. v acc)
     (v < 2048 ? (. (128 + v % 64) (. (192 + v // 64) acc))
      (v < 65536 ? (. (128 + v % 64) (. (128 + v // 64 % 64) (. (224 + v // 4096) acc)))
       (. (128 + v % 64) (. (128 + v // 64 % 64) (. (128 + v // 4096 % 64) (. (240 + v // 262144) acc)))))))
   (sp-cp? v) (v <= 1114111 && (v < 55296 || 57343 < v))
   (sp-reps c k acc) (0 < k ? (sp-reps c (k - 1) (c . acc)) acc)

   (nd f a b ns) [f [a b] ns]
   (sp-note d m) (d @ [f sp ns] [f sp (ns + [m])])
   (sp-lead d ns) (d @ [f sp m] [f sp (ns + m)])
   (sp-note2 d ns) (d @ [f sp m] [f sp (m + ns)])

   (spans s)
    (: n #s
       (ch i) (i < n ? (s i) -1)
       (cls i) (i < n ? (sp-cls (s i)) 0)
       (ws? i) ((cls i) & 2)
       (opc? i) ((cls i) & 4)
       (glued? i) (i < n && !((cls i) & 128))
       (eol i) (? (n <= i) i (ch i = 10 || ch i = 13) i (eol (i + 1)))
       (cut a b) (snip s a b)
       ; past whitespace and comments: (j . notes), the notes in order
       (skip i ns)
        (? (n <= i) (i . rev ns)
           (ws? i) (skip (i + 1) ns)
           (ch i = 59 || (ch i = 35 && ch (i + 1) = 33))
            (: e (eol i) (skip (e < n ? (e + 1) e) ([(cut i e) [i e]] . ns)))
           (i . rev ns))
       (lined? a b) (? (b <= a) 1 (ch a = 10) () (lined? (a + 1) b))

       ; datums until the closer: [nodes inner-notes past] or torn; the first note after a
       ; node, on the line it ends on, is that node's
       (took? acc ns) (two? ns && two? acc && lined? (acc 0 1 1) (ns 0 1 0))
       (items i acc)
        (skip i () @ (j . ns)
           (: tk (took? acc ns)
              acc2 (tk ? (sp-note <acc <ns . >acc) acc)
              ns2 (tk ? >ns ns)
              (? (n <= j) 'torn
                 ((cls j) & 32) [(rev acc2) ns2 (j + 1)]
                 (datum j @ 'torn 'torn [d k] (items k (sp-lead d ns2 . acc2))))))
       ; a skip, then one datum with the notes before it: [node past], torn, or () at a closer or the end
       (read1 i)
        (skip i () @ (j . ns)
           (? (n <= j || ((cls j) & 32)) ()
              (datum j @ 'torn 'torn [d k] [(sp-lead d ns) k])))
       (bracket w i)
        (items (i + 1) () @ 'torn 'torn
           [ds ns k] [(wrap (nd w i (i + 1) ()) ds i k) ns k])
       (wrap h ds a b)
        (: w (h 0)
           (? (ds = () && w = 'hash) [(nd 'tablet a (a + 1) ()) (nd 0 a b ())]
              (ds = () && w = 'tuple) [(nd 'iota a (a + 1) ()) (nd 0 a b ())]
              (h . ds)))

       (datum i)
        (: c (ch i)
           numlead (((cls i) & 64) && i + 1 < n && (sp-dig? (ch (i + 1)) || ch (i + 1) = 46))
           (? (c = 40) (items (i + 1) () @ 'torn 'torn [ds ns k] [(nd ds i k ns) k])
              ((cls i) & 16) (bracket (c @ 91 'list 'hash) i @ 'torn 'torn [f ns k] [(nd f i k ns) k])
              (c = 34) (ch (i + 1) = 34 && ch (i + 2) = 34 ? (raw i) (weave i (i + 1) (i + 1) ()))
              (c = 39) (lift (nom "\\") i (i + 1))
              (c = 64) (? (opc? (i + 1)) (op i)
                          (glued? (i + 1)) (lift 'tuple i (i + 1))
                          [(nd (nom "@") i (i + 1) ()) (i + 1)])
              (c = 44) [(nd (nom ",") i (i + 1) ()) (i + 1)]
              ((opc? i) && !numlead) (op i)
              (sp-dig? c) (nop i)
              (tok i @ k [(nd (sp-atom (chars i k)) i k ()) k])))
       (chars a b) (: (go k acc) (k < a ? acc (go (k - 1) (s k . acc))) (go (b - 1) ()))
       (tok i) (? (n <= i) i ((cls i) & 8) i (tok (i + 1)))

       ; a sigil over the next datum; a splicing one over an open form renames the wrap
       (lift w a i)
        (: h (nd w a (a + 1) ())
           (skip i () @ (j . ns)
              (? (sp-splice? w && j < n && ((cls j) & 16))
                  (items (j + 1) () @ 'torn 'torn
                     [ds ns2 k] [(nd (wrap h ds a k) a k (ns + ns2)) k])
                 (n <= j || ((cls j) & 32)) 'torn
                 (datum j @ 'torn 'torn [d k] [(nd (wrapd h (sp-lead d ns) a k) a k ()) k]))))
       (sp-splice? w) (w = 'hash || w = 'tuple || w = 'list)
       ; p1-wrap over a datum node: a splicing wrap takes a list's nodes as its own
       (wrapd h d a b)
        (: w (h 0) f (d 0)
           (? (f = () && w = 'hash) [(nd 'tablet a (a + 1) ()) (nd 0 a b ())]
              (f = () && w = 'tuple) [(nd 'iota a (a + 1) ()) (nd 0 a b ())]
              (sp-splice? w && (two? f || (f = () && w != 'hash))) (h . f)
              [h d]))

       ; an operator run, @ only first; a trailing - before a digit is the number's sign
       (run i k) (? (i + k < n && (ch (i + k) = 64 ? (k = 0) (opc? (i + k)))) (run i (k + 1)) k)
       (op i)
        (: k0 (run i 0)
           shed (1 < k0 && ch (i + k0 - 1) = 45 && sp-dig? (ch (i + k0)))
           r (shed ? (i + k0 - 1) (i + k0))
           sym (nom (cut i r))
           (? (cut i r = "\\") [(nd sym i r ()) r]
              !(shed || glued? r) [(nd sym i r ()) r]
              (fuse sym i r)))
       (fuse sym i r)
        (read1 r @ () 'torn 'torn 'torn
           [d k] [(nd [(nd 'mono i r ()) (nd [(nd sym i r ()) d] i k ())] i k ()) k])
       ; a digit-led token is cut at its last sigil: 2?<>x is 2?<> around x; a numeral wins first
       (nop i)
        (: e (tok i) l (chars i e) a (sp-atom l)
           (lst j best) (j < e ? (lst (j + 1) (opc? j ? (j + 1 - i) best)) best)
           k0 (lst i 0)
           shed (1 < k0 && ch (i + k0 - 1) = 45 && sp-dig? (ch (i + k0)))
           r (i + (shed ? (k0 - 1) k0))
           (? (!(nom? a) || r <= i || !(glued? r)) [(nd a i e ()) e]
              (fuse (nom (cut i r)) i r)))

       ; a string's run up to its quote or a hole: [hole? text past] or torn
       (str i acc)
        (? (n <= i) 'torn
           (ch i = 34) [0 (string (rev acc)) (i + 1)]
           (ch i != 92) (str (i + 1) (ch i . acc))
           (n <= i + 1) 'torn
           (: c (ch (i + 1))
              (? (c = 40) [1 (string (rev acc)) (i + 2)]
                 (c = 117) (ucl (i + 2) @ 'torn 'torn [v j] (str j (sp-u8 v acc)) _ (str (i + 2) (117 . acc)))
                 (c = 120) (? (n <= i + 3) 'torn (str (i + 4) (sp-dval (ch (i + 2)) * 16 + sp-dval (ch (i + 3)) . acc)))
                 (str (i + 2) (sp-esc c . acc)))))
       ; \u{h..} 1-6 digits or \uhhhh, surrogates out: [v past], () when none, torn at an end
       (ucl i) (? (n <= i) 'torn (ch i = 123) (uhex (i + 1) 0 0) (u4 i 0 0))
       (uhex i v k)
        (? (n <= i) 'torn
           (ch i = 125) (0 < k && sp-cp? v ? [v (i + 1)] ())
           (sp-hex? (ch i) && k < 6) (uhex (i + 1) (v * 16 + sp-dval (ch i)) (k + 1))
           ())
       (u4 i v k)
        (? (k = 4) (v < 55296 || 57343 < v ? [v i] ())
           (n <= i) 'torn
           (sp-hex? (ch i)) (u4 (i + 1) (v * 16 + sp-dval (ch i)) (k + 1))
           ())
       ; (weave [run (hole) run ..]), the runs never empty; with no hole the text itself
       (weave q i a ps)
        (str i () @ 'torn 'torn
           [h t j] (: ps2 (t = "" ? ps (nd t a (h ? (j - 2) (j - 1)) () . ps))
                      (? h (items j () @ 'torn 'torn [ds ns k] (weave q k k (nd ds (j - 1) k ns . ps2)))
                         [(wform (rev ps2) q j) j])))
       (wform ps a b)
        (? !(two? ps) (nd "" a b ())
           (!(two? >ps) && string? (<ps 0)) (nd (<ps 0) a b ())
           (nd [(nd 'weave a (a + 1) ()) (nd ((nd 'list a (a + 1) ()) . ps) a b ())] a b ()))

       ; raw texts: three or more quotes; one ending its line closes on a line of its own
       (qrun i k) (ch (i + k) = 34 ? (qrun i (k + 1)) k)
       (lead i k) (sp-hws? (ch (i + k)) ? (lead i (k + 1)) k)
       (raw i)
        (: q (qrun i 0) r (i + q) e (r + lead r 0)
           (? (ch e = 10) (rawml i (e + 1) q ())
              (ch e = 13 && ch (e + 1) = 10) (rawml i (e + 2) q ())
              (raw1 i r q ())))
       (raw1 a i q acc)
        (? (n <= i) 'torn
           (ch i != 34) (raw1 a (i + 1) q (ch i . acc))
           (: k (qrun i 0)
              (k < q ? (raw1 a (i + k) q (sp-reps 34 k acc))
               [(nd (string (rev (sp-reps 34 (k - q) acc))) a (i + k) ()) (i + k)])))
       ; lines last first, each [chars crlf?]
       (rawml a i q ls)
        (: w (lead i 0) k (qrun (i + w) 0)
           (? (q <= k) [(nd (rawtxt (rev ls) w ()) a (i + w + q) ()) (i + w + q)]
              (line i @ 'torn 'torn [l crlf j] (rawml a j q ([l crlf] . ls)))))
       (line i) (: (go j) (? (n <= j) 'torn
                              (ch j = 10) [(chars i j) 0 (j + 1)]
                              (ch j = 13 && ch (j + 1) = 10) [(chars i j) 1 (j + 2)]
                              (go (j + 1)))
                   (go i))
       (strip l w) (0 < w && two? l && sp-hws? <l ? (strip >l (w - 1)) l)
       (rawtxt ls w acc)
        (? !(two? ls) (string (rev acc))
           (: a2 (rev (strip (<ls 0) w) + acc)
              (!(two? >ls) ? (rawtxt >ls w a2)
               (rawtxt >ls w (<ls 1 ? (10 . 13 . a2) (10 . a2))))))

       ; the top: datums to the end or a stray closer, the last taking the notes after it
       (top i acc)
        (skip i () @ (j . ns)
           (: tk (took? acc ns)
              acc2 (tk ? (sp-note <acc <ns . >acc) acc)
              ns2 (tk ? >ns ns)
              (? (n <= j || ((cls j) & 32))
                  (rev (two? acc2 && two? ns2 ? (sp-note2 <acc2 ns2 . >acc2) acc2))
                 (datum j @ 'torn (scare 'unfinished-form j) [d k] (top k (sp-lead d ns2 . acc2))))))
       (top 0 ()))

   (spans-strip x) (x 0 @ f (two? f ? (map spans-strip f) f))
   (spans-forms s) (: (go x acc) (sound x @ 'torn (scare 'unfinished-form s) (a . b) (go b (a . acc)) (rev acc))
                      (go s ())))
) ; module spans
