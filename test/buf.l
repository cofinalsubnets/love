; a cask is a mutable flat byte array -- the one collection whose pin lands in place, so a
; second holder sees the write. its surface laws (tally, $, the byte pin, the charlist ctor,
; identity equality) are spec.l's; what lives here are the doors that take a range.
; `pour` blits a byte run between casks and strings -- a dst offset, a src offset, a count --
; and answers dst; an oversized count clamps to the room there is rather than trampling the
; heap. `snip` reads a range back out as a string, clamping its bounds the way a string snip
; does, and it snapshots: the bytes are copied, so a later pin cannot reach what was read.
; out of range, either door is a silent no-op.
(test
 ; --- a cask is its own kind ---
 !(string? (cask 4)) !(charm? (cask 4))

 ; --- an out-of-range pin or peep is a silent no-op, never a crash ---
 (: b (cask 2) _ (pin b 5 1) _ (pin b -1 1) (0 = peep b 0 0 + peep b 1 0))
 (0 = peep (cask 2) 9 0)

 ; --- pour: dst offset, src offset, count -- and it answers dst ---
 (: b (cask 4) _ (pour b 1 "ABCD" 2 2)       ; copy "cd" to offset 1
    (0 = peep b 0 0 && 67 = peep b 1 0 && 68 = peep b 2 0))
 (: b (cask 2) (b = pour b 0 "XY" 0 2))
 ; ... a cask is a source as readily as a sink
 (: s (cask 3) d (cask 3)
    _ (pin s 0 7) _ (pin s 1 8) _ (pin s 2 9)
    _ (pour d 0 s 0 3)
    (7 = peep d 0 0 && 9 = peep d 2 0))
 ; ... and an oversized count clamps
 (: b (cask 2) _ (pour b 0 "ABCD" 0 100) (2 = tally b))

 ; --- snip reads a range back out as a string ---
 (: b (cask 4) _ (pour b 0 "ABCD" 0 4) ("AB" = snip b 0 2))
 (: b (cask 4) _ (pour b 0 "ABCD" 0 4) (string? (snip b 0 2)))
 (: b (cask 4) _ (pour b 0 "ABCD" 0 4) ("ABCD" = snip b -9 99)) ; clamps like a string snip
 (: b (cask 4) ("" = snip b 2 2))                               ; an empty range is the empty string
 ; ... and the snapshot is taken, not aliased
 (: b (cask 2) _ (pour b 0 "AB" 0 2) s (snip b 0 2) _ (pin b 0 90) ("AB" = s))

 ; --- a cask equals itself; law.l's =-total corpus carries no cask, so it is said here ---
 (cask 2 @ b (b = b)))

; --- peepv / pinv: a whole tray in or out, at a width and a stride -------------------
; the range doors above move bytes; these move ELEMENTS, and carry the two numbers a byte
; run cannot -- how wide one is and how far apart they sit. a stride wider than the width
; is an interleave, which is the shape a frame of stereo PCM has (apps/harp/play.l's pack
; lays each channel with one call). they sit in `guts` beside peepw/pinw and are read the
; same way: through cite, never a (borrow 'guts) splice, the corpus being one scope. the
; bootstrap egg never mops, so ask the module first and the book after.
(: bufv-G (cite 'guts)
   (bufv k) (bufv-G k || book k)
   lay (bufv 'pinv)  see (bufv 'peepv)
   neg (0 - 1)
   _ (test lay see)

   ; a run laid contiguously reads back as itself, and the lay answers the cask it wrote
   _ (: c (cask 16) v (iota 4 + 1)
        g (: _ (test (c = lay c 0 4 4 v)) (see c 0 4 4 4))
        (test (4 = #g) (1 = peep g 0 0) (2 = peep g 1 0) (4 = peep g 3 0)))

   ; little-endian, low bytes first: 0x01020304 lands 04 03 02 01
   _ (: c (cask 4) _ (lay c 0 4 4 (iota 1 + 16909060))
        (test (4 = peep c 0 0) (3 = peep c 1 0) (2 = peep c 2 0) (1 = peep c 3 0)))

   ; a stride wider than the width INTERLEAVES: two channels into one frame run, and each
   ; reads back on its own -- which is the whole reason the door carries a stride
   _ (: c (cask 16) l (iota 4 + 10) r (iota 4 + 20)
        _ (lay c 0 2 4 l)  _ (lay c 2 2 4 r)
        gl (see c 0 2 4 4)  gr (see c 2 2 4 4)
        (test (10 = peep gl 0 0) (13 = peep gl 3 0)
              (20 = peep gr 0 0) (23 = peep gr 3 0)))

   ; a float element truncates TOWARD ZERO, the answer `int` gives -- so a tray of samples
   ; goes down with no pass to round it, and the low bytes are what a narrow width keeps
   _ (: c (cask 8) t ((iota 4 - 2) * 1.5)           ; -3.0 -1.5 0.0 1.5
        _ (lay c 0 2 2 t)
        g (see c 0 2 2 4)
        (test (65533 = peep g 0 0) (65535 = peep g 1 0)
              (0 = peep g 2 0) (1 = peep g 3 0)))

   ; the empty run fits anywhere inside the cask, and lays nothing
   _ (: c (cask 4) (test (c = lay c 4 1 1 (iota 0))))

   ; misuse is the silent () these doors answer, never a trampled heap
   _ (: c (cask 8) v (iota 2 + 1)
        (test !(lay c 0 0 4 v)                        ; no width
              !(lay c 0 9 9 v)                        ; wider than a word
              !(lay c 0 4 2 v)                        ; a stride under the width overlaps
              !(lay c 5 4 4 v)                        ; the run would leave the cask
              !(lay c neg 4 4 v)                      ; a negative offset
              !(lay "abc" 0 1 1 v)                    ; not a cask
              !(lay c 0 1 1 [1 2])                    ; not a tray
              !(see c 0 4 4 3)                        ; three words do not fit in eight bytes
              !(see c 0 4 4 neg)))                    ; nor a negative count
   ())
