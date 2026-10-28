; (show x) -> string, what printing x writes

(test
  ; numbers
  ("42" = show 42)
  ("-7" = show -7)
  ("0" = show 0)

  ; "" is a distinct empty string, printed as a chain of quotes
  ("\"\"" = show "")
  ; strings: printed with surrounding quotes; specials re-escaped
  ("\"hi\"" = show "hi")
  ("\"a\\nb\"" = show "a\nb")
  ("\"a\\tb\"" = show "a\tb")
  ("\"a\\eb\"" = show "a\eb") ; \e is ESC, the terminal's own letter
  ("\e" = "\x1b")             ; ... and just byte 27
  ("\"\\\\\"" = show "\\")
  ("\"\\\"\"" = show "\"")

  ; interned symbols print as their name
  ("foo" = show 'foo)
  ; a mint prints (mint <serial>): it re-reads to a fresh mint, so only the shape is checked
  ("(mint " = snip (show (mint 0)) 0 6)
  (mint 0 @ m (show m = show m))               ; stable: same mint, same face
  (: a (mint 0) b (mint 0) (show a != show b)) ; distinct mints, distinct faces
  (nom? (mint 0))
  ('bar = mint 'bar)                             ; mint is nom: a name answers itself

  ; quote sugar: a chain (` x) prints as 'x
  ("'foo" = show ''foo)
  ("'(a b)" = show ''(a b))

  ; proper lists
  ("(a b c)" = show '(a b c))
  ("(1 2 3)" = show (1 . 2 . 3 . ()))
  ("(\"a\" \"b\")" = show ("a" . "b" . ()))

  ; nesting
  ("(a (b) c)" = show ('a . ('b . ()) . 'c . ()))
  ("((1 2) (3 4))" = show '((1 2) (3 4)))

  ; result is always a string
  (string? (show 0))
  (string? (show "hi"))
  (string? (show '(1 2 3)))
  (string? (show {}))

  ; buffer growth past the initial cask
  (: (rng n) (n = 0 ? () (n . rng (n - 1)))
     s (show (rng 200))
   (do (string? s) (400 < #s))) ; fixme: a `do` in test position, likely meant as two tests

  ; gc stress: 500 shows, each allocating a port
  (: (loop n) (n = 0 ? (show (1 . 2 . 3 . ()))
                 (show "stress", loop (n - 1)))
   ("(1 2 3)" = loop 500)))

; a map that holds itself prints <cycle>; one map twice is no cycle; a nest prints in linear time
(: shm-t {} _ (pin shm-t 'a shm-t)
   shm-a {} shm-b {} _ (pins shm-a 'b shm-b) _ (pins shm-b 'a shm-a)
   (shm-ring n) (: ms (map (u \ {}) ^n) _ (each ^n (i \ pin (ms i) 'n (ms ((i + 1) % n)))) <ms)
   shm-x {1 2} shm-y {'a shm-x 'b shm-x}
   (shm-nest n x) (n = 0 ? x (shm-nest (n - 1) {'k x}))
 (test ("{a <cycle>}" = show shm-t) ("{b {a <cycle>}}" = show shm-a)
       (0 <= fsub (show (shm-ring 100)) "<cycle>" 0) (tally (show (shm-ring 100)) < 4000)
       !(0 <= fsub (show shm-y) "<cycle>" 0)
       (test-linear (n \ show (shm-nest n 1)) 1500)))

; a function over a map that holds the function, or holds itself, reads back to a <cycle>
(: shf-t {'a 1} (shf-f x) (shf-t x) _ (pin shf-t 'f shf-f)
   shf-s {} _ (pin shf-s 's shf-s) (shf-g x) (shf-s x)
 (test (0 <= fsub (show shf-f) "<cycle>" 0) (0 <= fsub (show shf-f) "(pin (pin (tablet 0) 'a 1) 'f" 0)
       (0 <= fsub (show shf-g) "{..1}" 0)))

; a partial laid in one cell -- an unknown head called short, apo's miss -- shows as the
; chain of unc cells it stands for
(: (sha-k3 a b c) (a < 1 ? [a b c] (sha-k3 (a - 1) b c))
   (sha-t2 f a b n) (n < 1 ? (f a b) (sha-t2 f a b (n - 1)))
 (test (show (sha-t2 sha-k3 0 2 1) = show ((sha-k3 0) 2))))
