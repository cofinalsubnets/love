; esprom -- an esp32's rom loader over its uart: run an ELF from RAM, or read, sum and write
; its flash. the reset is the usual pair, RTS on EN and DTR on IO0 through two transistors,
; or on a chip's own USB-Serial-JTAG (a ttyACM) the lines its peripheral reads directly.
;   love src/tools/esprom.l [-p TTY] run ELF [SECONDS]  each PT_LOAD at its address (.bss as
;                                                       zeros), e_entry, then the uart a while;
;                                                       -s attaches the flash first
;   love src/tools/esprom.l [-p TTY] -s SIZE read OFF LEN FILE   (the esp32's rom alone)
;   love src/tools/esprom.l [-p TTY] -s SIZE md5 OFF LEN
;   love src/tools/esprom.l [-p TTY] -s SIZE write OFF FILE      erase, write, check, boot it
;   love src/tools/esprom.l [-p TTY] reset                       boot the flash
; TTY /dev/ttyUSB0; SIZE the flash's bytes; -b BAUD past the sync, as 921600; -x ELF reads through
; a stub in RAM, as src/tools/espstub.c, and any rom; a number takes 0x and K or M
(borrow '(posix bytes hashes))
(: dtr 2 rts 4
   blk 6144                                           ; the rom's ram block
   fblk 1024                                          ; ..and its flash block
   usage "usage: esprom [-p TTY] [-s SIZE] [-b BAUD] [-x STUB] run ELF [SECONDS] | read OFF LEN FILE | md5 OFF LEN | write OFF FILE | reset"
   (die m) (say err ("esprom: " + m + "\n"), flush err, quit 1)
   (num w) (: (dig c) (? (48 <= c <= 57) (c - 48) (97 <= c <= 102) (c - 87) (65 <= c <= 70) (c - 55) 99)
              hex (2 < #w && w 0 = 48 && (w 1 = 120 || w 1 = 88))
              k (#w @ 0 0 n (w (n - 1) @ 75 1024 107 1024 77 1048576 109 1048576 _ 1))
              s (snip w (hex ? 2 0) (k = 1 ? #w (#w - 1)))
              b (hex ? 16 10)
              (0 < #s && foldl (a \ i \ a && dig (s i) < b) 1 ^#s ? (k * foldl (a \ i \ a * b + dig (s i)) 0 ^#s)
               (die ("not a number: " + w))))
   ; slip: a frame between two C0s, C0 and DB escaped
   (slip s) (string ([192] + catmap (i \ s i @ 192 [219 220] 219 [219 221] b [b]) ^#s + [192]))
   (unslip s) (: (go i a) (? (#s <= i) (string (rev a))
                             (s i = 219) (go (i + 2) ((s (i + 1) = 220 ? 192 219) . a))
                             (go (i + 1) (s i . a)))
                 (go 0 ()))
   ; a request: direction 0, the op, the data's size, a checksum (a data block's alone)
   (req op d ck) (slip (string [0 op] + wrle #d 2 + wrle ck 4 + d))
   (xsum d) (foldl (a \ i \ a ^ d i) 239 ^#d)
   (at s c i) (? (#s <= i) -1 (s i = c) i (at s c (i + 1)))
   (w32 l) (foldl (a \ v \ a + wrle v 4) "" l)
   (md5 s) (: b (cask 89) (md5-init b, md5-feed b s, md5-done b))
   ; the elf's loads -> [entry [[addr bytes]..]]
   (loads f)
    (? (#f < 52 || snip f 0 4 != "\x7fELF" || f 4 != 1 || f 5 != 1) (die "not a little-endian elf32")
       (: ph (rdle f 28 4) pe (rdle f 42 2)
          (seg k) (: o (ph + k * pe) fs (rdle f (o + 16) 4) ms (rdle f (o + 20) 4)
                     (rdle f o 4 = 1 && 0 < ms
                      ? [[(rdle f (o + 8) 4) (snip f (rdle f (o + 4) 4) (rdle f (o + 4) 4 + fs) + zbytes (ms - fs + padk ms 4))]]))
          [(rdle f 24 4) (catmap seg ^(rdle f 44 2))]))
   (slurp p) (uread p @ [1 t] t _ (die ("cannot read " + p)))
   ; the flags, then the verb and its words
   (opts as o) (as @ ("-p" . d . r) (opts r (pin o 'dev d)) ("-s" . n . r) (opts r (pin o 'size (num n)))
                  ("-b" . n . r) (opts r (pin o 'baud (num n)))
                  ("-x" . f . r) (opts r (pin o 'stub (slurp f))) _ [o as])
   (main as)
    (: oa (opts as {'dev "/dev/ttyUSB0"}) o <oa vs <>oa
       dev (o 'dev)
       fd (openfd dev 5)
       _ (charm? fd ? 0 (die (dev + ": " + uerrno fd)))
       st0 (termios fd)
       _ (nom? st0 ? (die (dev + ": " + uerrno st0)))
       ; raw 8N1, CS8 CREAD CLOCAL, a byte at a time
       (speed b) (settermios fd ([0 0 2224 0 b] + drop 5 st0 @ t (snip t 0 10 + [0 1] + drop 12 t)))
       _ (speed 115200)
       p (fdopen fd)
       got {'b ""}
       (down _) (await p, see p @ c (c = -1 ? 0 (unsee p c, pin got 'b (got 'b + chug p), down 0)))
       _ (twirl down 0)
       (send s) (say p s, flush p)
       (leave n) (settermios fd st0, quit n)
       (fail m) (settermios fd st0, die m)
       ; the first reply to op in the buffer, what lies before it dropped; () by the deadline.
       ; a C0 that closes no reply may open the next, as after a reset's line noise
       (frame op t)
        (: b (got 'b) i (at b 192 0) j (i < 0 ? -1 (at b 192 (i + 1)))
           (? (j < 0) (clock 0 < t ? (rest 5, frame op t) ())
              (j = i + 1) (pin got 'b (snip b j #b), frame op t)
              (: r (unslip (snip b (i + 1) j))
                 (8 <= #r && r 0 = 1 && r 1 = op ? (pin got 'b (snip b (j + 1) #b), r)
                  (pin got 'b (snip b j #b), frame op t)))))
       ; a reply -> its value and the n bytes of data it carries, its status right after them
       (call op d ck what n ms)
        (send (req op d ck), frame op (clock 0 + ms) @ r
           (? (!(string? r) || #r < 10 + n) (fail (what + ": no answer"))
              (r (8 + n) != 0) (fail (what + " refused, error " + show (r (9 + n))))
              [(rdle r 4 4) (snip r 8 (8 + n))]))
       (call0 op d what) (call op d 0 what 0 3000)
       ; into the rom's download, each step one write: EN low with IO0 high, then EN up while
       ; IO0 is held low, then IO0 let go. a USB-Serial-JTAG takes DTR as the strap and RTS as
       ; the reset, passing from strap to reset through both
       jtag? (0 <= findsub dev "ttyACM" || 0 <= findsub dev "JTAG")
       (lines on off ms) (modem fd on off, rest ms)
       (reset _) (jtag? ? (lines 0 (dtr | rts) 100, lines dtr rts 100, lines (dtr | rts) 0 0, lines rts dtr 100, lines 0 (dtr | rts) 200)
                    (lines 0 (dtr | rts) 0, lines (dtr | rts) 0 0, lines rts dtr 100, lines dtr rts 50, lines 0 (dtr | rts) 200),
                  pin got 'b "")
       ; ..and a plain boot, IO0 high through the reset
       (boot _) (jtag? ? (lines 0 dtr 0, lines rts 0 100, lines 0 (dtr | rts) 0) (lines rts dtr 100, lines 0 (dtr | rts) 0))
       (sync k)
        (k = 0 ? (fail (dev + ": no answer from the rom"))
           (send (req 8 (string [7 7 18 32] + string (map (_ \ 85) ^32)) 0),
            frame 8 (clock 0 + 100) @ r (string? r ? (rest 100, pin got 'b "") (k % 10 = 0 ? (reset 0), sync (k - 1)))))
       ; the rom answers at the old rate, then listens at the new; a USB-Serial-JTAG has no rate
       (connect _) (reset 0, speed 115200, sync 30, o 'baud @ b (charm? b && !jtag? ? (call0 15 (w32 [b 0]) "change_baudrate", speed b, rest 50, pin got 'b "")))
       ; the esp32 classic by the word at 0x40001000: its rom takes a shorter flash_begin
       (esp32? _) (<(call0 10 (w32 [1073745920]) "read_reg") = 15736195)
       ; the flash's pins and shape, as the rom wants them before it is read or written
       (attach _) (: sz (o 'size)
                     (charm? sz ? 0 (fail "-s SIZE: the flash's size is wanted"),
                      call0 13 (zbytes 8) "spi_attach",
                      call0 11 (w32 [0 sz 65536 4096 256 65535]) "spi_set_params", sz))
       (inside off n sz) (0 <= off && 0 <= n && off + n <= sz ? 0 (fail "past the flash's end"))
       (load [a b])
        (: n ((#b + blk - 1) // blk)
           (say out "load \(radix a 16), \(#b) bytes\n", flush out,
            call0 5 (w32 [#b n blk a]) "mem_begin",
            each ^n (k \ snip b (k * blk) (min #b (k * blk + blk)) @ d
                         (call 7 (w32 [#d k 0 0] + d) (xsum d) "mem_data" 0 3000))))
       (tail t)
        (clock 0 < t ? (got 'b @ b (#b = 0 ? 0 (say out b, flush out, pin got 'b "")), rest 20, tail t))
       ; its answer, when it comes before the jump, kept out of the program's output
       (enter f) (: ld (loads f) ent <ld (each <>ld load, send (req 6 (w32 [(ent = 0 ? 1 0) ent]) 0), frame 6 (clock 0 + 200)))
       (run f secs) (connect 0, charm? (o 'size) ? (attach 0), enter f, tail (clock 0 + 1000 * secs))
       ; the rom's md5 of the flash from off, n bytes, as hex
       (fmd5 off n) (call 19 (w32 [off n 0 0]) 0 "spi_flash_md5" 32 (3000 + 8 * n // 1000) @ [_ h] h)
       (stub _) (enter (o 'stub), frame 208 (clock 0 + 2000) @ r (string? r ? 0 (fail "the stub did not start")))
       ; the stub's read: 4K a reply, its crc32 after it, kept short so the reader never stalls the line
       (sread off n)
        (: (go i acc) (n <= i ? (join "" (rev acc))
                        (: k (min 4096 (n - i))
                           (i % 65536 = 0 ? (say out "read \(radix (off + i) 16)\n", flush out),
                            call 210 (w32 [(off + i) k]) 0 "read" (k + 4) (3000 + k // 8) @ [_ b]
                             (crc32 (snip b 0 k) = rdle b k 4 ? (go (i + k) (snip b 0 k . acc)) (fail "a block's crc")))))
           (go 0 ()))
       (fread off n path)
        (: _ (string? (o 'stub) || esp32? 0 ? 0 (fail "this rom cannot read its flash: only the esp32's can"))
           (: (go i acc) (n <= i ? (join "" (rev acc))
                           (: k (min 64 (n - i))
                              (i % 65536 = 0 ? (say out "read \(radix (off + i) 16)\n", flush out),
                               go (i + k) ((call 14 (w32 [(off + i) k]) 0 "read_flash_slow" 64 3000 @ [_ b] (snip b 0 k)) . acc))))
              data (string? (o 'stub) ? (stub 0, sread off n @ d (connect 0, attach 0, d)) (go 0 ()))
              sum (fmd5 off n)
              (md5 data != sum ? (fail ("read back " + md5 data + ", the rom sums " + sum))
               (uwrite path data ? (say out "\(n) bytes from \(radix off 16) to \(path), md5 \(sum)\n", flush out)
                (fail ("cannot write " + path))))))
       ; the stub's write: a 4K sector a request, crc32 its checksum, then read back through it
       (swrite off d)
        (stub 0,
         each ^(#d // 4096) (k \ snip d (k * 4096) (k * 4096 + 4096) @ s
                                 (call 212 (w32 [(off + k * 4096)] + s) (crc32 s) "write" 0 5000,
                                  k % 16 = 15 ? (say out "  \((k + 1) * 4096) bytes\n", flush out))),
         sread off #d = d ? (say out "read back through the stub\n", flush out) (fail "the stub read back other bytes"),
         connect 0, attach 0)
       (fwrite off data)
        (: e (esp32? 0) n ((#data + 4095) // 4096 * 4096 // fblk)
           d (data + string (map (_ \ 255) ^(n * fblk - #data)))
           (off % 4096 = 0 ? 0 (fail "the offset is not on a 4K sector"),
            say out "erase and write \(#data) bytes at \(radix off 16)\n", flush out,
            string? (o 'stub) ? (swrite off d) (call 2 (w32 ([#d n fblk off] + (e ? [] [0]))) 0 "flash_begin" 0 (3000 + 40 * #d // 1000),
            each ^n (k \ (call 3 (w32 [fblk k 0 0] + snip d (k * fblk) (k * fblk + fblk)) (xsum (snip d (k * fblk) (k * fblk + fblk))) "flash_data" 0 5000,
                          k % 64 = 63 ? (say out "  \((k + 1) * fblk) bytes\n", flush out)))),
            fmd5 off #d @ sum (sum = md5 d ? (say out "md5 \(sum) as written\n", flush out)
                                (fail ("the flash sums " + sum + ", the image " + md5 d)))))
       (vs @ ("run" . f . r) (run (slurp f) (r @ (s . _) (num s) _ 5), leave 0)
             ["read" a n f] (connect 0, attach 0 @ sz (inside (num a) (num n) sz, fread (num a) (num n) f), leave 0)
             ["md5" a n] (connect 0, attach 0 @ sz (inside (num a) (num n) sz, say out (fmd5 (num a) (num n) + "\n"), flush out), leave 0)
             ["write" a f] (slurp f @ data (connect 0, attach 0 @ sz (inside (num a) #data sz, fwrite (num a) data), boot 0, leave 0))
             ["reset"] (boot 0, leave 0)
             _ (fail usage)))
   (main >argv))
