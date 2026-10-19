; the reader in love, rdiff.l's oracle for io.c's, in the pure lisp subset
(: ; the input is a colist; thunk tails must be memoized or idempotent
   ! nil?
   (atom? x) (! (two? x))
   (!= a b) (! (a = b))
   (caap a) <<a (caup a) <>a
   (cuap a) ><a (cuup a) >>a
   (p1-cup cl) (cup cl @ t (lit? t ? (t ()) t))

   ; char classes: 2 ws  4 opc  8 tend  16 open  32 close  64 sign  128 gstop
   ; bit 0 unused: a string indexed past its end answers 1
   (p1-cin? s c) (: n #s
                    (go k) (? (n <= k) () (s k = c) 1 (go (k + 1)))
                    (go 0))
   (p1-bits c) (((c @ 12 1 (p1-cin? " \t\n\r" c)) ? 2 0)
                + ((p1-cin? "!#$%&*+-./:<=>?@\\^|~" c ? 4 0)
                + (((c @ 12 1 (p1-cin? " \t\n\r;#()[]{}\"," c)) ? 8 0)
                + ((p1-cin? "([{" c ? 16 0)
                + ((p1-cin? ")]}" c ? 32 0)
                + ((p1-cin? "+-" c ? 64 0)
                + ((c @ 12 1 (p1-cin? " \t\n\r;)]}" c)) ? 128 0)))))))
   p1-cls (: (go k acc) (k < 0 ? (string acc) (go (k - 1) (. (p1-bits k) acc)))
             (go 255 ()))
   ; 12 spelled out: love has no \f escape, "\f" is the letter f
   (p1-ws? c)   (p1-cls c & 2)
   (p1-dig? c)  (48 <= c ? (c <= 57))
   (p1-hex? c)  (p1-dig? c ? 1 (97 <= p1-low c ? (p1-low c <= 102)))
   (p1-low c)   ((65 <= c ? (c <= 90)) ? (c + 32) c)
   (p1-opc? c)  (p1-cls c & 4)
   ; a name-led token ends here; ' is absent, so a name keeps a prime (x', n'')
   (p1-tend? c) (p1-cls c & 8)

   ; `;` and `#!` run to end of line; a bare `#` is the tally sigil
   (p1-eol cl) (? (atom? cl) cl
                  (cap cl = 10 ? 1 (cap cl = 13)) (p1-cup cl)
                  (p1-eol (p1-cup cl)))
   (p1-skip cl)
     (atom? cl ? cl
      (cap cl @ c
         (? (p1-ws? c) (p1-skip (p1-cup cl))
            (c = 59) (p1-skip (p1-eol (p1-cup cl)))
            (c @ 35 (two? (p1-cup cl) ? (cap (p1-cup cl) = 33)))
              (p1-skip (p1-eol (p1-cup (p1-cup cl))))
            cl)))

   ; integers: + and * promote charm -> sun -> big, no width to get wrong
   (p1-dval c) (p1-dig? c ? (c - 48) (p1-low c - 87))
   (p1-digits cl radix n)
     (atom? cl ? n
      (p1-digits >cl radix (n * radix + p1-dval <cl)))
   ; none of these (0x, 08, 1e5) goes to the float lane
   (p1-all? p cl) (? (atom? cl) 1 (p <cl) (p1-all? p >cl) ())
   (p1-oct? c)  (48 <= c ? (c <= 55))
   (p1-dec-int? cl)
     (? (atom? cl) ()
        ; a leading zero belongs to octal, below -- but "0" alone is decimal
        (cap cl = 48 ? (two? >cl)) ()
        (p1-all? p1-dig? cl))
   (p1-hex-int? cl)                            ; [+-]?0[xX]<hex>+, sign peeled
     (? (atom? cl) ()
        (!= <cl 48) ()
        (atom? >cl) ()
        (!= (p1-low (caup cl)) 120) ()
        (atom? (cuup cl)) ()         ; a bare 0x is an honest symbol
        (p1-all? p1-hex? (cuup cl)))
   (p1-oct-int? cl)                            ; [+-]?0<oct>+, the zero the prefix
     (? (atom? cl) ()
        (!= <cl 48) ()
        (atom? >cl) ()
        (p1-all? p1-oct? >cl))
   ; a token charlist -> (1 . its number), or (); the wrapper, as -5 and 0 net to nothing
   (p1-int cl)
     (: sgn (? (atom? cl) 0 (cap cl = 45) -1 (cap cl = 43) 1 0)
        body (sgn @ 0 cl >cl)
        mag (? (p1-dec-int? body) (. 1 (p1-digits body 10 0))
               (p1-hex-int? body) (. 1 (p1-digits >>body 16 0))
               (p1-oct-int? body) (. 1 (p1-digits >body 8 0))
               ())
        (? (atom? mag) ()
           (sgn < 0) (. 1 (0 - cup mag))
           mag))

   (p1-tok cl acc)                                   ; a name-led token
     (? (atom? cl) (. (p1-rev acc ()) cl)
        (p1-tend? <cl) (. (p1-rev acc ()) cl)
        (p1-tok (p1-cup cl) (. <cl acc)))
   (p1-rev l acc) (two? l ? (p1-rev >l (. <l acc)) acc)
   (p1-drop cl k) (0 < k ? (p1-drop (p1-cup cl) (k - 1)) cl)
   (p1-take l k acc) (0 < k ? (p1-take >l (k - 1) (. <l acc)) (p1-rev acc ()))
   ; one past a token's last operator char, or 0
   (p1-runend l i best)
     (atom? l ? best
      (p1-runend >l (i + 1) (p1-opc? <l ? (i + 1) best)))
   ; an operator run, factored later by opfix. a trailing '-' before a digit is shed as
   ; the number's sign: `!-5` is ! then -5. @ may start a run, never extend one
   (p1-run cl acc)
     ((two? cl ? (cap cl = 64 ? (atom? acc) (p1-opc? <cl))) ?
        (p1-run (p1-cup cl) (. <cl acc))
        (: shed (? (atom? acc) ()
                   (!= <acc 45) ()
                   (atom? >acc) ()
                   (atom? cl) ()
                   (p1-dig? <cl))
           (shed ? (. (p1-rev >acc ()) (. 45 cl))
              (. (p1-rev acc ()) cl))))

   ; the float lane asks gem?, not the value: an unparsed nil nets as 0.0 does
   (p1-atom tok)
     (: n (p1-int tok)
        s (string tok)
        (? (two? n) >n
           (s = "infinity") (1.0 / 0.0)
           (s = "-infinity") (-1.0 / 0.0)
           (: lead (? (atom? tok) 0
                      (p1-cls <tok & 64) (two? >tok ? (caup tok) 0)
                      <tok)
              ((p1-dig? lead ? 1 (lead = 46)) ?
                 (gem s @ f (gem? f ? f (nom s)))
                 (nom s)))))

   (p1-esc c) (c @ 110 10 116 9 114 13 101 27 48 0 c)
   ; code point v's utf-8 bytes onto acc, last first
   (p1-u8 v acc)
     (v < 128 ? (. v acc)
      (v < 2048 ? (. (128 + v % 64) (. (192 + v // 64) acc))
       (v < 65536 ?
          (. (128 + v % 64) (. (128 + v // 64 % 64) (. (224 + v // 4096) acc)))
          (. (128 + v % 64) (. (128 + v // 64 % 64)
             (. (128 + v // 4096 % 64) (. (240 + v // 262144) acc)))))))
   ; \u{h..}: 1-6 hex digits, surrogates out -> (v . rest); 'torn at an end, () if none
   (p1-uhex cl v k)
     (atom? cl ? 'torn
      (cap cl @ c
         (c @ 125 ((0 < k ? (v <= 1114111 ? (v < 55296 ? 1 (57343 < v)))) ?
                     (. v (p1-cup cl)))
              ((p1-hex? c ? (k < 6)) ?
                 (p1-uhex (p1-cup cl) (v * 16 + p1-dval c) (k + 1))))))
   (p1-ucl cl) (atom? cl ? 'torn (cap cl = 123 ? (p1-uhex (p1-cup cl) 0 0)))
   (p1-str cl acc)
     (atom? cl ? 'torn
      (: c <cl r (p1-cup cl)
         (? (c = 34) (. (string (p1-rev acc ())) r)
            (!= c 92) (p1-str r (. c acc))
            (atom? r) 'torn
            (cap r = 40) (('hole . string (p1-rev acc ())) . p1-cup r)       ; \( opens a hole
            (cap r = 117)                              ; \u{h..}, else a plain u
              (p1-ucl (p1-cup r) @ u
                 (? (u = 'torn) 'torn
                    (two? u) (p1-str >u (p1-u8 <u acc))
                    (p1-str (p1-cup r) (. 117 acc))))
            (cap r = 120)                              ; \xhh
              (! (two? (p1-cup r) ? (two? (p1-cup (p1-cup r)))) ? 'torn
               (p1-str (p1-cup (p1-cup (p1-cup r)))
                       (. (p1-dval (cap (p1-cup r)) * 16 +
                              p1-dval (cap (p1-cup (p1-cup r)))) acc)))
            (p1-str (p1-cup r) (. (p1-esc <r) acc)))))
   ; (weave [run (hole) run ..]), the runs never empty; with no hole the text itself
   (p1-weave cl parts)
     (p1-str cl () @ r
        (atom? r ? 'torn
         (: seg (two? <r ? ><r <r)
            ps (seg = "" ? parts (seg . parts))
            (two? <r ? (p1-list >r 1 () @ d (atom? d ? 'torn (p1-weave >d (<d . ps))))
             (p1-wform (p1-rev ps ()) . >r)))))
   (p1-wform ps)
     (? (atom? ps) ""
        ((atom? >ps) ? (string? <ps)) <ps
        ('weave . ('list . ps) . ()))

   ; raw texts: a longer closing run keeps its extras; a multi-line one's breaks beside the
   ; quotes are not the text's. cl at the first quote
   (p1-hws? c) (c = 32 ? 1 (c = 9))
   (p1-qrun cl k) ((two? cl ? (cap cl = 34)) ? (p1-qrun (p1-cup cl) (k + 1)) (k . cl))
   (p1-lead cl k) ((two? cl ? (p1-hws? <cl)) ? (p1-lead (p1-cup cl) (k + 1)) (k . cl))
   (p1-reps c k acc) (0 < k ? (p1-reps c (k - 1) (c . acc)) acc)
   (p1-raw cl)
     (p1-qrun cl 0 @ qr
        (: q <qr r >qr s >(p1-lead r 0)
           crlf (two? s ? (cap s = 13 ? (two? (p1-cup s) ? (cap (p1-cup s) = 10))))
           (? (two? s ? (cap s = 10)) (p1-rawml (p1-cup s) q ())
              crlf (p1-rawml (p1-cup (p1-cup s)) q ())
              (p1-raw1 r q ()))))
   (p1-raw1 cl q acc)
     (? (atom? cl) 'torn
        (!= <cl 34) (p1-raw1 (p1-cup cl) q (<cl . acc))
        (p1-qrun cl 0 @ rr
           (<rr < q ? (p1-raw1 >rr q (p1-reps 34 <rr acc))
            (string (p1-rev (p1-reps 34 (<rr - q) acc) ()) . >rr))))
   ; a line -> (its chars . rest past the break), the break's \r not the line's
   (p1-line cl acc)
     (? (atom? cl) 'torn
        (cap cl = 10) (p1-rev acc () . p1-cup cl)
        (cap cl = 13 ? (two? (p1-cup cl) ? (cap (p1-cup cl) = 10)))
          (p1-rev acc () . p1-cup (p1-cup cl))
        (p1-line (p1-cup cl) (<cl . acc)))
   ; lines is last first, each (its chars . its break), the break 10 or 13
   (p1-rawml cl q lines)
     (p1-lead cl 0 @ lr
        (p1-qrun >lr 0 @ rr
           (? (q <= <rr) (p1-rawtxt (p1-rev lines ()) <lr () . p1-drop >lr q)
              (p1-line cl () @ la
                 (atom? la ? 'torn
                  (p1-rawml >la q ((<la . p1-crlf? cl la) . lines)))))))
   ; whether the line at cl, read into la, broke on \r\n
   (p1-crlf? cl la) (p1-drop cl (p1-len <la 0) @ e (cap e = 13 ? 13 10))
   (p1-len l k) (two? l ? (p1-len >l (k + 1)) k)
   (p1-strip l w) ((0 < w ? (two? l ? (p1-hws? <l))) ? (p1-strip >l (w - 1)) l)
   (p1-rawtxt ls w acc)
     (? (atom? ls) (string (p1-rev acc ()))
        (: line (p1-rev (p1-strip <<ls w) acc)
           (atom? >ls ? (p1-rawtxt >ls w line)
            (p1-rawtxt >ls w (>(cap ls) = 13 ? (10 . 13 . line) (10 . line))))))

   ; a splicing wrap (hash tuple list) over a list splices: {k v} is (hash k v)
   (p1-splice? w) (w @ 'hash 1 (w @ 'tuple 1 (w = 'list)))
   (p1-wrap w d)
     (? (d = () ? (w = 'hash)) (. 'tablet (. 0 ()))     ; {} -> (tablet 0)
        (d = () ? (w = 'tuple)) (. 'iota (. 0 ()))      ; @() -> (iota 0)
        (p1-splice? w ? (two? d ? 1 (d = () ? (!= w 'hash)))) (. w d)
        (. w (. d ())))
   ; a bracket is its wrap: [] -> (list), {} -> (tablet 0)
   (p1-open w cl)
     (p1-list cl 1 () @ d
        (two? d ? (. (p1-wrap w <d) >d) d))

   ; head: the next datum is a list's first, for the valence law (: and ? do not fuse)
   (p1-read1 cl0 head)
     (p1-skip cl0 @ cl
        (atom? cl ? ()
         (: c <cl r (p1-cup cl)
            ; + or - before a digit or `.` (-.5) starts a number, else an operator run
            numlead (p1-cls c & 64 ? (two? r ? (p1-dig? <r ? 1 (cap r = 46))))
            (? (c = 40) (p1-list r 1 ())
               (p1-cls c & 16) (p1-open (c @ 91 'list 'hash) r)
               (p1-cls c & 32) ()
               (c = 34) ((two? r ? (cap r = 34 ? (two? (p1-cup r) ? (cap (p1-cup r) = 34)))) ?
                           (p1-raw cl) (p1-weave r ()))
               (c = 39) (p1-lift (nom "\\") r head)
               ; @ glued to an operator char is a run, not the tuple sigil; @-5 sheds as !-5
               (c = 64) (? (two? r ? (p1-opc? <r)) (p1-op cl)
                           (p1-glued? r) (p1-lift 'tuple r head)
                           (. (nom "@") r))
               (c = 44) (. (nom ",") r)
               (p1-opc? c ? (! numlead)) (p1-op cl)
               (p1-dig? c) (p1-nop cl)
               (p1-tok cl () @ tr
                  (. (p1-atom <tr) >tr))))))

   ; an unfinished datum is torn, never EOF. a splicing sigil over an open form renames
   ; the wrap: @[1 2] is @(1 2), not (tuple list 1 2)
   (p1-lift w cl head)
     (: s (p1-skip cl)
        open (p1-splice? w ? (two? s ? (p1-cls <s & 16)))
        (open ? (p1-open w (p1-cup s))
           (p1-read1 s head @ d
              (atom? d ? 'torn
               (. (p1-wrap w <d) >d)))))

   ; the valence law: a run glued to the next datum reads (mono (run d)); spaced it is
   ; the plain symbol. \ never fuses
   (p1-op cl)
     (: rr (p1-run cl ())
        run (string <rr)
        rest >rr
        sym (nom run)
        shed (two? rest ? (cap rest = 45))    ; p1-run put a sign back: glued
        (? (run = "\\") (. sym rest)
           (! (shed ? 1 (p1-glued? rest))) (. sym rest)
           (p1-read1 rest () @ d
              (atom? d ? 'torn
               (. (. 'mono (. (. sym (. <d ())) ())) >d)))))
   ; a digit-led token is cut at its last sigil: 2?<>x is 2?<> around x; a numeral wins first
   (p1-nop cl)
     (: tr (p1-tok cl ())
        tok <tr rest >tr a (p1-atom tok)
        k0 (p1-runend tok 0 0)
        lastc (cap (p1-drop cl (0 < k0 ? (k0 - 1) 0)))
        shed (? (1 >= k0) ()
                (!= lastc 45) ()
                (p1-drop cl k0 @ r0 (two? r0 ? (p1-dig? <r0))))
        k (shed ? (k0 - 1) k0)
        r (p1-drop cl k)
        (? (! (nom? a)) (. a rest)                  ; a numeral: untouched
           (0 >= k) (. a rest)                   ; no sigil: a plain name-led token
           (! (p1-glued? r)) (. a rest)             ; run ends the form: the plain symbol
           (: sym (nom (string (p1-take tok k ())))
              d (p1-read1 r ())
              (atom? d ? 'torn
               (. (. 'mono (. (. sym (. <d ())) ())) >d)))))
   ; the next char starts a datum rather than ending the form
   (p1-glued? cl)
     (two? cl ? (cap cl @ c (! (p1-cls c & 128))))

   ; a list: datums until the close; ) ] } are one closer, so a crossed pair reads silently
   (p1-list cl0 head acc)
     (p1-skip cl0 @ cl
        (? (atom? cl) 'torn
           (p1-cls <cl & 32) (. (p1-rev acc ()) (p1-cup cl))
           (p1-read1 cl head @ d (atom? d ? 'torn (p1-list >d () (. <d acc))))))

   (p1-chars s)
     (: n #s
        (go k acc) (k < 0 ? acc (go (k - 1) (. (s k) acc)))
        (go (n - 1) ()))

   ; (datum . rest), () at a clean end, or `torn`, off a port, string, unforced tail or
   ; residue; the residue is always a charlist
   (x \ (p1-read1 (? (string? x)  (p1-chars x)
                     (port? x)    (flow x)
                     (lit? x)     (x ())
                     x) ())))
