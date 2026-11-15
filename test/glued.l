; multi-char glued sigils. the factor walk runs right to left, longest first. the reader
; half is `sound`, the factor half opfix
(: (rdr s) (sound s @ (r . _) r r r))

(test
 ; --- the reader: a run glued to a datum wraps it, and fuses with the next datum
 ('(mono (<> x)) = (rdr "<>x"))
 ('(mono (<> (list 1 2))) = (rdr "<>[1 2]"))
 ('(mono (! -5)) = (rdr "!-5"))                      ; a `-` before a digit sheds as its sign
 ('<> = (rdr "<>"))                                  ; nothing glued after it: the plain symbol
 ; a token is a numeral or a name to its end: neither a digit nor a name lead cuts at a sigil
 (1.5 = (rdr "1.5")) (0.5 = (rdr "0.5")) (0.0015 = (rdr "1.5e-3")) (31 = (rdr "0x1f"))
 ('a<>b = (rdr "a<>b")) ('2?<>x = (rdr "2?<>x"))

 ; --- the factor pass, and the value
 ('(cap (cup x)) = unglue (opfix '<>x))
 ('(nil? (cup x)) = unglue (opfix '!>x))
 (2 = <>[1 2 3]) (1 = !>[7]) (0 = !>[7 8]))

; --- right to left: two rows overlapping mid-run, the walk takes >| then <
(test
 (: w1 (grip 0 '<> 'tally) w2 (grip 0 '>| 'net)
    tree (unglue (opfix '<>|x))
    (grip 0 '<> w1, grip 0 '>| w2,
     tree = '(cap (net x))))
 ; and it backtracks: |< leaves an & with no row, so the walk takes < and then &|
 (: w1 (grip 0 '|< 'tally) w2 (grip 0 '&| 'net)
    tree (unglue (opfix '&|<x))
    (grip 0 '|< w1, grip 0 '&| w2,
     tree = '(net (cap x)))))

; --- the shadow law: a glued row factors to a value, so `<x` is cap wherever it is
; written and a binding of `cap` is just a binding; a nom row resolves at the use site ---
(test
 (1 = (: cap 5 ((v \ <v) '(1 2 3))))                ; <v stays cap
 (5 = (: cap 5 cap))                                ; ..and the binding still stands
 (6 = (: net 'not-a-fn ((l \ +l) '(1 2 3))))         ; a love-closure row is reached the same way
 (1 = (: nil? 0 ((l \ !l) ())))                      ; ..and one that is a nif's
 (2 = ((l \ (: cap <l cup >l (cap + tally cup))) '(1 2)))) ; the two names bound and the sigils used, one form

; --- opnom / unglue: the words back from value heads, for readers of post-opfix source ---
(test
 ('cap = opnom cap) ('jot = opnom jot) ('two? = opnom two?) ('nil? = opnom nil?)
 (0 = opnom 5) (0 = opnom 'cap) (0 = opnom '(1 2))   ; a miss is 0; a list never reaches the hash
 ('(cap (cup x)) = unglue (opfix '<>x))
 ('(+ (f (abs x)) (cap (cup y))) = unglue (opfix '(f |x + <>y)))
 (opfix '(cap x) = unglue (opfix '<x))          ; the two spellings meet at one tree
 ('(a (cap b)) = unglue '(a (cap b)))             ; a tree of words is already unglued: idempotent
 ; and the printer says the word, so a glued body reads as the prefix one does
 ("(cap x)" = show (opfix '<x))
 ("(jot x)" = show (opfix '^x))
 ("(net x)" = show (opfix '+x)))
