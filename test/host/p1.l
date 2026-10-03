; test/host/p1.l -- the reader in love, the oracle test/host/rdiff.l holds sound (the reader
; in src/love/io.c, ported from this) to. one form, whose value is the reader. written in the
; pure lisp subset, since it was once read by a reader of only that.
(: ; the input is a colist. thunk tails must be memoized or idempotent.
   ! nil?
   (atom? x) (! (two? x))
   (!= a b) (! (a = b))
   (caap a) <<a (caup a) <>a
   (cuap a) ><a (cuup a) >>a
   (p1-cup cl) (cup cl @ t (lit? t ? (t ()) t))

   ; --- char classes (love.c's op_break / ioread1sym terminators) -----------
   ; --- the class table ------------------------------------------------------
   ; one 256-byte string, a bitmask per char, so a membership test is an index
   ; and an `&` where it used to be a scan over a class string -- with a fresh
   ; closure and a `tally` minted per call, which is what made it the reader's
   ; whole cost (`p1-tend?` walked 15 chars for every character of every token).
   ; bit 0 is left unused on purpose: a string indexed past its end answers the
   ; charm 1, so a char outside 0..255 would match whichever class held bit 0.
   ; with bit 0 empty, (& 1 m) is 0 for every mask below and an out-of-range
   ; charm matches nothing -- which is exactly what the scan it replaces said.
   ;   2 ws   4 opc   8 tend   16 open   32 close   64 sign   128 gstop
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
   ; 12 is spelled out, here and in every class below: love's escapes are
   ; n t r e 0 x u and nothing else, so "\f" in a love string is the letter f --
   ; which would quietly make f whitespace and eat it out of `infinity`.
   (p1-ws? c)   (p1-cls c & 2)
   (p1-dig? c)  (48 <= c ? (c <= 57))
   (p1-hex? c)  (p1-dig? c ? 1 (97 <= p1-low c ? (p1-low c <= 102)))
   (p1-low c)   ((65 <= c ? (c <= 90)) ? (c + 32) c)
   ; op_break complemented: the chars that fuse into one operator run.
   (p1-opc? c)  (p1-cls c & 4)
   ; a name-led token ends here (love.c's ioread1sym switch). ' is absent --
   ; a name keeps a trailing/internal prime (x', n''); a leading ' is quote and
   ; never reaches the token lane.
   (p1-tend? c) (p1-cls c & 8)

   ; --- whitespace and comments --------------------------------------------
   ; `;` runs to end of line; `#!` does too; a bare `#` is the tally sigil.
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

   ; --- integers, at full precision ----------------------------------------
   ; love's + and * promote charm -> sun -> big by VALUE, so the tower is the
   ; arithmetic's and there is no width to get wrong (rung 2's law).
   (p1-dval c) (p1-dig? c ? (c - 48) (p1-low c - 87))
   (p1-digits cl radix n)
     (atom? cl ? n
      (p1-digits >cl radix (n * radix + p1-dval <cl)))
   ; the three predicates, love.c's is_dec_int / is_hex_int / is_oct_int. they
   ; are exhaustive over what a base-0 strtol took whole, which is why a token
   ; that is none of them (0x, 08, 1e5, abc) goes on to the float lane.
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
   ; a token charlist -> (1 . its number), or () if it is not one. the sign is
   ; peeled first so every base agrees about it.
   ; the wrapper is the presence, never the net. -5 and 0 both net to nothing,
   ; so a bare answer tested with nil? calls every negative and every zero "not
   ; a number" -- silently, and only for the literals most likely to matter.
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

   ; --- the token lanes -----------------------------------------------------
   (p1-tok cl acc)                                   ; a name-led token
     (? (atom? cl) (. (p1-rev acc ()) cl)
        (p1-tend? <cl) (. (p1-rev acc ()) cl)
        (p1-tok (p1-cup cl) (. <cl acc)))
   (p1-rev l acc) (two? l ? (p1-rev >l (. <l acc)) acc)
   (p1-drop cl k) (0 < k ? (p1-drop (p1-cup cl) (k - 1)) cl)
   (p1-take l k acc) (0 < k ? (p1-take >l (k - 1) (. <l acc)) (p1-rev acc ()))
   ; one past a token's last operator char, or 0 -- where its run ends.
   (p1-runend l i best)
     (atom? l ? best
      (p1-runend >l (i + 1) (p1-opc? <l ? (i + 1) best)))
   ; an operator run: a maximal run of operator chars, read as one plain symbol
   ; and factored later by opfix. a trailing '-' right before a digit is the
   ; next number's sign, not part of the run -- the run sheds it and the '-' is
   ; put back, so `!-5` is ! then -5.
   ; @ may start a run (@- and friends) but never extend one: past the first char it
   ; is the tuple sigil, so `!@0` is ! then @0 and not the symbol !@.
   (p1-run cl acc)
     ((two? cl ? (cap cl = 64 ? (atom? acc) (p1-opc? <cl))) ?
        (p1-run (p1-cup cl) (. <cl acc))
        ; the run ended: shed a trailing '-' if a digit follows and the run has
        ; more than that '-' to it, and hand the '-' back for the number lane.
        (: shed (? (atom? acc) ()
                   (!= <acc 45) ()
                   (atom? >acc) ()
                   (atom? cl) ()
                   (p1-dig? <cl))
           (shed ? (. (p1-rev >acc ()) (. 45 cl))
              (. (p1-rev acc ()) cl))))

   ; --- an atom: integer, then the named floats, then float, then symbol -----
   ; and the float lane asks the type, not the value: gem answers nil on a
   ; token it could not parse, and nil is the charm 0 -- indistinguishable by
   ; net from the float 0.0 it answers for "0.0". gem? separates them.
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

   ; --- strings -------------------------------------------------------------
   (p1-esc c) (c @ 110 10 116 9 114 13 101 27 48 0 c)
   ; code point v's utf-8 bytes onto acc, last first
   (p1-u8 v acc)
     (v < 128 ? (. v acc)
      (v < 2048 ? (. (128 + v % 64) (. (192 + v // 64) acc))
       (v < 65536 ?
          (. (128 + v % 64) (. (128 + v // 64 % 64) (. (224 + v // 4096) acc)))
          (. (128 + v % 64) (. (128 + v // 64 % 64)
             (. (128 + v // 4096 % 64) (. (240 + v // 262144) acc)))))))
   ; \u{h..}: one to six hex digits naming a code point, surrogates out -> (v . rest).
   ; 'torn when the input ends inside it, () when it is no such escape
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

   ; --- raw texts ------------------------------------------------------------
   ; three or more quotes open one and as many close it, no escapes. on one line a
   ; longer closing run keeps its extra quotes. when the opener ends its line, the
   ; text closes on a line of only spaces and the quotes, that line's indent comes off
   ; every line (at most that many spaces or tabs), and the breaks beside the quotes
   ; are not the text's. cl is at the first quote
   (p1-hws? c) (c = 32 ? 1 (c = 9))
   (p1-qrun cl k) ((two? cl ? (cap cl = 34)) ? (p1-qrun (p1-cup cl) (k + 1)) (. k cl))
   (p1-lead cl k) ((two? cl ? (p1-hws? <cl)) ? (p1-lead (p1-cup cl) (k + 1)) (. k cl))
   (p1-reps c k acc) (0 < k ? (p1-reps c (k - 1) (. c acc)) acc)
   (p1-raw cl)
     (p1-qrun cl 0 @ qr
        (: q <qr r >qr s >(p1-lead r 0)
           crlf (two? s ? (cap s = 13 ? (two? (p1-cup s) ? (cap (p1-cup s) = 10))))
           (? (two? s ? (cap s = 10)) (p1-rawml (p1-cup s) q ())
              crlf (p1-rawml (p1-cup (p1-cup s)) q ())
              (p1-raw1 r q ()))))
   (p1-raw1 cl q acc)
     (? (atom? cl) 'torn
        (!= <cl 34) (p1-raw1 (p1-cup cl) q (. <cl acc))
        (p1-qrun cl 0 @ rr
           (<rr < q ? (p1-raw1 >rr q (p1-reps 34 <rr acc))
            (. (string (p1-rev (p1-reps 34 (<rr - q) acc) ())) >rr))))
   ; a line -> (its chars . rest past the break), the break's \r not the line's
   (p1-line cl acc)
     (? (atom? cl) 'torn
        (cap cl = 10) (. (p1-rev acc ()) (p1-cup cl))
        (cap cl = 13 ? (two? (p1-cup cl) ? (cap (p1-cup cl) = 10)))
          (. (p1-rev acc ()) (p1-cup (p1-cup cl)))
        (p1-line (p1-cup cl) (. <cl acc)))
   ; lines is last first, each (its chars . its break), the break 10 or 13
   (p1-rawml cl q lines)
     (p1-lead cl 0 @ lr
        (p1-qrun >lr 0 @ rr
           (? (q <= <rr) (. (p1-rawtxt (p1-rev lines ()) <lr ()) (p1-drop >lr q))
              (p1-line cl () @ la
                 (atom? la ? 'torn
                  (p1-rawml >la q (. (. <la (p1-crlf? cl la)) lines)))))))
   ; whether the line at cl, read into la, broke on \r\n
   (p1-crlf? cl la) (p1-drop cl (p1-len <la 0) @ e (cap e = 13 ? 13 10))
   (p1-len l k) (two? l ? (p1-len >l (k + 1)) k)
   (p1-strip l w) ((0 < w ? (two? l ? (p1-hws? <l))) ? (p1-strip >l (w - 1)) l)
   (p1-rawtxt ls w acc)
     (? (atom? ls) (string (p1-rev acc ()))
        (: line (p1-rev (p1-strip <<ls w) acc)
           (atom? >ls ? (p1-rawtxt >ls w line)
            (p1-rawtxt >ls w (>(cap ls) = 13 ? (. 10 (. 13 line)) (. 10 line))))))

   ; --- the wraps -----------------------------------------------------------
   ; the value surface, the printer's read-back contract: ' and @ each wrap the
   ; next datum. a splicing wrap (hash tuple list) over a list splices instead:
   ; {k v} is (hash k v), not (hash (k v)).
   (p1-splice? w) (w @ 'hash 1 (w @ 'tuple 1 (w = 'list)))
   (p1-wrap w d)
     (? (d = () ? (w = 'hash)) (. 'tablet (. 0 ()))     ; {} -> (tablet 0)
        (d = () ? (w = 'tuple)) (. 'iota (. 0 ()))      ; @() -> (iota 0)
        (p1-splice? w ? (two? d ? 1 (d = () ? (!= w 'hash)))) (. w d)
        (. w (. d ())))
   ; a bracket is its wrap: [a b] is (list a b) and {k v} is the map -- each brace
   ; and bracket is its wrap's only spelling, so the splice law carries the empties
   ; too ([] -> (list), {} -> (tablet 0)) and the box is {x}.
   ; p1-lift reaches here too, with the wrap the sigil named instead.
   (p1-open w cl)
     (p1-list cl 1 () @ d
        (two? d ? (. (p1-wrap w <d) >d) d))

   ; --- the parser ----------------------------------------------------------
   ; (p1-read1 cl head) -- head is true when the next datum would be a list's
   ; first, which the valence law needs: the : and ? special forms consume the
   ; whole list, so a run glued at head does not fuse for those two.
   (p1-read1 cl0 head)
     (p1-skip cl0 @ cl
        (atom? cl ? ()
         (: c <cl r (p1-cup cl)
            ; a numeral has to start somewhere (rung 1): + and - are operator
            ; runs like every other punctuation, except that a digit -- or a
            ; `.`, for -.5 -- right after them makes the token a number.
            numlead (p1-cls c & 64 ? (two? r ? (p1-dig? <r ? 1 (cap r = 46))))
            (? (c = 40) (p1-list r 1 ())
               (p1-cls c & 16) (p1-open (c @ 91 'list 'hash) r)
               (p1-cls c & 32) ()
               (c = 34) ((two? r ? (cap r = 34 ? (two? (p1-cup r) ? (cap (p1-cup r) = 34)))) ?
                           (p1-raw cl) (p1-str r ()))
               (c = 39) (p1-lift (nom "\\") r head)
               ; @ glued to an operator char is an operator run (@- and friends), not the
               ; tuple sigil: a datum cannot start with one. the run's own shed rule keeps
               ; @-5 a number, exactly as it keeps !-5.
               (c = 64) (? (two? r ? (p1-opc? <r)) (p1-op cl)
                           (p1-glued? r) (p1-lift 'tuple r head)
                           (. (nom "@") r))
               (c = 44) (. (nom ",") r)
               (p1-opc? c ? (! numlead)) (p1-op cl)
               (p1-dig? c) (p1-nop cl)
               (p1-tok cl () @ tr
                  (. (p1-atom <tr) >tr))))))

   ; a wrap takes the next datum; an unfinished one is more, never EOF.
   ; a constructor sigil over an open form renames the wrap rather than stacking
   ; on it: @[1 2] is @(1 2). the constructors are exactly the splicing wraps, and
   ; stacking is what they cannot mean -- @[a b] would otherwise splice the
   ; bracket's own list in and read (tuple list a b), a wrong value with nothing
   ; to raise. ' and \ are not constructors: they take the next datum whatever it
   ; is, so '[a b] stays the form (list a b) quoted.
   ; @ reads glue (p1-read1): spaced it is the plain symbol, the head of the
   ; match form. the other sigils reach across the space.
   (p1-lift w cl head)
     (: s (p1-skip cl)
        open (p1-splice? w ? (two? s ? (p1-cls <s & 16)))
        (open ? (p1-open w (p1-cup s))
           (p1-read1 s head @ d
              (atom? d ? 'torn
               (. (p1-wrap w <d) >d)))))

   ; the valence law, reader half: a run glued to the datum after it is monadic
   ; -- the run becomes a wrap under a mono wrap, so the emission is the nested
   ; (mono (run d)), which opfix factors against book['operators] arity 0 -- a spaced
   ; run is the plain symbol, dyadic by opfix's default. head fuses too, so
   ; (<x = y) is (= (cap x) y) and (?x ..) is bit x applied -- no head is exempt.
   ; \ is the one run that never fuses anywhere: it is form space.
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
   ; a digit-led token carrying a sigil is a run, not a name: 2?<>x is 2?<>
   ; around x. a digit breaks p1-run, so the run is cut from the whole token,
   ; one past its last sigil. the numeral lane wins first.
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
   ; glued = the next char starts a datum rather than ending the form.
   (p1-glued? cl)
     (two? cl ? (cap cl @ c (! (p1-cls c & 128))))

   ; a list: datums until the close. an empty one is the zero point. the three
   ; closers are one: ) ] } each just end the open form, so the opener alone picks
   ; the wrap and a crossed pair reads silently -- matching them is libra's job,
   ; not the reader's (a reader of a subset, not a validator).
   (p1-list cl0 head acc)
     (p1-skip cl0 @ cl
        (? (atom? cl) 'torn
           (p1-cls <cl & 32) (. (p1-rev acc ()) (p1-cup cl))
           (p1-read1 cl head @ d (atom? d ? 'torn (p1-list >d () (. <d acc))))))

   ; a text -> its charlist
   (p1-chars s)
     (: n #s
        (go k acc) (k < 0 ? acc (go (k - 1) (. (s k) acc)))
        (go (n - 1) ()))

   ; --- the doors -----------------------------------------------------------
   ; one datum off text: (datum . rest), () at a clean end, or `torn` mid-shape. four
   ; doors: a port (through post.l's flow), a string, an unforced tail, or the charlist
   ; a previous read left. the residue is always a charlist.
   (x \ (p1-read1 (? (string? x)  (p1-chars x)
                     (port? x)    (flow x)
                     (lit? x)     (x ())
                     x) ())))
