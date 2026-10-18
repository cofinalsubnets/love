; text -- a text front end for the neutral assembler, on the peg combinators. lines like
;     li   r0, 60        ; a comment
;     label loop
;     br   eq, loop
; become the IR ((li r0 60) (label loop) (br eq loop)) that holo.l assembles. one line, one
; instruction; operands split on spaces and/or commas; a register or label is a symbol, an
; immediate an optionally negative integer. no arch here: mooncc's inline asm uses asm-text.
; binds no assembler names, so it loads in the raw holo.l stream and on the baked host alike.

; the borrow is its own top-level form: inside the `:` below it would run too late to serve it
(module 'holo
(borrow 'peg)

(:
   (txsep? c) (blank? c || c = 44)
   (txidc? c) (alnum? c || c = 95 || c = 45)                ; _ and -

   ;; a payload piece is a string from `one` or `span`, so `+` joins them
   txjoin (foldl (+) "")
   (txint s)   (foldl (a \ i \ a * 10 + s i - 48) 0 ^#s)
   (txnum p)   (<p = "-" ? -(txint (txjoin >p)) (txint (txjoin p)))

   ;; a token is at least one char, so `many` can't spin on the empty match
   txtsym (pmap (x \ [(name (txjoin x))]) (seq (one txidc?) (span txidc?)))
   txtnum (pmap (x \ [(txnum x)]) (seq (opt (lit "-")) (seq (one digit?) (span digit?))))
   txop   (alt txtnum txtsym)
   txgap  (skip (span txsep?))
   txline (seq txtsym (many (seq txgap txop)))

   (txdecomment s) (#s @ n
                      ((: (g i) (? (i >= n) s (s i = 59) (snip s 0 i) (g (i + 1)))) 0))
   (txtrim s) (: n #s
      a ((: (gl i) (i < n && blank? (s i) ? (gl (i + 1)) i)) 0)
      b ((: (gr j) (j > a && blank? (s (j - 1)) ? (gr (j - 1)) j)) n)
      (snip s a b))
   (txsplit s) (#s @ n
                  ((: (g i start acc)
                      (? (i >= n)     (rev (snip s start n . acc))
                         (s i = 10) (g (i + 1) (i + 1) (snip s start i . acc))
                         (g (i + 1) start acc)))
                   0 0 ()))

   ;; text -> IR. blank lines vanish; a line that won't parse raises, so a typo drops nothing.
   ;; assembling is the caller's: (holo-hex t (asm-text s))
   (asm-text src)
      (foldr (\ ln acc
                (txtrim (txdecomment ln) @ clean
                   (0 = #clean ? acc
                    (parse txline clean @ form
                       (two? form ? (form . acc) (scare 'asm-text clean))))))
             () (txsplit src)))
) ; module 'holo
