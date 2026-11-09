; espram -- an esp32's rom download over its uart, into RAM alone: each PT_LOAD of an ELF at
; its address (.bss as zeros), a jump to e_entry, then the uart's output for a while. no flash
; is touched. the reset is the usual pair, RTS on EN and DTR on IO0 through two transistors.
; usage: love src/tools/espram.l ELF [TTY [SECONDS]], TTY /dev/ttyUSB0, SECONDS 5
(borrow '(posix bytes))
(: dtr 2 rts 4
   blk 6144                                           ; the rom's ram block
   (die m) (say err ("espram: " + m + "\n"), flush err, quit 1)
   ; slip: a frame between two C0s, C0 and DB escaped
   (slip s) (string ([192] + catmap (i \ s i @ 192 [219 220] 219 [219 221] b [b]) ^#s + [192]))
   (unslip s) (: (go i a) (? (#s <= i) (string (rev a))
                             (s i = 219) (go (i + 2) ((s (i + 1) = 220 ? 192 219) . a))
                             (go (i + 1) (s i . a)))
                 (go 0 ()))
   ; a request: direction 0, the op, the data's size, a checksum (MEM_DATA's alone)
   (req op d ck) (slip (string [0 op] + wrle #d 2 + wrle ck 4 + d))
   (xsum d) (foldl (a \ i \ a ^ d i) 239 ^#d)
   (at s c i) (? (#s <= i) -1 (s i = c) i (at s c (i + 1)))
   ; the elf's loads -> [entry [[addr bytes]..]]
   (loads f)
    (? (#f < 52 || snip f 0 4 != "\x7fELF" || f 4 != 1 || f 5 != 1) (die "not a little-endian elf32")
       (: ph (rdle f 28 4) pe (rdle f 42 2)
          (seg k) (: o (ph + k * pe) fs (rdle f (o + 16) 4) ms (rdle f (o + 20) 4)
                     (rdle f o 4 = 1 && 0 < ms
                      ? [[(rdle f (o + 8) 4) (snip f (rdle f (o + 4) 4) (rdle f (o + 4) 4 + fs) + zbytes (ms - fs + padk ms 4))]]))
          [(rdle f 24 4) (catmap seg ^(rdle f 44 2))]))
   (main as)
    (: f (<as @ p (string? p ? (uread p @ [1 t] t _ (die ("cannot read " + p))) (die "usage: espram ELF [TTY [SECONDS]]")))
       ld (loads f) ent <ld segs <>ld
       dev (>as @ (d . _) d _ "/dev/ttyUSB0")
       secs (>>as @ (s . _) (read s) _ 5)
       fd (openfd dev 5)
       _ (charm? fd ? 0 (die (dev + ": " + uerrno fd)))
       st0 (termios fd)
       _ (nom? st0 ? (die (dev + ": " + uerrno st0)))
       ; raw 8N1 at 115200, CS8 CREAD CLOCAL, a byte at a time
       _ (settermios fd ([0 0 2224 0 115200] + drop 5 st0 @ t (snip t 0 10 + [0 1] + drop 12 t)))
       p (fdopen fd)
       got {'b ""}
       (down _) (await p, see p @ c (c = -1 ? 0 (unsee p c, pin got 'b (got 'b + chug p), down 0)))
       _ (twirl down 0)
       (send s) (say p s, flush p)
       ; the first reply to op in the buffer, what lies before it dropped; () by the deadline.
       ; a C0 that closes no reply may open the next, as after a reset's line noise
       (frame op t)
        (: b (got 'b) i (at b 192 0) j (i < 0 ? -1 (at b 192 (i + 1)))
           (? (j < 0) (clock 0 < t ? (rest 5, frame op t) ())
              (j = i + 1) (pin got 'b (snip b j #b), frame op t)
              (: r (unslip (snip b (i + 1) j))
                 (8 <= #r && r 0 = 1 && r 1 = op ? (pin got 'b (snip b (j + 1) #b), r)
                  (pin got 'b (snip b j #b), frame op t)))))
       (ok? r) (string? r && 12 <= #r && r (#r - 4) = 0)
       (call op d ck what)
        (send (req op d ck), frame op (clock 0 + 3000) @ r (ok? r ? r (die (what + " refused"))))
       ; into the rom's download, each step one write: EN low with IO0 high, then EN up while
       ; IO0 is held low, then IO0 let go
       (reset _) (modem fd 0 (dtr | rts), modem fd (dtr | rts) 0, modem fd rts dtr, rest 100,
                  modem fd dtr rts, rest 50, modem fd 0 (dtr | rts), rest 200, pin got 'b "")
       (sync k)
        (k = 0 ? (die (dev + ": no answer from the rom"))
           (send (req 8 (string [7 7 18 32] + string (map (_ \ 85) ^32)) 0),
            frame 8 (clock 0 + 100) @ r (string? r ? (rest 100, pin got 'b "") (k % 10 = 0 ? (reset 0), sync (k - 1)))))
       (load [a b])
        (: n ((#b + blk - 1) // blk)
           (say out "load \(radix a 16), \(#b) bytes\n", flush out,
            call 5 (wrle #b 4 + wrle n 4 + wrle blk 4 + wrle a 4) 0 "mem_begin",
            each ^n (k \ snip b (k * blk) (min #b (k * blk + blk)) @ d
                         (call 7 (wrle #d 4 + wrle k 4 + zbytes 8 + d) (xsum d) "mem_data"))))
       (tail t)
        (clock 0 < t ? (got 'b @ b (#b = 0 ? 0 (say out b, flush out, pin got 'b "")), rest 20, tail t))
       (reset 0, sync 30, each segs load,
        ; its answer, when it comes before the jump, kept out of the program's output
        send (req 6 (wrle (ent = 0 ? 1 0) 4 + wrle ent 4) 0), frame 6 (clock 0 + 200),
        tail (clock 0 + 1000 * secs),
        settermios fd st0, quit 0))
   (main >argv))
