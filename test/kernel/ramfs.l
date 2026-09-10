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
; purpose: a/json.l is a file the boot never loads, and the write laws put its
; bytes back, so nothing downstream in the corpus sees a clobbered tree.
;
; the `:` has a body -- the test itself -- so the helpers stay local; and each
; law is its own assert argument, since test maps over its args and a `do` would
; report only the last one.

(: f "a/json.l"
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
   (! (port? (open "a/kore/no-such-thing.l" "r")))
   (: q (open "a/kore/no-such-thing.l" "w")
      (&& (port? q) (: _ (close q) !(unlink "a/kore/no-such-thing.l"))))
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
(borrow "a/json.l")
(test (elem 'json-read (names ())))

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

; /dev/{null,zero}. neither holds a byte: null IS the source table's empty slot, whose
; law is already "writes discard, reads answer the end", and zero is that slot with a
; read door that fills. the table rows exist only so stat and dents can see them.
(: (rd p) (: q (open p "r") (? (port? q) (: s (slurp q) _ (close q) s) ()))
   (wr p s) (: q (open p "w") (? (port? q) (: _ (say q s) _ (close q) 1) 0))
 (test
   (= "" (rd "/dev/null"))
   (wr "/dev/null" "into the hole")
   (= "" (rd "/dev/null"))                       ; and it kept none of it
   ; zero has NO END, so it is read a byte at a time and never slurped
   (: q (open "/dev/zero" "r") a (see q) _ (close q) (= 0 a))))

; symlinks, first class: k_walk follows one at EVERY component, so a directory can be a
; link. the machine's own compat names are three of them -- /bin, /sbin and /usr/sbin all
; name /usr/bin -- and a link made here answers the same way.
(: (rd p) (: q (open p "r") (? (port? q) (: s (slurp q) _ (close q) s) ()))
   (wr p s) (: q (open p "w") (? (port? q) (: _ (say q s) _ (close q) 1) 0))
 (test
   ; one directory, four doors: written through the real name, read back through each
   ; link -- which is what following one MID-path buys and the leaf-only walk could not.
   (wr "/usr/bin/hello" "hi")
   (= "hi" (rd "/bin/hello"))
   (= "hi" (rd "/sbin/hello"))
   (= "hi" (rd "/usr/sbin/hello"))
   (= "/usr/bin" (readlink "/bin"))              ; the target as WRITTEN, unfollowed
   ; a link of our own, then a link to that link
   (! (symlink "/usr/bin" "/opt"))
   (= "hi" (rd "/opt/hello"))
   (! (symlink "/opt" "/opt2"))
   (= "hi" (rd "/opt2/hello"))
   ; .. lands on the RESOLVED path: /opt is /usr/bin, so its parent is /usr
   (= "hi" (rd "/opt/../bin/hello"))
   ; unlink takes the link and never what it names
   (! (unlink "/opt2"))
   (= "hi" (rd "/opt/hello"))
   ; a pair naming each other is answered, not spun
   (! (symlink "/loop2" "/loop1"))
   (! (symlink "/loop1" "/loop2"))
   (! (port? (open "/loop1" "r")))))

; stat follows the last name and lstat does not -- the pair POSIX has, and the only
; reason k_walk carries a leaf flag. /bin is a link TO a directory, so the two answer
; different kinds of the same path. (stat p) -> (size mtime-ms mode ns).
(test
  (= 16384 (& ((stat "/bin") 2) 61440))          ; 040000: through the link, a directory
  (= 40960 (& ((lstat "/bin") 2) 61440))         ; 0120000: the link itself
  (= 8 (cap (lstat "/bin"))))                    ; sized by its target, "/usr/bin"
