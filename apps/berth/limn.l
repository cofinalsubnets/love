; apps/berth/limn.l -- to limn is to paint: cb cells onto an outer terminal, as escapes.
; the third piece of the pane story and the one every seat needs -- cb says what is
; in a grid (bytes in, cells out), apps/berth/wharf.l says where the rectangle is, and this
; says a grid's cells at an origin. cells are the currency all three speak.
; a module: `(borrow 'limn)` on the artifact, `(borrow "apps/berth/limn.l")` off the tree.
;
; it takes a grid and an origin, never a plan and never a harbour: the bars come in as
; wharf-bars' list, so nothing here knows what a berth or a buffer is, and one painter
; serves panes of ptys and splits of one process alike.
;
; nothing is erased, and nothing needs to be -- a caller whose panes and bars tile its
; wharf (apps/berth/wharf.l's standing law) writes every cell every frame, so no stale glyph
; can survive a layout change. a caller that leaves gaps owns them.
;
; host-only: `glass` is cb's nif (love/quay/nif.c), so this never joins the corpus --
; test/limn.l is its gate.
(module '(limn limn-across limn-bars limn-down limn-glyph limn-glyphs limn-go limn-half limn-ink
          limn-pen limn-pics limn-row limn-rows limn-run limn-sgr limn-spans limn-tile)
(:
   ; --- the pen: a cell's face byte and its two colour words (love/quay/quay.h), as one
   ; number -- face | fg << 8 | bg << 34, a colour word being 26 bits. one SGR per pen
   ; change, respecified from zero each time -- cheap, and never stale ----------
   (limn-pen g fg bg) ((g >> 24) | (fg << 8) | (bg << 34))
   ; a colour word's SGR, base 38 for the fg and 48 for the bg: the outer terminal's own
   ; default, an xterm-256 index, or rgb
   (limn-ink base k) (: v (k & 16777215)
                        ((k >> 24) @- (show (base + 1))
                         1 (show base + ";5;" + show v)
                         2 (show base + ";2;" + show (v >> 16) + ";" + show (v >> 8 & 255)
                            + ";" + show (v & 255))))
   (limn-sgr p) (: fa (p & 255)
                 ("\e[0" + (fa & 1 ? ";1" "") + (fa & 8 ? ";2" "") + (fa & 16 ? ";3" "")
                  + (fa & 2 ? ";4" "") + (fa & 64 ? ";5" "") + (fa & 4 ? ";7" "")
                  + (fa & 128 ? ";8" "") + (fa & 32 ? ";9" "")
                  + ";" + limn-ink 38 (p >> 8 & 67108863) + ";" + limn-ink 48 (p >> 34) + "m"))

   ; the grid holds codepoints and the outer terminal speaks utf-8: each rendered once
   ; and cached. the blank is a space
   limn-glyphs {}
   (limn-glyph cp) (: g (limn-glyphs cp)
                      (string? g ? g
                       (: s (cp = 0 ? " " (utf8 cp))
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
                      (: v (px x y) (sum (x + 1) y (? (v >> 24) [(<a + (v >> 16 & 255)) (<>a + (v >> 8 & 255))
                                                               (<>>a + (v & 255)) ((a 3) + 1)] a))))
       t (sum 0 y0 [0 0 0 0])
       n (t 3)
       (? (n < 1) () [(<t // n) (<>t // n) (<>>t // n)]))
   (limn-tile s k)
    (: w (gaze s 6) h (gaze s 7)
       top (limn-half s k 0 (h // 2) w)
       bot (limn-half s k (h // 2) h w)
       (rgb c) (show <c + ";" + show <>c + ";" + show <>>c)
       bg (limn-ink 48 (glass s k 2))
       ; ▀ a top over what is under it, ▄ a bottom alone, a space for a tile the picture left bare
       (? (two? top) ("\e[0;38;2;" + rgb top + ";" + (? (two? bot) ("48;2;" + rgb bot) bg) + "m" + utf8 9600)
          (two? bot) ("\e[0;38;2;" + rgb bot + ";" + bg + "m" + utf8 9604)
          ("\e[0;" + bg + "m ")))

   ; ..or, where the outer terminal takes the pictures themselves (limn-pics), the cell's
   ; ground for one to lie over
   (limn-bare s k) ("\e[0;" + limn-ink 48 (glass s k 2) + "m ")

   ; a cluster's marks, after its base
   (limn-marks j s k m) (: v (glass s k m)
                           (m < 6 && 0 < v ? (say j (utf8 v), limn-marks j s k (m + 1)) 0))

   ; paint row i cell by cell, threading the pen. a wide char's tail says nothing: the
   ; outer terminal steps two columns for its lead. a selected cell wears the reverse face,
   ; and a tile is a ▀ or, with pk, bare ground
   (limn-row j s c i q p pk) (q < c ?
                           (: k (i * c + q)
                              g (: g0 (glass s k 0) ((gaze s 10) <= k < (gaze s 11) ? (g0 ^ 67108864) g0))
                              (? ((g >> 21 & 3) = 2) (limn-row j s c i (q + 1) p pk)
                                 ((g >> 23 & 1) = 1) (say j (pk ? (limn-bare s k) (limn-tile s k)), limn-row j s c i (q + 1) -1 pk)
                                 (: p2 (limn-pen g (glass s k 1) (glass s k 2))
                                    ((p = p2 ? 0 (say j (limn-sgr p2))),
                                     say j (limn-glyph (g & 2097151)),
                                     limn-marks j s k 3,
                                     limn-row j s c i (q + 1) p2 pk))))
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
       (cell i q) (: g (glass s (((i - v) * c) + q) 0)
                     ((g >> 23 & 1) = 1 ?
                        (: sl (g >> 16 & 127) e (peep t sl ())
                           (pin t sl (two? e ? [<e <>e (e 2) (e 3) (max (e 4) i) (max (e 5) q)]
                                        [i q (g >> 8 & 255) (g & 255) i q])))
                        0))
       (row i) (i < r ? (: _ (map (\ q (cell i q)) (jot c)) (row (i + 1))) 0)
       _ (row 0)
       t)
   (limn-send j id w h b)                           ; a=t in 4096-byte pieces, m=1 until the last
    (: n #b
       (go i) (i < n ?
                 (: e (min n (i + 4096))
                    _ (say j ((i = 0 ? ("\e_Ga=t,f=32,s=" + show w + ",v=" + show h + ",i=" + show id + ",q=2,") "\e_G")
                              + "m=" + (e < n ? "1" "0") + ";" + snip b i e + "\e\\"))
                    (go e))
                 0)
       (go 0))
   (limn-pics j s r c row0 col0 ib sent)
    (: cw (gaze s 6) ch (gaze s 7) t (limn-spans s r c)
       (one sl) (: e (t sl) w (picture s sl 0) h (picture s sl 1)
                   (? !(charm? w) 0
                      (: id ((ib * 1048576) + ((picture s sl 2) & 1048575))
                         _ (? (peep sent id 0) 0 (: _ (limn-send j id w h (picture s sl 3)) (pin sent id 1)))
                         x ((e 2) * cw) y ((e 3) * ch)
                         nc (((e 5) - (e 1)) + 1) nr (((e 4) - <e) + 1)
                         pw (min (nc * cw) (w - x)) ph (min (nr * ch) (h - y))
                         (0 < pw && 0 < ph ?
                            (say j (limn-go (row0 + <e) (col0 + (e 1)) + "\e_Ga=p,i=" + show id + ",p=1,q=2,C=1,x=" + show x
                                    + ",y=" + show y + ",w=" + show pw + ",h=" + show ph + ",c=" + show nc
                                    + ",r=" + show nr + "\e\\"))
                            0))))
       (map one (keys t)))

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
