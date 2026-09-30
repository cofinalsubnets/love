; sizes no heap holds and depths no C stack holds: each is refused as a scare a trap
; catches, or as the lane's own (), and the session carries on. the operands ride trap's
; x, so no constant fold runs the refusal at compile time, outside the trap.
(: rf-no (a \ b \ 'refused)
   (rf-try f x) (trap f x rf-no)
   rf-huge (max-charm // 2 + 1)                                ; 2^61 on a 64-bit charm
   (rf-nest n a) (n < 1 ? a (rf-nest (n - 1) [1 a]))
   rf-deep-a (rf-nest 2000 1)
   rf-deep-b (rf-nest 2000 2)
   rf-mid-a (rf-nest 500 1)
   rf-mid-b (rf-nest 500 2)
   rf-knobs (tune ()))

(test
 ; a tray's shape past any heap: refused before a byte is laid, never indexed past its end
 ('refused = rf-try (n \ star-tray [n] []) rf-huge)
 ('refused = rf-try (n \ peep (star-tray [n 8] []) [1 0] 0) rf-huge)
 ('refused = rf-try (n \ pin (star-tray [n 8] []) [1 0] 7) rf-huge)
 ('refused = rf-try (n \ top-tray [n 8] []) rf-huge)
 ('refused = rf-try iota rf-huge)
 ; an empty tray may name a vast axis: it holds nothing, so every index misses
 (star-tray [rf-huge 0] [] @ t (7 = peep t [5 0] 7))
 ([2 3] = shape (star-tray [2 3] [1 2 3 4 5 6]))

 ; a repeat no heap holds answers the lane's ()
 (() = ("a" * 1048576) * 1099511627776)
 (() = (map (+ 1) (jot 65536)) * 1099511627776)
 ("abab" = "ab" * 2)

 ; a pool knob no heap holds is refused, the rest of the tune still lands
 (: _ (tune [(peep rf-knobs 0 0) rf-huge rf-huge 1000000]) now (tune ())
    (: (same k) (peep rf-knobs k 0 = peep now k 0) (same 1 && same 2 && same 3)))
 (please 1, 1000 = tally (map (+ 1) (jot 1000)))

 ; a base the digits cannot spell answers ""
 ("" = radix 5 0) ("" = radix 100 1) ("" = radix 100 37)
 ("ff" = radix 255 16) ("z" = radix 35 36) ("101" = radix 5 2)

 ; an order past the car depth is refused; one within it answers
 ('refused = rf-try (p \ <p < <>p) [rf-deep-a rf-deep-b])
 ('refused = rf-try sort [rf-deep-b rf-deep-a])
 ('refused = rf-try (p \ max <p <>p) [rf-deep-a rf-deep-b])
 (rf-mid-a < rf-mid-b) !(rf-mid-b < rf-mid-a)
 ([rf-mid-a rf-mid-b] = sort [rf-mid-b rf-mid-a])

 ; a shift past any heap is a scare, not a spin
 ('refused = rf-try (k \ 1 << k) 17179869184)
 (1024 = 1 << 10)

 ; the reader keeps its nesting on the heap: any depth reads, and an unclosed one is torn
 ('torn = sound (map (_ \ 40) (jot 5000)))
 (: n 100000 s (map (i \ i < n ? 40 41) (jot (2 * n)))
    (go x k) (two? x ? (go <x (k + 1)) k)
    (n - 1 = go <(sound s) 0))
 ([1 [2]] = <(sound (map "(1 (2))" (jot 7)))))
