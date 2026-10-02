; --- test/limn.l: the laws of src/apps/mitty/limn.l, the cell painter ---
; `glass` is cb's nif (src/love/quay/nif.c) and love0 links it too, so these
; are corpus laws. `borrow` finds src/apps/mitty/limn.l by the filesystem walk, which the
; hosted seats have; a seat without one will want a guard here.
;
;   cat test/00-init.l test/limn.l | out/love   ; exits 1 on fail
;
; the vocabulary under test: a grid of cb cells in, escapes out. origins are
; 0-based going in and 1-based on the wire, which is the one conversion here.
(borrow "src/apps/mitty/limn.l")

; `sub?` is each gate's own here (test/host/mitty.l carries the same three lines) --
; it searches from i; `at?` is the exact-position twin, which is what counting wants
(: (at? h n i) (((i + #n) <= #h) && n = snip h i (i + #n))
   (sub? h n i) (? ((i + #n) < (#h + 1))
                   (at? h n i ? 1 (sub? h n (i + 1)))
                   0)
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (paint s r c row0 col0)                     ; limn one whole grid into a jug
    (jug 0 @ j (limn-rows j s r c row0 col0 0 -1 0, slurp j))

; --- the address: 0-based in, 1-based out, row then col ---
   _ (test
      ("\e[1;1H" = limn-go 0 0)
      ("\e[3;12H" = limn-go 2 11)
      ("\e[25;80H" = limn-go 24 79))

; --- a codepoint out as utf-8, each spelled once and cached, so asking twice answers
;     the same text; the blank is a space ---
   _ (test
      ("x" = limn-glyph 120)
      (" " = limn-glyph 0)
      (2 = #(limn-glyph 233))                        ; é
      (3 = #(limn-glyph 9474))                       ; │ the box glyph
      (4 = #(limn-glyph 128512))                     ; past the bmp: the cell holds it whole
      (limn-down = limn-glyph 9474)                  ; the two spellings of one line
      (limn-across = utf8 9472)
      (limn-glyph 201 = limn-glyph 201))              ; cached, and equal to itself

; --- the pen: a face byte and two colour words (src/love/quay/quay.h) as one number, and
;     one SGR per change, respecified from zero so it is never stale. a colour word's
;     top byte is its kind: 0 the outer terminal's default, 1 an index, 2 rgb ---
   _ (: (idx v) ((1 << 24) | v) (rgb v) ((2 << 24) | v)
        _ (test
           ("\e[0;39;49m" = limn-sgr (limn-pen 0 0 0))
           ("\e[0;38;5;1;48;5;4m" = limn-sgr (limn-pen 0 (idx 1) (idx 4)))
           ("\e[0;38;2;255;128;0;49m" = limn-sgr (limn-pen 0 (rgb 16744448) 0))
           ; the faces ride the glyph word's top byte: bold 1, under 2, reverse 4, dim 8,
           ; italic 16, strike 32, blink 64, hidden 128
           (sub? (limn-sgr (limn-pen (1 << 24) 0 0)) ";1" 0)
           (sub? (limn-sgr (limn-pen (2 << 24) 0 0)) ";4" 0)
           (sub? (limn-sgr (limn-pen (4 << 24) 0 0)) ";7" 0)
           (sub? (limn-sgr (limn-pen (16 << 24) 0 0)) ";3" 0)
           (sub? (limn-sgr (limn-pen (32 << 24) 0 0)) ";9" 0)))

; --- limned says a run of cells as limn-sgr and limn-glyph would, one SGR per pen
;     change, nothing for a wide char's tail, and answers the cells done and the pen ---
   _ (: s (mkscr 1 8)
        _ (scribe s "\e[1;3;7;9;38;5;200;48;2;9;8;7mA\e[0;2;4;5;8mB\e[m\u{4e16}c")
        r (limned s 0 8 -1 0 0)
        (pen k) (limn-pen (glass s k 0) (glass s k 1) (glass s k 2))
        _ (test
           ((limn-sgr (pen 0) + "A" + limn-sgr (pen 1) + "B" + limn-sgr (pen 2) + limn-glyph 19990
             + "c   ") = <r)
           ([8 0 0 0] = >r)))

; --- through a screen: truecolour and a codepoint the cp437 page lacks both come
;     back out as they went in ---
   _ (: s (mkscr 1 4)
        _ (scribe s "\e[1;38;2;1;2;3m\u{4e16}")   ; bold, rgb 1 2 3, and 世
        f (paint s 1 4 0 0)
        _ (test
           (sub? f "\e[0;1;38;2;1;2;3;49m" 0)
           (sub? f "\u{4e16}" 0)))

; --- a wide char's tail says nothing: the outer terminal steps two columns for the lead,
;     so the cell after it lands where the grid has it ---
   _ (: s (mkscr 1 4)
        _ (scribe s "\u{4e16}a")
        f (paint s 1 4 0 0)
        _ (test (sub? f "\u{4e16}a " 0)))

; --- a picture's tile is one ▀: its top half's mean colour over its bottom half's, each
;     from the pixels the picture set; a bare half is the cell's own bg ---
   _ (: s (mkscr 3 4)                               ; room for its two tile rows and the line under
        _ (scribe s "\ePq#0;2;100;0;0!8~-!8~-!8~\e\\")    ; solid red, 8x18: one tile and a sliver
        f (paint s 3 4 0 0)
        _ (test (sub? f "\e[0;38;2;255;0;0;48;2;255;0;0m\u{2580}" 0)))
   _ (: s (mkscr 2 4)                               ; two rows: the line under a picture
        _ (scribe s "\ePq#0;2;0;0;100!8~\e\\")             ; blue, one band: the top half only
        f (paint s 2 4 0 0)
        _ (test (sub? f "\e[0;38;2;0;0;255;49m\u{2580}" 0)))

; --- the law that matters: every row is addressed at its own origin, which is
;     the whole difference between painting a rectangle and painting full lines ---
   _ (: s (mkscr 3 4)
        _ (scribe s "ab")
        f (paint s 3 4 5 9)
        _ (test
           (sub? f "\e[6;10H" 0)                      ; row 0 of the grid at (5,9)
           (sub? f "\e[7;10H" 0)                      ; row 1 at the same column
           (sub? f "\e[8;10H" 0)                      ; row 2
           (sub? f "ab" 0)                            ; and the glyphs came through
           !(sub? f "\e[1;1H" 0)))                    ; never the home cell

; --- a blank cell is a space, so a pane always writes every cell it owns and no
;     stale glyph can survive underneath it (src/apps/mitty/limn.l's no-erase bargain) ---
   _ (: s (mkscr 1 4)
        _ (scribe s "z")
        f (paint s 1 4 0 0)
        _ (test (sub? f "z   " 0)))

; --- the pen carry: limn-rows answers the pen it ended on, and a run of cells
;     wearing one pen says its SGR once ---
   _ (: s (mkscr 1 6)
        _ (scribe s "aaaaaa")
        j (jug 0)
        p (limn-rows j s 1 6 0 0 0 -1 0)
        f (slurp j)
        (cnt t sb i n) (? (#t <= i) n
                          (at? t sb i) (cnt t sb (i + 1) (n + 1))
                          (cnt t sb (i + 1) n))
        _ (test
           (0 <= p)                                   ; a pen came back out
           (1 = cnt f "\e[0;" 0 0)))                  ; and exactly one SGR was said

; --- the bars, straight off wharf-bars' list: (dir row col len) ---
   _ (: j (jug 0)
        _ (limn-bars j '((across 4 0 3) (down 0 7 2)))
        f (slurp j)
        _ (test
           (sub? f "\e[5;1H" 0)                       ; the across bar's origin
           (sub? f (limn-across + limn-across + limn-across) 0)
           (sub? f "\e[1;8H" 0)                       ; the down bar, row by row
           (sub? f "\e[2;8H" 0)))

; --- a view looking back paints the history first, the grid below it ---
   _ (: s (mkscr 2 4)
        _ (scribe s "ab\r\ncd\r\nef")                 ; ab scrolls into the history
        home (paint s 2 4 0 0)
        _ (peer s 1)
        back (paint s 2 4 0 0)
        _ (test (sub? home "cd" 0) (sub? home "ef" 0) !(sub? home "ab" 0)
                (sub? back "ab" 0) (sub? back "cd" 0) !(sub? back "ef" 0)))

; --- a picture: a ▀ block to a plain outer terminal, bare ground under kitty's own
;     picture (limn-pics) to one that takes them -- sent once, placed each time ---
   _ (: s (mkscr 2 6)
        _ (scribe s ("\e_Ga=T,f=24,s=10,v=12,q=2;" + cats (map (_ \ "/wAA") (jot 120)) + "\e\\"))
        blocks (paint s 2 6 0 0)
        j (jug 0)
        _ (limn-rows j s 2 6 0 0 0 -1 1)
        bare (slurp j)
        sent {}
        k (jug 0) _ (limn-pics k s 2 6 3 4 1 sent) one (slurp k)
        k2 (jug 0) _ (limn-pics k2 s 2 6 3 4 1 sent) two (slurp k2)
        _ (test (sub? blocks (utf8 9600) 0) !(sub? bare (utf8 9600) 0)
                (sub? one "\e_Ga=t,f=32,s=10,v=12,i=1048577,q=2,m=0;" 0)   ; pane 1, gen 1
                (sub? one "\e[4;5H\e_Ga=p,i=1048577,p=1,q=2,C=1,x=0,y=0,w=10,h=12,c=2,r=1\e\\" 0)
                !(sub? two "a=t" 0) (sub? two "a=p,i=1048577" 0)))

; --- sixels: a picture's part in the cube's registers (greys past them), a band six
;     pixels high, a run as !n, a pixel the picture left as '?', scaled nearest ---
   _ (: (px r g b a) (cats [(string r) (string g) (string b) (string a)])
        red (px 255 0 0 255) blue (px 0 0 255 255) clear (px 0 0 0 0)
        six "\eP0;0;0q\"1;1;"
        _ (test ((six + "2;2#180;2;100;0;0BB$-\e\\") = limn-sixel (cats [red red red red]) 2 0 0 2 2 2 2)
                ((six + "4;4#180;2;100;0;0!4N$-\e\\") = limn-sixel (cats [red red red red]) 2 0 0 2 2 4 4)
                ((six + "2;1#180;2;100;0;0?@$-\e\\") = limn-sixel (cats [clear red]) 2 0 0 2 1 2 1)
                ((six + "1;2#5;2;0;0;100A$#180;2;100;0;0@$-\e\\") = limn-sixel (cats [red blue]) 1 0 0 1 2 1 2)
                ((six + "1;7#180;2;100;0;0~$-#180@$-\e\\") = limn-sixel (cats (map (_ \ red) (jot 7))) 1 0 0 1 7 1 7)
                ((six + "1;1#228;2;52;52;52@$-\e\\") = limn-sixel (px 128 128 128 255) 1 0 0 1 1 1 1)
                ((six + "1;1#216;2;0;0;0@$-\e\\") = limn-sixel (cats [red (px 0 0 0 255)]) 2 1 0 1 1 1 1)))

; --- ..and in a pane: its tiles stepped over, each picture's part laid at its top-left
;     tile, the same part laid again from what was laid, and the cells it took erased ---
   _ (: s (mkscr 2 6)
        _ (scribe s ("\e_Ga=T,f=24,s=10,v=12,q=2;" + cats (map (_ \ "/wAA") (jot 120)) + "\e\\"))
        ps (limn-placed s 2 6)
        j (jug 0) _ (limn-rows j s 2 6 0 0 0 -1 2) stepped (slurp j)
        laid {} k (jug 0) _ (limn-sixes k s ps 3 4 (gaze s 6) (gaze s 7) {} laid) one (slurp k)
        laid2 {} k2 (jug 0) _ (limn-sixes k2 s ps 3 4 (gaze s 6) (gaze s 7) laid laid2) two (slurp k2)
        u (jug 0) _ (limn-unsix u ps 3 4) gone (slurp u)
        _ (test (1 = tally ps) ([0 0 0 0 10 12 2 1] = drop 2 <ps)
                (sub? stepped "\e[C\e[C" 0) !(sub? stepped (utf8 9600) 0)
                (sub? one "\e[4;5H\eP0;0;0q\"1;1;10;12#180;2;100;0;0" 0)
                (one = two) (1 = tally (keys laid2))
                (gone = "\e[4;5H\e[2X")))

; --- a lead VS16 or a ZWJ sequence widened (?2027): its two cells erased, and the cursor
;     stepped two past it whatever width the outer terminal draws it ---
   _ (: s (mkscr 1 10)
        fam "\u{1f468}\u{200d}\u{1f469}\u{200d}\u{1f467}"
        _ (scribe s ("\e[?2027h\u{2764}\u{fe0f}x\u{4e16}" + fam + "y"))
        f (paint s 1 10 0 0)
        _ (test (sub? f "\e[2X\e7\u{2764}\u{fe0f}\e8\e[2Cx" 0)
                (sub? f "x\u{4e16}" 0)                    ; a plain wide char as before
                (sub? f ("\e[2X\e7" + fam + "\e8\e[2Cy") 0)))

; --- a selected cell wears the reverse face ---
   _ (: s (mkscr 1 4)
        _ (scribe s "abcd")
        plain (paint s 1 4 0 0)
        _ (select s 1 2 0)
        chosen (paint s 1 4 0 0)
        _ (test !(sub? plain ";7;" 0) (sub? chosen ";7;" 0)))

; --- an empty bar list paints nothing, and a zero-row pane paints nothing ---
   _ (jug 0 @ j (limn-bars j (), (test ("" = slurp j))))
   _ (mkscr 1 4 @ s (test ("" = paint s 0 4 0 0)))

   _ (test_fin ()))
