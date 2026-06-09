; (inspect x) -> string. Heap-allocates a data-sink port, prints x through
; gfputx, returns the harvested bytes. Should match what (. x) writes to stdout.

(assert
  ; numbers
  (= "42"   (inspect 42))
  (= "-7"   (inspect -7))
  (= "0"    (inspect 0))

  ; "" is a distinct empty string, printed as a pair of quotes
  (= "\"\""           (inspect ""))
  ; strings: printed with surrounding quotes; specials re-escaped
  (= "\"hi\""         (inspect "hi"))
  (= "\"a\\nb\""      (inspect "a\nb"))
  (= "\"a\\tb\""      (inspect "a\tb"))
  (= "\"\\\\\""       (inspect "\\"))
  (= "\"\\\"\""       (inspect "\""))

  ; interned symbols print as their name
  (= "foo" (inspect 'foo))
  ; gensyms print with the `$` sigil: named-uninterned as $<name>, anonymous as
  ; $<addr>. the `$` reader macro wraps with nom, so $x re-reads to a symbol.
  (= "$x" (inspect (nom "x")))
  (= "$foo" (inspect (nom 'foo)))
  (= "$" (ssub (inspect (nom 0)) 0 1))           ; anonymous -> $<addr>
  (symp $x)                                          ; $x reads back as a (fresh) symbol
  (= "$bar" (inspect $bar))

  ; quote sugar: a pair (` x) prints as 'x
  (= "'foo"      (inspect ''foo))
  (= "'(a b)"    (inspect ''(a b)))

  ; proper lists
  (= "(a b c)"       (inspect '(a b c)))
  (= "(1 2 3)"       (inspect (X 1 (X 2 (X 3 0)))))
  (= "(\"a\" \"b\")" (inspect (X "a" (X "b" 0))))

  ; nesting
  (= "(a (b) c)"     (inspect (X 'a (X (X 'b 0) (X 'c 0)))))
  (= "((1 2) (3 4))" (inspect '((1 2) (3 4))))

  ; result is always a string
  (strp (inspect 0))
  (strp (inspect "hi"))
  (strp (inspect '(1 2 3)))
  (strp (inspect (hashn 0)))

  ; buffer growth: a 200-element list far exceeds the 32-byte initial buf,
  ; forcing several doublings inside to_putc.
  (: (rng n) (? (= n 0) 0 (X n (rng (- n 1))))
     s (inspect (rng 200))
     ; 200 numbers + 199 separators + 2 parens = at least 400 chars
   (do (strp s) (< 400 (pin s))))

  ; GC stress: 500 inspects in a loop. Each call alloc'd a heap port + buf,
  ; provoking many GCs. Final call must still produce the expected output.
  (: (loop n) (? (= n 0) (inspect (X 1 (X 2 (X 3 0))))
                 (do (inspect "stress") (loop (- n 1))))
   (= "(1 2 3)" (loop 500))))
