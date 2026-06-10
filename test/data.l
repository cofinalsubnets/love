
(: s0 (nom 0)
   s1 (nom 0)
   s2 (nom 0)
 (assert !(= s0 s1)
         !(= s0 s2)
         !(= s1 s2)
         (= 'asdf (intern "asdf"))          ; intern: string -> the interned symbol
         (= 'asdf (intern 'asdf))           ; ...identity on any non-string arg
         !(= 'asdf (nom "asdf"))         ; nom str/sym is uninterned: distinct from the interned symbol
         !(= (nom "asdf") (nom "asdf")) ; ...and from each other
         (= "asdf" (string (nom "asdf")))  ; but carries the name -> (string sym) (string arg)
         (= "asdf" (string (nom 'asdf)))   ; ...and (symbol arg)
         (= "asdf" (string 'asdf))))
(:
 t (table 0)
 (Put k v) (pin t k v)
 (Del k) (pull t k 0)
 (Get k) (peep t k 0)
 _ (Put 1 2)
 _ (Put 2 3)
 _ (Put 3 4)
 _ (Put 't 'f)
 _ (assert
    (= 4 (sat t))
    (= 4 (sat (keys t))))
 _ (Del 2)
 _ (Del 't)
 (assert
    (= 2 (sat t))
    (= 2 (sat (keys t)))
    (: (lll t) (foldl (\ l k (cons k (cons (Get k) l))) 0 (keys t))
     (= (* 2 (sat t)) (sat (lll t))))))

(:
 (stripPrefix p s) (? (= p (slice s 0 (sat p))) (slice s (sat p) (sat s)))
 (lit l y n s) ((\ ss (? ss (y ss (cons l 0)) (n s))) (stripPrefix l s))
 (drop p y) (p (\ s _ (y s 0)))
 (opt p y _) (p y (\ s (y s 0)))
 (cats a b y n) (a (\ s l (b (\ s m (y s (cat l m))) n s)) n)
 (alt a b y n) (a y (b y n))
 (rep a y n s) ((opt (cats a (rep a))) y n s)
 (assert
  (= "xx" (scat "xx" ""))
  (= "xx" (scat "x" "x"))
  (= "xx" (scat "" "xx"))
  (= 4 (sat "slen"))
  (= "bidden" (slice "forbidden planet" 3 9))
  (= "all of it" (slice "all of it" -9 100))
  ; applying a string indexes it: a byte 0..255, or 1 when out of range --
  ; matching the empty string, where ("" k) is Church-numeral k**0 == 1
  (= 104 ("hi" 0))                          ; 'h'
  (= 105 ("hi" 1))                          ; 'i'
  (= 1 ("hi" 2))                            ; past the end -> 1
  (= 1 ("hi" -1))                           ; negative index -> 1
  (= 1 ("hi" 'x))                           ; non-numeric index -> 1
  (= 255 ((string 255) 0))                  ; high byte returns unsigned 0..255
  (= (peep "vaporeon" 3 0) ("vaporeon" 3))   ; identical to get with a 0 default
  (= "eon" (stripPrefix "vapor" "vaporeon"))
 (= '("eon" "vapor")
  (lit "vapor" cons 0 "vaporeon"))
 (= '("rrq" "R")
  (alt (lit "r") (lit "R") cons 0 "Rrrq"))
 (= '("q" "R" "r" "r")
  (rep (alt (lit "r") (lit "R")) cons 0 "Rrrq"))))

