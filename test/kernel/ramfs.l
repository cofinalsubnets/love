; The ramfs, inle's rung 0. The initrd is .rodata -- the
; artifact's own source blob, inflated and walked as a tar into one {path, bytes,
; len} row per file -- and reads come straight off it; the first write copies the
; blob into the kernel heap and the file reads from the copy ever after. So: a
; baked path opens and reads, an unbaked one answers the zero point for a read (a
; write CREATES since rung 2), and a write is visible to the next open, because
; the copy is per file and not per fd.
;
; kernel only -- test/kernel/all.l's roster, never $t: on the host `open` is the real
; filesystem and these laws would write the tree. The scratch is a real baked row on
; purpose: apps/json.l is a file the boot never loads, and the write laws put its
; bytes back, so nothing downstream in the corpus sees a clobbered tree.
;
; the `:` has a body -- the test itself -- so the helpers stay local; and each
; law is its own assert argument, since test maps over its args and a `do` would
; report only the last one.

(: f "apps/json.l"
   ; slurp a path, closing behind -- () when it would not open, so presence rides
   ; `port?` and never the emptiness of what was read.
   (rd p) (: q (open p "r") (? (port? q) (: s (slurp q) _ (close q) s) ()))
   (wr p s m) (: q (open p m) (? (port? q) (: _ (say q s) _ (close q) 1) 0))
   orig (rd f)
 (test
   ; a baked path opens, and carries the bytes the archive put in the row
   (port? (open f "r"))
   (< 0 (tally orig))
   ; ... and reads the same on the second open: a file does not drain
   (= orig (rd f))
   ; an unbaked path is absent for a read; a write creates it now (rung 2 --
   ; wfs.l holds those laws), so here it is unmade the moment it is proved
   (! (port? (open "apps/kore/no-such-thing.l" "r")))
   (: q (open "apps/kore/no-such-thing.l" "w")
      (&& (port? q) (: _ (close q) !(unlink "apps/kore/no-such-thing.l"))))
   ; the write copies the blob out of .rodata, and the next open sees it
   (wr f "hi" "w")
   (= "hi" (rd f))
   ; ... and append lands past what is there, not over it
   (wr f "!" "a")
   (= "hi!" (rd f))
   ; a truncate drops the copy's bytes without losing the row
   (wr f "" "w")
   (= "" (rd f))
   ; a write bigger than the baked blob grows the copy
   (wr f (+ orig orig) "w")
   (= (+ orig orig) (rd f))
   ; /proc/src is the same row read past every write above -- the mount is what lets a
   ; module load from bytes the tree it is editing cannot have reached
   (= orig (rd (+ "/proc/src/" f)))
   (! (wr (+ "/proc/src/" f) "no" "w"))
   ; put it back, and the tree reads as the bake left it
   (wr f orig "w")
   (= orig (rd f))))

; the payoff, and the end-to-end proof the rung is real: prel's module walk is gated
; on the presence of `open` (l/boot/prel.l's fsopen, by peep), so with the row in
; defs[] `borrow` resolves lib/<x>.l off the ramfs with zero prel change -- json is in
; no baked ai_libs table on this seat, only in the initrd. it also reads the
; scratch back through the compiler, so it is the restore above proving itself byte
; for byte; it has to stay after those laws.
(borrow "apps/json.l")
(test (member? 'json-read (names ())))

; /proc's live rows. meminfo is the kernel's own free list, gauge the collector's
; counters -- both filled at the open, off state the syscall under it cannot see, so
; the law that matters is that a read arrives at all and wears the shape. `key value`
; lines, and the first key names the file.
(: (rd p) (: q (open p "r") (? (port? q) (: s (slurp q) _ (close q) s) ()))
   (wr p s) (: q (open p "w") (? (port? q) (: _ (say q s) _ (close q) 1) 0))
 (test
   (= "ram-words " (snip (rd "/proc/meminfo") 0 10))
   (= "pool-words " (snip (rd "/proc/gauge") 0 11))
   ; nobody's to set: the ramfs never reads its own mode bits, so 0444 is a label and
   ; the refusal has to be the open's
   (! (wr "/proc/meminfo" "no"))
   (! (wr "/proc/gauge" "no"))
   ; the console's pen opens either way -- it reads empty on a seat with no console,
   ; which every headless lane in this corpus is
   (port? (open "/proc/vt/fg" "r"))
   (port? (open "/proc/vt/bg" "r"))))
