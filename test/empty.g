; "" normalizes to 0, and 0 acts like "" for every string operation.
; there is no distinct empty-string value: the empty string IS nil (0).
(assert
  ; the literal "" reads as 0 -- equal, falsy, and not a string object
  (= 0 "")
  (= "" 0)
  (nilp "")                                  ; "" is falsy
  (not (strp ""))                            ; "" is not a distinct string

  ; len: 0 and "" are the empty length
  (= 0 (len ""))
  (= 0 (len 0))

  ; scat: 0 is a two-sided identity, an empty result collapses to 0
  (= "ab" (scat "ab" ""))
  (= "ab" (scat "" "ab"))
  (= "ab" (scat "ab" 0))
  (= "ab" (scat 0 "ab"))
  (= 0 (scat "" ""))
  (= 0 (scat 0 0))

  ; ssub: an empty slice is 0, and slicing 0 (empty) is 0
  (= 0 (ssub "abc" 1 1))
  (= 0 (ssub "" 0 5))
  (= 0 (ssub 0 0 5))

  ; get: indexing the empty string returns the default
  (= 99 (get 99 0 ""))
  (= 99 (get 99 0 0))

  ; NB: applying the empty string is NOT byte-indexing -- "" is 0, a number, so
  ; ("" k) is Church-numeral application (k^0 = 1), not the string ap handler.
  ; Only real text objects index; the empty string is the number 0.
  (= 1 ("" 5))
  (= 1 (0 5))

  ; string: coercing the empty value (0 / "") stays empty (not a NUL char)
  (= 0 (string ""))
  (= 0 (string 0))

  ; puts treats 0 / "" as nothing to write (no crash, no output)
  (= 0 (puts ""))
  (= 0 (puts 0)))
