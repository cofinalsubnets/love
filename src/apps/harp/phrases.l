; src/apps/harp/phrases.l -- phrase books for the drifting center (src/apps/harp/drift.l):
; short phrases in just intervals over a center, each named, grouped by the way they
; pull. an otonal phrase (up the harmonic series) leans sharpward on the lattice, its
; utonal mirror flatward; a line is a walk of its own, note to note. a list inside a
; phrase sounds together.

(module '(phrases phrase-books book-names book book-phrases)
(borrow (: m (cite 'just) (? m m "src/apps/harp/just.l")))
(borrow (: m (cite 'tonnetz) (? m m "src/apps/harp/tonnetz.l")))
(:
   (r a b) (a /// b)
   ; a phrase and its utonal mirror, named as a pair
   (pair nm ph) [[nm ph] [(nm + "~") (pinv ph)]]
   (low c) (map (x \ x * (1 /// 2)) c)

   triads
    ((pair "major up" [1 (r 5 4) (r 3 2) (r 5 4)])
    + pair "major down" [(r 3 2) (r 5 4) 1 (r 3 4)]
    + pair "minor" [1 (r 6 5) (r 3 2) (r 6 5)]
    + pair "major held" [(low [1 (r 5 4) (r 3 2)]) (r 3 2) (r 15 8)]
    + pair "sixth" [1 (r 5 4) (r 5 3) (r 3 2)]
    + pair "ninth" [(low [1 (r 5 4) (r 3 2)]) (r 9 8) (r 5 4)])

   sevens
    ((pair "harmonic" (otonal [4 5 6 7]))
    + pair "subminor" [1 (r 7 6) (r 3 2) (r 7 6)]
    + pair "septimal line" [1 (r 8 7) (r 5 4) (r 3 2) (r 7 4)]
    + pair "tritone" [(low [1 (r 7 5)]) (r 7 4) (r 7 5)]
    + pair "seventh held" [(low (otonal [4 5 6 7])) (r 9 8) (r 7 4)])

   lines
    ((pair "fifths climb" (lpath [[1 0 0] [1 0 0] [1 0 0]]))
    + pair "thirds climb" (lpath [[0 1 0] [0 1 0] [-1 0 0]])
    + pair "zigzag" (lpath [[1 0 0] [0 1 0] [1 0 0] [0 -1 0]])
    + pair "square" (lpath [[1 0 0] [0 1 0] [-1 0 0] [0 -1 0]])
    + pair "seventh turn" (lpath [[0 0 1] [1 0 0] [0 0 -1]]))

   phrase-books [["triads" triads] ["sevens" sevens] ["lines" lines]
                 ["all" (triads + sevens + lines)]]
   book-names (map (b \ b 0) phrase-books)
   (book i) (phrase-books (i % #phrase-books))
   (book-phrases i) (map (p \ p 1) (book i 1)))
) ; module phrases
