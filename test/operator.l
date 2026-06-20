; the operator table -- ONE table, `operators`: sigil symbol -> arity (the symbol
; names itself) | (name . arity) (an alias), arity 1-7. the reader is structural
; (a sigil -- a maximal all-punct token -- reads as one plain symbol); code factors
; sigils against the table at COMPILE time (the opfix pass), so a pin in one form
; governs the next form -- the test runner reads and compiles one form at a time.
(: op-tbl operators)             ; leak to global scope for this file
(assert (book? op-tbl)
 ((link 'sat 1) = (op-tbl '$)) ((link 'nil? 1) = (op-tbl '!)) ((link 'dot 1) = (op-tbl '.))
 (2 = (op-tbl '+)) (2 = (op-tbl '-)) (2 = (op-tbl '%)) (3 = (op-tbl '?))
 ((link 'pin 3) = (op-tbl '<-)) ((link 'peep 3) = (op-tbl '->)))

; reading is structural: a sigil from a port is just the symbol, no table consulted
(assert ('^ = (sound (tap '(94)) 99)) ('+ = (sound (tap '(43)) 99)))

; wire ^^ as a temporary alias at two (list); restored below. ^ itself stays the
; xor nif throughout -- the factorization law is greedy longest-prefix, so the
; two-char key wins while pinned (^ alone could never chain: a non-last factor
; must be arity one and ^ is at two).
(pin op-tbl '^^ (link 'list 2))
(assert
 ('(1 2) = (1 ^^ 2))                            ; infix: captures the left operand
 ('(1 (2 3)) = (1 ^^ 2 ^^ 3))                   ; nests RIGHT-associatively
 ('(5 (1 2)) = `(5 (1 ^^ 2)))                  ; works inside lists
 ('("a" 7) = ("a" ^^ (tally "seven!!"))))      ; composes with the count word

; rebind: an alias at three, then at one
(pin op-tbl '^^ (link 'L 3))
(assert ('(1 2 3) = (1 ^^ 2 3)) ('((1 2 3) 4 5) = ((1 ^^ 2 3) ^^ 4 5)))
(pin op-tbl '^^ (link 'up 1))
(: up (+ 1)                                     ; a local 1-ary global to alias ^^ to
 (assert (6 = ^^5) (7 = ^^^^5)                  ; at one: prefix; chains factor greedily
         (0 = !^^5)))                           ; mixed chain: (nil? (up 5))

; restore: unpinned, ^^ no longer factors (^ is at two, can't lead a chain),
; so it reads as a plain symbol again
(pull op-tbl '^^ 0)
(assert !(op-tbl '^^) (nom? '^^) ("(^^ 5)" = (show (opfix '(^^ 5))))
        (-2 = (^ 1 -1)) (6 = (^ 5 3)))          ; ^ was the xor nif all along
