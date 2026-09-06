; src/apps/fat/fatcmd.l -- `love fat` and `love mkfs.vfat`: a command line over
; src/apps/fat/fat.l's FAT32. fat.l is the filesystem; this file is the face -- the
; verbs, the image-as-a-device, and the write-back.
;
;   love fat ls    IMG [PATH]        the names in a directory, one a line
;   love fat stat  IMG PATH          size and attribute bits
;   love fat cat   IMG PATH          a file's bytes on stdout
;   love fat get   IMG PATH [DST]    ... into a file instead (- is stdout)
;   love fat put   IMG PATH [SRC]    a file (or stdin) written to PATH
;   love fat mkdir IMG PATH
;   love fat rm    IMG PATH          a file, or an empty directory
;   love fat mkfs  IMG [SIZE]        format; SIZE like 64M makes the image first
;   love mkfs.vfat [-C] IMG [BLOCKS] busybox's spelling of the same format
;   love mkdosfs   ...               ... and its other name
;
; THE DEVICE IS THE WHOLE IMAGE IN MEMORY. fat.l wants a (rd wr nsec) chain and this
; one is a cask: the file is read once, the verb runs, and the cask goes back to disk
; only if something wrote. That is the same device shape test/host/fat.l drives the
; laws through, which is why there is no second code path to get wrong -- and it is
; honest about the cost: a 64 MB image is 64 MB of heap and a whole-file rewrite per
; mutating verb. Positioned reads would want a pread nif; nothing here has one.
;
; ⚠ FAT32 REFUSES ANYTHING UNDER ~33 MB, by the format's own law -- under 65525
; clusters the type is FAT16 by definition. `fat mkfs` on a smaller image answers the
; refusal rather than writing something that is not what its boot sector claims.
;
; every verb answers a status charm, 0 ok / 1 the operation said no / 2 a usage or an
; unreadable image, so a script reads the difference between "no such file in there"
; and "that is not a filesystem".
(module 'fatcmd
(use 'fat)

(: fatc-usage "usage: fat {ls|stat|cat|get|put|mkdir|rm|mkfs} IMG [PATH..]"
   (fatc-moan m) (: _ (say err ("fat: " + m)) _ (put err 10) _ (flush err) 1)
   (fatc-die c m) (: _ (fatc-moan m) (quit c))
   (fatc-slurp p) (: q (open p "r") (hot? q && (: s (slurp q) _ (close q) [1 (s + "")])))
   (fatc-blurt p s) (: q (open p "w") (hot? q && (: _ (say q s) _ (close q) 1)))

   ; a size word: 64M, 40m, 33554432. answers charms, () when it will not read.
   (fatc-size s)
    (: n #s
       (dig k a) (? (n <= k) [a ""]
                    (48 <= (s k) <= 57) (dig (k + 1) (a * 10 + (s k - 48)))
                    [a (snip s k n)])
       p (dig 0 0)
       v <p sfx <>p
       (? !#s () (! (48 <= (s 0) <= 57)) ()
          (sfx = "") v
          ((sfx = "k") || (sfx = "K")) (v * 1024)
          ((sfx = "m") || (sfx = "M")) (v * 1048576)
          ((sfx = "g") || (sfx = "G")) (v * 1073741824)
          ()))

   ; the image as a cask, and the cask as fat.l's device. rd hands back a fresh
   ; string (fat.l indexes it); wr pours into the cask and marks it dirty, which is
   ; what decides whether the file is rewritten at the end.
   (fatc-dev im dirty)
    [(\ lba n (: b (cask (n * 512)) _ (pour b 0 im (lba * 512) (n * 512)) (string b)))
     (\ lba s (: _ (pour im (lba * 512) s 0 #s) _ (pin dirty 0 1) (#s // 512)))
     (#im // 512)]

   ; open IMG as a mounted fs: answers [im dirty fs], or leaves through fatc-die.
   ; ⚠ the two failures are told apart on purpose: a missing file and a file that is
   ; not a FAT32 want different repairs, and one "cannot read" sends you to the wrong one.
   (fatc-open img)
    (: t (fatc-slurp img)
       _ (? t () (fatc-die 2 ("cannot read " + img)))
       s <>t
       im (cask #s)
       _ (#s && (pour im 0 s 0 #s))
       dirty (tablet 0)
       f (fat-mount (fatc-dev im dirty))
       _ (? (tablet? f) () (fatc-die 2 (img + ": not a FAT32 filesystem")))
       [im dirty f])
   ; the write-back, once, and only when something wrote
   (fatc-sync img im dirty)
    (? (peep dirty 0 0)
       (? (fatc-blurt img (string im)) 0 (fatc-moan ("cannot write " + img)))
       0)

   (fatc-ls img path)
    (: b (fatc-open img)
       r (fat-ls <>>b path)
       (? (two? r) (: _ (map (\ n (: _ (say out n) (put out 10))) (sort <>r))
                      _ (flush out) 0)
          (fatc-moan (path + ": no such directory"))))
   (fatc-stat img path)
    (: b (fatc-open img)
       r (fat-stat <>>b path)
       (? (two? r) (: _ (say out ((show <>r) + " bytes, attr " + (show <>>r)))
                      _ (put out 10) _ (flush out) 0)
          (fatc-moan (path + ": no such file"))))
   (fatc-get img path dst)
    (: b (fatc-open img)
       r (fat-read <>>b path)
       (? !(two? r) (fatc-moan (path + ": no such file"))
          ((dst = "") || (dst = "-")) (: _ (say out <>r) _ (flush out) 0)
          (? (fatc-blurt dst <>r) 0 (fatc-moan ("cannot write " + dst)))))
   (fatc-put img path src)
    (: t (? ((src = "") || (src = "-")) [1 (slurp in)] (fatc-slurp src))
       _ (? t () (fatc-die 2 ("cannot read " + src)))
       b (fatc-open img)
       im <b dirty <>b f <>>b
       ok (fat-write f path <>t)
       (? ok (fatc-sync img im dirty)
          (fatc-moan (path + ": cannot write (no parent directory, or the disk is full)"))))
   (fatc-mkdir img path)
    (: b (fatc-open img)
       (? (fat-mkdir <>>b path) (fatc-sync img <b <>b)
          (fatc-moan (path + ": cannot make (it exists, or its parent does not)"))))
   (fatc-rm img path)
    (: b (fatc-open img)
       (? (fat-rm <>>b path) (fatc-sync img <b <>b)
          (fatc-moan (path + ": cannot remove (no such file, or a directory with things in it)"))))
   ; mkfs: an existing image is formatted where it lies; a SIZE makes one first.
   ; ⚠ a size given for a file that is already there is honoured -- the image is
   ; remade at that size, which is what `mkfs.vfat -C` means and what a script
   ; re-running its own setup wants.
   (fatc-mkfs img size)
    (: have (fatc-slurp img)
       n (? (charm? size) size (? have #(<>have) 0))
       _ (? (charm? n && (0 < n)) () (fatc-die 2 ("no size for " + img + ", and no image there")))
       _ (? (% n 512) (fatc-die 2 "the size must be a whole number of 512-byte sectors") ())
       im (cask n)
       _ (? ((! (charm? size)) && have) (: s <>have (#s && (pour im 0 s 0 #s))) ())
       dirty (tablet 0)
       (? (fat-mkfs (fatc-dev im dirty))
          (? (fatc-blurt img (string im)) 0 (fatc-moan ("cannot write " + img)))
          (fatc-moan (img + ": too small for FAT32 (it wants about 33 MB; "
                          + "under 65525 clusters the format IS FAT16)"))))

   (fat-main av)
    (: n #av
       (arg k) (? (n <= k) "" (av k))
       v <av img (arg 1) p (arg 2)
       (? (n < 2) (: _ (say err (fatc-usage + "\n")) (quit 2))
          (v @
           "ls"    (fatc-ls img p)
           "stat"  (: _ (? #p () (fatc-die 2 "stat wants a path")) (fatc-stat img p))
           "cat"   (: _ (? #p () (fatc-die 2 "cat wants a path")) (fatc-get img p "-"))
           "get"   (: _ (? #p () (fatc-die 2 "get wants a path")) (fatc-get img p (arg 3)))
           "put"   (: _ (? #p () (fatc-die 2 "put wants a path")) (fatc-put img p (arg 3)))
           "mkdir" (: _ (? #p () (fatc-die 2 "mkdir wants a path")) (fatc-mkdir img p))
           "rm"    (: _ (? #p () (fatc-die 2 "rm wants a path")) (fatc-rm img p))
           "mkfs"  (fatc-mkfs img (? #p (fatc-size p) ()))
           w       (: _ (say err ("fat: unknown verb " + w + "\n" + fatc-usage + "\n"))
                      (quit 2)))))
   ; busybox spells the format two ways and takes -C SIZE-IN-1K-BLOCKS after the name.
   ; the blocks are 1024 here, which is what mkfs.vfat's own BLOCKS means.
   (mkfsv-main av)
    (: as (? ((two? av) && (<av = "-C")) >av av)
       (? !(two? as) (: _ (say err "usage: mkfs.vfat [-C] IMG [BLOCKS]\n") (quit 2))
          (: img <as
             bl (? (two? >as) (fatc-size <>as) ())
             (fatc-mkfs img (? (charm? bl) (bl * 1024) ())))))

   T (from 'verbs 'tab)
   _ (pins T 'fat fat-main 'mkfs.vfat mkfsv-main 'mkdosfs mkfsv-main))

) ; module 'fatcmd
