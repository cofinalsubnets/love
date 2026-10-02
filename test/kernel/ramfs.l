; test/kernel/ramfs.l -- the ramfs: reads come straight off the initrd, the first write copies a
; file into the heap and later opens read the copy (per file, not per fd), and an unbaked path
; reads as the zero point. kernel only: on the host these laws would write the tree. the scratch
; is /etc/profile, which this boot never reads, and its bytes are put back. each law is its own
; assert argument: a `do` would report only the last.

(: f "/etc/profile"
   ; slurp a path, closing behind -- () when it would not open, so presence rides
   ; `port?` and never the emptiness of what was read.
   (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s m) (open p m @ q (port? q ? (say q s, close q, 1) 0))
   orig (rd f)
 (test
   ; a baked path opens, and carries the bytes the archive put in the row
   (port? (open f "r"))
   (0 < #orig)
   ; ... and reads the same on the second open: a file does not drain
   (orig = rd f)
   ; an unbaked path is absent for a read; a write creates it now (rung 2 --
   ; wfs.l holds those laws), so here it is unmade the moment it is proved
   !(port? (open "/tmp/no-such-thing.l" "r"))
   (open "/tmp/no-such-thing.l" "w" @ q
      (port? q && (close q, !(unlink "/tmp/no-such-thing.l"))))
   ; the write copies the blob out of .rodata, and the next open sees it
   (wr f "hi" "w")
   ("hi" = rd f)
   ; ... and append lands past what is there, not over it
   (wr f "!" "a")
   ("hi!" = rd f)
   ; a truncate drops the copy's bytes without losing the row
   (wr f "" "w")
   ("" = rd f)
   ; a write bigger than the baked blob grows the copy
   (wr f (orig + orig) "w")
   (orig + orig = rd f)
   ; the tree under /love is what a module loads from, and nobody's to write
   (0 < tally (rd "/love/src/apps/json.l"))
   !(wr "/love/src/apps/json.l" "no" "w")
   ; put it back, and the tree reads as the bake left it
   (wr f orig "w")
   (orig = rd f)))

; the payoff, and the end-to-end proof the rung is real: prel's module walk is gated
; on the presence of `open` (src/love/boot/prel.l's fsopen, by peep), so with the row in
; defs[] `borrow` resolves lib/<x>.l off the ramfs with zero prel change -- json is in
; no baked ai_libs table on this seat, only in the initrd. it also reads the
; scratch back through the compiler, so it is the restore above proving itself byte
; for byte; it has to stay after those laws.
(borrow "src/apps/json.l")
(test (elem 'json-read (names ())))

; /proc's live rows. meminfo is the kernel's own free list, gauge the collector's
; counters -- both filled at the open, off state the syscall under it cannot see, so
; the law that matters is that a read arrives at all and wears the shape. `key value`
; lines, and the first key names the file.
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ("ram-words " = snip (rd "/proc/meminfo") 0 10)
   ("pool-words " = snip (rd "/proc/gauge") 0 11)
   ; the boot line, the row that says what this machine was asked to run. love's own
   ; `cmdline` is (. "love" bootargv), so the file opens on that word whatever the
   ; line after it, and ends the way a line does
   ("love" = snip (rd "/proc/cmdline") 0 4)
   (rd "/proc/cmdline" @ c (10 = c (#c - 1)))
   !(wr "/proc/cmdline" "no")
   ; nobody's to set: the ramfs never reads its own mode bits, so 0444 is a label and
   ; the refusal has to be the open's
   !(wr "/proc/meminfo" "no")
   !(wr "/proc/gauge" "no")
   ; the console's pen opens either way -- it reads empty on a seat with no console,
   ; which every headless lane in this corpus is
   (port? (open "/proc/vt/fg" "r"))
   (port? (open "/proc/vt/bg" "r"))
   ; and the glyph scale beside them -- the one vt file that is not a colour, and the
   ; only console state a write RESIZES rather than repaints
   (port? (open "/proc/vt/scale" "r"))))

; /dev/{null,zero}. neither holds a byte: null IS the source table's empty slot, whose
; law is already "writes discard, reads answer the end", and zero is that slot with a
; read door that fills. the table rows exist only so stat and dents can see them.
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ("" = rd "/dev/null")
   (wr "/dev/null" "into the hole")
   ("" = rd "/dev/null")                       ; and it kept none of it
   ; zero has NO END, so it is read a byte at a time and never slurped
   (: q (open "/dev/zero" "r") a (see q) (close q, (0 = a)))))

; symlinks, first class: k_walk follows one at EVERY component, so a directory can be a
; link. the machine's own compat names are three of them -- /bin, /sbin and /usr/sbin all
; name /usr/bin -- and a link made here answers the same way.
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ; one directory, four doors: written through the real name, read back through each
   ; link -- which is what following one MID-path buys and the leaf-only walk could not.
   (wr "/usr/bin/hello" "hi")
   ("hi" = rd "/bin/hello")
   ("hi" = rd "/sbin/hello")
   ("hi" = rd "/usr/sbin/hello")
   ("/usr/bin" = readlink "/bin")              ; the target as WRITTEN, unfollowed
   ; the tree's old name is a link onto it, read-only through either
   ("/love" = readlink "/proc/src")
   (0 < tally (rd "/proc/src/VERSION"))
   (rd "/proc/src/VERSION" = rd "/love/VERSION")
   (0 = wr "/proc/src/VERSION" "no")
   ; a link of our own, then a link to that link
   !(symlink "/usr/bin" "/opt")
   ("hi" = rd "/opt/hello")
   !(symlink "/opt" "/opt2")
   ("hi" = rd "/opt2/hello")
   ; .. lands on the RESOLVED path: /opt is /usr/bin, so its parent is /usr
   ("hi" = rd "/opt/../bin/hello")
   ; unlink takes the link and never what it names
   !(unlink "/opt2")
   ("hi" = rd "/opt/hello")
   ; a pair naming each other is answered, not spun
   !(symlink "/loop2" "/loop1")
   !(symlink "/loop1" "/loop2")
   !(port? (open "/loop1" "r"))))

; stat follows the last name and lstat does not -- the pair POSIX has, and the only
; reason k_walk carries a leaf flag. /bin is a link TO a directory, so the two answer
; different kinds of the same path. (stat p) -> (size mtime-ms mode ns).
(test
  (16384 = (stat "/bin") 2 & 61440)          ; 040000: through the link, a directory
  (40960 = (lstat "/bin") 2 & 61440)         ; 0120000: the link itself
  (8 = <(lstat "/bin")))                    ; sized by its target, "/usr/bin"
