; src/tools/halfkay.l -- a teensy 4.x's HalfKay bootloader over its hid interface: a flat image
; written by flash offset, then the board started.
;   love src/tools/halfkay.l find              the board's hidraw node and its output report's size
;   love src/tools/halfkay.l frame IN.bin OUT  the reports a write would send, end to end; no device
;   love src/tools/halfkay.l write IN.bin      wait for the board, write, start the program
; the board is in HalfKay after its button, or after its running usb serial is set to 134 baud. an
; output report is 1088 bytes: the flash offset in three bytes low first, 61 zeros, 1024 of the
; image. the first write erases the whole flash, so block 0 always goes; after it a block of FFs
; is left as the erase made it. a report at offset FFFFFF starts the program. there is no readback
(borrow 'posix)
(: blk 1024 rep 1088
   most 8192                                          ; the 4.1's 8 MB in blocks
   ; the waits are PJRC's and its forum's: a full erase on a 4.x has been seen to take 45 s, a
   ; block after it answers within half a second. measured on a 4.1: it takes two blocks at
   ; once and refuses the third for 3.3 s while it erases, 658 blocks with the erase go in
   ; 10.6 s, and the same image over itself in 0.8 s. so the erase's wait covers every block
   ; inside it, not the first alone
   t-erase 45000 t-next 500 t-node 10000 t-gone 15000
   (die m) (say err ("halfkay: " + m + "\n"), flush err, quit 1)
   ff (string (map (_ \ 255) ^blk))
   zz (string (map (_ \ 0) ^blk))
   (report off d) (string ([(off & 255) ((off >> 8) & 255) ((off >> 16) & 255)] + map (_ \ 0) ^61) + d)
   (block s k) (snip s (k * blk) (min #s (k * blk + blk)) @ d (d + snip ff 0 (blk - #d)))
   ; the reports for image s, in order, the start last
   (frames s)
    (: n ((#s + blk - 1) // blk)
       (go k acc) (? (n <= k) (rev (report 0xFFFFFF zz . acc))
                     (block s k @ d ((0 < k && (d = ff)) ? (go (k + 1) acc) (go (k + 1) (report (k * blk) d . acc)))))
       (go 0 ()))
   ; a hid report descriptor's output bytes, and whether it numbers its reports: [bytes id]
   (outsize d)
    (: (val i n) (n = 0 ? 0 (d i + 256 * val (i + 1) (n - 1)))
       (go i sz cnt o id)
        (? (#d <= i) [o id]
           (: b (d i) n ((b & 3) @ 3 4 k k) j (i + 1 + n)
              v (j <= #d ? (val (i + 1) n) (die "a report descriptor cut short"))
              ((b & 252) @ 116 (go j v cnt o id) 148 (go j sz v o id)
                           144 (go j sz cnt (o + (sz * cnt) // 8) id) 132 (go j sz cnt o 1)
                           _ (go j sz cnt o id))))
       (go 0 0 0 0 0))
   sys "/sys/class/hidraw/"
   ; the hidraw nodes that are PJRC's HalfKay (16C0:0478)
   (nodes _) (readdir sys @ l (two? l ? (filter (n \ uread (sys + n + "/device/uevent") @ [1 t] (t @ (a + "HID_ID=0003:000016C0:00000478\n" + b) 1 _ 0) _ 0) (sort l)) ()))
   (await t) (nodes 0 @ l (? (two? l) <l (clock 0 < t) (rest 100, await t) ()))
   (gone node t) (? (two? (stat ("/dev/" + node))) (clock 0 < t ? (rest 50, gone node t) 0) 1)
   ; the start report, sent until the board leaves: it refuses one while it still writes, and
   ; detaches as it takes one, so the write's own answer says nothing
   (start fd r node t) (: _ (push fd r) (? (gone node (clock 0 + 300)) 1 (clock 0 < t) (start fd r node t) 0))
   ; the node's output report must be HalfKay's on a 4.x, unnumbered
   (fits node)
    (: d (uread (sys + node + "/device/report_descriptor") @ [1 d] d _ (die ("cannot read " + node + "'s report descriptor")))
       o (outsize d)
       n (o 0) id (o 1 = 1 ? " and numbered" "")
       ((n = rep && (o 1 = 0)) ? n
          (die "\(node)'s output report is \(n) bytes\(id), not a teensy 4.x's \(rep) unnumbered: nothing written")))
   ; one report as one write, a 0 ahead of it for the report id the board does not use
   (push fd r) (cask (0 . map r ^#r) @ c (fdpush fd c 0 0 #c @ n (charm? n && n = #c ? 1 n)))
   ; 1 once the report is taken, else the last refusal at time t
   (until fd r t) (push fd r @ n (? (n = 1) 1 (clock 0 < t) (rest 20, until fd r t) n))
   (image p) (: s (uread p @ [1 s] s _ (die ("cannot read " + p)))
                _ (0 < #s ? 0 (die ("empty image " + p)))
                _ (#s <= most * blk ? 0 (die "\(p) is \(#s) bytes, past the \(most * blk) of a teensy 4.1's flash"))
                s)
   (write p)
    (: s (image p) fs (frames s)
       node (await (clock 0 + t-node) @ n (string? n ? n (die "no board in HalfKay (press its button, or set its usb serial to 134 baud)")))
       _ (fits node)
       fd (openfd ("/dev/" + node) 4 @ fd (charm? fd ? fd (die ("/dev/" + node + ": " + uerrno fd))))
       t0 (clock 0)
       held {'ms 0 'k 0}                              ; the longest a block waited, and which
       (go l k) (? (atom? >l) k
                   (: t1 (clock 0)
                      n (until fd <l (max (t0 + t-erase) (t1 + t-next)))
                      w (clock 0 - t1)
                      _ (held 'ms < w ? (pin held 'ms w, pin held 'k k) 0)
                      (n = 1 ? (go >l (k + 1))
                         (die "a block was not taken (\(charm? n ? "a short write" (uerrno n))), \(k) written before it: the flash is part written"))))
       k (go fs 0)
       ms (clock 0 - t0)
       (start fd (fs (#fs - 1)) node (clock 0 + t-gone) ? (say out "halfkay: \(k) blocks of \((#s + blk - 1) // blk) written from \(p) in \(ms) ms (write \(held 'k) waited \(held 'ms) ms), started\n", flush out, 0)
          (die "\(k) blocks written, but \(node) is still in HalfKay")))
   (main as)
    (as @ ["find"] (nodes 0 @ l (two? l ? (map (n \ say out "/dev/\(n) \(fits n)\n") l, flush out, 0) (die "no board in HalfKay")))
          ["frame" p q] (frames (image p) @ fs (uwrite q (join "" fs) ? 0 (die ("cannot write " + q))))
          ["write" p] (write p)
          _ (die "usage: love src/tools/halfkay.l find | frame IN.bin OUT | write IN.bin"))
   (main >argv))
