; src/apps/mitty/wharf.l -- the layout algebra under quay's panes. it answers rectangles in
; cells, never pixels; each consumer scales them its own way.
;
; a plan is a binary tree. a leaf is a pane's id; a node is one split:
;
;   (dir pct a b)   dir 'stack (a above b) or 'beside (a left of b)
;                   pct 1..99 -- a's share of the axis being divided
;
; an id is any value that is not a pair. () is reserved: wharf-shut's empty wharf.
;
; a split spends a cell on the bar between its halves (80 columns -> 39 and 40). under three
; cells b lays at zero extent, still in the list: ask wharf-show?.
;
; laws: every rectangle sits inside the wharf, and no two overlap (spans half-open).
(module '(wharf wharf-at wharf-bars wharf-panes wharf-col wharf-cols wharf-drag wharf-id wharf-lay wharf-layg
          wharf-row wharf-rows wharf-show? wharf-shut wharf-split wharf-steer)
(:
   ; --- reading a laid pane: (id row col rows cols), origins 0-based ----------
   (wharf-id b)    <b
   (wharf-row b)   <>b
   (wharf-col b)   <>>b
   (wharf-rows b)  <>>>b
   (wharf-cols b)  <>>>>b
   (wharf-show? b) (0 < wharf-rows b && 0 < wharf-cols b)

   ; a's share of n units at pct, the bar's g spent. both halves get at least one; under
   ; g + 2 a takes it all
   (wcut n pct g) (n < g + 2 ? n
                     ((n - g) * pct // 100 @ k
                        (? (k < 1) 1 (n - g - 1 < k) (n - g - 1) k)))
   (wrest n a g) (n < g + 2 ? 0 (n - g - a))

   ; --- the lay: every pane's rectangle, in plan order -----------------------
   ; a half with no room lays at its parent's corner, not past an unspent bar
   (wlay p row col r c g)
    (two? p ?
       (p @ [d pct a b]
        (d = 'stack ?
           (: h (wcut r pct g) t (wrest r h g)
              (cat (wlay a row col h c g)
                   (wlay b (0 < t ? (row + h + g) row) col t c g)))
           (: w (wcut c pct g) t (wrest c w g)
              (cat (wlay a row col r w g)
                   (wlay b row (0 < t ? (col + w + g) col) r t g)))))
       [[p row col r c]])
   ; () is the empty wharf, never a pane named ()
   (wharf-lay p r c) (() = p ? () (wlay p 0 0 r c 1))
   (wharf-layg p r c g) (() = p ? () (wlay p 0 0 r c g))

   ; --- the bars: (dir row col len), 'across spanning cols, 'down spanning rows
   ; a bar only where both halves are showable
   (wbars p row col r c)
    (two? p ?
       (p @ [d pct a b]
        (d = 'stack ?
           (: h (wcut r pct 1) t (wrest r h 1)
              (cat (0 < h && 0 < t ? [['across (row + h) col c]] ())
                   (cat (wbars a row col h c)
                        (wbars b (row + h + 1) col t c))))
           (: w (wcut c pct 1) t (wrest c w 1)
              (cat (0 < w && 0 < t ? [['down row (col + w) r]] ())
                   (cat (wbars a row col r w)
                        (wbars b row (col + w + 1) r t)))))))
   (wharf-bars p r c) (() = p ? () (wbars p 0 0 r c))

   ; --- the roster and the hit test -------------------------------------------
   (wpanes p) (two? p ? (cat (wpanes <>>p) (wpanes <>>>p)) [p])
   (wharf-panes p) (() = p ? () (wpanes p))

   ; which pane owns this cell, or () -- a zero-extent one owns nothing
   (wharf-at bs row col)
    (two? bs ?
     (: b <bs r0 (wharf-row b) c0 (wharf-col b)
        (r0 <= row < r0 + wharf-rows b && c0 <= col < c0 + wharf-cols b ?
           (wharf-id b)
           (wharf-at >bs row col)))
     ())

   ; --- steering ---------------------------------------------------------------
   ; focus moves to the nearest showable pane past this one's edge whose other axis
   ; overlaps; nowhere to go answers the id unchanged
   (wover a1 n1 a2 n2) (a1 < a2 + n2 && a2 < a1 + n1)
   (wpick bs id) (two? bs && (wharf-id <bs = id ? <bs (wpick >bs id)))
   (wpast f b d)
    (? (d = 'right) (wharf-col f + wharf-cols f <= wharf-col b
                     && wover (wharf-row f) (wharf-rows f) (wharf-row b) (wharf-rows b))
       (d = 'left)  (wharf-col b + wharf-cols b <= wharf-col f
                     && wover (wharf-row f) (wharf-rows f) (wharf-row b) (wharf-rows b))
       (d = 'down)  (wharf-row f + wharf-rows f <= wharf-row b
                     && wover (wharf-col f) (wharf-cols f) (wharf-col b) (wharf-cols b))
                    (wharf-row b + wharf-rows b <= wharf-row f
                     && wover (wharf-col f) (wharf-cols f) (wharf-col b) (wharf-cols b)))
   (wgap f b d)
    (? (d = 'right) (wharf-col b - wharf-col f - wharf-cols f)
       (d = 'left)  (wharf-col f - wharf-col b - wharf-cols b)
       (d = 'down)  (wharf-row b - wharf-row f - wharf-rows f)
                    (wharf-row f - wharf-row b - wharf-rows b))
   ; the tiebreak: how far off the other axis, so a straight move beats a diagonal
   (wskew f b d)
    (: v (d = 'right || d = 'left ? (wharf-row b - wharf-row f)
                                    (wharf-col b - wharf-col f))
       |v)
   (wnear f d best b)
    (atom? best ? b
       (: g1 (wgap f b d) g2 (wgap f best d)
          (? (g1 < g2) b (g2 < g1) best
             (wskew f b d < wskew f best d ? b best))))
   (wharf-steer bs id d)
    (wpick bs id @ f
       (atom? f ? id
          (filter (b \ wharf-show? b && wpast f b d) bs @ cs
             (two? cs ? (wharf-id (foldl (wnear f d) () cs)) id))))

   ; --- editing the plan --------------------------------------------------------
   ; split the pane named id in two, the new one second; an absent id changes nothing
   (wharf-split p id d pct new)
    (two? p ? [<p <>p (wharf-split <>>p id d pct new) (wharf-split <>>>p id d pct new)]
       (p = id ? [d pct p new] p))

   ; drag the bar through cell (ar ac) to row or column `to`: its split's share is the one
   ; that lays the bar there, held to 1..99. a cell on no bar changes nothing
   (wpct n k) (n < 3 ? 50 (: v ((k * 100 + n - 2) // (n - 1)) (? (v < 1) 1 (99 < v) 99 v)))
   (wdrag p row col r c ar ac to)
    (two? p ?
       (p @ [d pct a b]
        (d = 'stack ?
           (: h (wcut r pct 1) t (wrest r h 1)
              (? (0 < h && 0 < t && ar = row + h && col <= ac && ac < col + c) [d (wpct r (to - row)) a b]
                 [d pct (wdrag a row col h c ar ac to) (wdrag b (row + h + 1) col t c ar ac to)]))
           (: w (wcut c pct 1) t (wrest c w 1)
              (? (0 < w && 0 < t && ac = col + w && row <= ar && ar < row + r) [d (wpct c (to - col)) a b]
                 [d pct (wdrag a row col r w ar ac to) (wdrag b row (col + w + 1) r t ar ac to)]))))
       p)
   (wharf-drag p r c ar ac to) (() = p ? () (wdrag p 0 0 r c ar ac to))

   ; shut a pane; its sibling takes what the pair held. the last one answers ()
   (wharf-shut p id)
    (two? p ?
       (: a (wharf-shut <>>p id) b (wharf-shut <>>>p id)
          (? (() = a) b (() = b) a [<p <>p a b]))
       (p = id ? () p)))
) ; module wharf
