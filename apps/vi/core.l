; apps/vi/core.l -- the vi engine, pure: a state tablet stepped one byte at a
; time (vstep), rendered to one escape-sequence frame (vframe). no port, no
; tty, no file io in here -- the face (apps/vi/vi.l) reads keys, performs the
; write requests the ex commands leave on the state, and blits frames; the
; laws (apps/vi/law.l) drive vstep with byte lists and read the tablet back.
; search rides apps/kore/re.l (rebre/refind), so re.l loads first in any cat.
;
; the state (a tablet): 'lines (texts, never empty -- the vi invariant),
; 'row 'col (0-based), 'goal (the remembered column j/k aim for), 'top (first
; visible row), 'mode ('n normal, 'i insert, 'c ex, 's search), 'cnt (pending
; count), 'op (pending operator (char n) or ()), 'pc (pending char-arg nom:
; f F t T r g Z), 'reg (the yank: ('lin lines) | ('chr text)), 'undo 'redo
; (snapshot stacks), 'file 'dirty 'msg 'cmd (the ex/search line), 'pat 'pattx
; 'dir (the search state), 'quit (() | 1), 'dow (a write request: (name) --
; uread's shape, the face consumes it), 'doe (a READ request, same shape: :e/:o
; leave it, the face reads and calls vload), 'w 'h (the view).
;
; the syntax paint rides four more keys and apps/vi/hue.l: 'hl (paint? -- born
; on for a .l name, :hl flips it), 'pens (the class -> escape tablet; the FACE
; installs it, so this file still touches no getenv and no file), 'book (the
; vocabulary, folded once at the first paint), 'hlcar (the cached per-line
; "starts inside a string" carry, [gen flags] -- the wrapper is not
; decoration, gen 0 over an empty buffer is a real cached value, so a bare one
; could not say "no cache"), 'hlgen (bumped by the three line mutators -- vput,
; vsplice, vrest -- and nothing else touches 'lines).
;
; the dialect: motions h j k l 0 ^ $ w b e f F t T G gg, counts, the arrows as h j k l,
; the diagonals alt-y u b n (cli's edkey hands an alt letter in as 256 + the letter: a k
; or j then an h or l, the count on both, and never under an operator), operators
; d c y (doubled = linewise; with j/k/G/gg linewise, else within the line),
; x X D C s r J, i a I a o O, p P (lin + chr), u and ^R, / ? n N (BRE, over
; re.l), zz, ^F ^B ^D ^U paging.
;
; the ex line is a real one: [range] command [args], where an address is
; N . $ /re/ ?re? with +N / -N offsets, joined by , or ; and % for 1,$. the
; commands are s (over sed's own usub, so & and \1 read the same there as
; here), g and v, d y m t co j p nu = , and the file half w [NAME] e[!] [NAME]
; o [NAME] q q! wq x hl lint. a bare range moves the cursor.
; out of scope, documented: visual mode, named registers, ., macros, marks and
; :r, > and < (a shiftwidth is a config question this file has no table for),
; tabs render raw (the terminal's stops, not ours), no horizontal scroll (long
; lines clip at the view's edge).
(module 'vi
(use 'kore) ; the text/u floors
(use 'lint)  ; lint-scan, spliced for this module's compile
(:
   ; -- the small floor --
   ; lists do not index by application (a number list would church-tower), so
   ; the row walk is explicit; "" past the end keeps every reader total
   (vln st) (st 'lines (st 'row))
   (vlen st) (tally (vln st))
   (vnl st) (tally (st 'lines))
   (vink ln) (: n #ln                       ; first non-blank column
                 (go i) (? (i < n && (ln i = 32 || ln i = 9)) (go (i + 1)) i)
                 (: k (go 0) (? (k < n) k (0 < n) (n - 1) 0)))
   ; every edit to 'lines bumps the generation, which is what lets the paint's
   ; string carry be recomputed once per edit instead of once per keystroke
   (vgen st) (pin st 'hlgen (st 'hlgen + 1))
   (vput st r ln) (: _ (pin st 'lines (: (go l i) (? !(two? l) ()
                                                     ((? (i = r) ln <l) >< go >l (i + 1)))
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

   ; -- the word motions: (row col) -> (row col), crossing lines when free --
   (vwfwd st r c)                                  ; next word start
    (: ls (st 'lines) n #ls
       (at r2 c2) (: ln (ls r2) (c2 < #ln ? (vcl (ln c2)) 0))
       (skipk r2 c2 k)                             ; over the current run of class k
        (: ln (ls r2)
         (c2 < #ln && vcl (ln c2) = k ? (skipk r2 (c2 + 1) k) [r2 c2]))
       (skipb r2 c2)                               ; over blanks, line ends included
        (: ln (ls r2)
           (? (c2 < #ln) (? (vcl (ln c2) = 0) (skipb r2 (c2 + 1)) [r2 c2])
              ((r2 + 1) < n) (skipb (r2 + 1) 0)
              [r2 #ln]))
       k (at r c)
       p (? (k = 0) [r c] (skipk r c k))
       (skipb <p <>p))
   (vwend st r c)                                  ; next word end (inclusive target)
    (: ls (st 'lines) n #ls
       (skipb r2 c2) (: ln (ls r2)
                        (? (c2 < #ln) (? (vcl (ln c2) = 0) (skipb r2 (c2 + 1)) [r2 c2])
                           ((r2 + 1) < n) (skipb (r2 + 1) 0)
                           [r2 c2]))
       p (skipb r (c + 1))
       r2 <p c2 <>p ln (ls r2)
       (? (#ln <= c2) [r2 (? (0 < #ln) (#ln - 1) 0)]
          (: k (vcl (ln c2))
             (run j) (? ((j < #ln) && (vcl (ln j) = k)) (run (j + 1)) (j - 1))
             [r2 (run c2)])))
   (vwback st r c)                                 ; previous word start
    (: ls (st 'lines)
       (skipb r2 c2) (? (c2 < 0) (0 < r2 ? (: pr (r2 - 1) (skipb pr (#(ls pr) - 1)))
                                           '(0 0))
                        (: ln (ls r2)
                           (? (vcl (ln c2) = 0) (skipb r2 (c2 - 1)) [r2 c2])))
       p (skipb r (c - 1))
       r2 <p c2 <>p ln (ls r2)
       (? (tally ln <= c2) [r2 c2]
          (: k (vcl (ln c2))
             (run j) (? ((0 <= (j - 1)) && (vcl (ln (j - 1)) = k)) (run (j - 1)) j)
             [r2 (run c2)])))

   ; -- motions: key (+ n) -> ('to r c) exclusive | ('toi r c) inclusive
   ;             | ('lin r2) linewise target | () --
   (vmot st c n raw)
    (: r (st 'row) col (st 'col) ln (vln st) len #ln nl (vnl st)
     (c @ 104 ['to r (: k (col - n) (? (k < 0) 0 k))]             ; h
          108 ['to r (: k (col + n) (? (len < k) len k))]        ; l
          48 ['to r 0]                                           ; 0
          94 ['to r (vink ln)]                                   ; ^
          36 (? (0 < len) ['toi r (len - 1)] ['to r 0])         ; $
          119 (: (go i p) (? (i < 1) p                            ; w
                                 (go (i - 1) (vwfwd st <p <>p)))
                     p (go n [r col])
                     ['to <p <>p])
          101 (: (go i p) (? (i < 1) p                            ; e
                                 (go (i - 1) (vwend st <p <>p)))
                     p (go n [r col])
                     ['toi <p <>p])
          98 (: (go i p) (? (i < 1) p                             ; b
                                (go (i - 1) (vwback st <p <>p)))
                    p (go n [r col])
                    ['to <p <>p])
          106 ['lin (: k (r + n) (? (k < nl) k (nl - 1)))]       ; j
          107 ['lin (: k (r - n) (? (k < 0) 0 k))]               ; k
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
   (vopl st opc r1 r2)                             ; linewise rows r1..r2
    (: a (r1 < r2 ? r1 r2) b (r1 < r2 ? r2 r1)
       _ (vyank st 'lin (vtake st a b))
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
                   st)))))
   ; a motion answered mr while operator (opc . ocnt) was pending
   (vapply st opc mr)
    (: kind <mr
       (? (kind = 'lin) (vopl st opc (st 'row) <>mr)
          (: r2 <>mr c2 <>>mr
             (? (r2 = st 'row)
                (vopc st opc (st 'row) (st 'col) (? (kind = 'toi) (c2 + 1) c2))
                (? (st 'row < r2) (vopl st opc (st 'row) r2)     ; crossed lines: take them whole
                   (vopl st opc r2 (st 'row)))))))

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
             ln (vln st) len #ln
             at (after && 0 < len ? (st 'col + 1) (st 'col))
             _ (vput st (st 'row) (snip ln 0 at + tt + snip ln at len))
             _ (vgole st (at + #tt - 1))
             st)))
   (vjoin st n)
    (: (one s2) (? (s2 'row + 1 < vnl s2)
                   (: r (s2 'row) a (s2 'lines r) b (s2 'lines (r + 1))
                      bi (: k (vink b) (0 < #b ? k 0))
                      joined (a + " " + snip b bi #b)
                      _ (vgole s2 #a)
                      _ (vsplice s2 r (r + 1) [joined])
                      s2)
                   s2)
       (go i) (i < 1 ? st (one st, go (i - 1)))
       _ (vsnap st)
       (go (n < 2 ? 1 (n - 1))))
   (vundo st)
    (: u (st 'undo)
       (? !(two? u) (vmsg st "already at oldest change")
          (: _ (pins st 'redo ([(st 'lines) (st 'row) (st 'col)] >< st 'redo)
                        'undo >u)
             _ (vrest st <u)
             (vclampn st))))
   (vredo st)
    (: r (st 'redo)
       (? !(two? r) (vmsg st "already at newest change")
          (: _ (pin st 'undo ([(st 'lines) (st 'row) (st 'col)] >< st 'undo))
             _ (pin st 'redo >r)
             _ (vrest st <r)
             (vclampn st))))

   ; -- search (re.l): hunt for 'pat from the cursor, dir 1 fwd / -1 back --
   (vlast st ln bound)                             ; last match start in ln with start < bound
    (: (go i best) (: r (refind (st 'pat) ln i)
                      (? !(two? r) best
                         (: ms <>r
                            (? (ms < bound) (go (ms + 1) ms) best))))
       (go 0 ()))
   (vhunt st dir)
    (: ls (st 'lines) nl #ls r (st 'row) c (st 'col)
       (fwd i steps)
        (? (nl < steps) ()
           (: ln (ls i)
              from (steps = 0 ? (c + 1) 0)
              m (? (from <= #ln) (refind (st 'pat) ln from) ())
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

   ; -- libra ⚖, on the buffer ------------------------------------------------
   ; both of libra's weighings run in here, because both are pure functions over
   ; text (apps/libra/lint.l rides ahead of this file in the cat). the point is the
   ; buffer rather than the file on disk: it answers for what you are looking at,
   ; not for what you last saved, which is exactly when you want to be told.
   ; one scanner under libra's three faces and this one, so what pulchritude says
   ; is what `make lint` will refuse -- there is no second implementation to
   ; drift. lint counts line and col from one and the buffer from zero.
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
   ; a line reads [range] command [args]. an address is N . $ /re/ ?re? with any
   ; run of +N / -N after it; two of them join with , or ; (`;` moves dot to the
   ; first before reading the second) and % is 1,$. rows answer 0-based, so
   ; address 0 is -1 -- the "before the first line" m and t take as a destination.
   ; a search address that finds nothing answers 'bad, which is not (): "no
   ; address here" and "an address that failed" have to part company, or
   ; :/nomatch/d silently deletes the current line.

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
                    (: _ (? (0 < #tx) (pins st 'pat <>cp 'pattx tx) ())
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
                       (: _ (? (0 < #pat) (pins st 'pat <>cp 'pattx pat) ())
                          [1 (recomp <>cp) rep (vexhas? (snip s k n) 103)]))))))))
   (vexsubs st m rep a b g?)                       ; ((row text)..) for the rows that change
    (: (go r acc) (? (b < r) (rev acc)
                     (: res (usub m rep (st 'lines r) g?)
                        (go (r + 1) (<res ? ([r <>res] >< acc) acc))))
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
              (go (r + 1) ((inv? ? !m? m?) ? (r >< acc) acc))))
       (go a ()))
   (vexplan st rows sp)                            ; the body, dry: what it would touch
    (? (<sp = 's)
       (: (go l acc) (? !(two? l) acc
                        (: r <l res (usub <>sp <>>sp (st 'lines r) <>>>sp)
                           (go >l (<res ? ([r <>res] >< acc) acc))))
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
                     (: _ (? (0 < #pat) (pins st 'pat <>cp 'pattx pat) ())
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
       (: _ (pin st 'row r1) n (r2 - r1 + 1) (vjoin st (n < 2 ? 2 n))))

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
       (? (c = 27) st
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
                      st)
          (k = 'Z) (c != 90 ? st (pins st 'dow [(st 'file)] 'quit 1))
          ; f F t T
          (: mr (vfind st k c n)
             op (st 'op)
             _ (pin st 'op ())
             (? !(two? mr) st
                (two? op) (vapply st <op mr)
                (vgole st <>>mr)))))

   ; -- normal mode --
   (vnorm st c)
    (: n (: v (st 'cnt) (? (0 < v) v 1))
       (mv1 mr)                                    ; a motion result, no operator
        (? !(two? mr) st
           (<mr = 'lin)
            (: t <>mr _ (pin st 'row t)
             (pin st 'col (: g (st 'goal) len (vlen st)
                           (? (g < len) g (0 < len) (len - 1) 0))))
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
       (? (member? c '(104 108 48 94 36 119 101 98 106 107 71))   ; h l 0 ^ $ w e b j k G
           (motion (vmot st (? ((c = 119) &&                      ; the vi special case:
                                (: o (st 'op)                     ; cw changes the word only,
                                   (two? o && (<o = 99))))
                              101 c)                              ; ... so cw rides e
                          n rawc))
          (c = 377) (diag 107 104)  (c = 373) (diag 107 108)         ; alt-y alt-u: up-left, up-right
          (c = 354) (diag 106 104)  (c = 366) (diag 106 108)         ; alt-b alt-n: down-left, down-right
          (member? c '(102 70 116 84))                            ; f F t T
           (: _ (pin st 'cnt n)
              (pin st 'pc (? (c = 102) 'f (c = 70) 'F (c = 116) 't 'T)))
          (c = 103) (: _ (pin st 'gcnt rawc) (pin st 'pc 'g))
          (c = 90) (pin st 'pc 'Z)
          (c = 114) (: _ (pin st 'cnt n) (pin st 'pc 'r))
          (member? c '(100 121 99))                             ; d y c
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
          (c = 74) (vjoin st n)                                 ; J
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

   ; -- the one door: state x key -> state. a key is a byte, or one of cli's edkey codes:
   ; the arrows (h j k l in normal mode, insert's own), alt letters, home and end --
   (arrow c) (c @ -1 104 -2 108 -8 107 -9 106 c)
   (vstep st c)
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
                                    (pins st 'pat <>b 'pattx s,
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
     'mode 'n 'cnt 0 'op () 'pc () 'gcnt 0
     'reg () 'undo () 'redo ()
     'file file 'dirty () 'msg ""
     'cmd "" 'pat () 'pattx "" 'dir 1
     'quit () 'dow () 'doe ()
     'hl (vdotl file) 'pens () 'book () 'hlcar () 'hlgen 0
     'w 80 'h 24}

   ; -- the frame: one full redraw as a single text --
   (vframe st)
    (: e (string 27)
       w (st 'w) h (st 'h) body (h - 1)
       _ (st 'row < st 'top ? (pin st 'top (st 'row)))
       _ (st 'top + body - 1 < st 'row ? (pin st 'top (st 'row - (body - 1))))
       top (st 'top) ls (st 'lines) nl #ls
       (clip ln) (w < tally ln ? (snip ln 0 w) ln)
       ; the status line clips from the left. its tail is what carries the
       ; news -- the row,col, the ": 12 lines", the end of the : you are typing --
       ; and a deep path would otherwise push every word of it off the screen
       ; (which it did: `:e some/long/path.l` confirmed into the void). `<` marks
       ; the cut, the way vim marks a name it had to shorten. the TEXT lines
       ; still clip right: that is the no-horizontal-scroll rule and it stays.
       (clipl ln) (: k (tally ln) (? (w < k) ("<" + snip ln ((k - w) + 1) k) ln))
       ; -- the paint. escapes are zero width, so clip first and paint the clip:
       ; every column worked out below is the plain one, cursor included. off,
       ; this whole lane vanishes and the frame is the byte-for-byte old one.
       paint (st 'hl && tablet? (st 'pens))
       bk (? paint (: b (st 'book)
                      (? (tablet? b) b (: n (hue-book ()) _ (pin st 'book n) n)))
             ())
       ; the carry says which lines start inside a string (papel.l's css is forty
       ; lines of one literal); it is cached against the generation, so an edit
       ; pays for it and a keystroke that only moves the cursor does not
       car (? paint (: c (st 'hlcar)
                      (? (two? c && (<c = st 'hlgen)) <>c
                         (: k (hue-carry bk ls) _ (pin st 'hlcar [(st 'hlgen) k]) k)))
              ())
       (lay i) (: ln (clip (ls i))
                  (? paint (hue-line (st 'pens) bk ln (car i)) ln))
       (rows i acc)
        (? ((top + body) <= i) acc
           (rows (i + 1) (acc + (? (i < nl) (lay i) "~") + e + "[K" + "\r\n")))
       status (? (st 'mode = 'c) (":" + edtext (st 'cmd))
                 (st 'mode = 's) ((? (0 < st 'dir) "/" "?") + edtext (st 'cmd))
                 (0 < tally (st 'msg)) (st 'msg)
                 ((? (0 < tally (st 'file)) (st 'file) "[no name]") + (? (st 'dirty) " [+]" "") + (? (st 'mode = 'i) " -- INSERT --" "") + "  " + show (st 'row + 1) + "," + show (st 'col + 1)))
       ; in ex and search mode you are typing on the status line, so that is
       ; where the cursor goes: after the prefix, at the editor's column
       said? ((st 'mode = 'c) || (st 'mode = 's))
       cr (? said? h ((st 'row - top) + 1))
       cc (: k (? said? (edcol (st 'cmd) + 2) (st 'col + 1)) (? (w < k) w k))
       (e + "[H" + rows top "" + clipl status + e + "[K" + e + "[" + show cr + ";" + show cc + "H")))
) ; module 'vi
