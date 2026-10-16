; casks, the mutable byte arrays: the doors that take a range. pour blits and clamps,
; snip copies a range out; out of range either is a silent no-op
(test
 ; --- a cask is its own kind ---
 !(string? (cask 4)) !(charm? (cask 4))

 ; --- an out-of-range pin or peep is a silent no-op, never a crash ---
 (cask 2 @ b (pin b 5 1, pin b -1 1, 0 = peep b 0 0 + peep b 1 0))
 (0 = peep (cask 2) 9 0)

 ; --- pour: dst offset, src offset, count -- and it answers dst ---
 (cask 4 @ b (pour b 1 "ABCD" 2 2,           ; copy "cd" to offset 1
              0 = peep b 0 0 && 67 = peep b 1 0 && 68 = peep b 2 0))
 (cask 2 @ b (b = pour b 0 "XY" 0 2))
 ; ... a cask is a source as readily as a sink
 (: s (cask 3) d (cask 3)
    (pin s 0 7, pin s 1 8, pin s 2 9,
     pour d 0 s 0 3,
     7 = peep d 0 0 && 9 = peep d 2 0))
 ; ... and an oversized count clamps
 (cask 2 @ b (pour b 0 "ABCD" 0 100, 2 = #b))

 ; --- snip reads a range back out as a string ---
 (cask 4 @ b (pour b 0 "ABCD" 0 4, "AB" = snip b 0 2))
 (cask 4 @ b (pour b 0 "ABCD" 0 4, string? (snip b 0 2)))
 (cask 4 @ b (pour b 0 "ABCD" 0 4, "ABCD" = snip b -9 99))      ; clamps like a string snip
 (cask 4 @ b ("" = snip b 2 2))                                 ; an empty range is the empty string
 ; ... and the snapshot is taken, not aliased
 (: b (cask 2) _ (pour b 0 "AB" 0 2) s (snip b 0 2) (pin b 0 90, "AB" = s))

 ; --- a cask equals itself ---
 (cask 2 @ b (b = b)))

; --- peepv / pinv: a whole tray in or out, at a width and a stride ---
; cited, never borrowed (the corpus is one scope); the egg never mops, so the book is the fallback
(: bufv-G (cite 'guts)
   (bufv k) (bufv-G k || book k)
   lay (bufv 'pinv)  see (bufv 'peepv)
   neg (0 - 1)
   ((test lay see),

    ; a run laid contiguously reads back as itself, and the lay answers the cask it wrote
    (: c (cask 16) v (iota 4 + 1)
       g ((test (c = lay c 0 4 4 v)), see c 0 4 4 4)
       (test (4 = #g) (1 = peep g 0 0) (2 = peep g 1 0) (4 = peep g 3 0))),

    ; little-endian, low bytes first: 0x01020304 lands 04 03 02 01
    (cask 4 @ c (lay c 0 4 4 (iota 1 + 16909060),
                 (test (4 = peep c 0 0) (3 = peep c 1 0) (2 = peep c 2 0) (1 = peep c 3 0)))),

    ; a stride wider than the width interleaves: two channels, each read back on its own
    (: c (cask 16) l (iota 4 + 10) r (iota 4 + 20)
       _ (lay c 0 2 4 l)  _ (lay c 2 2 4 r)
       gl (see c 0 2 4 4)  gr (see c 2 2 4 4)
       (test (10 = peep gl 0 0) (13 = peep gl 3 0)
             (20 = peep gr 0 0) (23 = peep gr 3 0))),

    ; a float truncates toward zero, as `int`; a narrow width keeps the low bytes
    (: c (cask 8) t ((iota 4 - 2) * 1.5)            ; -3.0 -1.5 0.0 1.5
       _ (lay c 0 2 2 t)
       g (see c 0 2 2 4)
       (test (65533 = peep g 0 0) (65535 = peep g 1 0)
             (0 = peep g 2 0) (1 = peep g 3 0))),

    ; the empty run fits anywhere inside the cask, and lays nothing
    (cask 4 @ c (test (c = lay c 4 1 1 (iota 0)))),

    ; misuse is the silent () these doors answer, never a trampled heap
    (: c (cask 8) v (iota 2 + 1)
       (test !(lay c 0 0 4 v)                         ; no width
             !(lay c 0 9 9 v)                         ; wider than a word
             !(lay c 0 4 2 v)                         ; a stride under the width overlaps
             !(lay c 5 4 4 v)                         ; the run would leave the cask
             !(lay c neg 4 4 v)                       ; a negative offset
             !(lay "abc" 0 1 1 v)                     ; not a cask
             !(lay c 0 1 1 [1 2])                     ; not a tray
             !(see c 0 4 4 3)                         ; three words do not fit in eight bytes
             !(see c 0 4 4 neg))),                    ; nor a negative count
    ()))
