; seek -- a picker: a list narrowed as it is typed at, one item chosen. a pure state, a key
; step and a frame, so a tool runs it on cli's stage (seek-run) or in a pane of its own, and a
; test drives it headless. an item is anything: text-of answers the string a query is matched
; against, label-of what its row shows. a query's words must each sit in the text, case and
; all, and a query that only grows narrows the last hits instead of reading every item again.
;   ↑↓ ^p ^n  a row     ^b ^f  a page     home end  the ends     ^u  a fresh query
;   enter  this one     esc ^c  none
(module (seek seek-new seek-q seek-key seek-frame seek-run seek-match)
(:
 ; the words of a query, spaces apart
 (seek-words q) (filter (w \ 0 < #w) (cite 'kore 'usplit 32 q))
 (seek-match ws s) (? !(two? ws) 1 (0 <= subidx s <ws 0) (seek-match >ws s) 0)

 (seek-new items text-of label-of title)
  {'items items 'n #items 'text text-of 'label label-of 'title title
   'q "" 'hits items 'sel 0 'top 0 'page 20 'pick () 'over 0}

 ; the query moved: one that only grew narrows the last hits, any other reads every item
 (seek-q d q)
  (: ws (seek-words q)
     from (starts? q (d 'q) ? (d 'hits) (d 'items))
     hs (two? ws ? (filter (it \ seek-match ws ((d 'text) it)) from) (d 'items))
     (pins d 'q q 'hits hs 'n #hs 'sel 0 'top 0))

 (seek-key d k)
  (: n (d 'n) s (d 'sel) p (d 'page)
     (to i) (pin d 'sel (max 0 (min (n - 1) i)))
     (? (k = 27 || k = 3) (pin d 'over 1)
        (k = 10 || k = 13) (0 < n ? (pins d 'pick (<(drop s (d 'hits))) 'over 1) d)
        (k = -8 || k = 16) (to (s - 1))
        (k = -9 || k = 14) (to (s + 1))
        (k = 2) (to (s - p))
        (k = 6) (to (s + p))
        (k = -5) (to 0)
        (k = -6) (to (n - 1))
        (k = 21) (seek-q d "")
        (k = 127 || k = 8) (: q (d 'q) (0 < #q ? (seek-q d (snip q 0 (#q - 1))) d))
        (31 < k && k < 127) (seek-q d (d 'q + string k))
        d))

 ; the query on the top row with the count beside it, the hits below, the chosen one
 ; reversed; the window follows the choice, and the cursor waits at the query's end
 (seek-frame d w h)
  (: rows (max 1 (h - 1))
     sel (d 'sel)
     top (d 'top @ t (? (sel < t) sel (t + rows <= sel) (sel - rows + 1) t))
     _ (pins d 'top top 'page rows)
     tag (show (d 'n) + " of " + show #(d 'items) + "  " + d 'title)
     q ("> " + d 'q)
     head (edfit q (max 1 (w - #tag - 1)) " " + " \e[2m" + tag + "\e[22m")
     vis (take rows (drop top (d 'hits)))
     body (foldl (\ a p (: i <p it >p
                          (a + "\r\n" + (top + i = sel ? "\e[7m" "")
                           + edfit ((d 'label) it) w " " + "\e[27m")))
                 "" (zip ^#vis vis))
     ("\e[H\e[2J" + head + body + "\e[1;" + show (min w (#q + 1)) + "H\e[?25h"))

 ; full screen on cli's stage until a choice or esc: the item, or () for none
 (seek-run d)
  (pins d 'pick () 'over 0,
   stage (w \ h \ seek-frame d w h) (k \ seek-key d k) (_ \ d 'over),
   d 'pick))
) ; module seek
