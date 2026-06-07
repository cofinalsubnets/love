; tests for the multi-line line editor and its supporting helpers
; from g/repl.g. each editor primitive (edleft, edright, edbsp, ...)
; takes a continuation k and forwards a new (u l r d) to it; we test
; by passing a collector that packs the four arguments into a list.
; history navigation (uphist, downhist) extends this to seven arguments.
; numeric values stand in for character codes; the editor doesn't
; interpret them, only the parser does.

(: (k4 u l r d) (X u (X l (X r d)))
   (k7 u l r d hu hd cur) (X u (X l (X r (X d (X hu (X hd cur))))))

   (assert
     ; --- edleft: cursor moves left within the line ---
     (= (k4 0 '(1) '(2 3) 0)
        (edleft k4 0 '(2 1) '(3) 0))
     ; edleft at column 0 of a non-top line wraps to end of previous line
     (= (k4 0 '(2 1) 0 (X '(3) 0))
        (edleft k4 (X '(1 2) 0) 0 '(3) 0))
     ; edleft at start of buffer is a no-op
     (= (k4 0 0 '(1 2) 0)
        (edleft k4 0 0 '(1 2) 0))

     ; --- edright: cursor moves right within the line ---
     (= (k4 0 '(1) '(2 3) 0)
        (edright k4 0 0 '(1 2 3) 0))
     ; edright at end of a non-bottom line wraps to start of next
     (= (k4 (X '(1 2) 0) 0 '(3 4) 0)
        (edright k4 0 '(2 1) 0 (X '(3 4) 0)))
     ; edright at end of buffer is a no-op
     (= (k4 0 '(2 1) 0 0)
        (edright k4 0 '(2 1) 0 0))

     ; --- edbsp: delete the char left of the cursor ---
     (= (k4 0 '(1) '(3) 0)
        (edbsp k4 0 '(2 1) '(3) 0))
     ; edbsp at column 0 merges the current line onto the previous
     (= (k4 0 '(2 1) '(3) 0)
        (edbsp k4 (X '(1 2) 0) 0 '(3) 0))
     ; edbsp at start of buffer is a no-op
     (= (k4 0 0 '(1) 0)
        (edbsp k4 0 0 '(1) 0))

     ; --- eddel: delete the char right of the cursor ---
     (= (k4 0 '(1) '(3) 0)
        (eddel k4 0 '(1) '(2 3) 0))
     ; eddel at end of line splices the next line onto the current
     (= (k4 0 '(1) '(2 3) 0)
        (eddel k4 0 '(1) 0 (X '(2 3) 0)))
     ; eddel at end of buffer is a no-op
     (= (k4 0 '(1) 0 0)
        (eddel k4 0 '(1) 0 0))

     ; --- edhome / edend: cursor to start / end of current line ---
     (= (k4 0 0 '(1 2 3) 0)
        (edhome k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(3 2 1) 0 0)
        (edend k4 0 '(2 1) '(3) 0))

     ; --- edtop / edbot: cursor to start / end of whole buffer ---
     ; single-line buffer: edtop reduces to edhome, edbot to edend
     (= (k4 0 0 '(1 2 3) 0)
        (edtop k4 0 '(2 1) '(3) 0))
     (= (k4 0 '(3 2 1) 0 0)
        (edbot k4 0 '(2 1) '(3) 0))
     ; three-line buffer "1" / "2" / "3", cursor on bottom line:
     ; u = [(2) (1)] (closest first); l = (3); after edtop the cursor
     ; lands at the start of "1" and the rest of the buffer drops below.
     (= (k4 0 0 '(1) (X '(2) (X '(3) 0)))
        (edtop k4 (X '(2) (X '(1) 0)) '(3) 0 0))
     ; mirror: cursor on top of "1" / "2" / "3", edbot lands at end of "3"
     (= (k4 (X '(2) (X '(1) 0)) '(3) 0 0)
        (edbot k4 0 '(1) 0 (X '(2) (X '(3) 0))))
     ; mid-line cursor: the current line gets reassembled and dropped
     ; into d at its document position. doc: top "1", mid "89" (cursor
     ; between 8 and 9), bot "4". after edtop: cursor at start of "1",
     ; d holds the reassembled "89" then "4".
     (= (k4 0 0 '(1) (X '(8 9) (X '(4) 0)))
        (edtop k4 (X '(1) 0) '(8) '(9) (X '(4) 0)))

     ; --- edup: preserve column on the line above ---
     ; cursor at column 1 of line "xy", previous line "abcd" (chars 1..4):
     ; after edup, cursor at column 1 of "abcd" and "xy" becomes a d entry.
     (= (k4 0 '(1) '(2 3 4) (X '(5 6) 0))
        (edup k4 (X '(1 2 3 4) 0) '(5) '(6) 0))
     ; column beyond destination length clamps to end of destination line:
     ; cursor was at column 2 of "3456"; the line above is "12" (2 chars)
     ; so l becomes (2 1) -- the whole line reversed, cursor at end
     (= (k4 0 '(2 1) 0 (X '(3 4 5 6) 0))
        (edup k4 (X '(1 2) 0) '(4 3) '(5 6) 0))
     ; edup with no line above is a no-op
     (= (k4 0 '(1) '(2) 0)
        (edup k4 0 '(1) '(2) 0))

     ; --- eddown: preserve column on the line below ---
     (= (k4 (X '(5 6) 0) '(1) '(2 3 4) 0)
        (eddown k4 0 '(5) '(6) (X '(1 2 3 4) 0)))
     ; eddown with no line below is a no-op
     (= (k4 0 '(1) '(2) 0)
        (eddown k4 0 '(1) '(2) 0))

     ; --- joinln: charlists -> charlist with \n separators ---
     (= 0 (joinln 0))
     (= '(1 2 3) (joinln (X '(1 2 3) 0)))
     (= '(1 10 2) (joinln (X '(1) (X '(2) 0))))
     (= '(1 2 10 3 10 4 5) (joinln (X '(1 2) (X '(3) (X '(4 5) 0)))))

     ; --- flatten: editor state -> single charlist ---
     ; a single line "123" with cursor between 2 and 3
     (= '(1 2 3) (flatten 0 '(2 1) '(3) 0))
     ; two lines: top "1" then current "2" -- separated by \n
     (= '(1 10 2) (flatten (X '(1) 0) '(2) 0 0))
     ; three lines: top, middle (with cursor), bottom
     (= '(1 10 2 10 3) (flatten (X '(1) 0) '(2) 0 (X '(3) 0)))

     ; --- splitat: take n chars into acc (reversed), call k with (acc rest) ---
     (= (X '(2 1) '(3 4)) (splitat X 0 2 '(1 2 3 4)))
     ; stops cleanly at end-of-input even if n exceeds list length
     (= (X '(2 1) 0)      (splitat X 0 5 '(1 2)))
     ; n=0 takes nothing
     (= (X 0 '(1 2 3))    (splitat X 0 0 '(1 2 3)))

     ; --- mkframe: pack a buffer slot ---
     (= (X 0 (X '(1) (X 0 0))) (mkframe 0 '(1) 0 0))
     (= (X (X '(1) 0) (X '(2 3) (X '(4) (X '(5) 0))))
        (mkframe (X '(1) 0) '(2 3) '(4) (X '(5) 0)))

     ; --- detach: restore a pristine recall (a frame) to hu ---
     (= 0 (detach 0 0))                      ; cur=0: no change
     (: cur (mkframe 0 '(1) 0 0)
        (= (X cur 0) (detach 0 cur)))        ; cur a frame: prepend to hu
     (: cur (mkframe 0 '(1) 0 0)
        old (mkframe 0 '(9) 0 0)
        (= (X cur (X old 0)) (detach (X old 0) cur)))

     ; --- emptybuf: true iff all four halves are nil ---
     (emptybuf 0 0 0 0)
     (~ (emptybuf 0 '(1) 0 0))
     (~ (emptybuf (X '(1) 0) 0 0 0))
     (~ (emptybuf 0 0 '(1) 0))
     (~ (emptybuf 0 0 0 (X '(1) 0)))

     ; --- parses: true iff parseall yields at least one value ---
     ; "1" (charlist [49]) parses to the integer 1
     (parses 0 (X 49 0) 0 0)
     ; empty buffer doesn't parse to a value
     (~ (parses 0 0 0 0))
     ; "(" (unclosed list) returns m -- not twop
     (~ (parses 0 (X 40 0) 0 0))
     ; multi-line "(\n)" -- u=["("], current line ")"
     (parses (X (X 40 0) 0) (X 41 0) 0 0)

     ; --- uphist: pop the next older entry into the buffer ---
     ; non-empty hu with non-empty buffer: push current to hd, pop hu
     (: cur (mkframe 0 '(1) 0 0)
        old (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 (X cur 0) old)
           (uphist k7 0 '(1) 0 0 (X old 0) 0 cur)))
     ; empty buffer skips the push onto hd
     (: old (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 0 old)
           (uphist k7 0 0 0 0 (X old 0) 0 0)))
     ; off-top: hu empty, cur non-nil, buffer parses -> push, scroll into blank
     (: cur (mkframe 0 (X 49 0) 0 0)
        (= (k7 0 0 0 0 0 (X cur 0) 0)
           (uphist k7 0 (X 49 0) 0 0 0 0 cur)))
     ; off-top blocked when buffer doesn't parse (unclosed list)
     (: cur (mkframe 0 (X 40 0) 0 0)
        (= (k7 0 (X 40 0) 0 0 0 0 cur)
           (uphist k7 0 (X 40 0) 0 0 0 0 cur)))
     ; off-top blocked when not on a real recall (cur=0)
     (= (k7 0 (X 49 0) 0 0 0 0 0)
        (uphist k7 0 (X 49 0) 0 0 0 0 0))

     ; --- downhist: mirror of uphist on the hd side ---
     (: cur (mkframe 0 '(1) 0 0)
        new (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 (X cur 0) 0 new)
           (downhist k7 0 '(1) 0 0 0 (X new 0) cur)))
     (: new (mkframe 0 '(9) 0 0)
        (= (k7 0 '(9) 0 0 0 0 new)
           (downhist k7 0 0 0 0 0 (X new 0) 0)))
     (: cur (mkframe 0 (X 49 0) 0 0)
        (= (k7 0 0 0 0 (X cur 0) 0 0)
           (downhist k7 0 (X 49 0) 0 0 0 0 cur)))

     ; --- parseall: integration check ---
     ; "1 2 3" parses to (1 2 3)
     (= '(1 2 3) (parseall '(49 32 50 32 51)))
     ; "(1 2)" parses to ((1 2))
     (= '((1 2)) (parseall '(40 49 32 50 41)))
     ; trailing whitespace OK, empty yields 0
     (= 0 (parseall 0))
     ; unclosed list yields m -- we can detect via twop being false
     (~ (twop (parseall '(40 49))))

     ; --- floats: parse and round-trip via the gwen reader ---
     ; "1.5" parses to (1.5); the value is an actual flo, not a symbol
     (= 1.5 (A (parseall '(49 46 53))))
     ; "1e3" parses as float, not symbol
     (= 1000.0 (A (parseall '(49 101 51))))
     ; "1.2.3" stays a symbol (g_strtod partial-consume)
     (symp (A (parseall '(49 46 50 46 51))))))
