; test/wm.l -- the wm's pure core: xmonad's StackSet, ported. Rung 3 of the
; xmonad-in-ai port (rungs 1-2, the wire codec + the redirect handshake, live in
; doc/proto/{x11,wm}.l -- they need sockets; THIS is the half that needs none,
; so it lives in the corpus and runs on every target, ai0 included).
;
; The model, single-screen: a window STACK is () or (focus up down) -- a focus
; zipper, up REVERSED (nearest first); a SHEAF is (current-tag ((tag stack)..)),
; every tag exactly once. xmonad's laws hold by construction and are asserted
; below in the QuickCheck suite's exact-arithmetic edition: focus motions are
; inverses and cycle at order n (the church numerals compose the proof), swaps
; preserve the focused window, master ops are idempotent, insert/delete/send
; keep every window exactly once. A 200-step seeded fuzz walks the whole op
; vocabulary checking the invariant, xmonad's Properties.hs in miniature.
; Everything binds inside ONE body-having `:` -- nothing leaks to the corpus.
(: ; --- the stack zipper ---
   (stk f up dn) (L f up dn)
   (sfoc st) (cap st)  (sup st) (caup st)  (sdn st) (caup (cup st))
   (whole st) (? (two? st) (cat (rev (sup st)) (link (sfoc st) (sdn st))) ())   ; zipper -> the row, in order
   (sift l) (? (two? l) (stk (cap l) () (cup l)) ())                            ; the row -> a zipper, head focused
   (srev st) (? (two? st) (stk (sfoc st) (sdn st) (sup st)) ())                 ; the mirror: up <-> down
   (fup st) (? (! (two? st)) ()                                                 ; focus up, wrapping to the bottom
               (: up (sup st)
                  (? (two? up) (stk (cap up) (cup up) (link (sfoc st) (sdn st)))
                     (: all (rev (link (sfoc st) (sdn st)))
                        (stk (cap all) (cup all) ())))))
   (fdn st) (srev (fup (srev st)))                                              ; focus down = the mirrored focus up
   (wup st) (? (! (two? st)) ()                                                 ; swap the focused window upward
               (: up (sup st)
                  (? (two? up) (stk (sfoc st) (cup up) (link (cap up) (sdn st)))
                     (stk (sfoc st) (rev (sdn st)) ()))))                       ; at the top: rotate to the bottom
   (wdn st) (srev (wup (srev st)))
   (wmaster st) (? (! (two? st)) () (stk (sfoc st) () (cat (rev (sup st)) (sdn st))))   ; focused becomes master
   (fmaster st) (? (! (two? st)) ()                                             ; focus the master, order untouched
                   (: up (sup st)
                      (? (! (two? up)) st
                         (: all (rev up)
                            (stk (cap all) () (cat (cup all) (link (sfoc st) (sdn st))))))))
   (sput w st) (? (two? st) (stk w (sup st) (link (sfoc st) (sdn st))) (stk w () ()))   ; insert above the focus, focused
   (snub w l) (filter (\ x (! (= x w))) l)
   (srm w st) (? (! (two? st)) ()                                               ; delete w; focus falls down, then up
                 (: f (sfoc st) up (snub w (sup st)) dn (snub w (sdn st))
                    (? (! (= f w)) (stk f up dn)
                       (two? dn) (stk (cap dn) up (cup dn))
                       (two? up) (stk (cap up) (cup up) ())
                       ())))

   ; --- the sheaf: workspaces, one current, single screen ---
   (sheaf tags) (L (cap tags) (map (\ t (L t ())) tags))
   (cur s) (cap s)  (board s) (caup s)
   (wtag? s t) (any (\ p (= (cap p) t)) (board s))
   (wsget s t) (: p (assoc t (board s)) (? (two? p) (caup p) ()))
   (wsput s t st) (L (cur s) (map (\ p (? (= (cap p) t) (L t st) p)) (board s)))
   (view s t) (? (wtag? s t) (L t (board s)) s)
   (top s) (: st (wsget s (cur s)) (? (two? st) (sfoc st) ()))
   (row s) (whole (wsget s (cur s)))
   (amid s f) (wsput s (cur s) (f (wsget s (cur s))))                            ; reshape the current stack
   (windows s) (foldl (\ a p (cat a (whole (caup p)))) () (board s))
   (has? s w) (any (\ x (= x w)) (windows s))
   (put s w) (? (has? s w) s (amid s (sput w)))                                  ; manage w (a no-op if managed anywhere)
   (del s w) (L (cur s) (map (\ p (L (cap p) (srm w (caup p)))) (board s)))
   (tagof s w) (: r (filter (\ p (any (\ x (= x w)) (whole (caup p)))) (board s))
                  (? (two? r) (caap r) ()))
   (send s t) (? (! (&& (wtag? s t) (! (= t (cur s))) (two? (wsget s (cur s))))) s
                 (: w (top s) d (del s w)                                        ; the focused window emigrates; we stay
                    (wsput d t (sput w (wsget d t)))))
   (nodup? l) (? (! (two? l)) 1 (? (any (\ x (= x (cap l))) (cup l)) 0 (nodup? (cup l))))
   (sane? s) (&& (wtag? s (cur s)) (nodup? (windows s)))                         ; the StackSet invariant

   ; --- the zipper laws (xmonad's Properties, exact) ---
   st3 (stk 2 '(1) '(3))                                                         ; row (1 2 3), 2 focused
   _ (assert
      (= (whole (sift '(1 2 3))) '(1 2 3)) (! (sift ())) (! (whole ()))
      (= (whole st3) '(1 2 3)) (= (sfoc st3) 2)
      ; focus motions: inverses, order-preserving, cycling at the stack's order
      (= (fdn (fup st3)) st3) (= (fup (fdn st3)) st3)
      (= (whole (fup st3)) '(1 2 3)) (= (whole (fdn st3)) '(1 2 3))
      (= (sfoc (fup st3)) 1) (= (sfoc (fdn st3)) 3)
      (= (sfoc (fup (fup st3))) 3)                                               ; wrap: past the top -> the bottom
      (= ((3 fup) st3) st3) (= ((3 fdn) st3) st3)                                ; the church numeral IS the cycle law
      (= (fup (stk 7 () ())) (stk 7 () ()))                                      ; a singleton is a fixed point
      ; swaps: keep the focused window, move it; inverses; wrap rotates
      (= (wdn (wup st3)) st3) (= (wup (wdn st3)) st3)
      (= (sfoc (wup st3)) 2) (= (whole (wup st3)) '(2 1 3))
      (= (whole (wdn st3)) '(1 3 2))
      (= (whole (wup (fup st3))) '(2 3 1))                                       ; swapping the top rotates it to the bottom
      ; master: swap-master fronts the focus (idempotent); focus-master keeps order (idempotent)
      (= (whole (wmaster st3)) '(2 1 3)) (= (sfoc (wmaster st3)) 2)
      (= (wmaster (wmaster st3)) (wmaster st3))
      (= (whole (fmaster st3)) '(1 2 3)) (= (sfoc (fmaster st3)) 1)
      (= (fmaster (fmaster st3)) (fmaster st3))
      ; insert: above the focus, focused; delete: absent no-op, focus falls down then up
      (= (whole (sput 9 st3)) '(1 9 2 3)) (= (sfoc (sput 9 st3)) 9)
      (= (srm 2 st3) (stk 3 '(1) ())) (= (whole (srm 1 st3)) '(2 3)) (= (whole (srm 3 st3)) '(1 2))
      (= (srm 9 st3) st3) (! (srm 1 (stk 1 () ()))))

   ; --- the sheaf laws ---
   s0 (sheaf '(1 2 3))
   s1 (put s0 10)
   s2 (put (put s1 20) 30)                                                       ; ws1 row (30 20 10), 30 focused
   s4 (send s2 2)
   _ (assert
      (= (cur s0) 1) (! (row s0)) (! (top s0)) (sane? s0)
      (= (top s1) 10) (= (row s1) '(10)) (has? s1 10) (sane? s1)
      (= (put s1 10) s1)                                                         ; managing a managed window: a no-op
      (= (row s2) '(30 20 10)) (= (top s2) 30) (sane? s2)
      ; view: only the current tag turns; idempotent; reversible; windows untouched
      (= (cur (view s2 2)) 2) (! (top (view s2 2)))
      (= (view s2 9) s2) (= (view (view s2 2) 2) (view s2 2)) (= (view (view s2 2) 1) s2)
      (= (windows (view s2 2)) (windows s2))
      ; send: the focused window emigrates, focus falls to the next, we stay put
      (= (cur s4) 1) (= (tagof s4 30) 2) (= (top s4) 20) (= (row s4) '(20 10)) (sane? s4)
      (= (send s2 1) s2) (= (send s2 9) s2)                                      ; to self / to nowhere: no-ops
      (= (send (view s2 2) 1) (view s2 2))                                       ; an empty workspace sends nothing
      ; delete: everywhere, exactly once
      (! (has? (del s2 20) 20)) (= (row (del s2 20)) '(30 10))
      (= (top (del s2 30)) 20)                                                   ; deleting the focus: focus falls down
      (= (del s2 99) s2) (sane? (del s2 30))
      (! (has? (del s4 30) 30))                                                  ; ... on a non-current workspace too
      (= (tagof s2 10) 1) (! (tagof s2 99))
      (= (row ((3 (\ s (amid s fup))) s2)) (row s2)))                            ; church cycling lifts to the sheaf

   ; --- the seeded fuzz: xmonad's QuickCheck run, deterministic. 200 steps over
   ;     the whole op vocabulary; the invariant must hold at every step (a break
   ;     answers a red tuple whose sane? fails the final assert).
   (op k w s)
    (? (= k 0) (put s w)     (= k 1) (del s w)
       (= k 2) (amid s fup)  (= k 3) (amid s fdn)
       (= k 4) (amid s wup)  (= k 5) (amid s wdn)
       (= k 6) (amid s wmaster) (= k 7) (amid s fmaster)
       (= k 8) (view s (+ 1 (% w 3)))
       (send s (+ 1 (% w 3))))
   (fz i st s)
    (? (< i 1) s
       (: r1 (random st 10) r2 (random (cup r1) 40)
          s2 (op (cap r1) (+ 1 (cap r2)) s)
          (? (sane? s2) (fz (- i 1) (cup r2) s2) (L 'broke (cap r1) (+ 1 (cap r2))))))
   sF (fz 200 (seed 42) s0)
   (assert (sane? sF) (all (\ w (wtag? sF (tagof sF w))) (windows sF))))
