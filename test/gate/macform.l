; test/gate/macform.l ELF MACHO -- one link as an ELF and as dyld's mach-o: the mach-o lays its
; sections where ldlink does, so every reach from the code agrees and the code is the same bytes.
; the mach-o's __text may run on past the ELF's .text in zeros, its last object's alignment
; usage: love test/gate/macform.l ELF MACHO
(borrow 'posix)
(: (die m) (say err "FAIL macform: \(m)\n", quit 1)
   (slurp-file p) (uread p @ [1 s] (s + "") (die "cannot read \(p)"))
   _ (two? >>argv || die "usage: macform.l ELF MACHO")
   e (slurp-file <>argv) m (slurp-file <>>argv)
   (le s o n) (foldl (\ a k (a * 256 + s (o + k))) 0 (rev ^n))
   (name s o) (snip s o (o + 16) @ n (: z (filter (k \ n k = 0) ^16) (atom? z ? n (snip n 0 <z))))
   ; the ELF's .text is ldlink's section 1
   sh (le e 40 8 + 64)
   eo (le e (sh + 24) 8) en (le e (sh + 32) 8)
   ; the mach-o's __TEXT,__text: (offset size), or ()
   (sect at k)
    (k = 0 ? ()
       (: (one j s) (j = 0 ? () (? (name m s = "__text") [(le m (s + 48) 4) (le m (s + 40) 8)] (one (j - 1) (s + 80))))
          c (le m at 4) sz (le m (at + 4) 4)
          r (c = 25 && name m (at + 8) = "__TEXT" ? (one (le m (at + 64) 4) (at + 72)))
          (two? r ? r (sect (at + sz) (k - 1)))))
   mt (sect 32 (le m 16 4))
   _ (two? mt || die "the mach-o has no __TEXT,__text")
   mo <mt mn <>mt
   _ (mn < en && die "__text is \(mn) bytes, .text \(en)")
   _ (snip m (mo + en) (mo + mn) = string (map (_ \ 0) ^(mn - en)) || die "__text runs on past .text in more than zeros")
   d (filter (k \ e (eo + k) != m (mo + k)) ^en)
   _ (atom? d || die "\(#d) of \(en) code bytes differ, the first at +\(<d)")
   (say out "macform: \(en) code bytes alike in the ELF and the mach-o\n"))
