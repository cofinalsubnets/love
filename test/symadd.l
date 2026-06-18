; symbols left the string algebra (the mint round): a symbol is a point with a
; spelling ATTRIBUTE, not a string. + and * involving a symbol are nil in every
; direction; applying a symbol is const-1 (the unit action -- the name index is
; gone); intern and string are the EXPLICIT bridge, and a nom's name is its cap.
; strings keep the whole algebra (concat, the byte law, repetition) -- the byte
; column is unaffected; only the symbol band released it.

(: sa-z (intern "")
 (assert
  ; --- the release: no + in any direction ---
  !('ef + 'ef) !('a + 'b)                       ; sym + sym
  !("ab" + 'ef) !('ef + "ab")                   ; sym <-> string
  !(65 + 'ef) !('ef + 65)                       ; sym <-> number
  !(@(1 2) + 'ef) !('ef + @(1 2))               ; sym <-> array
  !(sa-z + 'ef) !('ef + sa-z)                   ; (intern "") is 0: nothing has no algebra
  !(sa-z + sa-z)
  ; --- no * either ---
  !('xy * 2) !(2 * 'xy) !('a * 'b) !(sa-z * 2)
  ; --- apply: const-1, uniformly (the unit action; no more name indexing) ---
  (1 = ('xyz 1)) (1 = ('xyz 0)) (1 = (sa-z 5)) (1 = ((mint 0) 'x))
  ; --- lists still take any element, symbols included (the list law, not string algebra)
  ('(ef 1 2) = ('ef + '(1 2)))
  ; --- the explicit bridge survives ---
  ("asdf" = (string 'asdf)) ('asdf = (intern "asdf"))
  ('xy = (intern (string 'xy)))                 ; intern . string = identity on interned
  (id? sa-z (intern ""))
  ; --- noms carry their name as data: the chain's cap ---
  ("cd" = (cap (nom "cd"))) ("cd" = (cap (nom 'cd)))
  ; --- strings keep everything ---
  ("abcd" = ("ab" + "cd")) ("Aab" = (65 + "ab")) ("abA" = ("ab" + 65))
  ("ababab" = ("ab" * 3)) ("" = ("" + ""))))

; --- mint serials: the total order is TOTAL over symbols -------------------
; every mint draws a serial from the one stream (pids share it); symbols
; order by name, then interned-first, then serial (creation order); noms
; (chains) inherit the chain order through chain lex + the mint tiebreak.
(: a (nom 'q) b (nom 'q) c (nom 'q)
   n1 (mint 0) n2 (mint 0)
 (assert
  (a < b) (b < c) (a < c) !(b < a) !(c < b)     ; strict, transitive, by creation
  !(a = b) !(b = c)                             ; the mint inside keeps = identity-sharp
  (n1 < n2) !(n2 < n1) !(n1 = n2)               ; mints order by creation too
  (() < n1) !(n1 < ())                          ; the zero point sits first among the nameless
  (n1 < 'q)                                     ; nameless below named (lex on "")
  ('(1 2 3) = (map cup (sort (L (link c 3) (link a 1) (link b 2)))))  ; sort sees the serials
  ; GC stability: the order survives heap churn (serials ride the copy)
  (: pre (L (a < b) (n1 < n2) (() < n1))
     _ ((: (churn k) (? (< 0 k) (: _ (map (\ i (string (mint 0))) '(1 2 3 4 5 6 7 8)) (churn (- k 1))) 0)) 500)
     (pre = (L (a < b) (n1 < n2) (() < n1))))
  ; the serial is the mint's hash: same-name noms key a map apart, stably
  (: t (tablet 0) _ (pin t a 'one) _ (pin t b 'two)
     (&& ('one = (t a)) ('two = (t b)) (2 = $t)))))
