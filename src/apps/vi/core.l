; src/apps/vi/core.l -- the vi engine, pure: a state tablet stepped one byte at a time
; (vstep); vframe paints a whole screen, vfresh the difference. no port, tty or file io:
; the face (src/apps/vi/vi.l) reads keys, blits frames and performs the requests the ex
; commands leave on the state ('dow write, 'doe read, 'dos split, 'dox an unknown ex word).
; search rides src/apps/kore/re.l, so re.l loads first in any cat.
;
; 'lines is never empty (the vi invariant); 'row 'col are 0-based, 'col always a
; character's first byte. 'hlgen is bumped by vput/vsplice/vrest alone, the only
; mutators of 'lines, and every paint cache keys on it. 'hlcar is [gen lang states]:
; the wrapper tells a cached gen 0 from no cache. 'pens is installed by the face, so
; this file reads no env. the lexer also tells % and the bracket objects which ( is code.
(module 'vi
(borrow 'kore) ; the text/u floors
(borrow 'lint)  ; lint-scan, spliced for this module's compile
(borrow 'tui)   ; tui-fresh, the diff repaint every full-screen app wants
(borrow 'text)  ; utf-8 read as characters, and their widths
(:
   ; -- the small floor --
   ; lists do not index by application (a number list would church-tower), so
   ; the row walk is explicit; "" past the end keeps every reader total
   ; the cursor's line. 'lines is a LIST, so asking for row r walks r pairs, and
   ; one keystroke asks many times -- so it is cached against the row and the
   ; generation, the two things that can make the answer stale
   (vln st)
    (st 'lncar @ c
       (two? c && <c = st 'row && <>c = st 'hlgen ? <>>c
          (st 'lines (st 'row) @ t
             (pin st 'lncar [(st 'row) (st 'hlgen) t],
              t))))
   (vlen st) #(vln st)
   (vnl st) #(st 'lines)
   (vdrop l k) (k < 1 || atom? l ? l (vdrop >l (k - 1)))
   ; a line's height in screen rows: 1 unwrapped, else what it folds to
   (vhgt st ln) (? !(st 'wrap) 1 #(vsegs ln (st 'w)))
   ; the last file row the body can show -- what H M L stop at. wrapped, that
   ; is a walk down the heights from the view's corner
   (vbot st)
    (: nl (vnl st) top (st 'top)
       (? !(st 'wrap) (top + (st 'h - 2) @ b (nl <= b ? (nl - 1) b))
          (: (go l i n) (? !(two? l) (i - 1)
                           (vhgt st <l @ k (n <= k ? i (go >l (i + 1) (n - k)))))
             (go (vdrop (st 'lines) top) top (st 'h - 1 + st 'tops)))))
   ; row r moved k SCREEN rows in direction d, answered as a file row in range
   (vskip st r d k)
    (: nl (vnl st)
       (fence i) (? (i < 0) 0 (nl <= i) (nl - 1) i)
       (go i n) (n < 1 ? i
                   (i + d @ j
                      (j < 0 || nl <= j ? i
                         ; a step costs the UPPER of the two lines, either way
                         (go j (n - vhgt st (st 'lines (i < j ? i j)))))))
       (? !(st 'wrap) (fence (r + d * k)) (go r k)))
   (vink ln) (: n #ln                       ; first non-blank column
                 (go i) (i < n && (ln i = 32 || ln i = 9) ? (go (i + 1)) i)
                 (go 0 @ k (? (k < n) k (0 < n) (n - 1) 0)))
   ; every edit to 'lines bumps the generation, which is what lets the paint's
   ; string carry be recomputed once per edit instead of once per keystroke
   (vgen st) (pin st 'hlgen (st 'hlgen + 1))
   (vput st r ln) (pin st 'lines (: (go l i) (two? l ?
                                                ((i = r ? ln <l) . go >l (i + 1)))
                                    (go (st 'lines) 0)),
                   vgen st)
   ; -- characters: 'col is a byte, always a character's first, and the screen counts
   ; columns -- a wide character two, a combining mark none, an ascii byte one (a tab
   ; renders raw, so it is the terminal's one column here too)
   (vnx ln i) (#ln <= i || ln i < 128 ? (i + 1) (cpnext ln i))
   (vhead ln i)                                    ; the first byte of the character at i
    (: (go j) (j < 1 || 2 < i - j || ln j & 192 != 128 ? j (go (j - 1)))
       j (#ln <= i ? i (go i))
       (j < i && cpnext ln j <= i ? i j))
   (vpv ln i) (i < 1 ? 0 (vhead ln (i - 1)))
   (vend ln) (vpv ln #ln)                          ; the last character, 0 on an empty line
   (vchars ln i k) (k < 1 || #ln <= i ? i (vchars ln (vnx ln i) (k - 1)))
   (vcharsb ln i k) (k < 1 || i < 1 ? i (vcharsb ln (vpv ln i) (k - 1)))
   (vcw ln i) (ln i @ b (b < 128 ? 1 (max 0 (wcwidth (cpat ln i)))))
   (vcols ln a b)                                  ; the columns bytes [a,b) take
    (: n #ln (go i c) (b <= i || n <= i ? c (go (vnx ln i) (c + vcw ln i))) (go a 0))
   (vcolat ln g)                                   ; the character column g falls in, #ln past it
    (: n #ln
       (go i c) (n <= i ? n (c + vcw ln i @ c2 (g < c2 ? i (go (vnx ln i) c2))))
       (go 0 0))
   ; the byte starts of the screen rows ln folds to at width w: a character that would
   ; cross the margin opens the next row. width never passes the byte count, so a line
   ; no longer than w is one row without a walk
   (vsegs ln w)
    (: n #ln
       (go i c acc) (n <= i ? (rev acc)
                       (vcw ln i @ cw
                          (w < c + cw && 0 < c ? (go i 0 (i . acc)) (go (vnx ln i) (c + cw) acc))))
       (n <= w ? [0] (go 0 0 [0])))
   ; the bytes of ln showing in columns [c0, c0 + w) -> [a b pad]: a wide character the
   ; left edge cuts is left out, its column shown blank
   (vwin ln c0 w)
    (: n #ln
       (lo i c) (n <= i || c0 <= c ? [i c] (lo (vnx ln i) (c + vcw ln i)))
       p (lo 0 0) a <p ca <>p
       (hi i c) (n <= i ? i (c + vcw ln i @ c2 (c0 + w < c2 ? i (hi (vnx ln i) c2))))
       [a (hi a ca) (ca < c0 ? 0 (ca - c0))])

   (vgole st c) (pins st 'col c 'goal (vcols (vln st) 0 c))
   (vclampn st) (: ln (vln st) n #ln               ; normal-mode col fence
                    (st 'col < n ? st (vgole st (vend ln))))
   (vcl c) (? (c = 32 || c = 9) 0              ; char class: blank / word / ink
              (48 <= c <= 57 ||
               65 <= c <= 90 ||
               97 <= c <= 122 || c = 95 || 128 <= c) 1   ; a letter past ascii is a word's
              2)
   (vclw c) (c = 32 || c = 9 ? 0 1)            ; the WORD class: blank / everything else
   (vupc c) (? (97 <= c <= 122) (c - 32) (65 <= c <= 90) (c + 32) c)   ; ~'s flip
   (vflip t) (jug 0 @ j (each ^#t (i \ say j (string (vupc (t i)))), slurp j))
   (vlead ln) (: n #ln                         ; the leading blanks, as a count
                 (go i) (i < n && (ln i = 32 || ln i = 9) ? (go (i + 1)) i)
                 (go 0))
   (vblanks n) (: (go i acc) (i < 1 ? acc (go (i - 1) (acc + " "))) (go n ""))
   (vmsg st m) (pin st 'msg m)
   (vsnap st) (pins st 'undo ([(st 'lines) (st 'row) (st 'col)] . st 'undo) 'redo ())
   (vrest st fr) (pins st 'lines <fr 'row <>fr, vgen st,
                  vgole st <>>fr, pin st 'dirty 1)

   ; the pure half of :e -- the face reads the file and hands the lines over, this
   ; starts the buffer over on them: cursor home, no history, not dirty. the paint
   ; is re-decided from the new name, so :e-ing a .l from a .txt lights up and the
   ; other way round goes plain, and the generation bump drops the cached carry
   ; along with the old buffer it described.
   (vload st ls nm)
    (pins st 'lines (? (two? ls) ls '("")) 'file nm 'row 0 'top 0 'tops 0 'left 0,
     vgole st 0,
     pins st 'undo () 'redo () 'dirty () 'hl (nom? (vlang st)),
     vgen st)

   ; splice: replace rows r1..r2 (inclusive) with the list `ins`; r2 = r1 - 1
   ; is a pure insertion at r1 (the end of the buffer included)
   (vsplice st r1 r2 ins)
    (: pre (vtake st 0 (r1 - 1))
       post (vtake st (r2 + 1) (vnl st - 1))
       nl2 (pre + ins + post)
     (pins st 'lines (two? nl2 ? nl2 '("")) 'dirty 1,
      vgen st))
   (vtake st r1 r2)                                ; rows r1..r2, a fresh list
    (: (go l i acc) (atom? l || r2 < i ? (rev acc)
                     (go >l (i + 1) (r1 <= i ? (<l . acc) acc)))
       (go (st 'lines) 0 ()))

   ; -- the word motions: (row col) -> (row col), crossing lines when free.
   ; cf is the class: vcl for w e b, vclw for W E B, and that one argument is the
   ; whole difference between the two families --
   (vwfwd st cf r c)                               ; next word start
    (: ls (st 'lines) n #ls
       (at r2 c2) (ls r2 @ ln (c2 < #ln ? (cf (ln c2)) 0))
       (skipk r2 c2 k)                             ; over the current run of class k
        (ls r2 @ ln
         (c2 < #ln && cf (ln c2) = k ? (skipk r2 (c2 + 1) k) [r2 c2]))
       (skipb r2 c2)                               ; over blanks, line ends included
        (ls r2 @ ln
           (? (c2 < #ln) (cf (ln c2) = 0 ? (skipb r2 (c2 + 1)) [r2 c2])
              (r2 + 1 < n) (skipb (r2 + 1) 0)
              [r2 #ln]))
       k (at r c)
       p (k = 0 ? [r c] (skipk r c k))
       (skipb <p <>p))
   (vwend st cf r c)                               ; next word end (inclusive target)
    (: ls (st 'lines) n #ls
       (skipb r2 c2) (ls r2 @ ln
                        (? (c2 < #ln) (cf (ln c2) = 0 ? (skipb r2 (c2 + 1)) [r2 c2])
                           (r2 + 1 < n) (skipb (r2 + 1) 0)
                           [r2 c2]))
       p (skipb r (vnx (ls r) c))
       r2 <p c2 <>p ln (ls r2)
       (#ln <= c2 ? [r2 (vend ln)]
          (: k (cf (ln c2))
             (run j) (j < #ln && cf (ln j) = k ? (run (j + 1)) (j - 1))
             [r2 (vhead ln (run c2))])))
   (vwback st cf r c)                              ; previous word start
    (: ls (st 'lines)
       (skipb r2 c2) (c2 < 0 ? (0 < r2 ? (r2 - 1 @ pr (skipb pr (#(ls pr) - 1)))
                                         '(0 0))
                        (ls r2 @ ln
                           (cf (ln c2) = 0 ? (skipb r2 (c2 - 1)) [r2 c2])))
       p (skipb r (c - 1))
       r2 <p c2 <>p ln (ls r2)
       (#ln <= c2 ? [r2 c2]
          (: k (cf (ln c2))
             (run j) (0 <= j - 1 && cf (ln (j - 1)) = k ? (run (j - 1)) j)
             [r2 (run c2)])))

   ; -- the delimiter scan ------------------------------------------------------
   ; % and the bracket objects want the delimiters that are code. in a buffer whose
   ; language the paint knows, its lexer -- the only string-and-comment truth this
   ; file has -- says which columns are inside a literal or a comment; anywhere
   ; else the mask is empty and every column counts, the way classic vi's % does.
   ; the language decides, not 'hl, so :hl moves the colour and nothing else.
   (vlang st) (hues-lang (st 'file) <(st 'lines))
   (vlex st g)
    (st 'lex @ c
       (two? c && <c = g ? <>c
          (hues-lexer g @ k (pin st 'lex [g k], k))))
   ; the per-line start states, folded once per generation and cached against it
   ; and the language. the paint reads this too, so an edit pays for one fold and
   ; a keystroke that only moves the cursor pays for none.
   (vcarry st g lx)
    (st 'hlcar @ c
       (two? c && <c = st 'hlgen && <>c = g ? <>>c
        (hue-carry lx (st 'lines) @ k (pin st 'hlcar [(st 'hlgen) g k], k))))
   (vskips st r)                                   ; the ([a b) ..) that are not code
    (vlang st @ g
       (? !(nom? g) ()
          (: lx (vlex st g)
             rs <(lx (st 'lines r) (vcarry st g lx r) 1)
             (go l acc) (? !(two? l) (rev acc)
                           (<l @ h
                              (go >l ((<h = 'string || <h = 'comment) ? ([<>h <>>h] . acc) acc))))
             (go rs ()))))
   (vcode? sk i) (? !(two? sk) 1 (<sk @ h (<h <= i < <>h ? () (vcode? >sk i))))
   (vopen? c)  (c = 40 || c = 91 || c = 123 || c = 60)
   (vclose? c) (c = 41 || c = 93 || c = 125 || c = 62)
   (vmatec c) (? (c = 40) 41 (c = 91) 93 (c = 123) 125 (c = 60) 62
                 (c = 41) 40 (c = 93) 91 (c = 125) 123 60)
   (vdelims st r o cl)                             ; ([col char] ..) on row r, ascending
    (: ln (st 'lines r) n #ln sk (vskips st r)
       (rev (foldl (\ acc i (ln i @ c ((c = o || c = cl) && vcode? sk i ? ([i c] . acc) acc))) () ^n)))
   ; the mate of the delimiter at (r c): rows are scanned whole, outward, and only
   ; this pair's own two characters count, so a ( inside [] is nesting and a [ is not
   (vmate st r c o cl)
    (: ch (st 'lines r c) fwd (ch = o) nl (vnl st)
       (rowd i) (vdelims st i o cl @ d (fwd ? d (rev d)))
       (past l) (? !(two? l) () (<<l = c) >l (past >l))
       (go i l d)
        (two? l ?
           (<l @ h
              (? (<>h = ch) (go i >l (d + 1))
                 (d < 1) [i <h]
                 (go i >l (d - 1))))
           ((fwd ? (i + 1) (i - 1)) @ j
              (j < 0 || nl <= j ? () (go j (rowd j) d))))
       (go r (past (rowd r)) 0))
   ; the innermost opener enclosing (r c) -- the cursor's own column counting
   (vencl st r c o cl)
    (: (rowd i) (rev (vdelims st i o cl))
       (upto l) (? !(two? l) () (<<l <= c) l (upto >l))
       (go i l d)
        (two? l ?
           (<l @ h
              (? (<>h = cl) (go i >l (d + 1))
                 (d < 1) [i <h]
                 (go i >l (d - 1))))
           (i < 1 ? () (go (i - 1) (rowd (i - 1)) d)))
       (go r (upto (rowd r)) 0))
   ; the pair to work on: on an opener or a closer it is that one's own, else the
   ; innermost that encloses. answers (r1 c1 r2 c2), the two delimiters themselves
   (vbpair st o cl)
    (: r (st 'row) c (st 'col) ln (st 'lines r) n #ln sk (vskips st r)
       here (c < n && vcode? sk c ? (ln c) 0)
       (pair a) (two? a ? (vmate st <a <>a o cl @ m (two? m ? [<a <>a <m <>m] ())))
       (? (here = o) (pair [r c])
          (here = cl) (vmate st r c o cl @ m (two? m ? [<m <>m r c] ()))
          (pair (vencl st r c o cl))))
   ; % -- the first delimiter at or after the cursor on this row, and its mate
   (vpct st)
    (: r (st 'row) ln (st 'lines r) n #ln sk (vskips st r)
       (go i) (? (n <= i) ()
                 ((vopen? (ln i) || vclose? (ln i)) && vcode? sk i) i
                 (go (i + 1)))
       i (go (st 'col))
       (? !(charm? i) ()
          ((ln i @ c (vclose? c ? (vmatec c) c)) @ o (vmate st r i o (vmatec o)))))

   ; -- paragraphs: a run of blank lines or a run of non-blank ones --------------
   (vblank? st i) (0 = #(st 'lines i))
   (vpara st d)                                    ; { and } -- the next blank line
    (: nl (vnl st)
       (skip p i) (? (i < 0 || nl <= i) i (p (vblank? st i)) (skip p (i + d)) i)
       j (skip (b \ !b) (skip (b \ b) (st 'row + d)))
       (? (j < 0) 0 (nl <= j) (nl - 1) j))

   ; -- motions: key (+ n) -> ('to r c) exclusive | ('toi r c) inclusive
   ;             | ('lin r2) linewise target, the goal column kept | ('linb r2)
   ;             the same, landing on the line's first ink | ('spn r1 c1 r2 c2)
   ;             an absolute charwise span | ('linr r1 r2) an absolute linewise
   ;             one, which is what a linewise text object answers | () --
   (vmot st c n raw)
    (: r (st 'row) col (st 'col) ln (vln st) len #ln nl (vnl st)
       (walk f cf k) (: (go i p) (i < 1 ? p (go (i - 1) (f st cf <p <>p)))
                        p (go n [r col])
                        [k <p <>p])
       ; dw where the last word moved over ends the line takes that line's tail
       ; and stops: vim's own special case, and it is the LAST step that decides
       (walkop cf) (: (go i p pv) (i < 1 ? [p pv] (go (i - 1) (vwfwd st cf <p <>p) p))
                      q (go n [r col] [r col])
                      p <q pv <>q
                      (<pv < <p ? ['to <pv #(st 'lines <pv)] ['to <p <>p]))
       (top1 k) (: t (st 'top + (k - 1)) b (vbot st)
                   (? (b < t) b (nl <= t) (nl - 1) t))
     (c @ 104 ['to r (vcharsb ln col n)]                         ; h
          108 ['to r (vchars ln col n)]                          ; l
          48 ['to r 0]                                           ; 0
          94 ['to r (vink ln)]                                   ; ^
          36 (0 < len ? ['toi r (vend ln)] ['to r 0])           ; $
          124 ['to r (vcolat ln (n - 1))]                        ; | -- a screen column
          119 (two? (st 'op) ? (walkop vcl) (walk vwfwd vcl 'to))   ; w
          101 (walk vwend vcl 'toi)                              ; e
          98  (walk vwback vcl 'to)                              ; b
          87  (two? (st 'op) ? (walkop vclw) (walk vwfwd vclw 'to))  ; W
          69  (walk vwend vclw 'toi)                             ; E
          66  (walk vwback vclw 'to)                             ; B
          106 ['lin (r + n @ k (k < nl ? k (nl - 1)))]           ; j
          107 ['lin (r - n @ k (k < 0 ? 0 k))]                   ; k
          ; + - _ and CR: whole lines, the cursor landing on the first non-blank
          (43 || 13) ['linb (r + n @ k (k < nl ? k (nl - 1)))]
          45 ['linb (r - n @ k (k < 0 ? 0 k))]
          95 ['linb (r + (n - 1) @ k (k < nl ? k (nl - 1)))]
          123 ['lin (vpara st -1)]  125 ['lin (vpara st 1)]      ; { }
          72 ['lin (top1 n)]                                     ; H
          76 ['lin (: f (vbot st) k (f - (n - 1))                 ; L
                      (k < st 'top ? (st 'top) k))]
          77 ['lin ((st 'top + vbot st) // 2)]                    ; M
          37 (vpct st @ p                                        ; %
                (? !(two? p) ()
                   (r < <p) ['spn r col <p (<>p + 1)]
                   (<p < r) ['spn <p <>p r (vnx ln col)]
                   (col <= <>p) ['toi r <>p]
                   ['spn r <>p r (vnx ln col)]))
          71 ['lin (0 < raw ? (raw - 1 @ k (k < nl ? k (nl - 1)))
                           (nl - 1))]))                               ; G
   ; f F t T with the argument character a, as text: a utf-8 lead is never a tail
   ; byte, so a byte-wise hit is a character's start
   (vfind st k a n)
    (: ln (vln st) len #ln col (st 'col) m #a
       fwd (k = 'f || k = 't)
       (go i c2 left) (left < 1 ? c2
                         ((fwd ? (fx (i + 1)) (bx (i - 1))) @ nx
                            (charm? nx ? (go nx nx (left - 1)))))        ; charm?, not truth: column 0 is a hit
       (at? j) (j + m <= len && snip ln j (j + m) = a)
       (fx i) (: (s2 j) (? (len <= j) () (at? j) j (s2 (j + 1))) (s2 i))
       (bx i) (: (s2 j) (? (j < 0) () (at? j) j (s2 (j - 1))) (s2 i))
       hit (go col () n)
       (? !(charm? hit) ()
        (k @ 'f  ['toi (st 'row) hit]
             't (col < hit ? ['toi (st 'row) (vpv ln hit)])
             'F ['to (st 'row) hit]
             (hit < col ? ['to (st 'row) (hit + m)]))))

   ; -- the operators --
   ; the opcodes are the keys themselves: d y c, and > < for the shifts, which are
   ; linewise whatever motion they are handed
   (vlinop? opc) (opc = 62 || opc = 60)
   (vyank st kind v) (pin st 'reg [kind v])
   (vopc st opc r c1 c2)                           ; charwise [c1,c2) on row r
    (: a (c1 < c2 ? c1 c2) b (c1 < c2 ? c2 c1)
       ln (st 'lines r) len #ln
       b2 (len < b ? len b)
       piece (snip ln a b2)
       (vyank st 'chr piece,
        opc @ 121 (vgole st a, st)        ; y: cursor to the span head
        (vsnap st,
         vput st r (snip ln 0 a + snip ln b2 len),
         pins st 'dirty 1 'row r,
         vgole st a,
         opc @ 99 (pin st 'mode 'i) (vclampn st),
         st)))
   ; a charwise span [r1,c1)..[r2,c2) that crosses rows: the two ends become one
   ; line and the register keeps the newlines, which is what p splits on
   (vospn st opc r1 c1 r2 c2)
    (r1 = r2 ? (vopc st opc r1 c1 c2)
       (: a (st 'lines r1) b (st 'lines r2)
          h (#a @ n (n < c1 ? n c1)) t (#b @ n (n < c2 ? n c2))
          mid (vtake st (r1 + 1) (r2 - 1))
          piece (foldl (s \ l \ s + l + "\n") (snip a h #a + "\n") mid + snip b 0 t)
          (vyank st 'chr piece,
           opc = 121 ? (pin st 'row r1, vgole st h, st)
             (vsnap st,
              vsplice st r1 r2 [(snip a 0 h + snip b t #b)],
              pin st 'row r1, vgole st h,
              opc = 99 ? (pin st 'mode 'i) (vclampn st)))))
   ; > and < -- rows r1..r2 in or out by one shiftwidth. an empty line stays empty,
   ; the way vim leaves it, and the register is not touched: a shift is not a cut
   (vshift st opc r1 r2)
    (: sw (st 'sw)
       _ (vsnap st)
       (go i) (r2 < i ? ()
                 (: ln (st 'lines i) k (vlead ln)
                    j (? (0 = #ln) 0 (opc = 62) (k + sw) (k - sw @ q (q < 0 ? 0 q)))
                    (vput st i (vblanks j + snip ln k #ln),
                     go (i + 1))))
       (go r1,
        (pins st 'dirty 1 'row r1),
        (vgole st (vink (vln st)), st)))
   (vopl st opc r1 r2)                             ; linewise rows r1..r2
    (: a (r1 < r2 ? r1 r2) b (r1 < r2 ? r2 r1)
       (vlinop? opc ? (vshift st opc a b)
          (vyank st 'lin (vtake st a b),
           opc = 121 ? (pin st 'row a, st)
             (vsnap st,
              opc = 99 ?
                (vsplice st a b '(""),
                 pin st 'row a, vgole st 0,
                 pin st 'mode 'i)
                (: _ (vsplice st a b ())
                   nl (vnl st)
                   (pin st 'row (a < nl ? a (nl - 1)),
                    vgole st (vink (vln st)),
                    st))))))
   ; a motion answered mr while operator (opc . ocnt) was pending. 'spn and 'linr
   ; are absolute -- a text object knows both its ends -- and the rest are relative
   ; to the cursor, which is the other end of the range
   (vapply st opc mr)
    (: kind <mr a <>mr b <>>mr
       (? (kind = 'lin || kind = 'linb) (vopl st opc (st 'row) a)
          (kind = 'linr) (vopl st opc a b)
          (kind = 'spn)  (>>>mr @ t
                            (vlinop? opc ? (vopl st opc a <t) (vospn st opc a b <t <>t)))
          (vlinop? opc)  (vopl st opc (st 'row) a)
          ; an inclusive end takes its whole character
          (a = st 'row)  (vopc st opc (st 'row) (st 'col) (kind = 'toi ? (vnx (st 'lines a) b) b))
          (st 'row < a)  (vospn st opc (st 'row) (st 'col) a (kind = 'toi ? (vnx (st 'lines a) b) b))
          (vospn st opc a b (st 'row) (kind = 'toi ? (vnx (vln st) (st 'col)) (st 'col)))))

   ; -- the text objects: i and a after an operator ----------------------------
   ; each answers a range in vapply's own vocabulary, so ci( and di( and yi( are
   ; one object under three operators rather than three commands.
   (vwobj st cf ar n)                              ; iw aw iW aW -- runs on this row
    (: r (st 'row) ln (st 'lines r) len #ln
       (len < 1 ? ()
          (: c (st 'col @ k (len <= k ? (vend ln) k))
             (rune i) (: k (cf (ln i))
                         (go j) (j < len && cf (ln j) = k ? (go (j + 1)) j)
                         (go i))
             (runs i) (: k (cf (ln i))
                         (go j) (0 <= j - 1 && cf (ln (j - 1)) = k ? (go (j - 1)) j)
                         (go i))
             (ext i j) (j < 1 || len <= i ? i (ext (rune i) (j - 1)))
             a (runs c)
             e1 (ext a n)
             ; around is the word and the blanks that follow -- two runs, each
             ; way round -- and with none to follow it takes the ones before
             e2 (ar ? (ext a (2 * n)) e1)
             a2 (ar && e2 = e1 && 0 < a && cf (ln (a - 1)) = 0 ? (runs (a - 1)) a)
             ['spn r a2 r e2])))
   (vqobj st ar q)                                 ; i" a" i' a' i` a`
    (: r (st 'row) ln (st 'lines r) n #ln c (st 'col)
       (nx i) (? (n <= i) () (ln i = 92) (nx (i + 2)) (ln i = q) i (nx (i + 1)))
       ; the pairs are counted from the line's start, the way vim counts them, so
       ; which quote is an opener never depends on where the cursor happens to sit
       (go i) (nx i @ a
                 (? !(charm? a) ()
                    (nx (a + 1) @ b
                       (? !(charm? b) ()
                          (a <= c <= b || c < a) [a b]
                          (go (b + 1))))))
       p (go 0)
       (two? p ?
          (: a <p b <>p
             (bl i) (i < n && (ln i = 32 || ln i = 9) ? (bl (i + 1)) i)
             (bk i) (0 < i && (ln (i - 1) = 32 || ln (i - 1) = 9) ? (bk (i - 1)) i)
             (!ar ? ['spn r (a + 1) r b]
                (bl (b + 1) @ e ['spn r (e = b + 1 ? (bk a) a) r e])))))
   (vbobj st ar o)                                 ; i( a( i[ a[ i{ a{ i< a<
    (vbpair st o (vmatec o) @ p                    ; (r1 c1 r2 c2), the delimiters
       (? !(two? p) ()
          ar ['spn <p <>p <>>p (<>>>p + 1)]
          ['spn <p (<>p + 1) <>>p <>>>p]))
   (vpobj st ar)                                   ; ip ap -- linewise, blank-delimited
    (: nl (vnl st) r (st 'row) k (vblank? st r)
       (up i) (0 < i && vblank? st (i - 1) = k ? (up (i - 1)) i)
       (dn i) (i < nl - 1 && vblank? st (i + 1) = k ? (dn (i + 1)) i)
       a (up r) b (dn r)
       (dn2 i) (i < nl - 1 && vblank? st (i + 1) != k ? (dn2 (i + 1)) i)
       (up2 i) (0 < i && vblank? st (i - 1) != k ? (up2 (i - 1)) i)
       (? !ar ['linr a b]
          (b < nl - 1) ['linr a (dn2 (b + 1))]
          (0 < a) ['linr (up2 (a - 1)) b]
          ['linr a b]))
   (vobj st ar c n)
    (c @ 119 (vwobj st vcl ar n)   87 (vwobj st vclw ar n)
         112 (vpobj st ar)
         (34 || 39 || 96) (vqobj st ar c)
         (40 || 41 || 98) (vbobj st ar 40)
         (91 || 93) (vbobj st ar 91)
         (123 || 125 || 66) (vbobj st ar 123)
         (60 || 62) (vbobj st ar 60)
         ())

   ; -- paste, join, undo --
   (vpaste st after n)
    (st 'reg @ rg
       (? !(two? rg) (vmsg st "nothing in the register")
          (<rg = 'lin)
           (: _ (vsnap st)
              at (after ? (st 'row + 1) (st 'row))
              (rep i s2) (i < 1 ? s2 (rep (i - 1) (vsplice s2 at (at - 1) <>rg, s2)))
              (rep n st,
               pin st 'row at,
               vgole st (vink (vln st)),
               st))
          (: _ (vsnap st)
             t <>rg
             (rep i acc) (i < 1 ? acc (rep (i - 1) (acc + t)))
             tt (rep n "")
             ln (vln st) len #ln r (st 'row)
             at (after && 0 < len ? (vnx ln (st 'col)) (st 'col))
             ; text.l's `lines` drops a trailing empty and a charwise register that
             ; ends at a line's start is exactly that -- so this split keeps them
             ps (: k #tt
                   (go i a acc) (? (k <= i) (rev (snip tt a k . acc))
                                   (tt i = 10) (go (i + 1) (i + 1) (snip tt a i . acc))
                                   (go (i + 1) a acc))
                   (go 0 0 ()))
             ; a charwise register that crossed rows carries its newlines: the
             ; line opens at the cursor and the tail rides the register's last row
             (#ps < 2 ?
                (vput st r (snip ln 0 at + tt + snip ln at len),
                 vgole st (vpv (vln st) (at + #tt)),
                 st)
                (: lst (vexlast ps)
                   mid (: (go l acc) (? !(two? >l) (rev acc) (go >l (<l . acc))) (go >ps ()))
                   (vput st r (snip ln 0 at + <ps),
                    vsplice st (r + 1) r (mid + [(lst + snip ln at len)]),
                    pin st 'row r,
                    vgole st at,
                    st))))))
   ; J puts one blank between the two lines and drops the next one's indent; gJ
   ; joins them exactly as they are, which is sp? = ()
   (vjoin st n sp?)
    (: (one s2) (s2 'row + 1 < vnl s2 ?
                   (: r (s2 'row) a (s2 'lines r) b (s2 'lines (r + 1))
                      bi (!sp? ? 0 (vink b @ k (0 < #b ? k 0)))
                      joined (a + (sp? ? " " "") + snip b bi #b)
                      (vgole s2 #a,
                       vsplice s2 r (r + 1) [joined],
                       s2))
                   s2)
       (go i) (i < 1 ? st (one st, go (i - 1)))
       (vsnap st,
        go (n < 2 ? 1 (n - 1))))
   ; ^A and ^X -- the number at or after the cursor, by n
   (vincr st n)
    (: r (st 'row) ln (st 'lines r) len #ln col (st 'col)
       (dig? i) (i < len && 48 <= ln i <= 57)
       (fx i) (? (len <= i) () (dig? i) i (fx (i + 1)))
       s (fx (dig? col ? (: (bk i) (0 < i && dig? (i - 1) ? (bk (i - 1)) i) (bk col)) col))
       (? !(charm? s) (vmsg st "no number here")
          (: a (0 < s && ln (s - 1) = 45 ? (s - 1) s)
             (fw i) (dig? i ? (fw (i + 1)) i)
             b (fw s)
             v (: t (snip ln a b) k #t
                   (go i acc) (k <= i ? acc (go (i + 1) (10 * acc + (t i - 48))))
                   q (go (a < s ? 1 0) 0)
                   (a < s ? (0 - q) q))
             w (v + n)
             (vsnap st,
              vput st r (snip ln 0 a + show w + snip ln b len),
              (pins st 'dirty 1),
              vgole st (a + #(show w) - 1)))))
   (vundo st)
    (st 'undo @ u
       (? !(two? u) (vmsg st "already at oldest change")
          (pins st 'redo ([(st 'lines) (st 'row) (st 'col)] . st 'redo)
                   'undo >u,
           vrest st <u,
           vclampn st)))
   (vredo st)
    (st 'redo @ r
       (? !(two? r) (vmsg st "already at newest change")
          (pin st 'undo ([(st 'lines) (st 'row) (st 'col)] . st 'undo),
           pin st 'redo >r,
           vrest st <r,
           vclampn st)))

   ; -- search (re.l): hunt for 'pat from the cursor, dir 1 fwd / -1 back --
   ; a word boundary is not a node re.l's engine can hold, so `*` asks for one
   ; with 'patw and it is checked at the span: a match with a word character
   ; against either end is refused and the hunt goes on from the next column
   (vfind1 st ln i)
    (refind (st 'pat) ln i @ m
       (? (!(two? m) || !(st 'patw)) m
          (: a <>m b <>>m
             (0 < a && vcl (ln (a - 1)) = 1 || b < #ln && vcl (ln b) = 1 ?
                (vfind1 st ln (a + 1))
                m))))
   (vlast st ln bound)                             ; last match start in ln with start < bound
    (: (go i best) (vfind1 st ln i @ r
                      (? !(two? r) best
                         (<>r @ ms
                            (ms < bound ? (go (ms + 1) ms) best))))
       (go 0 ()))
   (vhunt st dir)
    (: ls (st 'lines) nl #ls r (st 'row) c (st 'col)
       (fwd i steps)
        (nl < steps ? ()
           (: ln (ls i)
              cite (steps = 0 ? (c + 1) 0)
              m (cite <= #ln ? (vfind1 st ln cite))
              (two? m ? [i <>m]
                 (fwd ((i + 1) % nl) (steps + 1)))))
       (bwd i steps)
        (nl < steps ? ()
           (: ln (ls i)
              m (vlast st ln (steps = 0 ? c (#ln + 1)))
              (charm? m ? [i m]
               (bwd ((i - 1 + nl) % nl) (steps + 1)))))
       hit (0 < dir ? (fwd r 0) (bwd r 0))
       (two? hit ?
        (pin st 'row <hit, vgole st (vhead (ls <hit) <>hit), st)
        (vmsg st $ "not found: " + st 'pattx)))
   ; * and # -- the word under the cursor becomes the search. a name in this tree
   ; is full of BRE metacharacters (`map*`, `1.5`, `\`), so every one of them is
   ; spelled out, and 'patw asks the hunt for the boundaries the engine has no node for
   (vbesc t) (jug 0 @ j (each ^#t (i \ say j ((elem (t i) '(46 42 91 92 94 36) ? "\\" "") + string (t i))),
                          slurp j))
   (vstar st dir)
    (: ln (vln st) len #ln col (st 'col)
       (fx i) (? (len <= i) () (vcl (ln i) = 1) i (fx (i + 1)))
       s (fx col)
       (? !(charm? s) (vmsg st "no word under the cursor")
          (: a (: (bk i) (0 < i && vcl (ln (i - 1)) = 1 ? (bk (i - 1)) i) (bk s))
             (fw i) (i < len && vcl (ln i) = 1 ? (fw (i + 1)) i)
             w (snip ln a (fw a))
             b (rebre (vbesc w))
             (? !(two? b) st
                (pins st 'pat <>b 'pattx w 'patw 1 'dir dir,
                 vgole st a,
                 vhunt st dir)))))

   ; -- libra, on the buffer --------------------------------------------------
   ; both weighings are pure functions over text, so they run here, and over the
   ; BUFFER rather than the file: it answers for what you are looking at. one
   ; scanner under libra's three faces and this one, so what pulchritude says is
   ; what `make lint` refuses. lint counts line and col from one, the buffer from zero.
   (vlint st)
    (lint-scan (unlines (st 'lines)) @ ws
       (? !(two? ws) (vmsg st "balance clean")
          (: w1 <ws
             r (: k (<w1 - 1) nl (vnl st) (k < 0 ? 0 (k < nl ? k (nl - 1))))
             (pin st 'row r,
              vgole st (<>w1 - 1 @ c (c < 0 ? 0 c)),
              vclampn st,
              vmsg st (show #ws + (1 = #ws ? " warning: " " warnings: ")
                       + show <w1 + "," + show <>w1 + " " + <>>w1)))))


   ; -- the ex line -----------------------------------------------------------
   ; a line reads [range] command [args]; `;` moves dot to the first address before
   ; reading the second, and % is 1,$. rows answer 0-based, so address 0 is -1, the
   ; "before the first line" m and t take as a destination.
   ; a search address that finds nothing answers 'bad, NOT (): "no address here" and
   ; "an address that failed" must part company, or :/nomatch/d deletes the current line.

   (vexskip s i) (: n #s (go k) (k < n && (s k = 32 || s k = 9) ? (go (k + 1)) k) (go i))
   (vextrim s)
    (: n #s
       (fw k) (k < n && (s k = 32 || s k = 9) ? (fw (k + 1)) k)
       (bw k) (0 < k && (s (k - 1) = 32 || s (k - 1) = 9) ? (bw (k - 1)) k)
       a (fw 0) b (bw n)
       (a < b ? (snip s a b) ""))
   (vexhas? s c) (: n #s (go i) (? (n <= i) () (s i = c) 1 (go (i + 1))) (go 0))
   (vexbad? st a b) (vnl st @ nl (a < 0 || nl <= b || b < a))
   (vexlast l) (two? >l ? (vexlast >l) <l)
   (vexgo st r) (: nl (vnl st) k (? (r < 0) 0 (nl <= r) (nl - 1) r)
                   (pin st 'row k, vgole st (vink (vln st)), st))

   ; text up to the next unescaped dl -> [next-index text]. only the delimiter
   ; unescapes: \( and \1 have to reach the regex and the replacement whole
   (vexdelim s i dl)
    (: n #s
       (go j acc)
        (? (n <= j) [j acc]
           (s j = 92 && j + 1 < n && s (j + 1) = dl) (go (j + 2) (acc + string dl))
           (s j = dl) [(j + 1) acc]
           (go (j + 1) (acc + string (s j))))
       (go i ""))

   ; a pattern text -> [1 nodes]; "" reuses the last search. the wrapper is not
   ; decoration -- the empty pattern's nodes are legitimately ()
   (vexpat st tx)
    (? (0 < #tx) (rebre tx @ [_ nds _] [1 nds] ())
       (0 < #(st 'pattx)) [1 (st 'pat)]
       ())

   ; the next row matching nds from r in dir, wrapping; () when none does
   (vexfind st nds r dir)
    (: ls (st 'lines) nl #ls
       (go i steps)
        (nl < steps ? ()
           ((i % nl + nl) % nl @ k
              (two? (refind nds (ls k) 0) ? k (go (k + dir) (steps + 1)))))
       (go (r + dir) 1))

   (vaddr st s i dot)                              ; one address at i -> [j row] | 'bad | ()
    (: n #s
       (dig? k) (k < n && 48 <= s k <= 57)
       (num k acc) (dig? k ? (num (k + 1) (10 * acc + (s k - 48))) [k acc])
       (base k)
        (? (dig? k) (num k 0 @ [j v] [j (v - 1)])
           (n <= k) ()
           (s k = 46) [(k + 1) dot]
           (s k = 36) [(k + 1) (vnl st - 1)]
           (s k = 47 || s k = 63)
            (vexdelim s (k + 1) (s k) @ [j tx]
              (vexpat st tx @ cp
                 (? !(two? cp) 'bad
                    (: _ (0 < #tx ? (pins st 'pat <>cp 'pattx tx 'patw ()))
                       r (vexfind st <>cp dot (s k = 47 ? 1 -1))
                       (charm? r ? [j r] 'bad)))))
           ())
       (offs k r)                                  ; the +N / -N tail
        (k < n && (s k = 43 || s k = 45) ?
           ((s k = 43 ? 1 -1) @ sg
              (num (k + 1) 0 @ [j v] (offs j (r + sg * (j = (k + 1) ? 1 v)))))
           [k r])
       b (base i)
       (? (b = 'bad) 'bad
          (two? b) (offs <b <>b)
          (i < n && (s i = 43 || s i = 45)) (offs i dot)
          ()))

   ; [range] -> [next-index r1 r2 given?] | () when an address failed. % and a
   ; bare , are both 1,$; nothing at all is dot,dot, ungiven
   (vrange st s i)
    (: n #s dot (st 'row) last (vnl st - 1)
       (pair j a)
        (: dot2 (s j = 59 ? a dot)
           b (vaddr st s (j + 1) dot2)
           (? (b = 'bad) ()
              (two? b) [<b a <>b 1]
              [(j + 1) a a 1]))
       (? (i < n && s i = 37) [(i + 1) 0 last 1]
          (i < n && s i = 44) [(i + 1) 0 last 1]
          (vaddr st s i dot @ a
             (? (a = 'bad) ()
                !(two? a) [i dot dot ()]
                (: j <a r <>a
                   (j < n && (s j = 44 || s j = 59) ? (pair j r) [j r r 1]))))))

   ; -- substitute --
   ; `/pat/rep/flags` at i -> [1 matcher rep g?] | (). a fresh pattern also
   ; becomes the last search, which is where ex leaves it for n
   (vexspec st s i)
    (#s @ n
       (n <= i ? ()
          (s i @ dl
             (vexdelim s (i + 1) dl @ [j pat]
               (vexdelim s j dl @ [k rep]
                 (vexpat st pat @ cp
                    (two? cp ?
                       (0 < #pat ? (pins st 'pat <>cp 'pattx pat 'patw ()),
                        [1 (recomp <>cp) rep (vexhas? (snip s k n) 103)]))))))))
   (vexsubs st m rep a b g?)                       ; ((row text)..) for the rows that change
    (: (go r acc) (b < r ? (rev acc)
                     (usub m rep (st 'lines r) g? @ res
                        (go (r + 1) (<res ? ([r <>res] . acc) acc))))
       (go a ()))
   (vexlay st ps)                                  ; apply ((row text)..), answer the last row
    (: (go l lr) (? !(two? l) lr (<l @ h (vput st <h <>h, go >l <h)))
       (go ps 0))
   (vexdrop st rows)                               ; delete rows, given descending
    (: (go l) (two? l ? (vsplice st <l <l (), go >l))
       (go rows))
   (vexsub st s i r1 r2)
    (vexspec st s i @ sp
       (? !(two? sp) (vmsg st "bad substitution")
          (vexbad? st r1 r2) (vmsg st "out of range")
          (vexsubs st <>sp <>>sp r1 r2 <>>>sp @ hits
             (? !(two? hits) (vmsg st $ "not found: " + st 'pattx)
                (: _ (vsnap st)
                   lr (vexlay st hits)
                   (vexgo st lr,
                    vmsg st (show #hits + (1 = #hits ? " line" " lines") + " changed")))))))

   ; -- global --
   ; g/v collect the matching rows, then run the body on each from the last up,
   ; so a delete never moves a row still to be visited. the body is one of d, s
   ; and p -- the three that mean anything a line at a time.
   (vexgbody st body)
    ((0 < #body ? (body 0) 112) @ w
       (? (w = 100) ['d]
          (w = 112) ['p]
          (w = 115) (vexspec st body 1 @ [_ m rep g?] ['s m rep g?] ())
          ()))
   (vexhits st nds a b inv?)                       ; the matching rows, descending
    (: (go r acc)
        (b < r ? acc
           (two? (refind nds (st 'lines r) 0) @ m?
              (go (r + 1) ((inv? ? !m? m?) ? (r . acc) acc))))
       (go a ()))
   (vexplan st rows sp)                            ; the body, dry: what it would touch
    (<sp = 's ?
       (: (go l acc) (? !(two? l) acc
                        (: r <l res (usub <>sp <>>sp (st 'lines r) <>>>sp)
                           (go >l (<res ? ([r <>res] . acc) acc))))
          (go rows ()))
       rows)
   (vexglob st s i r1 r2 got? inv?)
    (: n #s
       a (got? ? r1 0) b (got? ? r2 (vnl st - 1))
       (? (n <= i) (vmsg st "no pattern")
          (vexbad? st a b) (vmsg st "out of range")
          (s i @ dl
             (vexdelim s (i + 1) dl @ [j pat]
               (vexpat st pat @ cp
                  (? !(two? cp) (vmsg st $ "bad pattern: " + pat)
                     (: _ (0 < #pat ? (pins st 'pat <>cp 'pattx pat 'patw ()))
                        sp (vexgbody st (vextrim (snip s j n)))
                        (? !(two? sp) (vmsg st "not a global command")
                           (vexhits st <>cp a b inv? @ rows
                              (? !(two? rows) (vmsg st $ "not found: " + st 'pattx)
                                 (<sp = 'p)
                                  (vexgo st (vexlast rows),
                                   vmsg st (show #rows + " lines"))
                                 (vexplan st rows sp @ plan
                                    (? !(two? plan) (vmsg st "not found")
                                       (vsnap st,
                                        <sp = 'd ? (vexdrop st plan) (vexlay st plan),
                                        vexgo st (<sp = 'd ? (vexlast rows) <(vexlast plan)),
                                        vmsg st (show #plan +
                                                 (<sp = 'd ? " fewer lines" " lines changed")))))))))))))))

   ; -- move, copy, join --
   ; the destination is one address after the verb, and 0 (row -1) is the line
   ; before the first
   (vexmove st s i r1 r2 copy?)
    (: d (vaddr st s (vexskip s i) (st 'row))
       nl (vnl st)
       (? !(two? d) (vmsg st "no destination")
          (<>d @ dr
             (? (vexbad? st r1 r2) (vmsg st "out of range")
                (dr < -1 || nl <= dr) (vmsg st "out of range")
                (!copy? && r1 - 1 <= dr <= r2) (vmsg st "destination inside the range")
                (: blk (vtake st r1 r2) k #blk
                   (vsnap st,
                    vsplice st (dr + 1) dr blk,
                    (? copy? ()
                       (dr < r1) (vsplice st (r1 + k) (r2 + k) ())
                       (vsplice st r1 r2 ())),
                    vexgo st (? copy? (dr + k) (dr < r1) (dr + k) dr),
                    vmsg st (show k + (1 = k ? " line" " lines") +
                             (copy? ? " copied" " moved"))))))))
   (vexjoin st r1 r2)
    (vexbad? st r1 r2 ? (vmsg st "out of range")
       (: _ (pin st 'row r1) n (r2 - r1 + 1) (vjoin st (n < 2 ? 2 n) 1)))

   ; :e / :o -- put another file in the buffer. this file touches no io, so the
   ; ex line leaves a request ('doe, uread's shape) exactly the way :w leaves
   ; 'dow, and the face performs it and calls vload. `!` forces over a dirty
   ; buffer. (vim's real `:o` is open mode -- a line-editor face we do not have
   ; and would not want; `:o NAME` reads as `:e NAME` here, which is what the
   ; hand reaching for it means.)
   (vedit st nm bang)
    (? (st 'dirty && !bang)
        (vmsg st "no write since last change (e! overrides)")
       (0 = tally nm) (vmsg st "no file name")
       (pin st 'doe [nm]))

   ; :set sw=N / shiftwidth=N (bare :set sw reports), and :set wrap / nowrap.
   ; two options: the number > and < move by, and how a line too long for the
   ; view is shown -- folded onto more screen rows, or slid under a window
   (vexset st arg)
    (: n #arg
       (eq k) (? (n <= k) () (arg k = 61) k (eq (k + 1)))
       j (eq 0)
       nm (vextrim (charm? j ? (snip arg 0 j) arg))
       (? (nm = "wrap" || nm = "nowrap")
           (pin st 'wrap (nm = "wrap" ? 1 ()),
            vmsg st (st 'wrap ? "wrap" "nowrap"))
          !(nm = "sw" || nm = "shiftwidth") (vmsg st $ "not an option: " + nm)
          !(charm? j) (vmsg st $ "shiftwidth=" + show (st 'sw))
          (: t (vextrim (snip arg (j + 1) n)) k #t
             (dig? i) (i < k && 48 <= t i <= 57)
             (go i acc) (dig? i ? (go (i + 1) (10 * acc + (t i - 48))) acc)
             (? (0 = k || !(dig? 0)) (vmsg st "shiftwidth wants a number")
                (go 0 0 @ v
                   (pin st 'sw (v < 1 ? 1 v),
                    vmsg st $ "shiftwidth=" + show (st 'sw)))))))

   ; -- the dispatch --
   (vexword s i)                                   ; the command name at i
    (: n #s
       (go k) (k < n && 97 <= s k <= 122 ? (go (k + 1)) k)
       k2 (go i)
       (? (i < k2) [k2 (snip s i k2)]
          (n <= i) [i ""]
          [(i + 1) (string (s i))]))
   ; the ex words and what each one means, so a head of one resolves to it: :spl is
   ; :split and :se is :set, unless two words with different meanings share the head.
   ; the face's own words ('exmore) count, each meaning itself. (word meaning) pairs
   vexwords '(("s" "s") ("g" "global") ("global" "global") ("v" "v")
              ("d" "delete") ("delete" "delete") ("y" "yank") ("yank" "yank")
              ("m" "move") ("move" "move") ("t" "copy") ("co" "copy") ("copy" "copy")
              ("j" "join") ("join" "join") ("p" "print") ("print" "print")
              ("nu" "number") ("number" "number") ("#" "#") ("=" "=")
              ("q" "q") ("w" "w") ("wq" "wq") ("x" "x")
              ("e" "edit") ("o" "edit") ("edit" "edit")
              ("hl" "hl") ("set" "set") ("lint" "lint")
              ("sp" "split") ("split" "split") ("vs" "vsplit") ("vsplit" "vsplit"))
   ; the word as typed when it is one, else the meaning of the one word it heads;
   ; ('many ..) when the heads mean different things, and the word itself when none
   (vexfull st w)
    (: ws (vexwords + map (x \ [x x]) (st 'exmore))
       hit (filter (p \ w = <p) ws)
       heads (filter (p \ (#<p @ k (#w < k && w = snip <p 0 #w))) ws)
       means (foldl (a \ p \ (elem <>p a ? a (<>p . a))) () heads)
       (? (two? hit) <>(<hit)
          !(two? means) w
          (two? >means) ['many (rev means)]
          <means))
   (vexcmd st s i r1 r2 got?)
    (vexword s i @ [j w0]
      (: n #s
         bang (j < n && s j = 33)
         k (bang ? (j + 1) j)
         arg (vextrim (snip s k n))
         nm (0 < #arg ? arg (st 'file))
         w (vexfull st w0)
         (? (two? w) (vmsg st ("ambiguous: " + w0 + " -- " + foldl (a \ m \ a + " " + m) "" <>w))
            (w = "s") (vexsub st s k r1 r2)
            (w = "global") (vexglob st s k r1 r2 got? ())
            (w = "v") (vexglob st s k r1 r2 got? 1)
            (w = "delete")
             (vexbad? st r1 r2 ? (vmsg st "out of range") (vopl st 100 r1 r2))
            (w = "yank")
             (vexbad? st r1 r2 ? (vmsg st "out of range") (vopl st 121 r1 r2))
            (w = "move") (vexmove st s k r1 r2 ())
            (w = "copy") (vexmove st s k r1 r2 1)
            (w = "join") (vexjoin st r1 r2)
            ; there is no printing to do on a screen, so these land the cursor
            ; on the range's last line. `l` is not among them -- it promises to
            ; spell control characters, and this frame does not
            (w = "print" || w = "number" || w = "#")
             (vexbad? st r1 r2 ? (vmsg st "out of range")
                (vexgo st r2, vmsg st (show (r2 - r1 + 1) + " lines")))
            (w = "=") (vmsg st (show (r2 + 1)))
            (w = "q") (? (bang || !(st 'dirty)) (pin st 'quit 1)
                         (vmsg st "no write since last change (q! overrides)"))
            (w = "w") (pin st 'dow [nm])
            (w = "wq" || w = "x") (pin st 'dow [nm], pin st 'quit 1)
            (w = "edit") (vedit st nm bang)
            (w = "split") (pin st 'dos ['stack arg])
            (w = "vsplit") (pin st 'dos ['beside arg])
            (w = "hl") (pin st 'hl (st 'hl ? () 1),
                        vmsg st (st 'hl ? "syntax on" "syntax off"))
            ; :set knows one option, which is the one > and < need a number for
            (w = "set") (vexset st arg)
            (w = "lint") (vlint st)                    ; libra's scan, on the buffer
            ; unknown here, but left on the state: a face with more ex words takes it
            (pin st 'dox [w arg], vmsg st $ "not an ex command: " + w))))
   (vex st)
    (: s (edtext (st 'cmd))
       n #s
       _ (pin st 'mode 'n)
       r (vrange st s 0)
       (? (n < 1) st
          !(two? r) (vmsg st "no match")
          (: i <r r1 <>r r2 <>>r got? <>>>r
             j (vexskip s i)
             (n <= j ? (got? ? (vexgo st r2) st)
                (vexcmd st s j r1 r2 got?)))))

   ; -- insert mode --
   (vins st c)
    (: r (st 'row) col (st 'col) ln (vln st) len #ln
       (? (c = 27) (pin st 'mode 'n,
                    vgole st (vpv ln col),
                    vclampn st)
          (c = 13 || c = 10)
           (vput st r (snip ln 0 col),
            vsplice st (r + 1) r [(snip ln col len)],
            pin st 'row (r + 1),
            vgole st 0)
          (c = 8 || c = 127)
           (? (0 < col) (vpv ln col @ p
                           (vput st r (snip ln 0 p + snip ln col len),
                            vgole st p))
              (0 < r) (: pv (st 'lines (r - 1)) pl #pv
                         (vsplice st (r - 1) r [(pv + ln)],
                          pin st 'row (r - 1),
                          vgole st pl))
              st)
          ; ^W back over one word, ^U back to the line's first non-blank (or its
          ; start, when the cursor already sits there)
          (c = 23)
           (: (bk i p) (0 < i && p (vcl (ln (i - 1))) ? (bk (i - 1) p) i)
              a (bk col (k \ k = 0) @ j (bk j (k \ k != 0)))
              (a < col ? (vput st r (snip ln 0 a + snip ln col len), vgole st a) st))
          (c = 21)
           (: k (vink ln) a (k < col ? k 0)
              (a < col ? (vput st r (snip ln 0 a + snip ln col len), vgole st a) st))
          (c = 9 || 32 <= c)
           (vput st r (snip ln 0 col + string c + snip ln col len),
            vgole st (col + 1))
          ; the arrows: insert's cursor may sit past the last char, so the fences are
          ; the line's length, and up and down keep the goal column as j and k do
          (c = -1) (vgole st (vpv ln col))
          (c = -2) (vgole st (col < len ? (vnx ln col) len))
          (c = -8 || c = -9)
           ((c = -8 ? (r - 1) (r + 1)) @ k
              (k < 0 || vnl st <= k ? st
                 (pin st 'row k, pin st 'col (vcolat (vln st) (st 'goal)))))
          st))

   ; -- the pending char-argument commands --
   ; keys come a byte at a time, so a utf-8 lead waits in 'pcb for its tail and the
   ; argument goes on as the character's text; a torn one goes on as what came
   (vpcu st c)
    (: b (st 'pcb)
       s (? (0 < #b) (b + string c) (192 <= c < 248) (string c) ())
       (? (c = 27) (pin st 'pcb "", vpc st c)
          !s (vpc st c)
          (: l (s 0) need (? (l < 224) 2 (l < 240) 3 4)
             (#s < need && (#s = 1 || c & 192 = 128) ? (pin st 'pcb s)
                (pin st 'pcb "", vpc st s)))))
   (vpc st c)
    (: k (st 'pc) n (st 'cnt @ v (0 < v ? v 1))
       (pin st 'pc (), pin st 'cnt 0,
        (? (c = 27) (pin st 'op (), st)            ; escape drops the pending operator too
           ; r replaces n characters, all of them there or none
           (k = 'r) ((? (string? c) c (c = 9 || 32 <= c) (string c) ()) @ t
                       (!t ? st
                          (: ln (vln st) len #ln col (st 'col)
                             lst (vchars ln col (n - 1))
                             (lst < len ?
                                (: (rep i acc) (i < 1 ? acc (rep (i - 1) (acc + t)))
                                   (vsnap st,
                                    vput st (st 'row) (snip ln 0 col + rep n "" + snip ln (vnx ln lst) len),
                                    vgole st (col + (n - 1) * #t)))
                                st))))
           (k = 'g) (? (c = 103)                                ; gg
                       (: t (0 < st 'gcnt ? (st 'gcnt - 1) 0)
                          nl (vnl st)
                          t2 (t < nl ? t (nl - 1))
                          mr ['lin t2]
                          op (st 'op)
                          (pin st 'op (),
                           two? op ? (vapply st <op mr)
                           (pin st 'row t2, vgole st (vink (vln st)))))
                       (c = 74) (vjoin st n ())                 ; gJ: no blank between
                       (c = 95) (: nl (vnl st)                  ; g_: last non-blank
                                   t (st 'row + (n - 1) @ k (k < nl ? k (nl - 1)))
                                   ln (st 'lines t)
                                   (bk i) (0 < i && (ln (i - 1) = 32 || ln (i - 1) = 9) ?
                                             (bk (i - 1)) i)
                                   e (bk #ln)
                                   op (st 'op) _ (pin st 'op ())
                                   mr ['toi t (vpv ln e)]
                                   (two? op ? (vapply st <op mr)
                                    (pin st 'row t, vgole st <>>mr, st)))
                       st)
           ; zt zz zb: the view slides under the cursor, the cursor stays put
           (k = 'z) (: body (st 'h - 1) r (st 'row)
                       t (c @ 116 r
                              98 (vskip st r -1 (body - 1))
                              (122 || 46) (vskip st r -1 (body // 2))
                              (st 'top))
                       (pins st 'top t 'tops 0, st))
           (k = 'Z) (c != 90 ? st (pins st 'dow [(st 'file)] 'quit 1))
           ; i and a after an operator name a text object rather than insert mode
           (k = 'ti || k = 'ta)
            (: mr (vobj st (k = 'ta) c n)
               op (st 'op)
               (pin st 'op (),
                two? mr && two? op ? (vapply st <op mr) st))
           ; f F t T -- and the pair is remembered, which is what ; and , repeat
           (: a (string? c ? c (string c))
              mr (vfind st k a n)
              op (st 'op)
              (pin st 'lastf [k a],
               pin st 'op (),
               (? !(two? mr) st
                  (two? op) (vapply st <op mr)
                  (vgole st <>>mr)))))))

   ; -- normal mode --
   (vnorm st c)
    (: n (st 'cnt @ v (0 < v ? v 1))
       (mv1 mr)                                    ; a motion result, no operator
        (? (atom? mr) st
           (<mr = 'lin)
            (<>mr @ t (pin st 'row t,
                       pin st 'col (: ln (vln st) k (vcolat ln (st 'goal))
                                    (k < #ln ? k (vend ln)))))
           ; 'linb is 'lin that lands on the line's first ink: + - _ and the ex
           ; addresses do that and j and k deliberately do not
           (<mr = 'linb) (pin st 'row <>mr, vgole st (vink (vln st)))
           ; a span with no operator lands on whichever end the cursor is not at,
           ; which is what makes % a motion as well as a range
           (<mr = 'spn)
            (: t >>>mr
               p (<>mr = st 'row && <>>mr = st 'col ? [<t (0 < <>t ? (<>t - 1) 0)]
                    [<>mr <>>mr])
               (pin st 'row <p,
                vgole st <>p))
           (pin st 'row <>mr,
            vgole st (: c2 <>>mr lim (vend (vln st)) (lim < c2 ? lim c2))))
       (motion mr)
        (: op (st 'op) (pin st 'op (),
                        (? !(two? mr) st
                           (two? op) (vapply st <op mr)
                           (mv1 mr))))
       (page d) (: h (st 'h) step (c @ (6 || 2) (h - 2) ((h - 2) // 2))
                   (pin st 'row (vskip st (st 'row) d step),
                    vclampn st))
       rawc (st 'cnt)
       _ (pin st 'cnt 0)
       ; a diagonal is its two halves, each a plain motion of the count; an operator
       ; pending is dropped -- a diagonal is not a range
       (diag vc hc) (two? (st 'op) ? (pin st 'op ())
                       (mv1 (vmot st vc n rawc), mv1 (vmot st hc n rawc)))
       (? ; an operator is pending and i or a arrives: a text object, not insert
          (two? (st 'op) && (c = 105 || c = 97))
           (pins st 'cnt n 'pc (c @ 105 'ti 'ta))
          (elem c '(104 108 48 94 36 124 119 101 98 87 69 66 106 107 71
                    43 13 45 95 123 125 72 76 77 37))
           (motion (vmot st ((c = 119 || c = 87) &&                 ; the vi special case:
                             (st 'op @ o                          ; cw changes the word only,
                                (two? o && <o = 99)) ?
                              (c = 119 ? 101 69) c)                ; ... so cw rides e
                          n rawc))
          (c = 377) (diag 107 104)  (c = 373) (diag 107 108)         ; alt-y alt-u: up-left, up-right
          (c = 354) (diag 106 104)  (c = 366) (diag 106 108)         ; alt-b alt-n: down-left, down-right
          (elem c '(102 70 116 84))                            ; f F t T
           (pin st 'cnt n,
            pin st 'pc (? (c = 102) 'f (c = 70) 'F (c = 116) 't 'T))
          (c = 103) (pin st 'gcnt rawc, pin st 'pc 'g)
          (c = 90) (pin st 'pc 'Z)
          (c = 122) (pin st 'pc 'z)                             ; zt zz zb
          (c = 114) (pin st 'cnt n, pin st 'pc 'r)
          ; ; and , -- the last f F t T again, forward and the other way
          (c = 59 || c = 44)
           (st 'lastf @ lf
              (? !(two? lf) st
                 (motion (vfind st (c = 59 ? <lf (<lf @ 'f 'F 'F 'f 't 'T 't)) <>lf n))))
          (elem c '(100 121 99 62 60))                       ; d y c > <
           (: op (st 'op)
              (two? op && <op = c ?
                 (n * <>op @ total
                    (pin st 'op (),
                     vopl st c (st 'row) (: t (st 'row + total - 1) nl (vnl st)
                                            (t < nl ? t (nl - 1)))))
                 (pin st 'op [c n], st)))
          (c = 120) (vln st @ ln                                ; x
                       (0 < #ln ? (vopc st 100 (st 'row) (st 'col) (vchars ln (st 'col) n)) st))
          (c = 88) (0 < st 'col ?                               ; X
                      (vopc st 100 (st 'row) (vcharsb (vln st) (st 'col) n) (st 'col))
                      st)
          (c = 68) (vlen st @ len                               ; D
                      (st 'col < len ? (vopc st 100 (st 'row) (st 'col) len) st))
          (c = 67) (vlen st @ len                               ; C
                      (st 'col < len ? (vopc st 99 (st 'row) (st 'col) len)
                         (vsnap st, pin st 'mode 'i),
                       st))
          (c = 115) (vln st @ ln                                ; s
                       (0 < #ln ?
                          (vopc st 99 (st 'row) (st 'col) (vchars ln (st 'col) n))
                          (vsnap st, pin st 'mode 'i, st)))
          (c = 74) (vjoin st n 1)                               ; J
          (c = 89) (vopl st 121 (st 'row)                       ; Y: yy, the whole line
                         (: t (st 'row + n - 1) nl (vnl st) (t < nl ? t (nl - 1))))
          (c = 83) (vopl st 99 (st 'row)                        ; S: cc
                         (: t (st 'row + n - 1) nl (vnl st) (t < nl ? t (nl - 1))))
          (c = 126) (: ln (vln st) len #ln col (st 'col)        ; ~
                       (len < 1 ? st
                          (vchars ln col n @ e
                             (vsnap st,
                              vput st (st 'row)
                                  (snip ln 0 col + vflip (snip ln col e) + snip ln e len),
                              pin st 'dirty 1,
                              vgole st (e < len ? e (vend ln))))))
          (c = 42) (vstar st 1)  (c = 35) (vstar st -1)         ; * #
          (c = 1) (vincr st n)   (c = 24) (vincr st (0 - n))    ; ^A ^X
          (c = 46) (vdot st rawc)                               ; .
          (c = 105) (vsnap st, pin st 'mode 'i)          ; i
          (c = 97) (vsnap st, ; a
                    vgole st (0 < vlen st ? (vnx (vln st) (st 'col)) 0),
                    pin st 'mode 'i)
          (c = 73) (vsnap st, vgole st (vink (vln st)), pin st 'mode 'i)   ; I
          (c = 65) (vsnap st, vgole st (vlen st), pin st 'mode 'i)         ; A
          (c = 111) (vsnap st, ; o
                     vsplice st (st 'row + 1) (st 'row) '(""),
                     pin st 'row (st 'row + 1),
                     vgole st 0,
                     pin st 'mode 'i)
          (c = 79) (vsnap st, ; O
                    vsplice st (st 'row) (st 'row - 1) '(""),
                    vgole st 0,
                    pin st 'mode 'i)
          (c = 112) (vpaste st 1 n)                             ; p
          (c = 80) (vpaste st () n)                             ; P
          (c = 118 || c = 86)                                   ; v V: visual, from here
           (pin st 'op (), pins st 'va [(st 'row) (st 'col)] 'mode (c = 118 ? 'v 'V))
          (c = 117) (vundo st)                                  ; u
          (c = 18) (vredo st)                                   ; ^R
          (c = 58) (pin st 'cmd (ednew ()), pin st 'mode 'c)     ; :
          (c = 47 || c = 63)                                    ; / ?
           (pin st 'cmd (ednew ()), pin st 'dir (c = 47 ? 1 -1), pin st 'mode 's)
          (c = 110) (two? (st 'pat) ? (vhunt st (st 'dir)) (vmsg st "no previous search"))
          (c = 78) (two? (st 'pat) ? (vhunt st (0 - st 'dir)) (vmsg st "no previous search"))
          (c = 6) (page 1) (c = 2) (page -1)                    ; ^F ^B
          (c = 4) (page 1) (c = 21) (page -1)                   ; ^D ^U (half via `page`)
          st))

   ; -- the dot register ---------------------------------------------------------
   ; `.` repeats the last CHANGE by keeping its keys. recording opens on a command
   ; that changes text and runs until normal mode is quiet again -- no pending
   ; operator or char argument, out of insert -- so `ciwfoo<esc>` is one entry.
   ; the count is kept APART from the keys, being the half a count on `.` replaces:
   ; `3dd` records as (3 "dd"), and `2.` feeds `2dd`.
   (vchange? c) (elem c '(120 88 68 67 115 83 114 74 126 112 80
                          105 97 73 65 111 79 100 99 62 60 1 24))
   (vquiet? st) ((st 'mode = 'n) && !(st 'pc) && !(two? (st 'op)))
   ; -- visual mode: the selection is the anchor 'va and the cursor, the motions
   ; walk the cursor as in normal mode, o swaps the ends, v and V change the kind
   ; or leave, and an operator takes the whole of it -- charwise both ends in, or
   ; the lines -- and leaves. a search returns to it; anything else is nothing
   (vback st) (two? (st 'va) ? (st 'vkind) 'n)
   vmotions '(104 108 48 94 36 124 119 101 98 87 69 66 106 107 71 43 13 45 95 123 125
              72 76 77 37 102 70 116 84 103 59 44 110 78 6 2 4 21 377 373 354 366)
   (vvis st c)
    (: kind (st 'mode) a (st 'va) r (st 'row) col (st 'col)
       r1 (<a < r ? <a r) r2 (<a < r ? r <a)
       fwd? (<a < r || <a = r && <>a <= col)
       c1 (fwd? ? <>a col) c2 (fwd? ? col <>a)
       (leave _) (pins st 'va () 'mode 'n)
       (op opc) (leave (),
                 kind = 'V || vlinop? opc ? (vopl st opc r1 r2)
                   (vospn st opc r1 c1 r2 (vnx (st 'lines r2) c2)))
       (? (c = 27) (leave ())
          (c = 118 || c = 86) ((c = 118 ? 'v 'V) @ k (k = kind ? (leave ()) (pin st 'mode k)))
          (c = 111) (pin st 'va [r col], pin st 'row <a, vgole st <>a)
          (elem c '(121 100 120 99 62 60)) (op (c = 120 ? 100 c))
          (48 <= c <= 57 && (48 < c || 0 < st 'cnt)) (pin st 'cnt (10 * st 'cnt + c - 48))
          (c = 47 || c = 63) (pin st 'vkind kind, vnorm st c)
          (c = 58) (leave (), vnorm st c)
          (elem (arrow c) vmotions) (vnorm st (arrow c))
          st))
   (vdigits k) (show k @ s (map (i \ s i) (jot #s)))
   (vdot st raw)
    (st 'dot @ d
       (atom? d ? (vmsg st "nothing to repeat")
          (: k (0 < raw ? raw <d)
             ks (0 < k ? (vdigits k + <>d) <>d)
             _ (pin st 'op ())                     ; `.` is not a motion: d. is just .
             _ (pin st 'dotting 1)
             s2 (vfeed st ks)
             (pin s2 'dotting (),
              s2))))

   ; -- the one door: state x key -> state. a key is a byte, or one of cli's edkey codes:
   ; the arrows (h j k l in normal mode, insert's own), alt letters, home and end --
   ; space and backspace are l and h, as they are in every vi
   (arrow c) (c @ -1 104 -2 108 -8 107 -9 106 32 108 (8 || 127) 104 c)
   (vstep st c)
    (: rec (st 'rec)
       on? (two? rec)
       start (!(st 'dotting) && !on? && vquiet? st && vchange? c)
       _ (start ? (pin st 'reccnt (st 'cnt)))
       _ (start || on? ? (pin st 'rec (c . (on? ? rec ()))))
       s2 (vstep1 st c)
       (two? (s2 'rec) && vquiet? s2 ?
           (pins s2 'dot [(s2 'reccnt) (rev (s2 'rec))] 'rec ())
          s2))
   (vstep1 st c)
    (st 'mode @ m
       (? (m = 'i) (vins st c)
          (m = 'v || m = 'V) (st 'pc ? (vpcu st c) (vvis st c))
          (m = 'c || m = 's)
           ; the line is cli's prompt; a backspace on nothing leaves too, which is vi's
           ; own rule and no prompt's
           (st 'cmd @ t
              ((c = 127 || c = 8 || c = -3) && edempty? t ? (pin st 'mode 'n)
                 (edcmd st 'cmd c
                  (s \ (pin st 'mode (m = 's ? (vback st) 'n),
                        vmsg st "",
                        (? (m = 'c) (vex st)
                           (s = "") (two? (st 'pat) ? (vhunt st (st 'dir)) st)
                           (rebre s @ b
                              (two? b ?
                                 (pins st 'pat <>b 'pattx s 'patw (),
                                  vhunt st (st 'dir))
                                 (vmsg st $ "bad pattern: " + s))))))
                  (_ \ pin st 'mode (m = 's ? (vback st) 'n)))))
          ; normal
          (? (st 'pc) (vpcu st c)
             (48 <= c <= 57 && (48 < c || 0 < st 'cnt))
              (pin st 'cnt (10 * st 'cnt + c - 48))
             (c = 27) (pins st 'cnt 0 'op (), vmsg st "")
             (vmsg st "", vnorm st (arrow c)))))
   (vfeed st bs) (bs @ (a . u) (vfeed (vstep st a) u) st)

   ; -- birth --
   ; the paint is born on for a language hues-lang knows and off for everything
   ; else, which is also why every frame law below still reads the plain bytes it
   ; always did: they open their buffers as "t".
   (vnew ls file)
    {'lines (two? ls ? ls '(""))
     'row 0 'col 0 'goal 0 'top 0 'tops 0 'left 0 'wrap ()
     'mode 'n 'cnt 0 'op () 'pc () 'pcb "" 'gcnt 0 'lastf ()
     'reg () 'undo () 'redo ()
     'dot () 'rec () 'reccnt 0 'dotting ()
     'file file 'dirty () 'msg "" 'sw 2
     'cmd "" 'pat () 'pattx "" 'patw () 'dir 1
     'quit () 'dow () 'doe () 'dos () 'dox () 'va () 'exmore ()
     'hl (nom? (hues-lang file (two? ls ? <ls ""))) 'pens () 'lex () 'hlcar () 'hlgen 0 'hlrow (tablet ())
     'lncar () 'laycar () 'lastr () 'w 80 'h 24}

   ; -- the frame ---------------------------------------------------------------
   ; vlay settles the view and works out what the screen should hold: the body rows
   ; (windowed, painted), the status line (clipped), and where the cursor goes.
   ; vframe writes all of it; vfresh writes the difference. one layout under both.
   (vlay st)
    (: w (st 'w) h (st 'h) body (h - 1) ls (st 'lines)
       wrap? (st 'wrap) row (st 'row) cln (vln st)
       (hgt ln) (vhgt st ln)
       ; the cursor's screen row within its line and the byte that row opens on
       cseg (: (go l i) (two? >l && <>l <= st 'col ? (go >l (i + 1)) [i <l])
               (wrap? ? (go (vsegs cln w) 0) [0 0]))
       cs <cseg
       ; -- settle the view. unwrapped, 'top is the old row arithmetic and 'left
       ; slides half a screen at a time, never further right than the line's end.
       ; wrapped, the corner carries a segment offset too and the distance to the
       ; cursor is a walk -- over a screenful of lines at most, each being a row.
       _ (wrap? ?
            ((row - (body - 1) @ q (q < 0 ? 0 q)) @ lo
               (st 'top < lo ? (pins st 'top lo 'tops 0),
                (row < st 'top || row = st 'top && cs < st 'tops)
                ? (pins st 'top row 'tops cs)))
            (: _ (row < st 'top ? (pin st 'top row))
               _ ((st 'top + (body - 1)) < row ? (pin st 'top (row - (body - 1))))
               ; 'left is a screen column, and the cursor's character shows whole
               col (st 'col)
               cc0 (vcols cln 0 col)
               cw (col < #cln ? (vcw cln col) 1)
               lim (vcols cln 0 #cln - w @ q (q < 0 ? 0 q))
               ((cc0 < st 'left || st 'left + w < cc0 + cw)
                ? (pin st 'left (cc0 - w // 2 @ q (? (q < 0) 0 (lim < q) lim q))))))
       t0 (st 'top) l0 (vdrop ls t0)
       ; the screen rows from the view's corner down to the cursor, inclusive
       cnt (!wrap? ? (row - t0 + 1)
               (: (go l i acc) (row <= i ? (acc + cs + 1 - st 'tops)
                                  (go >l (i + 1) (acc + hgt <l)))
                  (go l0 t0 0)))
       ; further than the body reaches: slide the corner down by the overflow
       _ ((wrap? && body < cnt)
          ? (: (adv l i k d) (? !(two? l) [i k]
                                (hgt <l - k @ e
                                   (d < e ? [i (k + d)] (adv >l (i + 1) 0 (d - e)))))
               q (adv l0 t0 (st 'tops) (cnt - body))
               (pins st 'top <q 'tops <>q)))
       top (st 'top) tops (st 'tops) left (st 'left)
       ; the status line clips from the LEFT: its tail carries the news (row,col, the
       ; ": 12 lines", the end of the : being typed), which a deep path would push off
       ; the screen. `<` marks the cut.
       (clipl ln) (#ln @ k (w < k ? ("<" + snip ln (k - w + 1) k) ln))
       ; -- the paint. escapes are zero width, so the window is cut in plain columns
       ; and painted from there: every column worked out below is the plain one,
       ; cursor included. off, this whole lane vanishes.
       ; a language the name does not tell paints as .l, once :hl asks for it
       lg (st 'hl && tablet? (st 'pens) ? (vlang st @ g (nom? g ? g 'l)))
       lx (nom? lg ? (vlex st lg))
       paint (lit? lx)
       car (paint ? (vcarry st lg lx))
       ; the painted window, cached against the text that made it, the carry it began
       ; on and the columns it was cut to -- keyed by SCREEN row, so the table is the
       ; height of the view and never the height of the file. typing moves one row;
       ; the other twenty-odd are answered out of here without the lexer running
       ; the selection, on a row of the file: its columns [s1 s2), or () off it. a
       ; charwise one runs both ends in; a line takes one cell at least, so an empty
       ; line still shows
       vis? (st 'mode = 'v || st 'mode = 'V)
       va (st 'va)
       vr1 (vis? ? (<va < row ? <va row) 0) vr2 (vis? ? (<va < row ? row <va) 0)
       vfwd? (vis? && (<va < row || <va = row && <>va <= st 'col))
       vc1 (vfwd? ? <>va (st 'col)) vc2 (vfwd? ? (st 'col) <>va)
       (sel fr raw) (!vis? || fr < vr1 || vr2 < fr ? ()
                       (#raw @ k
                          (? (st 'mode = 'V) [0 (k < 1 ? 1 k)]
                             (vr1 = vr2) [vc1 (vnx raw vc2)]
                             (fr = vr1) [vc1 (vnx raw vc1 @ e (k < e ? e k))]
                             (fr = vr2) [0 (vnx raw vc2)]
                             [0 (k < 1 ? 1 k)])))
       ; win is the row's [a b pad]: its bytes, and the blank a cut wide character leaves
       (lay raw in i win fr)
        (: k #raw a <win b (<>win @ e (k < e ? k e))
           s (sel fr raw)
           (vblanks <>>win +
           (? (two? s && (k = 0 || <s < b) && a < <>s)
               (: p (<s < a ? a <s) q (b < <>s ? b <>s)
                  pad (k < <>s && q = k ? " " "")       ; the cell past the end, a line's own
                  (snip raw a p + "\e[7m" + snip raw p q + pad + "\e[0m" + snip raw q b))
              (b <= a) ""
              !paint (snip raw a b)
              (: rw (st 'hlrow) ky [raw in a b lg] c (peep rw i ())
                 (two? c && <c = ky ? <>c
                    (hue-win (st 'pens) lx raw in a b @ p
                       (pin rw i [ky p],
                        p)))))))
       ; 'lines and the carry are LISTS: asking for row i by application walks i
       ; pairs, so a screenful deep in a file walked the file forty times over --
       ; 55% of a keystroke, and the whole of why moving around got slower the
       ; further down you were. drop to the corner once and step from there
       (rows l cl i k acc fr)
        (? (body <= i) (rev acc)
           !(two? l) (rows l cl (i + 1) 0 ("~" . acc) fr)
           (: raw <l
              win (wrap? ? (vdrop (vsegs raw w) k @ sg [<sg (two? >sg ? <>sg #raw) 0])
                     (vwin raw left w))
              r (lay raw <cl i win fr)
              (wrap? && k + 1 < hgt raw ? (rows l cl (i + 1) (k + 1) (r . acc) fr)
                 (rows >l >cl (i + 1) 0 (r . acc) (fr + 1)))))
       status (? (st 'mode = 'c) (":" + edtext (st 'cmd))
                 (st 'mode = 's) ((0 < st 'dir ? "/" "?") + edtext (st 'cmd))
                 (0 < #(st 'msg)) (st 'msg)
                 ((? (0 < #(st 'file)) (st 'file) "[no name]") + (st 'dirty ? " [+]" "")
                  + (st 'mode @ 'i " -- INSERT --" 'v " -- VISUAL --" 'V " -- VISUAL LINE --" "")
                  + "  " + show (st 'row + 1) + "," + show (st 'col + 1)))
       ; in ex and search mode you are typing on the status line, so that is
       ; where the cursor goes: after the prefix, at the editor's column
       said? (st 'mode = 'c || st 'mode = 's)
       cr (said? ? h (body < cnt ? body cnt))
       cc (: k (? said? (edcol (st 'cmd) + 2)
                  wrap? (vcols cln <>cseg (st 'col) + 1)
                  (vcols cln 0 (st 'col) - left + 1))
             (w < k ? w k))
       ; the body is a pure function of these, so when none of them moved the rows
       ; are the ones we laid last time -- a keystroke that only walks the cursor
       ; about lays nothing at all, which is the common keystroke
       key [(st 'hlgen) w top tops left body (paint ? 1 ()) (wrap? ? 1 ())
            (vis? ? [(st 'mode) vr1 vc1 vr2 vc2])]
       lc (st 'laycar)
       rs (two? lc && <lc = key ? <>lc
             (rows (vdrop l0 (top - t0)) (vdrop car top) 0 tops () top @ k
                (pin st 'laycar [key k],
                 k)))
       [rs (clipl status) cr cc key])

   ; -- the frame: one full redraw as a single text --
   (vframe st)
    (: e (string 27) L (vlay st)
       (go l acc) (atom? l ? acc (go >l (acc + <l + e + "[K" + "\r\n")))
       (e + "[H" + go <L "" + <>L + e + "[K"
          + e + "[" + show <>>L + ";" + show <>>>L + "H"))

   ; -- the frame as a refresh: only what changed -------------------------------
   ; src/apps/tui.l does the diffing; what is vi's here is the geometry that says the view
   ; has not moved, and vlay's own key, which says the body cannot have changed
   (vfresh st)
    (: L (vlay st)
       (tui-fresh st (st 'h)
                  [(st 'w) (st 'h) (st 'top) (st 'tops) (st 'left)]
                  (L 4) <L <>L <>>L <>>>L)))
) ; module 'vi
