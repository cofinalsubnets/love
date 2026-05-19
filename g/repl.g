; the read-eval-print loop and its multi-line line editor. loaded
; after boot.g by the interactive frontends (host and kernel). the
; buffer is a four-zipper threaded positionally through the editor
; functions: u (lines above the cursor, reversed), l (chars left of
; the cursor on the current line, reversed), r (chars at/after the
; cursor on the current line, in order), d (lines below). state is
; passed and returned through helpers in continuation-passing style,
; so no table is allocated per keystroke. on each tick the whole
; multi-line input is redrawn from the cursor position saved by
; DECSC at the start of edit, then the cursor is positioned with
; relative escapes.
(: (revappend a b) (foldl b (flip cons) a)
   (append a b) (revappend (rev a) b)

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
     (? (twop ls)
        (? (twop (cdr ls))
           (append (car ls) (cons 10 (joinln (cdr ls))))
           (car ls))
        0)

   ; flatten the editor state into one charlist suitable for parse
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
   (edup k u l r d)
     (? (twop u) (splitat (\ ll rr (k (cdr u) ll rr (cons (revappend l r) d)))
                          0 (len l) (car u))
        (k u l r d))
   (eddown k u l r d)
     (? (twop d) (splitat (\ ll rr (k (cons (revappend l r) u) ll rr (cdr d)))
                          0 (len l) (car d))
        (k u l r d))

   ; map a raw byte (or escape sequence) to an event code:
   ; printable >0; -1 left, -2 right, -3 bsp, -4 del, -5 home,
   ; -6 end, -7 quit, -8 up, -9 down; 10 = enter.
   (edesc x) (? (!= 91 (getc 0)) 0
     (: c (getc 0)
        (? (= c 68) -1 (= c 67) -2
           (= c 65) -8 (= c 66) -9
           (= c 72) -5 (= c 70) -6
           (|| (= c 49) (= c 55)) (: _ (getc 0) -5)
           (|| (= c 52) (= c 56)) (: _ (getc 0) -6)
           (= c 51) (: _ (getc 0) -4) 0)))
   (edev x) (: c (getc 0)
     (? (|| (= c -1) (= c 4)) -7
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5 (= c 5) -6 (= c 27) (edesc 0)
        (? (&& (<= 32 c) (< c 127)) c 0)))

   ; redraw from the saved cursor (DECRC), clearing everything below
   ; first. pl is the prompt's column at DECSC time; the topmost
   ; input line shares it, subsequent lines start at column 0.
   ; cursor is positioned by counting rows-from-bottom (len d) and
   ; target column.
   (edrender pl u l r d)
     (: _ (putc 27) _ (putc 56)             ; DECRC
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

   ; print the prompt, save the cursor (DECSC), dispatch events
   ; until ^D or until enter at end-of-buffer with parse OK. enter
   ; always splits the current line at the cursor; only when the
   ; cursor was at the end of the whole buffer do we try parse and
   ; possibly submit. e/m are the empty and more sentinels passed
   ; to parse; eofsym is returned on ^D so the repl can distinguish
   ; that from a parsed datum that happens to equal 0.
   (edline e m eofsym)
     (: pl 4
        _ (puts " ;; ") _ (putc 27) _ (putc 55)
        (loop u l r d)
          (: _ (edrender pl u l r d)
             c (edev 0)
             (? (= c -7) eofsym
                (= c 10) (: nu (cons (rev l) u)
                            (? (&& (nilp r) (nilp d))
                               (: res (parse (flatten nu 0 r d) e m)
                                  (? (= res m) (loop nu 0 r d) res))
                               (loop nu 0 r d)))
                (< 0 c)  (loop u (cons c l) r d)
                (= c -1) (edleft  loop u l r d)
                (= c -2) (edright loop u l r d)
                (= c -3) (edbsp   loop u l r d)
                (= c -4) (eddel   loop u l r d)
                (= c -5) (edhome  loop u l r d)
                (= c -6) (edend   loop u l r d)
                (= c -8) (edup    loop u l r d)
                (= c -9) (eddown  loop u l r d)
                (loop u l r d)))
        (loop 0 0 0 0))

   e (sym 0) m (sym 0) eofsym (sym 0)
   (repl x)
     (: r (edline e m eofsym)
        (? (= r eofsym) 0
           (: _ (? (= r e) 0 (: _ (. (ev 'ev r)) (putc 10)))
               (repl 0))))
   (repl 0))
