; test/cats.l -- cats is the foldr of + over a list, whatever the list holds: the nif's
; fast lanes (all strings, all lists) and its fold for the rest, held to that fold.
(: cats-ref (l \ foldr (+) () l)
   cats-s "ab" cats-b [2 3]
   cats-pieces ["" "a" "bc" () [1] [2 3] '(97 98) 5 0.5 (iota 2) 'q {} "\0x"]
   ; every list of up to three pieces, and the pieces' kinds mixed every way
   cats-lists (: (go n) (? (n < 1) [[]] (: r (go (n - 1)) (r + catmap (l \ map (p \ (p . l)) cats-pieces) r)))
                 (go 3))
   (test
    (all (l \ cats l = cats-ref l) cats-lists)
    (#cats-pieces + 1 @ n (#cats-lists = n * n * n))      ; every list of up to three pieces, some twice
    ; what is shared is what + shares: a lone piece is itself, the last list its own tail
    (== (cats [cats-s]) cats-s) (== (cats [() cats-s ()]) cats-s) (!(== (cats [cats-s ""]) cats-s))
    (== >(cats [[1] cats-b]) cats-b) (== >>(cats [[1] () [4] cats-b]) cats-b) (!(== (cats [cats-b cats-b]) cats-b))
    (cats [] = ()) (cats 5 = ()) (cats "ab" = ())
    (cats [[1 . 2] [3]] = cats-ref [[1 . 2] [3]])               ; an improper piece takes the fold
    (cats [@(1 2) @(3 4)] = @(4 6))                              ; ..and so do trays: + is a sum there
    (catmap (x \ [x x]) [1 2] = [1 1 2 2]) (catmap show [1 2 3] = "123")
    (catmap (x \ x) [] = ())
    (: big (map (i \ show i) ^5000) (cats big = foldl (+) "" big))))
