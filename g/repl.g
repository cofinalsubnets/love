; the read-eval-print loop, its parser, and its multi-line line editor.
; loaded after boot.g by the interactive frontends (host and kernel).
;
; the parser is pure gwen: read1 walks a charlist and returns
; (value . rest) on success, e on no-datum (top-level EOF or stray
; closing paren), m on incomplete input (open list, dangling quote,
; unterminated string). numbers are signed decimal with an optional
; 0x/0X prefix for hex; octals are not special. the C `str` builtin
; materializes symbol names and string literals from charlists.
;
; the editor buffer is a four-zipper threaded positionally through
; the editor functions: u (lines above the cursor, reversed), l (chars
; left of cursor on the current line, reversed), r (chars at/after
; cursor on the current line, in order), d (lines below). state is
; passed through helpers in CPS so no table is allocated per
; keystroke. on each tick the whole multi-line input is redrawn from
; the prompt's row via relative cursor motion; the loop tracks rows
; above the cursor from the previous render so terminal scrolling
; doesn't desync.
;
; command history is a parallel zipper (hu, hd) over previously-
; submitted buffer states. when the buffer cursor is on the top line,
; up navigates history toward older; mirrored for down. on first edit
; to a recalled entry, the pristine version is restored to its slot
; and the buffer becomes a new entry, so the original survives.
(: e (sym 0) m (sym 0) eofsym (sym 0)

   (revappend a b) (foldl b (flip cons) a)
   (append a b) (revappend (rev a) b)

   ; --- parser char classification ---
   (isws c)    (|| (= c 32) (= c 10) (= c 9) (= c 13) (= c 12) (= c 0))
   (iscom c)   (|| (= c 35) (= c 59))
   (isdig c)   (&& (>= c 48) (<= c 57))
   (ishex c)   (|| (isdig c) (&& (>= c 65) (<= c 70)) (&& (>= c 97) (<= c 102)))
   (isdelim c) (|| (isws c) (iscom c) (= c 40) (= c 41) (= c 34) (= c 39))
   (digval c)  (? (isdig c) (- c 48)
                  (>= c 97) (- c 87)        ; a-f -> 10-15
                  (- c 55))                  ; A-F -> 10-15

   ; skip a comment to end of physical line (consuming the \n).
   (skipln cl) (? (twop cl)
                  (? (|| (= (car cl) 10) (= (car cl) 13)) (cdr cl)
                     (skipln (cdr cl)))
                  cl)
   ; skip whitespace and # / ; comments
   (skipws cl) (? (twop cl)
                  (: c (car cl)
                     (? (isws c)  (skipws (cdr cl))
                        (iscom c) (skipws (skipln (cdr cl)))
                        cl))
                  cl)

   ; --- integer parsing on a charlist ---
   ; each returns (cons int rest) on success, 0 on failure (no digits).
   (decimal cl)
     (: (loop n cl had)
          (? (&& (twop cl) (isdig (car cl)))
             (loop (+ (* n 10) (- (car cl) 48)) (cdr cl) -1)
             (? had (cons n cl) 0))
        (loop 0 cl 0))
   (hex cl)
     (: (loop n cl had)
          (? (&& (twop cl) (ishex (car cl)))
             (loop (+ (* n 16) (digval (car cl))) (cdr cl) -1)
             (? had (cons n cl) 0))
        (loop 0 cl 0))
   ; unsigned int with optional 0x / 0X prefix.
   (uint cl)
     (? (&& (twop cl) (= (car cl) 48))
        (: rest (cdr cl)
           (? (&& (twop rest) (|| (= (car rest) 120) (= (car rest) 88)))
              (hex (cdr rest))
              (decimal cl)))
        (decimal cl))
   ; signed int.
   (numof cl)
     (? (twop cl)
        (: c (car cl)
           (? (= c 45) (: r (uint (cdr cl))
                          (? (twop r) (cons (- 0 (car r)) (cdr r)) 0))
              (= c 43) (uint (cdr cl))
              (uint cl)))
        0)

   ; read one token: a maximal run of non-delimiter chars.
   ; returns (cons token-charlist rest).
   (readtok cl)
     (: (loop acc cl)
          (? (&& (twop cl) (nilp (isdelim (car cl))))
             (loop (cons (car cl) acc) (cdr cl))
             (cons (rev acc) cl))
        (loop 0 cl))

   ; quote symbol -- gwen's quote special form is named with a backtick.
   qsym (sym "`")

   ; read one datum from a charlist.
   (read1 cl)
     (: cl (skipws cl)
        (? (nilp cl) e
           (: c (car cl)
              (? (= c 40) (rdlist (cdr cl))    ; (
                 (= c 41) e                     ; ) at top level
                 (= c 39) (rdquot (cdr cl))    ; '
                 (= c 34) (rdstr  (cdr cl))    ; "
                 (rdatom cl)))))

   ; read until a closing paren (already past the opening one).
   (rdlist cl)
     (: cl (skipws cl)
        (? (nilp cl) m
           (= (car cl) 41) (cons 0 (cdr cl))
           (: r (read1 cl)
              (? (= r m) m
                 (= r e) m
                 (: rest (rdlist (cdr r))
                    (? (= rest m) m
                       (cons (cons (car r) (car rest)) (cdr rest))))))))

   ; read one datum after a quote mark; wrap as (qsym datum).
   (rdquot cl)
     (: r (read1 cl)
        (? (= r m) m
           (= r e) m
           (cons (cons qsym (cons (car r) 0)) (cdr r))))

   ; read a string literal until the closing quote, honoring \X.
   (rdstr cl)
     (: (loop acc cl)
          (? (nilp cl) m
             (: c (car cl)
                rest (cdr cl)
                (? (= c 34) (cons (str (rev acc)) rest)        ; closing "
                   (= c 92) (? (nilp rest) m                    ; trailing \
                               (loop (cons (car rest) acc) (cdr rest)))
                   (loop (cons c acc) rest))))
        (loop 0 cl))

   ; read an atom: a token, then decide number-or-symbol.
   (rdatom cl)
     (: tr (readtok cl)
        tok (car tr)
        r (numof tok)
        val (? (&& (twop r) (nilp (cdr r))) (car r) (sym (str tok)))
        (cons val (cdr tr)))

   ; drain a charlist into a list of all the datums it holds.
   ; propagates m if anything in the chain is incomplete.
   (parseall cl)
     (: r (read1 cl)
        (? (= r m) m
           (= r e) 0
           (: rest (parseall (cdr r))
              (? (= rest m) m
                 (cons (car r) rest)))))

   ; --- editor ---

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
     (? (twop ls)
        (? (twop (cdr ls))
           (append (car ls) (cons 10 (joinln (cdr ls))))
           (car ls))
        0)

   ; flatten the editor state into one charlist suitable for parseall
   (flatten u l r d)
     (joinln (revappend u (cons (revappend l r) d)))

   ; walk xs forward taking n chars into acc (reversed); when done
   ; call k with (rev (take n xs)) and (drop n xs). stops cleanly at
   ; end-of-xs even if n exceeds the list length.
   (splitat k acc n xs)
     (? (&& (twop xs) (< 0 n)) (splitat k (cons (car xs) acc) (- n 1) (cdr xs))
        (k acc xs))

   ; map non-printables to space; otherwise pass through
   (prc c) (putc (? (&& (<= 32 c) (< c 127)) c 32))

   ; CPS editor primitives. each takes the loop as continuation k
   ; and forwards a new (u l r d) to it; helpers are no-ops at their
   ; boundary. left/right wrap across lines; bsp at column 0 merges
   ; the current line onto the previous; del at end-of-line splices
   ; the next line on. up/down preserve column, clamped to the
   ; destination line's length.
   (edleft k u l r d)
     (? (twop l) (k u (cdr l) (cons (car l) r) d)
        (twop u) (k (cdr u) (rev (car u)) 0 (cons (revappend l r) d))
        (k u l r d))
   (edright k u l r d)
     (? (twop r) (k u (cons (car r) l) (cdr r) d)
        (twop d) (k (cons (revappend l r) u) 0 (car d) (cdr d))
        (k u l r d))
   (edbsp k u l r d)
     (? (twop l) (k u (cdr l) r d)
        (twop u) (k (cdr u) (rev (car u)) r d)
        (k u l r d))
   (eddel k u l r d)
     (? (twop r) (k u l (cdr r) d)
        (twop d) (k u l (car d) (cdr d))
        (k u l r d))
   (edhome k u l r d) (k u 0 (revappend l r) d)
   (edend  k u l r d) (k u (revappend r l) 0 d)
   ; edtop / edbot jump across the whole buffer: cursor at the start of
   ; the topmost line / end of the bottommost line. on a single-line
   ; buffer they degenerate to edhome / edend.
   (edtop k u l r d)
     (? (twop u) (: ru (rev u)
                     (k 0 0 (car ru) (append (cdr ru) (cons (revappend l r) d))))
        (k u 0 (revappend l r) d))
   (edbot k u l r d)
     (? (twop d) (: rd (rev d)
                     (k (append (cdr rd) (cons (revappend l r) u)) (revappend (car rd) 0) 0 0))
        (k u (revappend r l) 0 d))
   (edup k u l r d)
     (? (twop u) (splitat (\ ll rr (k (cdr u) ll rr (cons (revappend l r) d)))
                          0 (len l) (car u))
        (k u l r d))
   (eddown k u l r d)
     (? (twop d) (splitat (\ ll rr (k (cons (revappend l r) u) ll rr (cdr d)))
                          0 (len l) (car d))
        (k u l r d))

   ; --- history zipper ---

   ; pack the buffer's four halves into one slot for history storage.
   (mkframe u l r d) (cons u (cons l (cons r d)))

   ; if cur holds a pristine recall, restore it at its slot in hu;
   ; called before any mutating edit so the original survives.
   (detach hu cur) (? (twop cur) (cons cur hu) hu)

   ; predicates over the buffer used by the history navigation rules
   ; below: empty buffers don't get pushed during normal nav, and
   ; off-the-end nav only pushes when the buffer parses to a value.
   (emptybuf u l r d) (&& (nilp u) (nilp l) (nilp r) (nilp d))
   (parses u l r d)   (twop (parseall (flatten u l r d)))

   ; up/down through the history zipper. on a normal pop, push the
   ; current buffer onto the other side (skipping if empty); if the
   ; other side is empty (hu or hd) but we're on a real recall (cur
   ; non-nil) and the buffer parses, push and scroll into a fresh
   ; empty line.
   (uphist k u l r d hu hd cur)
     (? (twop hu)
        (: e (car hu)
           nhd (? (emptybuf u l r d) hd (cons (mkframe u l r d) hd))
           (k (car e) (car (cdr e)) (car (cdr (cdr e))) (cdr (cdr (cdr e))) (cdr hu) nhd e))
        (&& (twop cur) (parses u l r d))
        (: nhd (cons (mkframe u l r d) hd)
           (k 0 0 0 0 hu nhd 0))
        (k u l r d hu hd cur))
   (downhist k u l r d hu hd cur)
     (? (twop hd)
        (: e (car hd)
           nhu (? (emptybuf u l r d) hu (cons (mkframe u l r d) hu))
           (k (car e) (car (cdr e)) (car (cdr (cdr e))) (cdr (cdr (cdr e))) nhu (cdr hd) e))
        (&& (twop cur) (parses u l r d))
        (: nhu (cons (mkframe u l r d) hu)
           (k 0 0 0 0 nhu hd 0))
        (k u l r d hu hd cur))

   ; map a raw byte (or escape sequence) to an event code:
   ; printable >0; -1 left, -2 right, -3 bsp, -4 del, -5 home,
   ; -6 end, -7 quit, -8 up, -9 down, -10 buffer top, -11 buffer end;
   ; 10 = enter.
   ;
   ; after `ESC [ 1` there are two shapes: `~` is plain Home; `; M F`
   ; carries a modifier digit M (5=ctrl, 2=shift, ...) and a final byte
   ; F. modified Home/End jump to buffer top/end; modified arrows fold
   ; back to plain arrow events (we don't act on the modifier).
   (edesc1 c) (? (= c 126) -5
                 (= c 59)  (: _ (getc 0)
                              d (getc 0)
                              (? (= d 72) -10 (= d 70) -11
                                 (= d 65)  -8 (= d 66)  -9
                                 (= d 67)  -2 (= d 68)  -1 0))
                 0)
   (edesc x) (? (!= 91 (getc 0)) 0
     (: c (getc 0)
        (? (= c 68) -1 (= c 67) -2
           (= c 65) -8 (= c 66) -9
           (= c 72) -5 (= c 70) -6
           (= c 49) (edesc1 (getc 0))
           (= c 55) (: _ (getc 0) -5)
           (|| (= c 52) (= c 56)) (: _ (getc 0) -6)
           (= c 51) (: _ (getc 0) -4) 0)))
   (edev x) (: c (getc 0)
     (? (|| (= c -1) (= c 4)) -7
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5 (= c 5) -6 (= c 27) (edesc 0)
        (? (&& (<= 32 c) (< c 127)) c 0)))

   ; redraw the buffer in place. pra is "rows above the cursor from
   ; the previous render" -- we move up that many rows first so we
   ; land back on the prompt's row. all motion is relative: nothing
   ; depends on a saved absolute cursor, so the terminal scrolling
   ; (when the buffer reaches the last row) doesn't desync us. pl is
   ; the prompt's column; the topmost line shares it, subsequent
   ; lines start at column 0.
   (edrender pl pra u l r d)
     (: _ (? (< 0 pra) (, (putc 27) (putc 91) (putn pra 10) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 pl)  (, (putc 27) (putc 91) (putn pl 10)  (putc 67)) 0)
        _ (putc 27) _ (putc 91) _ (putc 74) ; clear to end of screen
        _ (each (rev u) (\ ln (, (each ln prc) (putc 10))))
        _ (each (revappend l r) prc)
        _ (each d (\ ln (, (putc 10) (each ln prc))))
        ld (len d)
        col (+ (? (twop u) 0 pl) (len l))
        _ (? (< 0 ld) (, (putc 27) (putc 91) (putn ld 10) (putc 65)) 0)
        _ (putc 13)
        _ (? (< 0 col) (, (putc 27) (putc 91) (putn col 10) (putc 67)) 0)
        (puts ""))

   ; print the prompt, then dispatch events until ^D or until enter
   ; at end-of-buffer with the buffer fully parsed. enter always
   ; splits the current line at the cursor; only when the cursor is
   ; at end-of-buffer do we try parseall, which may yield multiple
   ; datums on one line. returns eofsym on ^D, otherwise
   ; (cons vs (cons nhu nhd)) so the repl can thread history.
   ;
   ; the loop carries pra = rows above the cursor as of the previous
   ; render. edrender uses pra to move back up to the prompt's row
   ; before redrawing, so we never rely on a saved absolute cursor
   ; position -- terminal scrolling stays consistent. since nothing
   ; between renders moves the cursor (no putc except in the submit
   ; branch which exits), the next render's pra is always (len u) of
   ; the CURRENT frame, regardless of how the state transitions; we
   ; cache it as npra and route every recursion through it.
   ;
   ; kloop wraps the CPS helpers for non-mutating motion; kedit does
   ; the same for mutating ops (backspace, delete) and applies detach
   ; on the way. khist is the continuation used by uphist/downhist
   ; for history navigation. cur is the pristine frame of the
   ; currently-recalled entry, or 0 if the buffer is a free edit.
   (edline hu hd)
     (: ps1 " ;; "
        pr (ps1 _)
        _ (puts pr)
        pl (len pr)
        (loop pra u l r d hu hd cur)
          (: _ (edrender pl pra u l r d)
             c (edev 0)
             npra (len u)
             (kloop uu ll rr dd) (loop npra uu ll rr dd hu hd cur)
             (kedit uu ll rr dd) (loop npra uu ll rr dd (detach hu cur) hd 0)
             (khist uu ll rr dd nhu nhd ncur) (loop npra uu ll rr dd nhu nhd ncur)
             (? (= c -7) eofsym
                (= c 10) (: nu (cons (rev l) u)
                            (? (&& (nilp r) (nilp d))
                               (: vs (parseall (flatten nu 0 r d))
                                  (? (= vs m)
                                     (loop npra nu 0 r d (detach hu cur) hd 0)
                                     (: _ (putc 10)
                                        nhu (? (nilp vs) (revappend hd (detach hu cur))
                                               (twop cur) (revappend hd (cons cur hu))
                                               (revappend hd (cons (mkframe u l r d) hu)))
                                        (cons vs (cons nhu 0)))))
                               (loop npra nu 0 r d (detach hu cur) hd 0)))
                (< 0 c)  (loop npra u (cons c l) r d (detach hu cur) hd 0)
                (= c -1) (edleft  kloop u l r d)
                (= c -2) (edright kloop u l r d)
                (= c -3) (edbsp   kedit u l r d)
                (= c -4) (eddel   kedit u l r d)
                (= c -5) (edhome  kloop u l r d)
                (= c -6) (edend   kloop u l r d)
                (= c -8) (? (twop u) (edup    kloop u l r d)
                            (uphist   khist u l r d hu hd cur))
                (= c -9) (? (twop d) (eddown  kloop u l r d)
                            (downhist khist u l r d hu hd cur))
                (= c -10) (edtop kloop u l r d)
                (= c -11) (edbot kloop u l r d)
                (loop npra u l r d hu hd cur)))
        (loop 0 0 0 0 0 hu hd 0))

   ; the outer (: ...) has no trailing body expression: every binding
   ; defined inside it becomes a global, which lets t/repl.g drive the
   ; editor and parser directly. the host and kernel frontends call
   ; (repl 0 0) explicitly to start the loop.
   (repl hu hd)
     (: r (edline hu hd)
        (? (= r eofsym) 0
           (: vs  (car r)
              nhu (car (cdr r))
              nhd (cdr (cdr r))
              _ (each vs (\ v (: _ (. (ev 'ev v)) (putc 10))))
              (repl nhu nhd)))))
