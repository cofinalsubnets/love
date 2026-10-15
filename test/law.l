; --- the language's laws, quantified: a free `x` means "forall x, this is 1" ---
(: law-flat [0 1 2 5 -1 -5 2.5 -2.5 0.0 () "" "a" "ab" 'sym '(1 2) '(-2 1)
              (twin 3 4) (twin -1 2) (twin 0 3) @() @(1 2) @(1 2 3) (7 /// 2) (-7 /// 2) cap 'x]
   law-jot [^0 ^1 ^2 ^4 ^5 ^^0 ^^1 ^^2 ^^4 ^^5 ^^^0 ^^^1 ^^^2 ^^^3 ^^^4 ^^^^3]
   law-corpus (law-flat + law-jot)
   ; a law is (nom . closure), holding when every value answers 1 (a tray, a mask of all 1)
   (law-bad f) (: (go l) (? (atom? l) ()
                            (aall (1 = f <l)) (go >l)
                            [1 <l])                       ; (1 witness) -- presence, not the value
                  (go law-corpus))
   (law-run r) (: nom <r f <>r b (law-bad f)
                  (? (two? b)
                     (puts ("law FAILED: " + string nom + "   at " + show <>b + "\n"), 0)
                     1))
   law-rows
    [
      ; --- each glued sigil is its word
      ['cap      (x \ <x = cap x)]
      ['cup      (x \ >x = cup x)]
      ['net      (x \ +x = net x)]
      ['saturate (x \ $x = saturate x)]
      ['nil?     (x \ !x = nil? x)]
      ['abs      (x \ |x = abs x)]
      ['negate   (x \ -x = negate x)]
      ['jot      (x \ ^x = jot x)]
      ; --- the little schemer's five, total: an atom is its own cap, its cup is ()
      ['cap-total  (x \ two? x ? 1 (x = <x))]
      ['cup-total  (x \ two? x ? 1 (() = >x))]
      ['link-apart (x \ : p (x . x) (<p = x && >p = x))]
      ['link-back  (x \ two? x ? (x = (. <x >x)) 1)]
      ['nil?-total (x \ : b !x (b = 0 || b = 1))]
      ['=-total    (x \ : b (x = x) (b = 1))]
      ['==-finer  (x \ x == x ? (x = x) 1)]            ; == implies =, never the converse
      ; --- the measure and its tower: each rung is idempotent, a retraction not a conversion
      ['net-idem  (x \ : n +x (n = +n))]
      ['re-idem   (x \ coin? x ? 1 (: r (re +x) (r = re +r)))]
      ['ceil-idem (x \ : c (ceil x) (c = ceil c))]
      ['sat-idem  (x \ : s $x (s = $s))]
      ['bit-idem  (x \ : b ?x (b = ?b))]
      ['ceil-net  (x \ coin? x ? 1 (ceil x = ceil (re +x)))]   ; ceil retracts onto the integers
      ['sat-ceil  (x \ $x = (0 < ceil x ? (ceil x) 0))] ; saturate is ceil, floor raised to 0
      ; --- int/ceil/saturate on a ratio long-divide, exact past 2^53 where the float net rounds
      ['ratio-rungs (_ \ : b ((60 2) + 1)
                          s (word ? 1 (32 2))
                          (all (p \ : n <p d <>p c (ceil (n /// d))
                                    (int (n /// d) = n // d
                                     && c = n // d + (0 < n && 0 != n % d ? 1 0)
                                     && saturate (n /// d) = (0 < c ? c 0)))
                               [[7 2] [-7 2] [0 5] [b (3 * s)] [-b (3 * s)]
                                [b s] [(b * b) (b * s)]]))]
      ['add-assoc
       (x \ lit? x || coin? x || tray? x ? 1
            (: ws [0 2 -5 2.5 (twin 3 4) () "" "ab" 'sym '(1 2) '(-2 1)]
               ; no carve: text splices into a chain by the charlist hom
               (ok? y z) (((x + y) + z) = (x + (y + z)))
               (all (y \ all (ok? y) ws) ws)))]
      ['mul-assoc
       (x \ lit? x || coin? x ? 1
            (: ws [0 2 -5 2.5 (twin 3 4) () "" "ab" 'sym '(1 2) @(1 2)]
               (ch v) (two? v ? 1 0)
               (txt? v) (string? v || (v = () ? 0 (nom? v)))
               ; chain * chain reassociates into another nesting; text demotes to repetition
               (ok? y z) (? (coin? y || coin? z) 1
                            (ch x && (ch y || ch z) && !(txt? y) && !(txt? z)) 1
                            (aall (((x * y) * z) = (x * (y * z)))))   ; a tray's = is a mask
               (all (y \ all (ok? y) ws) ws)))]
      ; --- * on chains is the cartesian product: associative up to reL, the reassociation iso
      ['mul-reassoc
       (x \ !(two? x) ? 1
            (: cs ['(1 2) '(3) '(4 5 6) ()]
               (reL p) (: q <p [<q [<>q <>p]])
               (ok? b c) ((map reL ((x * b) * c)) = (x * (b * c)))
               (all (b \ all (ok? b) cs) cs)))]
      ; a count floats out of the product
      ['mul-count-out
       (x \ !(two? x) ? 1
            (: cs ['(1 2) '(3) '(4 5 6) ()]
               ns [0 1 2 3]
               (ok? n c) (((x * n) * c) = ((x * c) * n))
               (all (n \ all (ok? n) cs) ns)))]
      ; tally is the product's homomorphism into (naturals, *)
      ['mul-tally-hom
       (x \ !(two? x) ? 1
            (: cs ['(1 2) '(3) '(4 5 6) ()]
               (ok? b) (#(x * b) = #x * #b)
               (all ok? cs)))]
      ['mul-dist
       (x \ lit? x || coin? x ? 1
            (: ms [0 1 2 5]
               nums [0 2 -5 2.5 (twin 3 4)]
               act (all (m \ all (n \ aall ((x * (m + n)) = ((x * m) + (x * n)))) ms) ms)
               num (two? x || tray? x || string? x || (x = () ? 0 (nom? x)) ? 1
                    (all (y \ all (z \ (x * (y + z)) = ((x * y) + (x * z))) nums) nums))
               cart (two? x
                     ? (: bs ['(3) '(-2 1)]
                          (all (a \ all (b \ ((a + b) * x) = ((a * x) + (b * x))) bs) bs))
                       1)
               (act && num && cart)))]
      ['bit-sat   (x \ ?x = (0 < $x))]                      ; bit is saturate, ceiling lowered to 1
      ['nil?-bit  (x \ !x = (0 = $x))]                      ; nil? is bit's complement
      ['sat-net   (x \ $x = $(net x))]                      ; ..so $ factors through the net: one clamp, at the end
      ['bit-nil   (x \ ?x = !!x)]                           ; ..and the bit is nil?'s own double negation
      ['sat-green (x \ : s $x (0 <= s && charm? s))]        ; ..and the codomain each names
      ['bit-bool  (x \ : b ?x (b = 0 || b = 1))]
      ['apply-is-id (x \ atom? x ? 1 (<x = (cap $ x)))]
      ; --- the language advisories, as laws
      ['unit-f     (x \ : (g _) x (g = (g)))]             ; (f) == f: a nullary call is the value
      ['curry      (x \ charm? x ? (((x +) 2) = (x + 2)) 1)]
      ['seq        (x \ : y 1 y (y + 1) (y = 2))]         ; the sequence law: a rebind reads the previous
      ['empty-form (x \ ((:) = ()))]]
   law-ok (foldl (a \ r \ a + law-run r) 0 law-rows)
   (test (law-ok = tally law-rows)))
