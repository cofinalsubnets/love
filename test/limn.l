; --- test/limn.l: the laws of apps/berth/limn.l, the cell painter ---
; `glass` is cb's nif (love/quay/nif.c) and love0 links it too, so these
; are corpus laws. `borrow` finds apps/berth/limn.l by the filesystem walk, which the
; hosted seats have; a seat without one will want a guard here.
;
;   cat test/00-init.l test/limn.l | out/love   ; exits 1 on fail
;
; the vocabulary under test: a grid of cb cells in, escapes out. origins are
; 0-based going in and 1-based on the wire, which is the one conversion here.
(borrow "apps/berth/limn.l")

; `sub?` is each gate's own here (test/host/berth.l carries the same three lines) --
; it searches from i; `at?` is the exact-position twin, which is what counting wants
(: (at? h n i) (((i + #n) <= #h) && n = snip h i (i + #n))
   (sub? h n i) (? ((i + #n) < (#h + 1))
                   (? (at? h n i) 1 (sub? h n (i + 1)))
                   0)
   (mkscr r c) (screen (cask (screen () r c)) r c)
   (paint s r c row0 col0)                     ; limn one whole grid into a jug
    (: j (jug 0) _ (limn-rows j s r c row0 col0 0 -1) (slurp j))

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

; --- the pen: a face byte and two colour words (love/quay/quay.h) as one number, and
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

; --- through a screen: truecolour and a codepoint the cp437 page lacks both come
;     back out as they went in ---
   _ (: s (mkscr 1 4)
        _ (scribe s "\e[1;38;2;1;2;3m\u{4e16}")   ; bold, rgb 1 2 3, and 世
        f (paint s 1 4 0 0)
        _ (test
           (sub? f "\e[0;1;38;2;1;2;3;49m" 0)
           (sub? f "\u{4e16}" 0)))

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
;     stale glyph can survive underneath it (apps/berth/limn.l's no-erase bargain) ---
   _ (: s (mkscr 1 4)
        _ (scribe s "z")
        f (paint s 1 4 0 0)
        _ (test (sub? f "z   " 0)))

; --- the pen carry: limn-rows answers the pen it ended on, and a run of cells
;     wearing one pen says its SGR once ---
   _ (: s (mkscr 1 6)
        _ (scribe s "aaaaaa")
        j (jug 0)
        p (limn-rows j s 1 6 0 0 0 -1)
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

; --- an empty bar list paints nothing, and a zero-row pane paints nothing ---
   _ (: j (jug 0) _ (limn-bars j ()) (test ("" = slurp j)))
   _ (: s (mkscr 1 4) (test ("" = paint s 0 4 0 0)))

   _ (test_fin ())
   _ (puts "limn: ok") _ (putc 10))
