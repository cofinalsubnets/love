; (show x) -> string. Heap-allocates a data-sink port, prints x through
; gfputx, returns the harvested bytes. Should match what (. x) writes to stdout.

(assert
  ; numbers
  (= "42"   (show 42))
  (= "-7"   (show -7))
  (= "0"    (show 0))

  ; "" is a distinct empty string, printed as a pair of quotes
  (= "\"\""           (show ""))
  ; strings: printed with surrounding quotes; specials re-escaped
  (= "\"hi\""         (show "hi"))
  (= "\"a\\nb\""      (show "a\nb"))
  (= "\"a\\tb\""      (show "a\tb"))
  (= "\"\\\\\""       (show "\\"))
  (= "\"\\\"\""       (show "\""))

  ; interned symbols print as their name
  (= "foo" (show 'foo))
  ; gensyms print with the `$` sigil: named-uninterned as $<name>, anonymous as
  ; $<addr>. display form only -- `$` READS as the sat operator now.
  (= "$x" (show (nom "x")))
  (= "$foo" (show (nom 'foo)))
  (= "$" (slice (show (nom 0)) 0 1))           ; anonymous -> $<addr>
  (symp (gsym x))
  (= "$bar" (show (gsym bar)))

  ; quote sugar: a pair (` x) prints as 'x
  (= "'foo"      (show ''foo))
  (= "'(a b)"    (show ''(a b)))

  ; proper lists
  (= "(a b c)"       (show '(a b c)))
  (= "(1 2 3)"       (show (cons 1 (cons 2 (cons 3 0)))))
  (= "(\"a\" \"b\")" (show (cons "a" (cons "b" 0))))

  ; nesting
  (= "(a (b) c)"     (show (cons 'a (cons (cons 'b 0) (cons 'c 0)))))
  (= "((1 2) (3 4))" (show '((1 2) (3 4))))

  ; result is always a string
  (strp (show 0))
  (strp (show "hi"))
  (strp (show '(1 2 3)))
  (strp (show (table 0)))

  ; buffer growth: a 200-element list far exceeds the 32-byte initial buf,
  ; forcing several doublings inside to_putc.
  (: (rng n) (? (= n 0) 0 (cons n (rng (- n 1))))
     s (show (rng 200))
     ; 200 numbers + 199 separators + 2 parens = at least 400 chars
   (do (strp s) (< 400 (sat s))))

  ; GC stress: 500 inspects in a loop. Each call alloc'd a heap port + buf,
  ; provoking many GCs. Final call must still produce the expected output.
  (: (loop n) (? (= n 0) (show (cons 1 (cons 2 (cons 3 0))))
                 (do (show "stress") (loop (- n 1))))
   (= "(1 2 3)" (loop 500))))
