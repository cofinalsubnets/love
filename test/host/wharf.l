; test/host/wharf.l -- the laws of src/apps/mitty/wharf.l, quay's layout algebra, arithmetic over
; lists. a rectangle is (id row col rows cols), 0-based; a bar is (dir row col len), dir 'across
; or 'down. not in the corpus: borrow finds wharf.l on the filesystem, and love0's second
; evaluation stops inside it. run: cat test/00-init.l test/host/wharf.l | out/love
(borrow "src/apps/mitty/wharf.l")

; --- the two standing laws, checked rather than trusted ---
; spans are half-open, so a zero-extent pane is inside everything and overlaps
; nothing -- which is why neither law needs to except it.
(: (ovl a1 n1 a2 n2) (a1 < a2 + n2 && a2 < a1 + n1)
   (hit a b) (ovl (wharf-row a) (wharf-rows a) (wharf-row b) (wharf-rows b) &&
              ovl (wharf-col a) (wharf-cols a) (wharf-col b) (wharf-cols b))
   (clashes bs) (two? bs ? (#(filter (hit <bs) >bs) + clashes >bs) 0)
   (inside r c b) (0 <= wharf-row b && wharf-row b + wharf-rows b <= r &&
                   0 <= wharf-col b && wharf-col b + wharf-cols b <= c)
   (strays r c bs) #(filter (nil? * inside r c) bs)
   ; every plan laid at every size: nothing overlaps, nothing escapes, nobody is lost
   (sound? p r c) (wharf-lay p r c @ bs
                   (0 = clashes bs && 0 = strays r c bs && #bs = #(wharf-panes p)))
   plans '(9
           (beside 50 1 2)
           (stack 50 1 2)
           (beside 25 1 (stack 75 2 3))
           (stack 30 (beside 50 1 2) (beside 50 3 4))
           (beside 50 (stack 50 1 2) (stack 50 3 4))
           (beside 10 1 (beside 10 2 (beside 10 3 4))))
   ; <>s, not (cup s): the tail of (24 80) is the list (80), whose net is 80 --
   ; so the arithmetic below would run on a list and quietly prove nothing
   sizes '((24 80) (1 1) (2 2) (3 3) (1 80) (80 1) (5 7) (200 300))
 _ (test
    (0 = #(filter (p \ !(foldl (a \ s \ (a && sound? p <s <>s)) 1 sizes))
                        plans)))
 ; a gap of g units between halves, as lux's bsp lays pixels: g 1 is the cell lay exactly,
 ; and a wider gap keeps both laws at every size
 (gsound? p r c g) (wharf-layg p r c g @ bs
                      (0 = clashes bs && 0 = strays r c bs && #bs = #(wharf-panes p)))
 _ (test
    (all (p \ all (s \ wharf-layg p <s <>s 1 = wharf-lay p <s <>s) sizes) plans)
    (all (p \ all (s \ all (g \ gsound? p <s <>s g) [2 4 9]) sizes) plans)
    ('((1 0 0 24 38) (2 0 42 24 38)) = wharf-layg '(beside 50 1 2) 24 80 4)))

; --- 1. a lone pane is the whole wharf, and wears no bar ---
(: _ (test
      ('((7 0 0 24 80)) = wharf-lay 7 24 80)
      (() = wharf-bars 7 24 80)
      ('(7) = wharf-panes 7)))

; --- 2. a split spends exactly one cell on its bar ---
; 39 + 1 + 40 = 80, and the bar stands in the column neither half was given.
(: bs (wharf-lay '(beside 50 1 2) 24 80)
   br (wharf-bars '(beside 50 1 2) 24 80)
 _ (test
    ('((1 0 0 24 39) (2 0 40 24 40)) = bs)
    ('((down 0 39 24)) = br)
    (80 = wharf-cols <bs + 1 + wharf-cols <>bs)
    (24 = wharf-rows <bs)))                   ; the undivided axis is untouched

; --- 3. stack divides the rows the same way, and its bar lies across ---
(: _ (test
      ('((1 0 0 11 80) (2 12 0 12 80)) = wharf-lay '(stack 50 1 2) 24 80)
      ('((across 11 0 80)) = wharf-bars '(stack 50 1 2) 24 80)))

; --- 4. pct is a's share of what is left after the bar ---
(wharf-lay '(beside 25 1 2) 24 80 @ bs
 (test (19 = wharf-cols <bs) (60 = wharf-cols <>bs)))

; --- 5. nesting: a plan is a tree, and the halves divide what they were handed ---
(: p '(beside 50 1 (stack 50 2 3))
 _ (test
    ('((1 0 0 24 39) (2 0 40 11 40) (3 12 40 12 40)) = wharf-lay p 24 80)
    ('((down 0 39 24) (across 11 40 40)) = wharf-bars p 24 80)
    ('(1 2 3) = wharf-panes p)))

; --- 6. the tight end: three cells is the smallest split there is ---
; under three, the split does not happen: a takes the axis, b lays at its
; parent's corner with zero extent -- present in the list, absent from the glass.
(: p '(beside 50 1 2)
   b3 (wharf-lay p 24 3)
   b2 (wharf-lay p 24 2)
 _ (test
    ('((1 0 0 24 1) (2 0 2 24 1)) = b3)         ; 1 + bar + 1
    (two? (wharf-bars p 24 3))
    ('((1 0 0 24 2) (2 0 0 24 0)) = b2)         ; no bar, and b is at the corner
    (() = wharf-bars p 24 2)
    (wharf-show? <b2)
    !(wharf-show? <>b2)
    (2 = #b2)))                          ; and it is still in the list

; --- 7. the hit test: bars belong to nobody ---
(wharf-lay '(beside 50 1 (stack 50 2 3)) 24 80 @ bs
 (test
  (1 = wharf-at bs 0 0)
  (() = wharf-at bs 0 39)                   ; the bar's own column
  (2 = wharf-at bs 0 40)
  (3 = wharf-at bs 12 40)
  (() = wharf-at bs 11 40)                  ; the across bar between 2 and 3
  (() = wharf-at bs 99 99)
  ; a zero-extent pane claims nothing, even the cell it is seated on -- asked
  ; alone, because its showable sibling covers that corner and answers first
  (() = wharf-at (drop 1 (wharf-lay '(beside 50 1 2) 24 2)) 0 0)))

; --- 8. steering: nearest past the edge, other axis overlapping ---
; the wall is a no-op rather than a condition, and so is a focus that has been shut.
(wharf-lay '(beside 50 1 (stack 50 2 3)) 24 80 @ bs
 (test
  (2 = wharf-steer bs 1 'right)             ; ties on gap break to the nearer row
  (1 = wharf-steer bs 2 'left)
  (1 = wharf-steer bs 3 'left)              ; one tall pane reached from either
  (3 = wharf-steer bs 2 'down)
  (2 = wharf-steer bs 3 'up)
  (1 = wharf-steer bs 1 'left)              ; the wall
  (3 = wharf-steer bs 3 'right)
  (2 = wharf-steer bs 2 'up)
  (99 = wharf-steer bs 99 'left)))          ; a stale id steers nowhere

; --- 8a. an unshowable pane is never steered to ---
(wharf-lay '(beside 50 1 2) 24 2 @ bs
 (test (1 = wharf-steer bs 1 'right)))

; --- 9. splitting names the new pane, and leaves the rest of the plan alone ---
(: _ (test
      ('(stack 50 2 5) = wharf-split 2 2 'stack 50 5)
      ('(beside 50 1 (stack 50 2 5)) = wharf-split '(beside 50 1 2) 2 'stack 50 5)
      ('(beside 50 1 2) = wharf-split '(beside 50 1 2) 99 'stack 50 5)))

; --- 10. shutting promotes the sibling: the pair's whole rectangle, bar included ---
(wharf-shut '(beside 50 1 (stack 50 2 3)) 2 @ p
 (test
  ('(beside 50 1 3) = p)
  ('((1 0 0 24 39) (3 0 40 24 40)) = wharf-lay p 24 80)
  (() = wharf-shut 7 7)                     ; the last one leaves an empty wharf
  ('(beside 50 1 2) = wharf-shut '(beside 50 1 2) 99)
  (1 = wharf-shut '(beside 50 1 2) 2)))

; --- 10a. the empty wharf holds nothing, and is not a pane named () ---
(: _ (test
      (() = wharf-lay () 24 80)
      (() = wharf-bars () 24 80)
      (() = wharf-panes ())
      (() = wharf-at (wharf-lay () 24 80) 0 0)))

; --- 11. split then shut is the identity on the plan ---
(: p '(beside 25 1 (stack 75 2 3))
 _ (test (p = wharf-shut (wharf-split p 3 'beside 50 4) 4)))

; --- 12. a drag lays the bar it holds where it is let go, held inside the axis; a cell on
; no bar changes nothing; the nested bar moves alone ---
(: p '(beside 50 1 (stack 50 2 3))
   b0 (wharf-bars p 24 80)                                     ; down at col 39, across at row 11
   p1 (wharf-drag p 24 80 5 39 20)
   p2 (wharf-drag p 24 80 11 60 4)
   p3 (wharf-drag p 24 80 0 0 30)
   p4 (wharf-drag p 24 80 5 39 0)
   p5 (wharf-drag p 24 80 5 39 200)
   (test (elem '(down 0 39 24) b0)
         (elem '(down 0 20 24) (wharf-bars p1 24 80))
         (elem '(across 4 40 40) (wharf-bars p2 24 80))
         (<>p = <>p2)                                         ; the outer share kept
         (p = p3)
         (1 = <>p4) (99 = <>p5)
         (3 = #(wharf-lay p4 24 80)) (1 = wharf-cols <(wharf-lay p4 24 80))
         (() = wharf-drag () 24 80 0 0 5)))

(test_fin ())
(puts "wharf: ok")
