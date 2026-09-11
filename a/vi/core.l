; a/vi/core.l -- the vi engine, pure: a state tablet stepped one byte at a
; time (vstep), rendered to escape sequences -- vframe writes a whole screen,
; vfresh writes the difference from the last one. no port, no tty, no file io
; in here -- the face (a/vi/vi.l) reads keys, performs the write requests the
; ex commands leave on the state, and blits frames; the laws (t/law/vi.l)
; drive vstep with byte lists and read the tablet back.
; search rides a/kore/re.l (rebre/refind), so re.l loads first in any cat.
;
; the state (a tablet): 'lines (texts, never empty -- the vi invariant),
; 'row 'col (0-based), 'goal (the column j/k aim for), 'top (first visible row),
; 'mode ('n normal, 'i insert, 'c ex, 's search), 'cnt (pending count), 'op
; (pending operator (char n) or ()), 'pc (pending char-arg nom: f F t T r g z Z,
; and ti/ta for a text object), 'lastf (the f F t T that ; and , repeat), 'reg
; (the yank: ('lin lines) | ('chr text), a charwise text carrying newlines when the
; cut crossed rows), 'undo 'redo (snapshot stacks), 'dot 'rec 'reccnt 'dotting (the
; `.` register: the last change's keys, its count apart from them, and the guard
; keeping a replay from recording itself), 'file 'dirty 'msg 'sw (the shiftwidth
; > and < move by), 'cmd (the ex/search line), 'pat 'pattx 'patw (the search state;
; 'patw is * and #'s word-bounding, which re.l's engine has no node for), 'dir,
; 'quit (() | 1), 'dow (a write request: (name), uread's shape, the face consumes
; it), 'doe (a READ request, same shape: :e/:o leave it, the face calls vload),
; 'w 'h (the view).
;
; the syntax paint rides a/vi/hue.l and five more keys: 'hl (paint? -- born on for
; a .l name, :hl flips it), 'pens (the class -> escape tablet, installed by the FACE
; so this file touches no getenv and no file), 'book (the vocabulary, folded once at
; the first paint), 'hlcar (the per-line "starts inside a string" carry as
; [gen flags] -- the wrapper is load-bearing, gen 0 over an empty buffer being a real
; cached value a bare one could not tell from "no cache"), 'hlgen (bumped by the three
; line mutators, vput/vsplice/vrest, and nothing else touches 'lines), 'hlrow (the
; painted row per SCREEN row, keyed by the text, carry and width it came from).
; the lexer is not only the paint's: % and the bracket objects read its runs to know
; which ( is code, which is why a ) in a literal is not a mate.
;
; the dialect: motions h j k l (space and backspace too, and the arrows)
; 0 ^ $ | w b e W B E f F t T ; , { } + - _ G gg g_ H M L %, counts, the
; diagonals alt-y u b n (cli's edkey hands an alt letter in as 256 + the
; letter: a k or j then an h or l, the count on both, and never under an
; operator), operators d c y > < (doubled = linewise; with j/k/G/gg linewise,
; else charwise, crossing rows when the motion does -- dw stops where the
; word ends the line, vim's own special case), the text objects i and a with
; w W p ( ) b [ ] { } B < > " ' `, x X D C s S r J gJ ~ Y, i a I a o O,
; p P (lin + chr), u and ^R, `.` with a count, ^A ^X, * # / ? n N (BRE, over
; re.l), zt zz zb, ZZ, ^F ^B ^D ^U paging, and ^W ^U in insert.
;
; the ex line is a real one: [range] command [args], where an address is
; N . $ /re/ ?re? with +N / -N offsets, joined by , or ; and % for 1,$. the
; commands are s (over sed's own usub, so & and \1 read the same there as
; here), g and v, d y m t co j p nu = , and the file half w [NAME] e[!] [NAME]
; o [NAME] q q! wq x hl lint set. a bare range moves the cursor.
; out of scope, documented: visual mode, named registers ("a and the rest),
; marks (m ' `), macros (q @), :r and :!, g~ gu gU, sentence motions ( and ),
; ge, ^E ^Y, gj gk, tabs render raw (the terminal's stops, not ours), no
; horizontal scroll (long lines clip at the view's edge).
(module 'vi
(borrow 'kore) ; the text/u floors
(borrow 'lint)  ; lint-scan, spliced for this module's compile
(:
   ; -- the small floor --
   ; lists do not index by application (a number list would church-tower), so
   ; the row walk is explicit; "" past the end keeps every reader total
   ; the cursor's line. 'lines is a LIST, so asking for row r walks r pairs, and
   ; one keystroke asks many times -- so it is cached against the row and the
   ; generation, the two things that can make the answer stale
   (vln st)
    (: c (st 'lncar)
       (? (two? c && <c = st 'row && <>c = st 'hlgen) <>>c
          (: t (st 'lines (st 'row))
             _ (pin st 'lncar [(st 'row) (st 'hlgen) t])
             t)))
   (vlen st) (tally (vln st))
   (vnl st) (tally (st 'lines))
   (vink ln) (: n #ln                       ; first non-blank column
                 (go i) (? (i < n && (ln i = 32 || ln i = 9)) (go (i + 1)) i)
                 (: k (go 0) (? (k < n) k (0 < n) (n - 1) 0)))
   ; every edit to 'lines bumps the generation, which is what lets the paint's
   ; string carry be recomputed once per edit instead of once per keystroke
   (vgen st) (pin st 'hlgen (st 'hlgen + 1))
   (vput st r ln) (: _ (pin st 'lines (: (go l i) (? !(two? l) ()
                                                     ((? (i = r) ln <l) . go >l (i + 1)))
                                         (go (st 'lines) 0)))
                     (vgen st))
   (vgole st c) (pins st 'col c 'goal c)
   (vclampn st) (: n (vlen st)                     ; normal-mode col fence
                    (? (st 'col < n) st
                       (vgole st (? (0 < n) (n - 1) 0))))
   (vcl c) (? (c = 32 || c = 9) 0              ; char class: blank / word / ink
              (48 <= c <= 57 ||
               65 <= c <= 90 ||
               97 <= c <= 122 || c = 95) 1
              2)
   (vclw c) (? (c = 32 || c = 9) 0 1)          ; the WORD class: blank / everything else
   (vupc c) (? (97 <= c <= 122) (c - 32) (65 <= c <= 90) (c + 32) c)   ; ~'s flip
   (vflip t) (: n #t (go i acc) (? (n <= i) acc (go (i + 1) (acc + string (vupc (t i)))))
                (go 0 ""))
   (vlead ln) (: n #ln                         ; the leading blanks, as a count
                 (go i) (? (i < n && (ln i = 32 || ln i = 9)) (go (i + 1)) i)
                 (go 0))
   (vblanks n) (: (go i acc) (? (i < 1) acc (go (i - 1) (acc + " "))) (go n ""))
   (vmsg st m) (pin st 'msg m)
   (vsnap st) (pins st 'undo ([(st 'lines) (st 'row) (st 'col)] . st 'undo) 'redo ())
   (vrest st fr) (: _ (pins st 'lines <fr 'row <>fr)
                     _ (vgole st <>>fr) _ (pin st 'dirty 1) (vgen st))

   ; the pure half of :e -- the face reads the file and hands the lines over, this
   ; starts the buffer over on them: cursor home, no history, not dirty. the paint
   ; is re-decided from the new name, so :e-ing a .l from a .md lights up and the
   ; other way round goes plain, and the generation bump drops the cached carry
   ; along with the old buffer it described.
   (vload st ls nm)
    (pins st 'lines (? (two? ls) ls '("")) 'file nm 'row 0 'top 0,
     vgole st 0,
     pins st 'undo () 'redo () 'dirty () 'hl (vdotl nm),
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
       (at r2 c2) (: ln (ls r2) (c2 < #ln ? (cf (ln c2)) 0))
       (skipk r2 c2 k)                             ; over the current run of class k
        (: ln (ls r2)
         (c2 < #ln && cf (ln c2) = k ? (skipk r2 (c2 + 1) k) [r2 c2]))
       (skipb r2 c2)                               ; over blanks, line ends included
        (: ln (ls r2)
           (? (c2 < #ln) (? (cf (ln c2) = 0) (skipb r2 (c2 + 1)) [r2 c2])
              ((r2 + 1) < n) (skipb (r2 + 1) 0)
              [r2 #ln]))
       k (at r c)
       p (? (k = 0) [r c] (skipk r c k))
       (skipb <p <>p))
   (vwend st cf r c)                               ; next word end (inclusive target)
    (: ls (st 'lines) n #ls
       (skipb r2 c2) (: ln (ls r2)
                        (? (c2 < #ln) (? (cf (ln c2) = 0) (skipb r2 (c2 + 1)) [r2 c2])
                           ((r2 + 1) < n) (skipb (r2 + 1) 0)
                           [r2 c2]))
       p (skipb r (c + 1))
       r2 <p c2 <>p ln (ls r2)
       (? (#ln <= c2) [r2 (? (0 < #ln) (#ln - 1) 0)]
          (: k (cf (ln c2))
             (run j) (? ((j < #ln) && (cf (ln j) = k)) (run (j + 1)) (j - 1))
             [r2 (run c2)])))
   (vwback st cf r c)                              ; previous word start
    (: ls (st 'lines)
       (skipb r2 c2) (? (c2 < 0) (0 < r2 ? (: pr (r2 - 1) (skipb pr (#(ls pr) - 1)))
                                           '(0 0))
                        (: ln (ls r2)
                           (? (cf (ln c2) = 0) (skipb r2 (c2 - 1)) [r2 c2])))
       p (skipb r (c - 1))
       r2 <p c2 <>p ln (ls r2)
       (? (tally ln <= c2) [r2 c2]
          (: k (cf (ln c2))
             (run j) (? ((0 <= (j - 1)) && (cf (ln (j - 1)) = k)) (run (j - 1)) j)
             [r2 (run c2)])))

   ; -- the delimiter scan ------------------------------------------------------
   ; % and the bracket objects want the delimiters that are code. in a .l buffer
   ; a/vi/hue.l's lexer -- the paint's, the only string-and-comment truth this
   ; file has -- says which columns are inside a literal or a comment; anywhere
   ; else the mask is empty and every column counts, the way classic vi's % does.
   ; the file's name decides, not 'hl, so :hl moves the colour and nothing else.
   (vbook st) (: b (st 'book) (tablet? b ? b (: k (hue-book ()) _ (pin st 'book k) k)))
   ; the per-line "starts inside a string" flags, folded once per generation and
   ; cached against it. the paint reads this too, so an edit pays for one fold
   ; and a keystroke that only moves the cursor pays for none.
   (vcarry st bk)
    (: c (st 'hlcar)
       (two? c && <c = st 'hlgen ? <>c
        (: k (hue-carry bk (st 'lines)) _ (pin st 'hlcar [(st 'hlgen) k]) k)))
   (vskips st r)                                   ; the ([a b) ..) that are not code
    (? !(vdotl (st 'file)) ()
       (: bk (vbook st)
          rs <(hue-lex bk (st 'lines r) ((vcarry st bk) r) 1)
          (go l acc) (? !(two? l) (rev acc)
                        (: h <l
                           (go >l ((<h = 'string || <h = 'comment) ? ([<>h <>>h] . acc) acc))))
          (go rs ())))
   (vcode? sk i) (? !(two? sk) 1 (: h <sk (? (<h <= i < <>h) () (vcode? >sk i))))
   (vopen? c)  (c = 40 || c = 91 || c = 123 || c = 60)
   (vclose? c) (c = 41 || c = 93 || c = 125 || c = 62)
   (vmatec c) (? (c = 40) 41 (c = 91) 93 (c = 123) 125 (c = 60) 62
                 (c = 41) 40 (c = 93) 91 (c = 125) 123 60)
   (vdelims st r o cl)                             ; ([col char] ..) on row r, ascending
    (: ln (st 'lines r) n #ln sk (vskips st r)
       (go i acc) (? (n <= i) (rev acc)
                     (: c (ln i)
                        (go (i + 1) ((c = o || c = cl) && vcode? sk i ? ([i c] . acc) acc))))
       (go 0 ()))
   ; the mate of the delimiter at (r c): rows are scanned whole, outward, and only
   ; this pair's own two characters count, so a ( inside [] is nesting and a [ is not
   (vmate st r c o cl)
    (: ch ((st 'lines r) c) fwd (ch = o) nl (vnl st)
       (rowd i) (: d (vdelims st i o cl) (fwd ? d (rev d)))
       (past l) (? !(two? l) () (<<l = c) >l (past >l))
       (go i l d)
        (? (two? l)
           (: h <l
              (? (<>h = ch) (go i >l (d + 1))
                 (d < 1) [i <h]
                 (go i >l (d - 1))))
           (: j (fwd ? (i + 1) (i - 1))
              (? (j < 0 || nl <= j) () (go j (rowd j) d))))
       (go r (past (rowd r)) 0))
   ; the innermost opener enclosing (r c) -- the cursor's own column counting
   (vencl st r c o cl)
    (: (rowd i) (rev (vdelims st i o cl))
       (upto l) (? !(two? l) () (<<l <= c) l (upto >l))
       (go i l d)
        (? (two? l)
           (: h <l
              (? (<>h = cl) (go i >l (d + 1))
                 (d < 1) [i <h]
                 (go i >l (d - 1))))
           (? (i < 1) () (go (i - 1) (rowd (i - 1)) d)))
       (go r (upto (rowd r)) 0))
   ; the pair to work on: on an opener or a closer it is that one's own, else the
   ; innermost that encloses. answers (r1 c1 r2 c2), the two delimiters themselves
   (vbpair st o cl)
    (: r (st 'row) c (st 'col) ln (st 'lines r) n #ln sk (vskips st r)
       here (? (c < n && vcode? sk c) (ln c) 0)
       (pair a) (? !(two? a) () (: m (vmate st <a <>a o cl) (two? m ? [<a <>a <m <>m] ())))
       (? (here = o) (pair [r c])
          (here = cl) (: m (vmate st r c o cl) (two? m ? [<m <>m r c] ()))
          (pair (vencl st r c o cl))))
   ; % -- the first delimiter at or after the cursor on this row, and its mate
   (vpct st)
    (: r (st 'row) ln (st 'lines r) n #ln sk (vskips st r)
       (go i) (? (n <= i) ()
                 ((vopen? (ln i) || vclose? (ln i)) && vcode? sk i) i
                 (go (i + 1)))
       i (go (st 'col))
       (? !(charm? i) ()
          (: o (: c (ln i) (? (vclose? c) (vmatec c) c)) (vmate st r i o (vmatec o)))))

   ; -- paragraphs: a run of blank lines or a run of non-blank ones --------------
   (vblank? st i) (0 = #(st 'lines i))
   (vpara st d)                                    ; { and } -- the next blank line
    (: nl (vnl st)
       (skip p i) (? (i < 0 || nl <= i) i (p (vblank? st i)) (skip p (i + d)) i)
       j (skip (\ b !b) (skip (\ b b) (st 'row + d)))
       (? (j < 0) 0 (nl <= j) (nl - 1) j))

   ; -- motions: key (+ n) -> ('to r c) exclusive | ('toi r c) inclusive
   ;             | ('lin r2) linewise target, the goal column kept | ('linb r2)
   ;             the same, landing on the line's first ink | ('spn r1 c1 r2 c2)
   ;             an absolute charwise span | ('linr r1 r2) an absolute linewise
   ;             one, which is what a linewise text object answers | () --
   (vmot st c n raw)
    (: r (st 'row) col (st 'col) ln (vln st) len #ln nl (vnl st)
       (walk f cf k) (: (go i p) (? (i < 1) p (go (i - 1) (f st cf <p <>p)))
                        p (go n [r col])
                        [k <p <>p])
       ; dw where the last word moved over ends the line takes that line's tail
       ; and stops: vim's own special case, and it is the LAST step that decides
       (walkop cf) (: (go i p pv) (? (i < 1) [p pv] (go (i - 1) (vwfwd st cf <p <>p) p))
                      q (go n [r col] [r col])
                      p <q pv <>q
                      (? (<pv < <p) ['to <pv #(st 'lines <pv)] ['to <p <>p]))
       (top1 k) (: t (st 'top + (k - 1)) b (st 'h - 2)
                   (? ((st 'top + b) < t) (st 'top + b) (nl <= t) (nl - 1) t))
     (c @ 104 ['to r (: k (col - n) (? (k < 0) 0 k))]             ; h
          108 ['to r (: k (col + n) (? (len < k) len k))]        ; l
          48 ['to r 0]                                           ; 0
          94 ['to r (vink ln)]                                   ; ^
          36 (? (0 < len) ['toi r (len - 1)] ['to r 0])         ; $
          124 ['to r (: k (n - 1) (? (len < k) len k))]          ; |
          119 (two? (st 'op) ? (walkop vcl) (walk vwfwd vcl 'to))   ; w
          101 (walk vwend vcl 'toi)                              ; e
          98  (walk vwback vcl 'to)                              ; b
          87  (two? (st 'op) ? (walkop vclw) (walk vwfwd vclw 'to))  ; W
          69  (walk vwend vclw 'toi)                             ; E
          66  (walk vwback vclw 'to)                             ; B
          106 ['lin (: k (r + n) (? (k < nl) k (nl - 1)))]       ; j
          107 ['lin (: k (r - n) (? (k < 0) 0 k))]               ; k
          ; + - _ and CR: whole lines, the cursor landing on the first non-blank
          (43 || 13) ['linb (: k (r + n) (? (k < nl) k (nl - 1)))]
          45 ['linb (: k (r - n) (? (k < 0) 0 k))]
          95 ['linb (: k (r + (n - 1)) (? (k < nl) k (nl - 1)))]
          123 ['lin (vpara st -1)]  125 ['lin (vpara st 1)]      ; { }
          72 ['lin (top1 n)]                                     ; H
          76 ['lin (: b (st 'top + (st 'h - 2)) f (? (nl <= b) (nl - 1) b)
                      k (f - (n - 1)) (? (k < st 'top) (st 'top) k))]  ; L
          77 ['lin (: b (st 'top + (st 'h - 2)) f (? (nl <= b) (nl - 1) b)
                      ((st 'top + f) // 2))]                     ; M
          37 (: p (vpct st)                                      ; %
                (? !(two? p) ()
                   (r < <p) ['spn r col <p (<>p + 1)]
                   (<p < r) ['spn <p <>p r (col + 1)]
                   (col <= <>p) ['toi r <>p]
                   ['spn r <>p r (col + 1)]))
          71 ['lin (? (0 < raw) (: k (raw - 1) (? (k < nl) k (nl - 1)))
                           (nl - 1))]))                               ; G
   ; f F t T with the argument char a
   (vfind st k a n)
    (: ln (vln st) len (tally ln) col (st 'col)
       fwd (k = 'f || k = 't)
       (go i c2 left) (? (left < 1) c2
                         (: nx (? fwd (fx (i + 1)) (bx (i - 1)))
                            (? (charm? nx) (go nx nx (left - 1)) ())))   ; charm?, not truth: column 0 is a hit
       (fx i) (: (s2 j) (? (len <= j) () (ln j = a) j (s2 (j + 1))) (s2 i))
       (bx i) (: (s2 j) (? (j < 0) () (ln j = a) j (s2 (j - 1))) (s2 i))
       hit (go col () n)
       (? !(charm? hit) ()
        (k @ 'f  ['toi (st 'row) hit]
             't (col < hit ? ['toi (st 'row) (hit - 1)])
             'F ['to (st 'row) hit]
             (hit < col ? ['to (st 'row) (hit + 1)]))))

   ; -- the operators --
   ; the opcodes are the keys themselves: d y c, and > < for the shifts, which are
   ; linewise whatever motion they are handed
   (vlinop? opc) (opc = 62 || opc = 60)
   (vyank st kind v) (pin st 'reg [kind v])
   (vopc st opc r c1 c2)                           ; charwise [c1,c2) on row r
    (: a (c1 < c2 ? c1 c2) b (c1 < c2 ? c2 c1)
       ln (st 'lines r) len #ln
       b2 (? (len < b) len b)
       piece (snip ln a b2)
       _ (vyank st 'chr piece)
       (opc @ 121 (vgole st a, st)        ; y: cursor to the span head
        (vsnap st,
         vput st r (snip ln 0 a + snip ln b2 len),
         pins st 'dirty 1 'row r,
         vgole st a,
         opc @ 99 (pin st 'mode 'i) (vclampn st),
         st)))
   ; a charwise span [r1,c1)..[r2,c2) that crosses rows: the two ends become one
   ; line and the register keeps the newlines, which is what p splits on
   (vospn st opc r1 c1 r2 c2)
    (? (r1 = r2) (vopc st opc r1 c1 c2)
       (: a (st 'lines r1) b (st 'lines r2)
          h (: n #a (? (n < c1) n c1)) t (: n #b (? (n < c2) n c2))
          mid (vtake st (r1 + 1) (r2 - 1))
          piece (foldl (\ s l (s + l + "\n")) (snip a h #a + "\n") mid + snip b 0 t)
          _ (vyank st 'chr piece)
          (? (opc = 121) (: _ (pin st 'row r1) (vgole st h, st))
             (: _ (vsnap st)
                _ (vsplice st r1 r2 [(snip a 0 h + snip b t #b)])
                _ (pin st 'row r1) _ (vgole st h)
                (? (opc = 99) (pin st 'mode 'i) (vclampn st))))))
   ; > and < -- rows r1..r2 in or out by one shiftwidth. an empty line stays empty,
   ; the way vim leaves it, and the register is not touched: a shift is not a cut
   (vshift st opc r1 r2)
    (: sw (st 'sw)
       _ (vsnap st)
       (go i) (? (r2 < i) ()
                 (: ln (st 'lines i) k (vlead ln)
                    j (? (0 = #ln) 0 (opc = 62) (k + sw) (: q (k - sw) (? (q < 0) 0 q)))
                    _ (vput st i (vblanks j + snip ln k #ln))
                    (go (i + 1))))
       _ (go r1)
       _ (pins st 'dirty 1 'row r1)
       (vgole st (vink (vln st)), st))
   (vopl st opc r1 r2)                             ; linewise rows r1..r2
    (: a (r1 < r2 ? r1 r2) b (r1 < r2 ? r2 r1)
       (? (vlinop? opc) (vshift st opc a b)
          (: _ (vyank st 'lin (vtake st a b))
             (? (opc = 121) (: _ (pin st 'row a) st)
                (: _ (vsnap st)
                   (? (opc = 99)
                      (: _ (vsplice st a b '(""))
                         _ (pin st 'row a) _ (vgole st 0)
                         (pin st 'mode 'i))
                      (: _ (vsplice st a b ())
                         nl (vnl st)
                         _ (pin st 'row (? (a < nl) a (nl - 1)))
                         _ (vgole st (vink (vln st)))
                         st)))))))
   ; a motion answered mr while operator (opc . ocnt) was pending. 'spn and 'linr
   ; are absolute -- a text object knows both its ends -- and the rest are relative
   ; to the cursor, which is the other end of the range
   (vapply st opc mr)
    (: kind <mr a <>mr b <>>mr
       (? (kind = 'lin || kind = 'linb) (vopl st opc (st 'row) a)
          (kind = 'linr) (vopl st opc a b)
          (kind = 'spn)  (: t >>>mr
                            (? (vlinop? opc) (vopl st opc a <t) (vospn st opc a b <t <>t)))
          (vlinop? opc)  (vopl st opc (st 'row) a)
          (a = st 'row)  (vopc st opc (st 'row) (st 'col) (? (kind = 'toi) (b + 1) b))
          (st 'row < a)  (vospn st opc (st 'row) (st 'col) a (? (kind = 'toi) (b + 1) b))
          (vospn st opc a b (st 'row) (? (kind = 'toi) (st 'col + 1) (st 'col)))))

   ; -- the text objects: i and a after an operator ----------------------------
   ; each answers a range in vapply's own vocabulary, so ci( and di( and yi( are
   ; one object under three operators rather than three commands.
   (vwobj st cf ar n)                              ; iw aw iW aW -- runs on this row
    (: r (st 'row) ln (st 'lines r) len #ln
       (? (len < 1) ()
          (: c (: k (st 'col) (? (len <= k) (len - 1) k))
             (rune i) (: k (cf (ln i))
                         (go j) (? (j < len && cf (ln j) = k) (go (j + 1)) j)
                         (go i))
             (runs i) (: k (cf (ln i))
                         (go j) (? (0 <= (j - 1) && cf (ln (j - 1)) = k) (go (j - 1)) j)
                         (go i))
             (ext i j) (? (j < 1 || len <= i) i (ext (rune i) (j - 1)))
             a (runs c)
             e1 (ext a n)
             ; around is the word and the blanks that follow -- two runs, each
             ; way round -- and with none to follow it takes the ones before
             e2 (? ar (ext a (2 * n)) e1)
             a2 (? (ar && e2 = e1 && 0 < a && cf (ln (a - 1)) = 0) (runs (a - 1)) a)
             ['spn r a2 r e2])))
   (vqobj st ar q)                                 ; i" a" i' a' i` a`
    (: r (st 'row) ln (st 'lines r) n #ln c (st 'col)
       (nx i) (? (n <= i) () (ln i = 92) (nx (i + 2)) (ln i = q) i (nx (i + 1)))
       ; the pairs are counted from the line's start, the way vim counts them, so
       ; which quote is an opener never depends on where the cursor happens to sit
       (go i) (: a (nx i)
                 (? !(charm? a) ()
                    (: b (nx (a + 1))
                       (? !(charm? b) ()
                          (a <= c <= b || c < a) [a b]
                          (go (b + 1))))))
       p (go 0)
       (? !(two? p) ()
          (: a <p b <>p
             (bl i) (? (i < n && (ln i = 32 || ln i = 9)) (bl (i + 1)) i)
             (bk i) (? (0 < i && (ln (i - 1) = 32 || ln (i - 1) = 9)) (bk (i - 1)) i)
             (? !ar ['spn r (a + 1) r b]
                (: e (bl (b + 1)) ['spn r (? (e = (b + 1)) (bk a) a) r e])))))
   (vbobj st ar o)                                 ; i( a( i[ a[ i{ a{ i< a<
    (: p (vbpair st o (vmatec o))                  ; (r1 c1 r2 c2), the delimiters
       (? !(two? p) ()
          ar ['spn <p <>p <>>p (<>>>p + 1)]
          ['spn <p (<>p + 1) <>>p <>>>p]))
   (vpobj st ar)                                   ; ip ap -- linewise, blank-delimited
    (: nl (vnl st) r (st 'row) k (vblank? st r)
       (up i) (? (0 < i && (vblank? st (i - 1)) = k) (up (i - 1)) i)
       (dn i) (? (i < (nl - 1) && (vblank? st (i + 1)) = k) (dn (i + 1)) i)
       a (up r) b (dn r)
       (dn2 i) (? (i < (nl - 1) && (vblank? st (i + 1)) != k) (dn2 (i + 1)) i)
       (up2 i) (? (0 < i && (vblank? st (i - 1)) != k) (up2 (i - 1)) i)
       (? !ar ['linr a b]
          (b < (nl - 1)) ['linr a (dn2 (b + 1))]
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
    (: rg (st 'reg)
       (? !(two? rg) (vmsg st "nothing in the register")
          (<rg = 'lin)
           (: _ (vsnap st)
              at (? after (st 'row + 1) (st 'row))
              (rep i s2) (? (i < 1) s2 (rep (i - 1) (: _ (vsplice s2 at (at - 1) <>rg) s2)))
              _ (rep n st)
              _ (pin st 'row at)
              _ (vgole st (vink (vln st)))
              st)
          (: _ (vsnap st)
             t <>rg
             (rep i acc) (i < 1 ? acc (rep (i - 1) (acc + t)))
             tt (rep n "")
             ln (vln st) len #ln r (st 'row)
             at (after && 0 < len ? (st 'col + 1) (st 'col))
             ; text.l's `lines` drops a trailing empty and a charwise register that
             ; ends at a line's start is exactly that -- so this split keeps them
             ps (: k #tt
                   (go i a acc) (? (k <= i) (rev (snip tt a k . acc))
                                   (tt i = 10) (go (i + 1) (i + 1) (snip tt a i . acc))
                                   (go (i + 1) a acc))
                   (go 0 0 ()))
             ; a charwise register that crossed rows carries its newlines: the
             ; line opens at the cursor and the tail rides the register's last row
             (? (#ps < 2)
                (: _ (vput st r (snip ln 0 at + tt + snip ln at len))
                   _ (vgole st (at + #tt - 1))
                   st)
                (: lst (vexlast ps)
                   mid (: (go l acc) (? !(two? >l) (rev acc) (go >l (<l . acc))) (go >ps ()))
                   _ (vput st r (snip ln 0 at + <ps))
                   _ (vsplice st (r + 1) r (mid + [(lst + snip ln at len)]))
                   _ (pin st 'row r)
                   _ (vgole st at)
                   st)))))
   ; J puts one blank between the two lines and drops the next one's indent; gJ
   ; joins them exactly as they are, which is sp? = ()
   (vjoin st n sp?)
    (: (one s2) (? (s2 'row + 1 < vnl s2)
                   (: r (s2 'row) a (s2 'lines r) b (s2 'lines (r + 1))
                      bi (? !sp? 0 (: k (vink b) (0 < #b ? k 0)))
                      joined (a + (sp? ? " " "") + snip b bi #b)
                      _ (vgole s2 #a)
                      _ (vsplice s2 r (r + 1) [joined])
                      s2)
                   s2)
       (go i) (i < 1 ? st (one st, go (i - 1)))
       _ (vsnap st)
       (go (n < 2 ? 1 (n - 1))))
   ; ^A and ^X -- the number at or after the cursor, by n
   (vincr st n)
    (: r (st 'row) ln (st 'lines r) len #ln col (st 'col)
       (dig? i) (i < len && 48 <= ln i <= 57)
       (fx i) (? (len <= i) () (dig? i) i (fx (i + 1)))
       s (fx (? (dig? col) (: (bk i) (? (0 < i && dig? (i - 1)) (bk (i - 1)) i) (bk col)) col))
       (? !(charm? s) (vmsg st "no number here")
          (: a (? (0 < s && ln (s - 1) = 45) (s - 1) s)
             (fw i) (? (dig? i) (fw (i + 1)) i)
             b (fw s)
             v (: t (snip ln a b) k #t
                   (go i acc) (? (k <= i) acc (go (i + 1) (10 * acc + (t i - 48))))
                   q (go (a < s ? 1 0) 0)
                   (a < s ? (0 - q) q))
             w (v + n)
             _ (vsnap st)
             _ (vput st r (snip ln 0 a + show w + snip ln b len))
             _ (pins st 'dirty 1)
             (vgole st (a + #(show w) - 1)))))
   (vundo st)
    (: u (st 'undo)
       (? !(two? u) (vmsg st "already at oldest change")
          (: _ (pins st 'redo ([(st 'lines) (st 'row) (st 'col)] . st 'redo)
                        'undo >u)
             _ (vrest st <u)
             (vclampn st))))
   (vredo st)
    (: r (st 'redo)
       (? !(two? r) (vmsg st "already at newest change")
          (: _ (pin st 'undo ([(st 'lines) (st 'row) (st 'col)] . st 'undo))
             _ (pin st 'redo >r)
             _ (vrest st <r)
             (vclampn st))))

   ; -- search (re.l): hunt for 'pat from the cursor, dir 1 fwd / -1 back --
   ; a word boundary is not a node re.l's engine can hold, so `*` asks for one
   ; with 'patw and it is checked at the span: a match with a word character
   ; against either end is refused and the hunt goes on from the next column
   (vfind1 st ln i)
    (: m (refind (st 'pat) ln i)
       (? (!(two? m) || !(st 'patw)) m
          (: a <>m b <>>m
             (? ((0 < a && vcl (ln (a - 1)) = 1) || (b < #ln && vcl (ln b) = 1))
                (vfind1 st ln (a + 1))
                m))))
   (vlast st ln bound)                             ; last match start in ln with start < bound
    (: (go i best) (: r (vfind1 st ln i)
                      (? !(two? r) best
                         (: ms <>r
                            (? (ms < bound) (go (ms + 1) ms) best))))
       (go 0 ()))
   (vhunt st dir)
    (: ls (st 'lines) nl #ls r (st 'row) c (st 'col)
       (fwd i steps)
        (? (nl < steps) ()
           (: ln (ls i)
              cite (steps = 0 ? (c + 1) 0)
              m (? (cite <= #ln) (vfind1 st ln cite) ())
              (? (two? m) [i <>m]
                 (fwd (% (i + 1) nl) (steps + 1)))))
       (bwd i steps)
        (? (nl < steps) ()
           (: ln (ls i)
              m (vlast st ln (steps = 0 ? c (#ln + 1)))
              (charm? m ? [i m]
               (bwd (% ((i - 1) + nl) nl) (steps + 1)))))
       hit (0 < dir ? (fwd r 0) (bwd r 0))
       (two? hit ?
        (pin st 'row <hit, vgole st <>hit, st)
        (vmsg st $ "not found: " + st 'pattx)))
   ; * and # -- the word under the cursor becomes the search. a name in this tree
   ; is full of BRE metacharacters (`map*`, `1.5`, `\`), so every one of them is
   ; spelled out, and 'patw asks the hunt for the boundaries the engine has no node for
   (vbesc t) (: n #t
                (go i acc) (? (n <= i) acc
                              (go (i + 1) (acc + (elem (t i) '(46 42 91 92 94 36) ? "\\" "")
                                               + string (t i))))
                (go 0 ""))
   (vstar st dir)
    (: ln (vln st) len #ln col (st 'col)
       (fx i) (? (len <= i) () (vcl (ln i) = 1) i (fx (i + 1)))
       s (fx col)
       (? !(charm? s) (vmsg st "no word under the cursor")
          (: a (: (bk i) (? (0 < i && vcl (ln (i - 1)) = 1) (bk (i - 1)) i) (bk s))
             (fw i) (? (i < len && vcl (ln i) = 1) (fw (i + 1)) i)
             w (snip ln a (fw a))
             b (rebre (vbesc w))
             (? !(two? b) st
                (: _ (pins st 'pat <>b 'pattx w 'patw 1 'dir dir)
                   _ (vgole st a)
                   (vhunt st dir))))))

   ; -- libra, on the buffer --------------------------------------------------
   ; both weighings are pure functions over text, so they run here, and over the
   ; BUFFER rather than the file: it answers for what you are looking at. one
   ; scanner under libra's three faces and this one, so what pulchritude says is
   ; what `make lint` refuses. lint counts line and col from one, the buffer from zero.
   (vlint st)
    (: ws (lint-scan (unlines (st 'lines)))
       (? !(two? ws) (vmsg st "balance clean")
          (: w1 <ws
             r (: k (<w1 - 1) nl (vnl st) (? (k < 0) 0 (? (k < nl) k (nl - 1))))
             _ (pin st 'row r)
             _ (vgole st (: c (<>w1 - 1) (? (c < 0) 0 c)))
             _ (vclampn st)
             (vmsg st (show #ws + (? (1 = #ws) " warning: " " warnings: ")
                       + show <w1 + "," + show <>w1 + " " + <>>w1)))))


   ; -- the ex line -----------------------------------------------------------
   ; a line reads [range] command [args]; `;` moves dot to the first address before
   ; reading the second, and % is 1,$. rows answer 0-based, so address 0 is -1, the
   ; "before the first line" m and t take as a destination.
   ; a search address that finds nothing answers 'bad, NOT (): "no address here" and
   ; "an address that failed" must part company, or :/nomatch/d deletes the current line.

   (vexskip s i) (: n #s (go k) (? (k < n && (s k = 32 || s k = 9)) (go (k + 1)) k) (go i))
   (vextrim s)
    (: n #s
       (fw k) (? (k < n && (s k = 32 || s k = 9)) (fw (k + 1)) k)
       (bw k) (? (0 < k && (s (k - 1) = 32 || s (k - 1) = 9)) (bw (k - 1)) k)
       a (fw 0) b (bw n)
       (a < b ? (snip s a b) ""))
   (vexhas? s c) (: n #s (go i) (? (n <= i) () (s i = c) 1 (go (i + 1))) (go 0))
   (vexbad? st a b) (: nl (vnl st) (a < 0 || nl <= b || b < a))
   (vexlast l) (? (two? >l) (vexlast >l) <l)
   (vexgo st r) (: nl (vnl st) k (? (r < 0) 0 (nl <= r) (nl - 1) r)
                   (pin st 'row k, vgole st (vink (vln st)), st))

   ; text up to the next unescaped dl -> [next-index text]. only the delimiter
   ; unescapes: \( and \1 have to reach the regex and the replacement whole
   (vexdelim s i dl)
    (: n #s
       (go j acc)
        (? (n <= j) [j acc]
           (s j = 92 && (j + 1) < n && s (j + 1) = dl) (go (j + 2) (acc + string dl))
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
        (? (nl < steps) ()
           (: k (((i % nl) + nl) % nl)
              (? (two? (refind nds (ls k) 0)) k (go (k + dir) (steps + 1)))))
       (go (r + dir) 1))

   (vaddr st s i dot)                              ; one address at i -> [j row] | 'bad | ()
    (: n #s
       (dig? k) (k < n && 48 <= s k <= 57)
       (num k acc) (? (dig? k) (num (k + 1) (10 * acc + (s k - 48))) [k acc])
       (base k)
        (? (dig? k) (num k 0 @ [j v] [j (v - 1)])
           (n <= k) ()
           (s k = 46) [(k + 1) dot]
           (s k = 36) [(k + 1) (vnl st - 1)]
           (s k = 47 || s k = 63)
            (vexdelim s (k + 1) (s k) @ [j tx]
              (: cp (vexpat st tx)
                 (? !(two? cp) 'bad
                    (: _ (? (0 < #tx) (pins st 'pat <>cp 'pattx tx 'patw ()) ())
                       r (vexfind st <>cp dot (s k = 47 ? 1 -1))
                       (charm? r ? [j r] 'bad)))))
           ())
       (offs k r)                                  ; the +N / -N tail
        (? (k < n && (s k = 43 || s k = 45))
           (: sg (s k = 43 ? 1 -1)
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
          (: a (vaddr st s i dot)
             (? (a = 'bad) ()
                !(two? a) [i dot dot ()]
                (: j <a r <>a
                   (? (j < n && (s j = 44 || s j = 59)) (pair j r) [j r r 1]))))))

   ; -- substitute --
   ; `/pat/rep/flags` at i -> [1 matcher rep g?] | (). a fresh pattern also
   ; becomes the last search, which is where ex leaves it for n
   (vexspec st s i)
    (: n #s
       (? (n <= i) ()
          (: dl (s i)
             (vexdelim s (i + 1) dl @ [j pat]
               (vexdelim s j dl @ [k rep]
                 (: cp (vexpat st pat)
                    (? !(two? cp) ()
                       (: _ (? (0 < #pat) (pins st 'pat <>cp 'pattx pat 'patw ()) ())
                          [1 (recomp <>cp) rep (vexhas? (snip s k n) 103)]))))))))
   (vexsubs st m rep a b g?)                       ; ((row text)..) for the rows that change
    (: (go r acc) (? (b < r) (rev acc)
                     (: res (usub m rep (st 'lines r) g?)
                        (go (r + 1) (<res ? ([r <>res] . acc) acc))))
       (go a ()))
   (vexlay st ps)                                  ; apply ((row text)..), answer the last row
    (: (go l lr) (? !(two? l) lr (: h <l _ (vput st <h <>h) (go >l <h)))
       (go ps 0))
   (vexdrop st rows)                               ; delete rows, given descending
    (: (go l) (? !(two? l) () (: _ (vsplice st <l <l ()) (go >l)))
       (go rows))
   (vexsub st s i r1 r2)
    (: sp (vexspec st s i)
       (? !(two? sp) (vmsg st "bad substitution")
          (vexbad? st r1 r2) (vmsg st "out of range")
          (: hits (vexsubs st <>sp <>>sp r1 r2 <>>>sp)
             (? !(two? hits) (vmsg st $ "not found: " + st 'pattx)
                (: _ (vsnap st)
                   lr (vexlay st hits)
                   _ (vexgo st lr)
                   (vmsg st (show #hits + (1 = #hits ? " line" " lines") + " changed")))))))

   ; -- global --
   ; g/v collect the matching rows, then run the body on each from the last up,
   ; so a delete never moves a row still to be visited. the body is one of d, s
   ; and p -- the three that mean anything a line at a time.
   (vexgbody st body)
    (: w (0 < #body ? (body 0) 112)
       (? (w = 100) ['d]
          (w = 112) ['p]
          (w = 115) (vexspec st body 1 @ [_ m rep g?] ['s m rep g?] ())
          ()))
   (vexhits st nds a b inv?)                       ; the matching rows, descending
    (: (go r acc)
        (? (b < r) acc
           (: m? (two? (refind nds (st 'lines r) 0))
              (go (r + 1) ((inv? ? !m? m?) ? (r . acc) acc))))
       (go a ()))
   (vexplan st rows sp)                            ; the body, dry: what it would touch
    (? (<sp = 's)
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
          (: dl (s i)
             (vexdelim s (i + 1) dl @ [j pat]
               (: cp (vexpat st pat)
                  (? !(two? cp) (vmsg st $ "bad pattern: " + pat)
                     (: _ (? (0 < #pat) (pins st 'pat <>cp 'pattx pat 'patw ()) ())
                        sp (vexgbody st (vextrim (snip s j n)))
                        (? !(two? sp) (vmsg st "not a global command")
                           (: rows (vexhits st <>cp a b inv?)
                              (? !(two? rows) (vmsg st $ "not found: " + st 'pattx)
                                 (<sp = 'p)
                                  (: _ (vexgo st (vexlast rows))
                                     (vmsg st (show #rows + " lines")))
                                 (: plan (vexplan st rows sp)
                                    (? !(two? plan) (vmsg st "not found")
                                       (: _ (vsnap st)
                                          _ (? (<sp = 'd) (vexdrop st plan) (vexlay st plan))
                                          _ (vexgo st (<sp = 'd ? (vexlast rows) <(vexlast plan)))
                                          (vmsg st (show #plan +
                                                    (<sp = 'd ? " fewer lines" " lines changed"))))))))))))))))

   ; -- move, copy, join --
   ; the destination is one address after the verb, and 0 (row -1) is the line
   ; before the first
   (vexmove st s i r1 r2 copy?)
    (: d (vaddr st s (vexskip s i) (st 'row))
       nl (vnl st)
       (? !(two? d) (vmsg st "no destination")
          (: dr <>d
             (? (vexbad? st r1 r2) (vmsg st "out of range")
                (dr < -1 || nl <= dr) (vmsg st "out of range")
                (!copy? && (r1 - 1) <= dr <= r2) (vmsg st "destination inside the range")
                (: blk (vtake st r1 r2) k #blk
                   _ (vsnap st)
                   _ (vsplice st (dr + 1) dr blk)
                   _ (? copy? ()
                        (dr < r1) (vsplice st (r1 + k) (r2 + k) ())
                        (vsplice st r1 r2 ()))
                   _ (vexgo st (? copy? (dr + k) (dr < r1) (dr + k) dr))
                   (vmsg st (show k + (1 = k ? " line" " lines") +
                             (copy? ? " copied" " moved"))))))))
   (vexjoin st r1 r2)
    (? (vexbad? st r1 r2) (vmsg st "out of range")
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

   ; :set sw=N / shiftwidth=N, and bare :set sw reports. the only option there is,
   ; because it is the only number this file's commands need and cannot guess
   (vexset st arg)
    (: n #arg
       (eq k) (? (n <= k) () (arg k = 61) k (eq (k + 1)))
       j (eq 0)
       nm (vextrim (? (charm? j) (snip arg 0 j) arg))
       (? !(nm = "sw" || nm = "shiftwidth") (vmsg st $ "not an option: " + nm)
          !(charm? j) (vmsg st $ "shiftwidth=" + show (st 'sw))
          (: t (vextrim (snip arg (j + 1) n)) k #t
             (dig? i) (i < k && 48 <= t i <= 57)
             (go i acc) (? (dig? i) (go (i + 1) (10 * acc + (t i - 48))) acc)
             (? (0 = k || !(dig? 0)) (vmsg st "shiftwidth wants a number")
                (: v (go 0 0)
                   _ (pin st 'sw (? (v < 1) 1 v))
                   (vmsg st $ "shiftwidth=" + show (st 'sw)))))))

   ; -- the dispatch --
   (vexword s i)                                   ; the command name at i
    (: n #s
       (go k) (? (k < n && 97 <= s k <= 122) (go (k + 1)) k)
       k2 (go i)
       (? (i < k2) [k2 (snip s i k2)]
          (n <= i) [i ""]
          [(i + 1) (string (s i))]))
   (vexcmd st s i r1 r2 got?)
    (vexword s i @ [j w]
      (: n #s
         bang (j < n && s j = 33)
         k (bang ? (j + 1) j)
         arg (vextrim (snip s k n))
         nm (0 < #arg ? arg (st 'file))
         (? (w = "s") (vexsub st s k r1 r2)
            (w = "g" || w = "global") (vexglob st s k r1 r2 got? ())
            (w = "v") (vexglob st s k r1 r2 got? 1)
            (w = "d" || w = "delete")
             (? (vexbad? st r1 r2) (vmsg st "out of range") (vopl st 100 r1 r2))
            (w = "y" || w = "yank")
             (? (vexbad? st r1 r2) (vmsg st "out of range") (vopl st 121 r1 r2))
            (w = "m" || w = "move") (vexmove st s k r1 r2 ())
            (w = "t" || w = "co" || w = "copy") (vexmove st s k r1 r2 1)
            (w = "j" || w = "join") (vexjoin st r1 r2)
            ; there is no printing to do on a screen, so these land the cursor
            ; on the range's last line. `l` is not among them -- it promises to
            ; spell control characters, and this frame does not
            (w = "p" || w = "print" || w = "nu" || w = "number" || w = "#")
             (? (vexbad? st r1 r2) (vmsg st "out of range")
                (: _ (vexgo st r2) (vmsg st (show (r2 - r1 + 1) + " lines"))))
            (w = "=") (vmsg st (show (r2 + 1)))
            (w = "q") (? (bang || !(st 'dirty)) (pin st 'quit 1)
                         (vmsg st "no write since last change (q! overrides)"))
            (w = "w") (pin st 'dow [nm])
            (w = "wq" || w = "x") (: _ (pin st 'dow [nm]) (pin st 'quit 1))
            (w = "e" || w = "o" || w = "edit") (vedit st nm bang)
            (w = "hl") (: _ (pin st 'hl (st 'hl ? () 1))
                          (vmsg st (st 'hl ? "syntax on" "syntax off")))
            ; :set knows one option, which is the one > and < need a number for
            (w = "set") (vexset st arg)
            (w = "lint") (vlint st)                    ; libra's scan, on the buffer
            (vmsg st $ "not an ex command: " + w))))
   (vex st)
    (: s (edtext (st 'cmd))
       n #s
       _ (pin st 'mode 'n)
       r (vrange st s 0)
       (? (n < 1) st
          !(two? r) (vmsg st "no match")
          (: i <r r1 <>r r2 <>>r got? <>>>r
             j (vexskip s i)
             (? (n <= j) (got? ? (vexgo st r2) st)
                (vexcmd st s j r1 r2 got?)))))

   ; -- insert mode --
   (vins st c)
    (: r (st 'row) col (st 'col) ln (vln st) len #ln
       (? (c = 27) (: _ (pin st 'mode 'n)
                      _ (vgole st (0 < col ? (col - 1) 0))
                      (vclampn st))
          (c = 13 || c = 10)
           (: _ (vput st r (snip ln 0 col))
              _ (vsplice st (r + 1) r [(snip ln col len)])
              _ (pin st 'row (r + 1))
              (vgole st 0))
          (c = 8 || c = 127)
           (? (0 < col) (: _ (vput st r (snip ln 0 (col - 1) + snip ln col len))
                           (vgole st (col - 1)))
              (0 < r) (: pv (st 'lines (r - 1)) pl #pv
                         _ (vsplice st (r - 1) r [(pv + ln)])
                         _ (pin st 'row (r - 1))
                         (vgole st pl))
              st)
          ; ^W back over one word, ^U back to the line's first non-blank (or its
          ; start, when the cursor already sits there)
          (c = 23)
           (: (bk i p) (? (0 < i && p (vcl (ln (i - 1)))) (bk (i - 1) p) i)
              a (: j (bk col (\ k (k = 0))) (bk j (\ k (k != 0))))
              (? (a < col) (: _ (vput st r (snip ln 0 a + snip ln col len)) (vgole st a)) st))
          (c = 21)
           (: k (vink ln) a (? (k < col) k 0)
              (? (a < col) (: _ (vput st r (snip ln 0 a + snip ln col len)) (vgole st a)) st))
          (c = 9 || 32 <= c)
           (: _ (vput st r (snip ln 0 col + string c + snip ln col len))
              (vgole st (col + 1)))
          ; the arrows: insert's cursor may sit past the last char, so the fences are
          ; the line's length, and up and down keep the goal column as j and k do
          (c = -1) (vgole st (0 < col ? (col - 1) 0))
          (c = -2) (vgole st (col < len ? (col + 1) len))
          (c = -8 || c = -9)
           (: k (c = -8 ? (r - 1) (r + 1))
              (? (k < 0 || vnl st <= k) st
                 (: _ (pin st 'row k) n (vlen st) g (st 'goal)
                    (pin st 'col (g < n ? g n)))))
          st))

   ; -- the pending char-argument commands --
   (vpc st c)
    (: k (st 'pc) n (: v (st 'cnt) (? (0 < v) v 1))
       _ (pin st 'pc ()) _ (pin st 'cnt 0)
       (? (c = 27) (pin st 'op (), st)             ; escape drops the pending operator too
          (k = 'r) (? (c = 9 || 32 <= c)
                      (: ln (vln st) len #ln col (st 'col)
                         (? (col + n <= len)
                            (: (rep i acc) (i < 1 ? acc (rep (i - 1) (acc + string c)))
                               _ (vsnap st)
                               _ (vput st (st 'row) (snip ln 0 col + rep n "" + snip ln (col + n) len))
                               (vgole st (col + n - 1)))
                            st))
                      st)
          (k = 'g) (? (c = 103)                                 ; gg
                      (: t (0 < st 'gcnt ? (st 'gcnt - 1) 0)
                         nl (vnl st)
                         t2 (t < nl ? t (nl - 1))
                         mr ['lin t2]
                         op (st 'op)
                         _ (pin st 'op ())
                         (two? op ? (vapply st <op mr)
                          (pin st 'row t2, vgole st (vink (vln st)))))
                      (c = 74) (vjoin st n ())                  ; gJ: no blank between
                      (c = 95) (: nl (vnl st)                   ; g_: last non-blank
                                  t (: k (st 'row + (n - 1)) (? (k < nl) k (nl - 1)))
                                  ln (st 'lines t)
                                  (bk i) (? (0 < i && (ln (i - 1) = 32 || ln (i - 1) = 9))
                                            (bk (i - 1)) i)
                                  e (bk #ln)
                                  op (st 'op) _ (pin st 'op ())
                                  mr ['toi t (0 < e ? (e - 1) 0)]
                                  (two? op ? (vapply st <op mr)
                                   (pin st 'row t, vgole st <>>mr, st)))
                      st)
          ; zt zz zb: the view slides under the cursor, the cursor stays put
          (k = 'z) (: body (st 'h - 1) r (st 'row)
                      t (c @ 116 r
                             98 (: q (r - (body - 1)) (? (q < 0) 0 q))
                             (122 || 46) (: q (r - (body // 2)) (? (q < 0) 0 q))
                             (st 'top))
                      (pin st 'top t, st))
          (k = 'Z) (c != 90 ? st (pins st 'dow [(st 'file)] 'quit 1))
          ; i and a after an operator name a text object rather than insert mode
          (k = 'ti || k = 'ta)
           (: mr (vobj st (k = 'ta) c n)
              op (st 'op)
              _ (pin st 'op ())
              (? (two? mr && two? op) (vapply st <op mr) st))
          ; f F t T -- and the pair is remembered, which is what ; and , repeat
          (: mr (vfind st k c n)
             op (st 'op)
             _ (pin st 'lastf [k c])
             _ (pin st 'op ())
             (? !(two? mr) st
                (two? op) (vapply st <op mr)
                (vgole st <>>mr)))))

   ; -- normal mode --
   (vnorm st c)
    (: n (: v (st 'cnt) (? (0 < v) v 1))
       (mv1 mr)                                    ; a motion result, no operator
        (? (one? mr) st
           (<mr = 'lin)
            (: t <>mr _ (pin st 'row t)
             (pin st 'col (: g (st 'goal) len (vlen st)
                           (? (g < len) g (0 < len) (len - 1) 0))))
           ; 'linb is 'lin that lands on the line's first ink: + - _ and the ex
           ; addresses do that and j and k deliberately do not
           (<mr = 'linb) (: _ (pin st 'row <>mr) (vgole st (vink (vln st))))
           ; a span with no operator lands on whichever end the cursor is not at,
           ; which is what makes % a motion as well as a range
           (<mr = 'spn)
            (: t >>>mr
               p (? (<>mr = st 'row && <>>mr = st 'col) [<t (0 < <>t ? (<>t - 1) 0)]
                    [<>mr <>>mr])
               _ (pin st 'row <p)
               (vgole st <>p))
           (: _ (vgole st (: c2 <>>mr len (vlen st)
                             lim (0 < len ? (len - 1) 0)
                             (lim < c2 ? lim c2)))
              (pin st 'row <>mr)))
       (motion mr)
        (: op (st 'op) _ (pin st 'op ())
           (? !(two? mr) st
              (two? op) (vapply st <op mr)
              (mv1 mr)))
       (page d) (: h (st 'h) step (c @ (6 || 2) (h - 2) ((h - 2) // 2))
                   nl (vnl st)
                   t (st 'row + d * step)
                   t2 (? (t < 0) 0 (? (t < nl) t (nl - 1)))
                   _ (pin st 'row t2)
                   (vclampn st))
       rawc (st 'cnt)
       _ (pin st 'cnt 0)
       ; a diagonal is its two halves, each a plain motion of the count; an operator
       ; pending is dropped -- a diagonal is not a range
       (diag vc hc) (? (two? (st 'op)) (pin st 'op ())
                       (: _ (mv1 (vmot st vc n rawc)) (mv1 (vmot st hc n rawc))))
       (? ; an operator is pending and i or a arrives: a text object, not insert
          (two? (st 'op) && (c = 105 || c = 97))
           (pins st 'cnt n 'pc (c @ 105 'ti 'ta))
          (elem c '(104 108 48 94 36 124 119 101 98 87 69 66 106 107 71
                    43 13 45 95 123 125 72 76 77 37))
           (motion (vmot st (? ((c = 119 || c = 87) &&              ; the vi special case:
                                (: o (st 'op)                     ; cw changes the word only,
                                   (two? o && (<o = 99))))
                              (c = 119 ? 101 69) c)                ; ... so cw rides e
                          n rawc))
          (c = 377) (diag 107 104)  (c = 373) (diag 107 108)         ; alt-y alt-u: up-left, up-right
          (c = 354) (diag 106 104)  (c = 366) (diag 106 108)         ; alt-b alt-n: down-left, down-right
          (elem c '(102 70 116 84))                            ; f F t T
           (pin st 'cnt n,
            pin st 'pc (? (c = 102) 'f (c = 70) 'F (c = 116) 't 'T))
          (c = 103) (: _ (pin st 'gcnt rawc) (pin st 'pc 'g))
          (c = 90) (pin st 'pc 'Z)
          (c = 122) (pin st 'pc 'z)                             ; zt zz zb
          (c = 114) (: _ (pin st 'cnt n) (pin st 'pc 'r))
          ; ; and , -- the last f F t T again, forward and the other way
          (c = 59 || c = 44)
           (: lf (st 'lastf)
              (? !(two? lf) st
                 (motion (vfind st (c = 59 ? <lf (<lf @ 'f 'F 'F 'f 't 'T 't)) <>lf n))))
          (elem c '(100 121 99 62 60))                       ; d y c > <
           (: op (st 'op)
              (? (two? op && (<op = c))
                 (: total (* n <>op)
                    _ (pin st 'op ())
                    (vopl st c (st 'row) (: t ((st 'row + total) - 1) nl (vnl st)
                                            (? (t < nl) t (nl - 1)))))
                 (: _ (pin st 'op [c n]) st)))
          (c = 120) (: len (vlen st)                            ; x
                       (? (0 < len)
                          (vopc st 100 (st 'row) (st 'col)
                                (: e (st 'col + n) (? (len < e) len e)))
                          st))
          (c = 88) (? (0 < st 'col)                             ; X
                      (vopc st 100 (st 'row) (: k (st 'col - n) (? (k < 0) 0 k)) (st 'col))
                      st)
          (c = 68) (: len (vlen st)                             ; D
                      (? (st 'col < len) (vopc st 100 (st 'row) (st 'col) len) st))
          (c = 67) (: len (vlen st)                             ; C
                      _ (? (st 'col < len) (vopc st 99 (st 'row) (st 'col) len)
                           (: _ (vsnap st) (pin st 'mode 'i)))
                      st)
          (c = 115) (: len (vlen st)                            ; s
                       (? (0 < len)
                          (vopc st 99 (st 'row) (st 'col)
                                (: e (st 'col + n) (? (len < e) len e)))
                          (: _ (vsnap st) _ (pin st 'mode 'i) st)))
          (c = 74) (vjoin st n 1)                               ; J
          (c = 89) (vopl st 121 (st 'row)                       ; Y: yy, the whole line
                         (: t ((st 'row + n) - 1) nl (vnl st) (? (t < nl) t (nl - 1))))
          (c = 83) (vopl st 99 (st 'row)                        ; S: cc
                         (: t ((st 'row + n) - 1) nl (vnl st) (? (t < nl) t (nl - 1))))
          (c = 126) (: ln (vln st) len #ln col (st 'col)        ; ~
                       (? (len < 1) st
                          (: e (: k (col + n) (? (len < k) len k))
                             _ (vsnap st)
                             _ (vput st (st 'row)
                                    (snip ln 0 col + vflip (snip ln col e) + snip ln e len))
                             _ (pin st 'dirty 1)
                             (vgole st (e < len ? e (len - 1))))))
          (c = 42) (vstar st 1)  (c = 35) (vstar st -1)         ; * #
          (c = 1) (vincr st n)   (c = 24) (vincr st (0 - n))    ; ^A ^X
          (c = 46) (vdot st rawc)                               ; .
          (c = 105) (: _ (vsnap st) (pin st 'mode 'i))          ; i
          (c = 97) (: _ (vsnap st)                              ; a
                      _ (vgole st (? (0 < vlen st) (st 'col + 1) 0))
                      (pin st 'mode 'i))
          (c = 73) (: _ (vsnap st) _ (vgole st (vink (vln st))) (pin st 'mode 'i))   ; I
          (c = 65) (: _ (vsnap st) _ (vgole st (vlen st)) (pin st 'mode 'i))         ; A
          (c = 111) (: _ (vsnap st)                             ; o
                       _ (vsplice st (st 'row + 1) (st 'row) '(""))
                       _ (pin st 'row (st 'row + 1))
                       _ (vgole st 0)
                       (pin st 'mode 'i))
          (c = 79) (: _ (vsnap st)                              ; O
                      _ (vsplice st (st 'row) (st 'row - 1) '(""))
                      _ (vgole st 0)
                      (pin st 'mode 'i))
          (c = 112) (vpaste st 1 n)                             ; p
          (c = 80) (vpaste st () n)                             ; P
          (c = 117) (vundo st)                                  ; u
          (c = 18) (vredo st)                                   ; ^R
          (c = 58) (: _ (pin st 'cmd (ednew ())) (pin st 'mode 'c))     ; :
          ((c = 47) || (c = 63))                                ; / ?
           (: _ (pin st 'cmd (ednew ())) _ (pin st 'dir (? (c = 47) 1 -1)) (pin st 'mode 's))
          (c = 110) (? (two? (st 'pat)) (vhunt st (st 'dir)) (vmsg st "no previous search"))
          (c = 78) (? (two? (st 'pat)) (vhunt st (0 - st 'dir)) (vmsg st "no previous search"))
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
   (vdigits k) (: s (show k) (map (\ i (s i)) (jot #s)))
   (vdot st raw)
    (: d (st 'dot)
       (? (one? d) (vmsg st "nothing to repeat")
          (: k (0 < raw ? raw <d)
             ks (0 < k ? ((vdigits k) + <>d) <>d)
             _ (pin st 'op ())                     ; `.` is not a motion: d. is just .
             _ (pin st 'dotting 1)
             s2 (vfeed st ks)
             _ (pin s2 'dotting ())
             s2)))

   ; -- the one door: state x key -> state. a key is a byte, or one of cli's edkey codes:
   ; the arrows (h j k l in normal mode, insert's own), alt letters, home and end --
   ; space and backspace are l and h, as they are in every vi
   (arrow c) (c @ -1 104 -2 108 -8 107 -9 106 32 108 (8 || 127) 104 c)
   (vstep st c)
    (: rec (st 'rec)
       on? (two? rec)
       start (!(st 'dotting) && !on? && vquiet? st && vchange? c)
       _ (? start (pin st 'reccnt (st 'cnt)) ())
       _ (? (start || on?) (pin st 'rec (c . (on? ? rec ()))) ())
       s2 (vstep1 st c)
       (? (two? (s2 'rec) && vquiet? s2)
           (pins s2 'dot [(s2 'reccnt) (rev (s2 'rec))] 'rec ())
          s2))
   (vstep1 st c)
    (: m (st 'mode)
       (? (m = 'i) (vins st c)
          (m = 'c || m = 's)
           ; the line is cli's editor; enter takes it, escape leaves, and a backspace on
           ; nothing leaves too
           (: t (st 'cmd)
              (? ((c = 127 || c = 8 || c = -3) && edempty? t) (pin st 'mode 'n)
                 (: _ (edstep t c)
                    e (t 'ev)
                    (? (e = 0) st
                       (e = 27) (pin st 'mode 'n)
                       (e = 9) (edput t 9, st)
                       (e = 10)
                        (: s (edtext t)
                           _ (pin st 'mode 'n)
                           _ (vmsg st "")
                           (? (m = 'c) (vex st)
                              (s = "") (two? (st 'pat) ? (vhunt st (st 'dir)) st)
                              (: b (rebre s)
                                 (? (two? b)
                                    (pins st 'pat <>b 'pattx s 'patw (),
                                     vhunt st (st 'dir))
                                    (vmsg st $ "bad pattern: " + s)))))
                       st))))
          ; normal
          (? (st 'pc) (vpc st c)
             (48 <= c <= 57 && (48 < c || 0 < st 'cnt))
              (pin st 'cnt (10 * st 'cnt + c - 48))
             (c = 27) (pins st 'cnt 0 'op (), vmsg st "")
             (vmsg st "", vnorm st (arrow c)))))
   (vfeed st bs) (bs @ (a . u) (vfeed (vstep st a) u) st)

   ; -- birth --
   ; the paint is born on for a .l name and off for everything else, which is
   ; also why every frame law below still reads the plain bytes it always did:
   ; they open their buffers as "t".
   (vdotl f) (: n #f (1 < n && f (n - 2) = 46 && f (n - 1) = 108))
   (vnew ls file)
    {'lines (two? ls ? ls '(""))
     'row 0 'col 0 'goal 0 'top 0
     'mode 'n 'cnt 0 'op () 'pc () 'gcnt 0 'lastf ()
     'reg () 'undo () 'redo ()
     'dot () 'rec () 'reccnt 0 'dotting ()
     'file file 'dirty () 'msg "" 'sw 2
     'cmd "" 'pat () 'pattx "" 'patw () 'dir 1
     'quit () 'dow () 'doe ()
     'hl (vdotl file) 'pens () 'book () 'hlcar () 'hlgen 0 'hlrow (tablet ())
     'lncar () 'laycar () 'lastr () 'w 80 'h 24}

   ; -- the frame ---------------------------------------------------------------
   ; vlay settles 'top and works out what the screen should hold: the body rows
   ; (clipped, painted), the status line (clipped), and where the cursor goes.
   ; vframe writes all of it; vfresh writes the difference. one layout under both.
   (vlay st)
    (: w (st 'w) h (st 'h) body (h - 1)
       _ (st 'row < st 'top ? (pin st 'top (st 'row)))
       _ (st 'top + body - 1 < st 'row ? (pin st 'top (st 'row - (body - 1))))
       top (st 'top) ls (st 'lines)
       (clip ln) (w < #ln ? (snip ln 0 w) ln)
       ; the status line clips from the LEFT: its tail carries the news (row,col, the
       ; ": 12 lines", the end of the : being typed), which a deep path would push off
       ; the screen. `<` marks the cut. the TEXT lines still clip right -- the
       ; no-horizontal-scroll rule.
       (clipl ln) (: k #ln (? (w < k) ("<" + snip ln ((k - w) + 1) k) ln))
       ; -- the paint. escapes are zero width, so clip first and paint the clip:
       ; every column worked out below is the plain one, cursor included. off,
       ; this whole lane vanishes and the frame is the byte-for-byte old one.
       paint (st 'hl && tablet? (st 'pens))
       bk (? paint (vbook st) ())
       car (? paint (vcarry st bk) ())
       ; the painted row, cached against the text that made it, the carry it began
       ; on and the width it was cut to -- keyed by SCREEN row, so the table is the
       ; height of the view and never the height of the file. typing moves one row;
       ; the other twenty-odd are answered out of here without the lexer running
       (lay raw in i)
        (: ln (clip raw)
           (? !paint ln
              (: rw (st 'hlrow)
                 k (peep rw i ())
                 (? (two? k && <k = ln && <>k = in && <>>k = w) <>>>k
                    (: p (hue-line (st 'pens) bk ln in)
                       _ (pin rw i [ln in w p])
                       p)))))
       ; 'lines and the carry are LISTS: asking for row i by application walks i
       ; pairs, so a screenful deep in a file walked the file forty times over --
       ; 55% of a keystroke, and the whole of why moving around got slower the
       ; further down you were. drop to the top once and step from there
       (drop l k) (? (k < 1 || one? l) l (drop >l (k - 1)))
       (rows l cl i acc)
        (? (body <= i) (rev acc)
           (rows >l >cl (i + 1) ((two? l ? (lay <l <cl i) "~") . acc)))
       status (? (st 'mode = 'c) (":" + edtext (st 'cmd))
                 (st 'mode = 's) ((? (0 < st 'dir) "/" "?") + edtext (st 'cmd))
                 (0 < #(st 'msg)) (st 'msg)
                 ((? (0 < #(st 'file)) (st 'file) "[no name]") + (? (st 'dirty) " [+]" "") + (? (st 'mode = 'i) " -- INSERT --" "") + "  " + show (st 'row + 1) + "," + show (st 'col + 1)))
       ; in ex and search mode you are typing on the status line, so that is
       ; where the cursor goes: after the prefix, at the editor's column
       said? (st 'mode = 'c || st 'mode = 's)
       cr (? said? h ((st 'row - top) + 1))
       cc (: k (? said? (edcol (st 'cmd) + 2) (st 'col + 1)) (? (w < k) w k))
       ; the body is a pure function of these five, so when none of them moved the
       ; rows are the ones we laid last time -- a keystroke that only walks the
       ; cursor about lays nothing at all, which is the common keystroke
       key [(st 'hlgen) w top body (paint ? 1 ())]
       lc (st 'laycar)
       rs (? (two? lc && (= <lc key)) <>lc
             (: k (rows (drop ls top) (drop car top) 0 ())
                _ (pin st 'laycar [key k])
                k))
       [rs (clipl status) cr cc key])

   ; -- the frame: one full redraw as a single text --
   (vframe st)
    (: e (string 27) L (vlay st)
       (go l acc) (? (one? l) acc (go >l (acc + <l + e + "[K" + "\r\n")))
       (e + "[H" + go <L "" + <>L + e + "[K"
          + e + "[" + show <>>L + ";" + show <>>>L + "H"))

   ; -- the frame as a refresh: only what changed -------------------------------
   ; a full redraw a keystroke is the flicker: the screen is cleared line by line and
   ; rewritten while the terminal draws it. so keep the rows the last frame put there,
   ; place only the ones that differ, and bracket the lot in synchronised-output mode
   ; (DEC 2026) so a scroll lands in one piece -- a terminal that does not know 2026
   ; ignores it, as does quay.
   (vfresh st)
    (: e (string 27) L (vlay st)
       rs <L ss <>L key (L 4)
       geo [(st 'w) (st 'h) (st 'top)]
       old (st 'lastr)                             ; [geo key rows status]
       same? (two? old && (= <>old key))           ; vlay's own key: the body cannot differ
       at? (two? old && (= <old geo))
       (place i ln) (e + "[" + show (i + 1) + ";1H" + ln + e + "[K")
       (dif a b i acc)
        (? !(two? b) acc
           (dif (two? a ? >a ()) >b (i + 1)
                ((two? a && (= <a <b)) ? acc (acc + place i <b))))
       body (? same? ""
                at? (dif <>>old rs 0 "")
                (: (go l acc) (? !(two? l) acc (go >l (acc + <l + e + "[K" + "\r\n")))
                   (e + "[H" + go rs "")))
       stat (? (at? && (= <>>>old ss)) "" (place (st 'h - 1) ss))
       _ (pin st 'lastr [geo key rs ss])
       (e + "[?2026h" + body + stat
          + e + "[" + show <>>L + ";" + show <>>>L + "H" + e + "[?2026l")))
) ; module 'vi
