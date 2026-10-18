; test/kernel/ramfs.l -- the ramfs: reads come off the initrd, the first write copies a file into
; the heap and later opens read the copy (per file, not per fd), an unbaked path reads as the zero
; point. kernel only: on the host these laws would write the tree. the scratch /etc/profile is
; never read by this boot, and its bytes are put back

(: f "/etc/profile"
   ; () when it would not open: presence rides `port?`, never emptiness
   (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s m) (open p m @ q (port? q ? (say q s, close q, 1) 0))
   orig (rd f)
 (test
   ; a baked path opens, with the bytes the archive put in the row
   (port? (open f "r"))
   (0 < #orig)
   ; a file does not drain
   (orig = rd f)
   ; an unbaked path is absent for a read; a write creates it (wfs.l's laws), so it is unmade here
   !(port? (open "/tmp/no-such-thing.l" "r"))
   (open "/tmp/no-such-thing.l" "w" @ q
      (port? q && (close q, !(unlink "/tmp/no-such-thing.l"))))
   ; the write copies the blob out of .rodata
   (wr f "hi" "w")
   ("hi" = rd f)
   ; append lands past what is there
   (wr f "!" "a")
   ("hi!" = rd f)
   ; a truncate drops the bytes, not the row
   (wr f "" "w")
   ("" = rd f)
   (wr f (orig + orig) "w")
   (orig + orig = rd f)
   ; the tree under /love is what modules load from, and read-only
   (0 < tally (rd "/love/src/apps/json.l"))
   !(wr "/love/src/apps/json.l" "no" "w")
   ; put it back
   (wr f orig "w")
   (orig = rd f)))

; the payoff: prel's module walk is gated on `open`, so `borrow` resolves off the ramfs with no
; prel change -- json is only in the initrd. it also reads the scratch back through the
; compiler, so it proves the restore above and must stay after those laws
(borrow "src/apps/json.l")
(test (elem 'json-read (names ())))

; /proc's live rows, filled at the open off state the syscall cannot see: a read arrives and
; wears the shape, `key value` lines, the first key naming the file
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ("ram-words " = snip (rd "/proc/meminfo") 0 10)
   ; ffalloc's invariant: blocks in address order, none touching
   (elem "free-ordered 1" (split "\n" (rd "/proc/meminfo")))
   ("pool-words " = snip (rd "/proc/gauge") 0 11)
   ; `cmdline` is (. "love" bootargv): the file opens on that word and ends with a newline
   ("love" = snip (rd "/proc/cmdline") 0 4)
   (rd "/proc/cmdline" @ c (10 = c (#c - 1)))
   !(wr "/proc/cmdline" "no")
   ; the ramfs never reads its own mode bits, so the refusal has to be the open's
   !(wr "/proc/meminfo" "no")
   !(wr "/proc/gauge" "no")
   ; the pen opens even with no console, as on every headless lane
   (port? (open "/proc/vt/fg" "r"))
   (port? (open "/proc/vt/bg" "r"))
   ; the glyph scale: the one vt file not a colour, and resized rather than repainted by a write
   (port? (open "/proc/vt/scale" "r"))))

; /dev/{null,zero} hold no bytes: null is the source table's empty slot, zero that slot with a
; read door that fills; the rows exist so stat and dents see them
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ("" = rd "/dev/null")
   (wr "/dev/null" "into the hole")
   ("" = rd "/dev/null")                       ; kept none
   ; zero has no end: read a byte, never slurp
   (: q (open "/dev/zero" "r") a (see q) (close q, (0 = a)))))

; symlinks: k_walk follows one at every component, so a directory can be a link. /bin, /sbin
; and /usr/sbin all name /usr/bin
(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   (wr p s) (open p "w" @ q (port? q ? (say q s, close q, 1) 0))
 (test
   ; written through the real name, read through each link: following mid-path
   (wr "/usr/bin/hello" "hi")
   ("hi" = rd "/bin/hello")
   ("hi" = rd "/sbin/hello")
   ("hi" = rd "/usr/sbin/hello")
   ("/usr/bin" = readlink "/bin")              ; the target as written, unfollowed
   ; the tree's other name is a read-only link onto it
   ("/love" = readlink "/proc/src")
   (0 < tally (rd "/proc/src/VERSION"))
   (rd "/proc/src/VERSION" = rd "/love/VERSION")
   (0 = wr "/proc/src/VERSION" "no")
   !(symlink "/usr/bin" "/opt")
   ("hi" = rd "/opt/hello")
   !(symlink "/opt" "/opt2")
   ("hi" = rd "/opt2/hello")
   ; .. lands on the resolved path: /opt's parent is /usr
   ("hi" = rd "/opt/../bin/hello")
   !(unlink "/opt2")
   ("hi" = rd "/opt/hello")
   ; a pair naming each other is answered, not spun
   !(symlink "/loop2" "/loop1")
   !(symlink "/loop1" "/loop2")
   !(port? (open "/loop1" "r"))))

; stat follows the last name and lstat does not, the reason k_walk carries a leaf flag.
; (stat p) -> (size mtime-ms mode ns)
(test
  (16384 = (stat "/bin") 2 & 61440)          ; 040000: a directory
  (40960 = (lstat "/bin") 2 & 61440)         ; 0120000: the link itself
  (8 = <(lstat "/bin")))                    ; sized by its target, "/usr/bin"
