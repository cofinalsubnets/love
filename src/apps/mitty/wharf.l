; src/apps/mitty/wharf.l -- a wharf is where several vessels berth: the layout algebra under
; quay's panes, and the one piece every seat shares. it answers rectangles in cells,
; never pixels -- mitty seats them with \e[r;cH, the kernel console multiplies them by
; the font's width and height, and neither has to know what the other does with them.
; cells are the only currency both speak, and the one `gaze` already answers in.
; a module: `(borrow 'wharf)` on the artifact, `(borrow "src/apps/mitty/wharf.l")` off the tree.
;
; a plan is a binary tree. a leaf is a pane's id; a node is one split:
;
;   (dir pct a b)   dir 'stack (a above b) or 'beside (a left of b)
;                   pct 1..99 -- a's share of the axis being divided
;
; an id is any value that is not a pair, since pairs are how a node is told from a
; leaf; charms are the obvious choice and what the laws use. () is reserved -- it is
; how wharf-shut says the last pane is gone.
;
; a split spends a cell on the bar between its halves, so two panes side by side in
; 80 columns get 39 and 40. under three cells there is no room for two, so the split
; does not happen and b lays at zero extent. a zero-extent pane is still in the list,
; wearing (id row col 0 0): ask wharf-show?, never whether the rectangle nets nothing.
;
; two laws hold of every lay, and test/host/wharf.l checks them over a spread of plans
; and sizes rather than trusting the arithmetic: every rectangle sits inside the wharf,
; and no two overlap. the spans are half-open, so a zero-extent pane overlaps nothing
; -- including itself -- and neither law has to except it.
(module '(wharf wharf-at wharf-bars wharf-panes wharf-col wharf-cols wharf-drag wharf-id wharf-lay wharf-row
          wharf-rows wharf-show? wharf-shut wharf-split wharf-steer)
(:
   ; --- reading a laid pane: (id row col rows cols), origins 0-based ----------
   (wharf-id b)    <b
   (wharf-row b)   <>b
   (wharf-col b)   <>>b
   (wharf-rows b)  <>>>b
   (wharf-cols b)  <>>>>b
   (wharf-show? b) (0 < wharf-rows b && 0 < wharf-cols b)

   ; a's share of n cells at pct, the bar's cell already spent. both halves get
   ; at least one; under three there is no split to make and a takes it all.
   (wcut n pct) (n < 3 ? n
                   ((n - 1) * pct // 100 @ k
                      (? (k < 1) 1 (n - 2 < k) (n - 2) k)))
   (wrest n a) (n < 3 ? 0 (n - 1 - a))

   ; --- the lay: every pane's rectangle, in plan order -----------------------
   ; a half with no room lays at its parent's corner, not past the bar that was never
   ; spent, so a caller may do arithmetic on an origin without asking if it is real.
   (wlay p row col r c)
    (two? p ?
       (p @ [d pct a b]
        (d = 'stack ?
           (: h (wcut r pct) t (wrest r h)
              (cat (wlay a row col h c)
                   (wlay b (0 < t ? (row + h + 1) row) col t c)))
           (: w (wcut c pct) t (wrest c w)
              (cat (wlay a row col r w)
                   (wlay b row (0 < t ? (col + w + 1) col) r t)))))
       [[p row col r c]])
   ; () is the empty wharf, never a pane named (): wharf-shut answers it when the last
   ; one leaves, and a door that missed this hands back a phantom pane wearing the
   ; empty name. the same guard rides bars and panes below.
   (wharf-lay p r c) (() = p ? () (wlay p 0 0 r c))

   ; --- the bars: (dir row col len), 'across spanning cols, 'down spanning rows
   ; a bar rides only where a split actually happened -- both halves showable --
   ; so a wharf too narrow to divide is drawn with no line through it.
   (wbars p row col r c)
    (two? p ?
       (p @ [d pct a b]
        (d = 'stack ?
           (: h (wcut r pct) t (wrest r h)
              (cat (0 < h && 0 < t ? [['across (row + h) col c]] ())
                   (cat (wbars a row col h c)
                        (wbars b (row + h + 1) col t c))))
           (: w (wcut c pct) t (wrest c w)
              (cat (0 < w && 0 < t ? [['down row (col + w) r]] ())
                   (cat (wbars a row col r w)
                        (wbars b row (col + w + 1) r t)))))))
   (wharf-bars p r c) (() = p ? () (wbars p 0 0 r c))

   ; --- the roster and the hit test -------------------------------------------
   (wpanes p) (two? p ? (cat (wpanes <>>p) (wpanes <>>>p)) [p])
   (wharf-panes p) (() = p ? () (wpanes p))

   ; which pane owns this cell, or () for none -- a zero-extent one owns nothing,
   ; since its half-open span is empty, so the mouse can never land on the unshowable
   (wharf-at bs row col)
    (two? bs ?
     (: b <bs r0 (wharf-row b) c0 (wharf-col b)
        (r0 <= row < r0 + wharf-rows b && c0 <= col < c0 + wharf-cols b ?
           (wharf-id b)
           (wharf-at >bs row col)))
     ())

   ; --- steering ---------------------------------------------------------------
   ; focus moves to the nearest showable pane past this one's edge whose other axis
   ; overlaps -- the rule that lets one tall pane be reached from any of the short ones
   ; beside it. nowhere to go answers the id unchanged, so a steer at the wall is a
   ; no-op rather than a condition.
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
   ; split the pane named id in two; the new one takes the second half. an id
   ; that is not in the plan changes nothing, which is what a stale focus deserves.
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
           (: h (wcut r pct) t (wrest r h)
              (? (0 < h && 0 < t && ar = row + h && col <= ac && ac < col + c) [d (wpct r (to - row)) a b]
                 [d pct (wdrag a row col h c ar ac to) (wdrag b (row + h + 1) col t c ar ac to)]))
           (: w (wcut c pct) t (wrest c w)
              (? (0 < w && 0 < t && ac = col + w && row <= ar && ar < row + r) [d (wpct c (to - col)) a b]
                 [d pct (wdrag a row col r w ar ac to) (wdrag b row (col + w + 1) r t ar ac to)]))))
       p)
   (wharf-drag p r c ar ac to) (() = p ? () (wdrag p 0 0 r c ar ac to))

   ; shut a pane; its sibling takes the whole of what the pair held, bar and all.
   ; shutting the last one answers () -- a wharf with nothing tied up at it.
   (wharf-shut p id)
    (two? p ?
       (: a (wharf-shut <>>p id) b (wharf-shut <>>>p id)
          (? (() = a) b (() = b) a [<p <>p a b]))
       (p = id ? () p)))
) ; module wharf
