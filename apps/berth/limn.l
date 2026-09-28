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
(module '(limn limn-across limn-bars limn-down limn-glyph limn-glyphs limn-go limn-ink limn-pen
          limn-row limn-rows limn-run limn-sgr)
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
                      (? (string? g) g
                       (: s (cp = 0 ? " " (utf8 cp))
                          _ (pin limn-glyphs cp s)
                          s)))

   (limn-go row col) ("\e[" + show (row + 1) + ";" + show (col + 1) + "H")
   limn-down (utf8 9474)                      ; │
   limn-across (utf8 9472)                    ; ─

   ; paint row i cell by cell, threading the pen. a wide char's tail says nothing: the
   ; outer terminal steps two columns for its lead
   (limn-row j s c i q p) (? (q < c)
                           (: k (i * c + q)
                              g (glass s k 0)
                              (? ((g >> 21 & 3) = 2) (limn-row j s c i (q + 1) p)
                                 (: p2 (limn-pen g (glass s k 1) (glass s k 2))
                                    _ (p = p2 ? 0 (say j (limn-sgr p2)))
                                    _ (say j (limn-glyph (g & 2097151)))
                                    (limn-row j s c i (q + 1) p2))))
                           p)

   ; one pane: every grid row addressed at its own origin, which is the whole
   ; difference between painting a rectangle and painting a run of full lines.
   ; p is the pen carried in and answered back, so a caller threads it across panes
   (limn-rows j s r c row0 col0 i p)
    (? (i < r)
       (: _ (say j (limn-go (row0 + i) col0))
          p2 (limn-row j s c i 0 p)
          (limn-rows j s r c row0 col0 (i + 1) p2))
       p)

   (limn-run j n s) (? (0 < n) (: _ (say j s) (limn-run j (n - 1) s)) 0)

   ; the bars between panes, straight off wharf-bars: (dir row col n), 'across or 'down
   (limn-bars j bs)
    (map ([d row col n] \
          (? (d = 'across) (: _ (say j (limn-go row col)) (limn-run j n limn-across))
             (: (down i) (? (i < n)
                            (: _ (say j (limn-go (row + i) col)) _ (say j limn-down)
                               (down (i + 1)))
                            0)
                (down 0))))
         bs))
) ; module limn
