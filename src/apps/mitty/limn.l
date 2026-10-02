; src/apps/mitty/limn.l -- to limn is to paint: cb cells onto an outer terminal, as escapes.
; the third piece of the pane story and the one every seat needs -- cb says what is
; in a grid (bytes in, cells out), src/apps/mitty/wharf.l says where the rectangle is, and this
; says a grid's cells at an origin. cells are the currency all three speak.
; a module: `(borrow 'limn)` on the artifact, `(borrow "src/apps/mitty/limn.l")` off the tree.
;
; it takes a grid and an origin, never a plan and never a harbour: the bars come in as
; wharf-bars' list, so nothing here knows what a berth or a buffer is, and one painter
; serves panes of ptys and splits of one process alike.
;
; nothing is erased, and nothing needs to be -- a caller whose panes and bars tile its
; wharf (src/apps/mitty/wharf.l's standing law) writes every cell every frame, so no stale glyph
; can survive a layout change. a caller that leaves gaps owns them.
;
; host-only: `glass` is cb's nif (src/love/quay/nif.c), so this never joins the corpus --
; test/limn.l is its gate.
(module '(limn limn-across limn-bars limn-down limn-glyph limn-glyphs limn-go limn-half limn-ink
          limn-pen limn-pics limn-placed limn-row limn-rows limn-run limn-sgr limn-sixel limn-sixes
          limn-spans limn-tile limn-unsix)
(:
   ; --- the pen: a cell's face byte and its two colour words (src/love/quay/quay.h), as one
   ; number -- face | fg << 8 | bg << 34, a colour word being 26 bits. one SGR per pen
   ; change, respecified from zero each time -- cheap, and never stale ----------
   (limn-pen g fg bg) (g >> 24 | fg << 8 | bg << 34)
   ; a colour word's SGR, base 38 for the fg and 48 for the bg: the outer terminal's own
   ; default, an xterm-256 index, or rgb
   (limn-ink base k) (k & 16777215 @ v
                        ((k >> 24) @- (show (base + 1))
                         1 (show base + ";5;" + show v)
                         2 (show base + ";2;" + show (v >> 16) + ";" + show (v >> 8 & 255)
                            + ";" + show (v & 255))))
   (limn-sgr p) (p & 255 @ fa
                 ("\e[0" + (fa & 1 ? ";1" "") + (fa & 8 ? ";2" "") + (fa & 16 ? ";3" "")
                  + (fa & 2 ? ";4" "") + (fa & 64 ? ";5" "") + (fa & 4 ? ";7" "")
                  + (fa & 128 ? ";8" "") + (fa & 32 ? ";9" "")
                  + ";" + limn-ink 38 (p >> 8 & 67108863) + ";" + limn-ink 48 (p >> 34) + "m"))

   ; the grid holds codepoints and the outer terminal speaks utf-8: each rendered once
   ; and cached. the blank is a space
   limn-glyphs {}
   (limn-glyph cp) (limn-glyphs cp @ g
                      (string? g ? g
                       ((cp = 0 ? " " (utf8 cp)) @ s
                          (pin limn-glyphs cp s, s))))

   (limn-go row col) ("\e[" + show (row + 1) + ";" + show (col + 1) + "H")
   limn-down (utf8 9474)                      ; │
   limn-across (utf8 9472)                    ; ─

   ; a picture's tile as one ▀: its top half's colour over its bottom half's, each the mean
   ; of the pixels the picture set there; a half with none is the cell's own bg. its SGR is
   ; its own, so the pen after it is none (-1) and the next cell says its own
   (limn-half s k y0 y1 w)
    (: (px x y) (tilepx s k x y)
       (sum x y a) (? (y1 <= y) a (w <= x) (sum 0 (y + 1) a)
                      (px x y @ v (sum (x + 1) y (v >> 24 ? [(<a + (v >> 16 & 255)) (<>a + (v >> 8 & 255))
                                                           (<>>a + (v & 255)) (a 3 + 1)] a))))
       t (sum 0 y0 [0 0 0 0])
       n (t 3)
       (n < 1 ? () [(<t // n) (<>t // n) (<>>t // n)]))
   (limn-tile s k)
    (: w (gaze s 6) h (gaze s 7)
       top (limn-half s k 0 (h // 2) w)
       bot (limn-half s k (h // 2) h w)
       (rgb c) (show <c + ";" + show <>c + ";" + show <>>c)
       bg (limn-ink 48 (glass s k 2))
       ; ▀ a top over what is under it, ▄ a bottom alone, a space for a tile the picture left bare
       (? (two? top) ("\e[0;38;2;" + rgb top + ";" + (two? bot ? ("48;2;" + rgb bot) bg) + "m" + utf8 9600)
          (two? bot) ("\e[0;38;2;" + rgb bot + ";" + bg + "m" + utf8 9604)
          ("\e[0;" + bg + "m ")))

   ; ..or, where the outer terminal takes the pictures themselves (limn-pics), the cell's
   ; ground for one to lie over
   (limn-bare s k) ("\e[0;" + limn-ink 48 (glass s k 2) + "m ")

   ; paint row i from column q, threading the pen. the cells go out through limned
   ; (src/love/quay/nif.c): a pen change as limn-sgr says it, a glyph and the rest of its
   ; cluster, a selected cell in reverse, nothing for a wide char's tail, and a wide lead
   ; with more to it (VS16, a ZWJ sequence, a mark) erased first and stepped past after,
   ; since an outer terminal may draw it one column or several. it stops at a tile: a ▀
   ; here (pk 0), bare ground for kitty's picture (1), or stepped over, a sixel's pixels
   ; being in the text layer (2)
   (limn-row j s c i q p pk)
    (q < c ?
       (([b t f fg bg] \
         (say j b,
          (q + t < c ?
             ((i * c + q + t) @ k
                (say j (pk @- (limn-tile s k) 1 (limn-bare s k) 2 "\e[C"),
                 limn-row j s c i (q + t + 1) -1 pk))
             (f < 0 ? -1 (f | fg << 8 | bg << 34)))))
        (limned s (i * c + q) (c - q) (p < 0 ? -1 (p & 255)) (p < 0 ? 0 (p >> 8 & 67108863))
                (p < 0 ? 0 (p >> 34))))
       p)

   ; one pane: every grid row addressed at its own origin, which is the whole
   ; difference between painting a rectangle and painting a run of full lines.
   ; p is the pen carried in and answered back, so a caller threads it across panes.
   ; a view looking v lines back shows the history first: row i is grid row i - v
   (limn-rows j s r c row0 col0 i p pk)
    (i < r ?
       (say j (limn-go (row0 + i) col0),
        limn-rows j s r c row0 col0 (i + 1) (limn-row j s c (i - gaze s 8) 0 p pk) pk)
       p)

   ; --- the pictures themselves, to an outer terminal that speaks kitty's graphics: each
   ;     sent once, by an id made of the pane's number ib and the picture's gen (sent keeps
   ;     which went), then placed over its tiles -- the part of it they show, clipped to the
   ;     pane, stretched over the cells they fill. the caller clears the old placements
   ;     first (a=d), so a picture that scrolled away is simply not placed again ---
   ; slot -> [row col tx ty last-row last-col]: its top-left visible tile, where in the
   ; picture that is, and how far its tiles run
   (limn-spans s r c)
    (: t {} v (gaze s 8)
       (cell i q) (glass s ((i - v) * c + q) 0 @ g
                     ((g >> 23 & 1) = 1 ?
                        (: sl (g >> 16 & 127) e (peep t sl ())
                           (pin t sl (two? e ? [<e <>e (e 2) (e 3) (max (e 4) i) (max (e 5) q)]
                                        [i q (g >> 8 & 255) (g & 255) i q])))
                        0))
       (row i) (i < r ? (map (q \ cell i q) (jot c), row (i + 1)) 0)
       (row 0,
        t))
   ; what each picture's tiles show: [slot gen row col x y pw ph nc nr], its top-left tile
   ; at row col of the pane, the part of it x y pw ph in its own pixels, over nc x nr cells
   (limn-placed s r c)
    (: cw (gaze s 6) ch (gaze s 7) t (limn-spans s r c)
       (one sl) (: e (t sl) w (picture s sl 0) h (picture s sl 1)
                   (? !(charm? w) ()
                      (: x (e 2 * cw) y (e 3 * ch)
                         nc (e 5 - e 1 + 1) nr (e 4 - <e + 1)
                         pw (min (nc * cw) (w - x)) ph (min (nr * ch) (h - y))
                         (0 < pw && 0 < ph ? [sl (picture s sl 2) <e (e 1) x y pw ph nc nr] ()))))
       (filter two? (map one (sort (keys t)))))
   (limn-send j id w h b)                           ; a=t in 4096-byte pieces, m=1 until the last
    (: n #b
       (go i) (i < n ?
                 (min n (i + 4096) @ e
                    (say j ((i = 0 ? ("\e_Ga=t,f=32,s=" + show w + ",v=" + show h + ",i=" + show id + ",q=2,") "\e_G")
                            + "m=" + (e < n ? "1" "0") + ";" + snip b i e + "\e\\"),
                     go e))
                 0)
       (go 0))
   (limn-pics j s r c row0 col0 ib sent)
    (map ([sl g row col x y pw ph nc nr] \
          (ib * 1048576 + (g & 1048575) @ id
             (peep sent id 0 ? 0
                (limn-send j id (picture s sl 0) (picture s sl 1) (picture s sl 3), pin sent id 1),
              say j (limn-go (row0 + row) (col0 + col) + "\e_Ga=p,i=" + show id + ",p=1,q=2,C=1,x=" + show x
                     + ",y=" + show y + ",w=" + show pw + ",h=" + show ph + ",c=" + show nc
                     + ",r=" + show nr + "\e\\"))))
         (limn-placed s r c))

   ; --- the pictures as sixels, for an outer terminal that draws those and not kitty's:
   ;     the text layer holds them, so a tile is stepped over (pk 2) and a picture goes out
   ;     again only when what its pane shows of it moves; the caller erases the cells the old
   ;     ones sat on (limn-unsix) first. a sixel draws at the outer terminal's pixels, so the
   ;     part shown is scaled to ow x oh a cell ---
   ; a colour's register: the 6x6x6 cube's 216, then 24 greys past them
   (limn-reg r g b) (: hi (max r (max g b)) lo (min r (min g b))
                       (hi - lo < 12 ? (216 + ((r + g + b) * 23 + 382) // 765)
                          ((r * 5 + 127) // 255 * 36 + ((g * 5 + 127) // 255 * 6 + (b * 5 + 127) // 255))))
   (limn-rgb n) (n < 216 ? (show (n // 36 * 20) + ";" + show (n // 6 % 6 * 20) + ";" + show (n % 6 * 20))
                   ((n - 216) * 100 // 23 @ v (show v + ";" + show v + ";" + show v)))
   (limn-sixrun j ch n) (? (n < 1) 0 (n < 4) (say j (cats (map (_ \ ch) (jot n)))) (say j ("!" + show n + ch)))
   ; one register's row of a band, off its [x bits] ascending: runs of one char, a gap '?'
   (limn-sixrow j l pos ch n)
    (two? l ?
       (: e <l x <e c (string (63 + <>e))
          (x = pos && c = ch ? (limn-sixrow j >l (pos + 1) ch (n + 1))
             (limn-sixrun j ch n, limn-sixrun j "?" (x - pos), limn-sixrow j >l (x + 1) c 1)))
       (limn-sixrun j ch n))
   ; the part x y pw ph of a picture w wide (b its rgba bytes) as a sixel tw x th, nearest
   ; pixel, a register defined where it is first used; a pixel the picture left is the ground
   (limn-sixel b w x y pw ph tw th)
    (: j (jug 0) def {}
       (reg tx ty) (((y + (ty * ph) // th) * w + (x + (tx * pw) // tw)) * 4 @ i
                     (b (i + 3) = 0 ? -1 (limn-reg (b i) (b (i + 1)) (b (i + 2)))))
       (col tx y0 k acc) (k = 6 || th <= y0 + k ? acc
                            (reg tx (y0 + k) @ n
                               (col tx y0 (k + 1) (n < 0 ? acc (pin acc n (peep acc n 0 | 1 << k))))))
       (band y0) ({} @ t
                    (map (tx \ (col tx y0 0 {} @ cs (map (n \ pin t n ([tx (cs n)] . peep t n ())) (keys cs))))
                         (jot tw),
                     map (n \ (say j (peep def n 0 ? ("#" + show n) (pin def n 1, "#" + show n + ";2;" + limn-rgb n)),
                               limn-sixrow j (rev (t n)) 0 "" 0,
                               say j "$"))
                         (sort (keys t)),
                     say j "-"))
       (bands y0) (y0 < th ? (band y0, bands (y0 + 6)) 0)
       (say j ("\eP0;0;0q\"1;1;" + show tw + ";" + show th),
        bands 0,
        say j "\e\\",
        slurp j))
   ; the placements ps of a pane at row0 col0 as sixels, each at ow x oh a cell; old holds
   ; the ones already laid, by what they show, and new gets the ones used
   (limn-sixes j s ps row0 col0 ow oh old new)
    (: cw (gaze s 6) ch (gaze s 7)
       (map ([sl g row col x y pw ph nc nr] \
             (: tw (max 1 (pw * ow // cw)) th (max 1 (ph * oh // ch))
                key (show [g x y pw ph tw th])
                six (peep old key () @ o (string? o ? o (limn-sixel (picture s sl 4) (picture s sl 0) x y pw ph tw th)))
                (pin new key six,
                 say j (limn-go (row0 + row) (col0 + col) + six))))
            ps))
   ; the cells placements ps covered, erased: a sixel goes with the text under it
   (limn-unsix j ps row0 col0)
    (map ([sl g row col x y pw ph nc nr] \
          (map (i \ say j (limn-go (row0 + (row + i)) (col0 + col) + "\e[" + show nc + "X")) (jot nr)))
         ps)

   (limn-run j n s) (0 < n ? (say j s, limn-run j (n - 1) s) 0)

   ; the bars between panes, straight off wharf-bars: (dir row col n), 'across or 'down
   (limn-bars j bs)
    (map ([d row col n] \
          (d = 'across ? (say j (limn-go row col), limn-run j n limn-across)
             (:- (down 0)
                 (down i) (i < n ? (say j (limn-go (row + i) col), say j limn-down, down (i + 1))
                             0))))
         bs))
) ; module limn
