; test/gate/machox.l ELF MACHO -- the ELF transposed to dyld's mach-o, with no objects, is
; mooncc's own mach-o link of the same objects, byte for byte, signature and all
; usage: love test/gate/machox.l ELF MACHO
(borrow '(holo posix kore))
(: (die m) (say err "FAIL machox: \(m)\n", quit 1)
   (slurp-file p) (uread p @ [1 s] (s + "") (die "cannot read \(p)"))
   _ (two? >>argv || die "usage: machox.l ELF MACHO")
   e (slurp-file <>argv) m (slurp-file <>>argv)
   t (join "" (map macho-str (macho-of-elf e (last (usplit 47 <>>argv)))))
   _ (#t = #m || die "\(#t) bytes, the link's \(#m)")
   _ (t = m || (filter (k \ t k != m k) ^#t @ d (die "\(#d) of \(#t) bytes differ, the first at \(<d)")))
   (say out "machox: \(#t) bytes, the ELF transposed is the mach-o link\n"))
