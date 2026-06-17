; (show x) -> string. Heap-allocates a data-sink port, prints x through
; gfputx, returns the harvested bytes. Should match what (. x) writes to stdout.

(assert
  ; numbers
  (= "42"   (show 42))
  (= "-7"   (show -7))
  (= "0"    (show 0))

  ; "" is a distinct empty string, printed as a chain of quotes
  (= "\"\""           (show ""))
  ; strings: printed with surrounding quotes; specials re-escaped
  (= "\"hi\""         (show "hi"))
  (= "\"a\\nb\""      (show "a\nb"))
  (= "\"a\\tb\""      (show "a\tb"))
  (= "\"\\\\\""       (show "\\"))
  (= "\"\\\"\""       (show "\""))

  ; interned symbols print as their name
  (= "foo" (show 'foo))
  ; a mint prints (mint 0) -- re-reads to a FRESH point, the mutables'
  ; round-trip (identity is the mint's whole product; no spelling carries it).
  ; the old $<name> form died with the named-uninterned species: a nom is a
  ; chain now and prints like one.
  (= "(mint 0)" (show (mint 0)))
  (nomp (mint 0))
  (= "(mint 0)" (show (mint 'bar)))

  ; quote sugar: a chain (` x) prints as 'x
  (= "'foo"      (show ''foo))
  (= "'(a b)"    (show ''(a b)))

  ; proper lists
  (= "(a b c)"       (show '(a b c)))
  (= "(1 2 3)"       (show (link 1 (link 2 (link 3 0)))))
  (= "(\"a\" \"b\")" (show (link "a" (link "b" 0))))

  ; nesting
  (= "(a (b) c)"     (show (link 'a (link (link 'b 0) (link 'c 0)))))
  (= "((1 2) (3 4))" (show '((1 2) (3 4))))

  ; result is always a string
  (strp (show 0))
  (strp (show "hi"))
  (strp (show '(1 2 3)))
  (strp (show (tablet 0)))

  ; buffer growth: a 200-element list far exceeds the 32-byte initial buf,
  ; forcing several doublings inside to_putc.
  (: (rng n) (? (= n 0) 0 (link n (rng (- n 1))))
     s (show (rng 200))
     ; 200 numbers + 199 separators + 2 parens = at least 400 chars
   (do (strp s) (< 400 (tally s))))

  ; GC stress: 500 inspects in a loop. Each call alloc'd a heap port + buf,
  ; provoking many GCs. Final call must still produce the expected output.
  (: (loop n) (? (= n 0) (show (link 1 (link 2 (link 3 0))))
                 (do (show "stress") (loop (- n 1))))
   (= "(1 2 3)" (loop 500))))
