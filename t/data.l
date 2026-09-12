
(: s0 (mint 0)
   s1 (mint 0)
   s2 (mint 0)
 (test !(s0 = s1)
         !(s0 = s2)
         !(s1 = s2)
         ('asdf = intern "asdf")  ; intern: string -> the interned symbol
         ('asdf = intern 'asdf)   ; ...identity on any non-string arg
         ('asdf = nom "asdf")     ; nom on a string is that same interning
         ('asdf = (2 nom "asdf")) ; ...so it is a projection to the kind: idempotent
         ("asdf" = string 'asdf)))
(:
 t (tablet 0)
 (Put k v) (pin t k v)
 (Del k) (pull t k 0)
 (Get k) (peep t k 0)
 (ln x) (foldl (\ n _ (1 + n)) 0 x)             ; spine length ($ on a list is the net sum)
 _ (Put 1 2)
 _ (Put 2 3)
 _ (Put 3 4)
 _ (Put 't 'f)
 _ (test
    (4 = tally t)
    (4 = ln (keys t)))
 _ (Del 2)
 _ (Del 't)
 (test
    (2 = tally t)
    (2 = ln (keys t))
    (: (lll t) (foldl (\ l k (. k (. (Get k) l))) () (keys t))
     ((2 * tally t) = ln (lll t)))))

(:
 (stripPrefix p s) (? (p = snip s 0 #p) (snip s #p #s))
 (lit l y n s) ((\ ss (? ss (y ss (. l ())) (n s))) (stripPrefix l s))
 (drop p y) (p (\ s _ (y s ())))
 (opt p y _) (p y (\ s (y s ())))
 (cats a b y n) (a (\ s l (b (\ s m (y s (cat l m))) n s)) n)
 (alt a b y n) (a y (b y n))
 (rep a y n s) ((opt (cats a (rep a))) y n s)
 (test
  ("xx" = ("xx" + ""))
  ("xx" = ("x" + "x"))
  ("xx" = ("" + "xx"))
  (4 = tally "slen")
  ("bidden" = snip "forbidden planet" 3 9)
  ("all of it" = snip "all of it" -9 100)
  ; applying a string indexes it: a byte 0..255, or 1 when out of range --
  ; matching the empty string, where ("" k) is Church-numeral k**0 == 1
  (104 = ("hi" 0))         ; 'h'
  (105 = ("hi" 1))         ; 'i'
  !("hi" 2)                ; past the end -> 1
  !("hi" -1) !("hi" -2)    ; a negative index is out of range, like one past the end
  ("hix" = ("hi" 'x))      ; a point operand is text: it juxtaposes
  (255 = ((string 255) 0)) ; high byte returns unsigned 0..255
  ; apply and peep coincide on the sequence kinds -- the same index action, apply answering
  ; () where peep answers the caller default. a rule the tree keeps, not a law it promises:
  ; a tray towers instead of indexing. snip still reads a negative, clamping to the front.
  (peep "vaporeon" 3 0 = ("vaporeon" 3))
  (0 = peep "vaporeon" -1 0) !("vaporeon" -1)
  ; pin writes exactly where peep reads, and text has no cell, so it answers a fresh string
  ("vapoReon" = pin "vaporeon" 4 82) ("vaporeon" = pin "vaporeon" -1 82)
  ("eon" = stripPrefix "vapor" "vaporeon")
 (= '("eon" "vapor")
  (lit "vapor" (.) 0 "vaporeon"))
 (= '("rrq" "R")
  (alt (lit "r") (lit "R") (.) 0 "Rrrq"))
 (= '("q" "R" "r" "r")
  (rep (alt (lit "r") (lit "R")) (.) 0 "Rrrq"))))


; snip is one knife over both spellings of a sequence, text and its charlist. the grid
; below cuts every window of a six-byte word both ways and wants the same answer back,
; overshoots and negatives included -- that equation IS the hom.
(:
 snip-s "forbid"
 snip-l (map snip-s (jot #snip-s))
 snip-ix [-3 0 1 2 3 6 9]
 (snip-grid f) (map (\ i (map (\ j (f i j)) snip-ix)) snip-ix)
 (test
  ([1 2 3] = snip [1 2 3 4 5] 0 3)
  ([3 4 5] = snip [1 2 3 4 5] 2 99)
  ([1 2] = snip [1 2 3 4 5] -3 2)
  (["b" [1 2]] = snip ['a "b" [1 2]] 1 3)      ; the elements, whatever they are
  ; an empty window answers the empty of the kind: () where text answers ""
  (() = snip [1 2 3] 3 3) (() = snip [1 2 3] 4 1) (() = snip () 0 3)
  ("" = snip "abc" 3 3)
  ([1 2] = snip (. 1 (. 2 3)) 0 2)             ; an improper tail is no element of it
  ((snip-grid (\ i j (string (snip snip-l i j)))) = (snip-grid (\ i j (snip snip-s i j))))))
