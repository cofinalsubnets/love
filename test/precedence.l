; precedence (band) and associativity (hand): a tighter incoming operator steals the pending
; operand, an equal one goes by its hand. arithmetic, shifts and bitwise fold left, the rest right
(test
 ; --- the tree: opfix factors a quoted form ---
 ((opfix '(2 * 3 + 4)) = '(+ (* 2 3) 4))
 ((opfix '(a * b + c)) = '(+ (* a b) c))
 ((opfix '(a + b * c)) = '(+ a (* b c)))
 ((opfix '(a + b + c)) = '(+ (+ a b) c))            ; the additive band folds left
 ((opfix '(10 - 2 - 3)) = '(- (- 10 2) 3))
 ((opfix '(a / b / c)) = '(/ (/ a b) c))
 ((opfix '(a . b . c)) = '(. a (. b c)))        ; cons stays right-handed: a builder folds right
 ((opfix '(a <+> b <+> c)) = '(<+> a (<+> b c)))    ; a coined operator defaults to right hand, house band
 ((opfix '(3 = 1 + 2)) = '(= 3 (+ 1 2)))
 ((opfix '(a < b && c < d)) = '(&& (< a b) (< c d)))
 ((opfix '(a < b || c < d)) = '(|| (< a b) (< c d))) ; a rung under &&
 ((opfix '(a && b || c && d)) = '(|| (&& a b) (&& c d)))
 ((opfix '(c && 0 < c && c < 10))                   ; a guard chain nests for pat.l to flatten
  = '(&& c (&& (< 0 c) (< c 10))))
 ; the bitwise ops and shifts sit between comparison and arithmetic, in c's order
 ((opfix '(a + b & c)) = '(& (+ a b) c))            ; an align-up owes no parens
 ((opfix '(a | b + c)) = '(| a (+ b c)))
 ((opfix '(a & b | c ^ d)) = '(| (& a b) (^ c d)))
 ((opfix '(a & b & c)) = '(& (& a b) c))
 ((opfix '(x & 15 = 15)) = '(= (& x 15) 15))        ; above comparison, so a mask reads
 ((opfix '(x ^ y = z)) = '(= (^ x y) z))
 ((opfix '(v >> 8 & 255)) = '(& (>> v 8) 255))
 ((opfix '(f & 1 << n)) = '(& f (<< 1 n)))          ; the reading a bit test wants
 ((opfix '(x << 8 + y)) = '(<< x (+ 8 y)))          ; under additive: a shifted sum owes parens
 ((opfix '(a << b << c)) = '(<< (<< a b) c))
 ((opfix '(1 < 2 ? x)) = '(? (< 1 2) x))            ; ? loosest: the whole comparison is the condition
 ; a clause form collects its arms flat, as the prefix spelling does
 ((opfix '(1 < 2 ? x y)) = '(? (< 1 2) x y))
 ((opfix '(c ? a b d e)) = '(? c a b d e))
 ((opfix '(x @ p1 b1 p2 b2)) = '(@ x p1 b1 p2 b2))
 ((opfix '(f y z @ p b)) = '(@ (f y z) p b))        ; the whole leading span is the scrutinee
 ((opfix '(c ? x @ p b)) = '(? c (@ x p b)))        ; equal band, right hand: the inner clause form folds first
 ((opfix '(c ? a x @ p b)) = '(? c a (@ x p b)))
 ((opfix '(x @ p c ? a b)) = '(@ x p (? c a b)))
 ; a clause form inside its own kind owes parens: a nested @ eats the outer's arms
 ((opfix '(x @ p1 y @ q c p2 b2)) = '(@ x p1 (@ y q c p2 b2)))
 ((opfix '(x @ p1 (y @ q c) p2 b2)) = '(@ x p1 (@ y q c) p2 b2))
 ((opfix '(c1 ? a1 c2 ? a2 e)) = '(? c1 a1 (? c2 a2 e)))
 (7 = (0 ? 1 1 ? 7 9)) (7 = (? 0 1 1 7 9))
 ((opfix '(x @ p b $ y)) = '($ (@ x p b) y))        ; $ is looser, so it takes the whole match
 ((opfix '(c ? a + b)) = '(? c (+ a b)))            ; an n-ary frame yields its last operand to a tighter op
 ((opfix '(? c a b)) = '(? c a b))                  ; the prefix spelling is a fixed point
 (: r (grip -1 '? ()) (grip -1 '? r, r = 10))         ; the arity is the lane; the door restores exactly
 ((opfix '(a + b . c)) = '(. (+ a b) c))
 ((opfix '(a :+ b . c)) = '(. (:+ a b) c))         ; a coined op at house band beats .
 ((opfix '(a :+ b + c)) = '(+ (:+ a b) c))          ; house is the tightest band
 ((opfix '(a :+ b ** c)) = '(** (:+ a b) c))
 ((opfix '(a :+ b && c)) = '(&& (:+ a b) c))
 ((opfix '(a + b :+ c)) = '(+ a (:+ b c)))

 ; --- ** flip-applies at the tightest band, $ weak-applies near the loosest; glued $x saturates ---
 ((opfix '(a ** b * c)) = '(* (** a b) c))
 ((opfix '(a * b ** c)) = '(* a (** b c)))
 ((opfix '(f $ a + b)) = '($ f (+ a b)))
 ((opfix '(f $ g $ x)) = '($ f ($ g x)))            ; right-assoc, haskell's $
 ((opfix '(a ** b $ c)) = '($ (** a b) c))

 ; --- the infix lambda is looser than $, so a body runs to the end of the form ---
 ((opfix '(x \ f $ g x)) = '(\ x ($ f (g x))))
 ((opfix '(x \ a + b)) = '(\ x (+ a b)))
 ((opfix '((x \ x + 1) $ 9)) = '($ (\ x (+ x 1)) 9))  ; so applying one owes its parens

 ; --- idempotence: factored output is a fixed point ---
 ((opfix (opfix '(a * b + c))) = (opfix '(a * b + c)))

 ; --- the value: numbers where the grouping shows ---
 (10 = (2 * 3 + 4))
 (14 = (2 * (3 + 4)))
 (7 = (1 + 2 * 3))
 (5 = (10 - 2 - 3))                                   ; the right hand would read 11
 (1 = (8 / 4 / 2))                                    ; the right hand would read 4
 (3 = (2 - 3 + 4))
 (1 = (3 = 1 + 2))
 (1 = (0 < 5 && 5 < 10))
 ('big = (1 < 2 ? 'big))                              ; ? is dyadic: the one-armed cond
 (4 = (3 ** (+ 1)))                                   ; ** flip-applies: ((+ 1) 3)
 (8 = (2 * 3 ** (+ 1)))
 (6 = ((+ 1) $ 2 + 3))
 (10 = ((x \ x + 1) $ 9))
 (10 = ((x \ x + 1) 9))
 (13 = ((+ 1) $ (+ 2) $ 10))
 (0 = $-5) (3 = $2.9)                                 ; glued $x is saturate, not weak-apply

 ; --- (grip ar nm v) sets an operator's row, answering the one replaced; each test restores
 ; in its own form, or the next form would parse differently ---
 (: was (grip 2 '<+> -60)                           ; haskell's `infixl 7 <+>`: minus is the left hand
    tree (opfix '(a <+> b <+> c))
    (grip 2 '<+> was,
     was = () && tree = '(<+> (<+> a b) c)))
 (: _ (grip 2 '<+> 60)                       ; `infixr 7`: a positive band is right-handed
    tree (opfix '(a <+> b <+> c))
    (grip 2 '<+> (),
     tree = '(<+> a (<+> b c))))
 (: _ (grip 2 '<+> -60)
    prev (grip 2 '<+> ())                                        ; () clears, answering what it cleared
    (prev = -60 && ((opfix '(a <+> b * c)) = '(* (<+> a b) c)))) ; back to house band, above *
 ((grip 2 '<+> ()) = ())
 (: _ (grip 2 '=: '(pin 20))                                     ; the (nom band) alias: a target with no row to lend
    tree (opfix '(t =: k))
    (grip 2 '=: (),
     tree = '(pin t k)))
 (: was (grip 2 '+ -70)
    tree (opfix '(a + b * c))
    (grip 2 '+ was,
     tree = '(* (+ a b) c) && ((opfix '(a + b * c)) = '(+ a (* b c)))))
 ; a bad shape is refused with a scare, never pinned: it would silently demote its operator
 (!(catch (_ \ grip 2 '^^ 0)))                        ; a table miss answers 0, so 0 can never be a row
 (!(catch (_ \ grip 2 '^^ '(a b))))
 (!(catch (_ \ grip 2 '^^ 'zzz)))                     ; an alias to a word with no row
 (!(catch (_ \ grip 2 'plain 60)))                    ; the name must be an all-punct sigil
 ((opfix '(x ^^ y ^^ z)) = '(^^ x (^^ y z))))

(test
 ; --- chaining: a comparison run is the && of its links, each operand once, short-circuiting;
 ; parens opt out ---
 (1 < 2 < 3) !(2 < 1 < 3) !(1 < 3 < 2)
 (1 < 2 <= 2 < 5)
 (3 > 2 > 1) !(0 = 1 = 2)
 (1 < 1 + 1 < 3)
 ; a link may be a span: juxtaposition binds tighter
 (: s "a1" (97 <= s 0 <= 122))
 (: s "a1" !(48 <= s 0 <= 57))
 (: s "ab" (s 0 < s 1 < 99))
 (: t (tablet 0) _ (pin t 0 0)                        ; a span link is evaluated once
    (bump v) (pin t 0 (1 + peep t 0 0), 2)
    r (1 < bump () < 3)
    (r && (1 = (peep t 0 0))))
 (0 = (1 < (2 < 3)))                                  ; (< 2 3) is 1, and (< 1 1) is 0
 ((show (opfix '(a < b))) = (show '(< a b)))
 ((show (opfix '(< a (< b c)))) = (show '(< a (< b c))))
 (: t (tablet 0) _ (pin t 0 0)                        ; the shared operand runs once
    (bump v) (pin t 0 (1 + peep t 0 0), 2)
    r (1 < (bump ()) < 3)
    (r && (1 = (peep t 0 0))))
 (: t (tablet 0) _ (pin t 0 0)                        ; a false link never reaches the rest
    (bump v) (pin t 0 999, 9)
    r (2 < 1 < (bump ()))
    (!r && (0 = (peep t 0 0)))))
(test
 (!(catch (_ \ grip 7 '^^ 60)))                     ; a lane with no key is refused, never minted

 ; --- the glued lane, arity 0: `?` is `bit` glued and cond spaced ---
 (: r (grip 0 '? ()) (grip 0 '? r, opnom r = 'bit))     ; clear-and-restore is the non-destructive read
 ; the fixture needs a sigil with no glued row
 (: was (grip 0 '& 'cup)
    tree (opfix '&x)
    (grip 0 '& was,
     was = () && tree = '(cup x)))
 ((unglue (opfix '?5)) = '(bit 5))

 ; --- && and || stay lazy ---
 (: t (tablet 0) _ (pin t 0 0)
    r (1 || (pin t 0 999))
    (r = 1 && (0 = (peep t 0 0))))
 (: t (tablet 0) _ (pin t 0 0)
    r (0 && (pin t 0 999))
    (!r && 0 = peep t 0 0)))
