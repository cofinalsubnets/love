; "" is a distinct, truthy empty-string object -- the identity element for + (and
; scat) over strings. It is NOT the number 0: 0 (nil) is still tolerated as an
; "empty" argument by the lenient string ops, but the two are distinguishable.
(assert
  ; the literal "" reads as a real, truthy string object distinct from 0
  (strp "")                                  ; "" is a string
  (not (nilp ""))                            ; "" is truthy
  (nilp (= "" 0))                            ; "" is not equal to 0
  (nilp (same "" 0))                         ; ... nor identical to it
  (= "" "")                                  ; but all empty strings are equal

  ; len: both the empty string and 0 have empty length
  (= 0 (len ""))
  (= 0 (len 0))

  ; + / scat: "" is a two-sided identity, and joining empties yields ""
  (= "ab" (+ "" "ab"))   (= "ab" (+ "ab" ""))
  (= "ab" (scat "ab" ""))   (= "ab" (scat "" "ab"))
  (= "" (scat "" ""))                        ; empty join -> the empty string
  (strp (scat "" ""))                        ; ... still a string, not 0
  ; 0 is still accepted as an empty operand by scat (non-strings are dropped)
  (= "ab" (scat "ab" 0))   (= "ab" (scat 0 "ab"))
  (= 0 (scat 0 0))

  ; ssub: an empty slice collapses to 0 (no string object is built)
  (= 0 (ssub "abc" 1 1))
  (= 0 (ssub "" 0 5))
  (= 0 (ssub 0 0 5))

  ; get: indexing the empty string returns the default
  (= 99 (get 99 0 ""))
  (= 99 (get 99 0 0))

  ; applying "" IS byte-indexing now (it is a real text object): every index is
  ; out of range, so ("" k) == 1 -- the same value the number 0 yields, but via
  ; the string ap handler, not Church-numeral application.
  (= 1 ("" 5))
  (= 1 (0 5))

  ; string: coercing "" stays the empty string; coercing 0 stays 0
  (= "" (string ""))   (strp (string ""))
  (= 0 (string 0))

  ; puts writes nothing for an empty operand; "" returns "", 0 returns 0
  (= "" (puts ""))
  (= 0 (puts 0)))
