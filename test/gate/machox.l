; test/gate/machox.l ELF MACHO -- the ELF transposed to dyld's mach-o, with no objects, is
; mooncc's own mach-o link of the same objects, byte for byte, symbols and signature and all;
; and that mach-o transposed back is the ELF
; usage: love test/gate/machox.l ELF MACHO
(borrow '(holo posix kore))
(: (die m) (say err "FAIL machox: \(m)\n", quit 1)
   (slurp-file p) (uread p @ [1 s] (s + "") (die "cannot read \(p)"))
   _ (two? >>argv || die "usage: machox.l ELF MACHO")
   e (slurp-file <>argv) m (slurp-file <>>argv)
   (same t u what) (t = u || (: n (min #t #u) d (filter (k \ t k != u k) ^n)
                            (die "\(what): \(#t) bytes against \(#u), \(#d) of the first \(n) differ, the first at \(<d)")))
   t (join "" (map macho-str (macho-of-elf e (last (usplit 47 <>>argv)))))
   _ (same t m "the transpose and the mach-o link")
   b (join "" (map macho-str (elf-of-macho m)))
   _ (same b e "the mach-o transposed back and the ELF")
   (say out "machox: \(#t) bytes there and \(#b) back, each the other link\n"))
