; src/tools/transpose.l -- a hosted -pie love laid as its kernel: re-base its PT_LOADs at the
; kernel base, apply love_rela ahead of time, lay and patch boot.o below the image, write
; k_image_top, and emit the flat ELF. cat after src/love/holo/{elf,obj,link}.l:
;
;   love <cat> in.pie boot.o out.elf arch [kernel.o ..]
;
; (transpose pie bootb out arch kobs) takes bytes, kobs the kernel's objects as [path bytes], laid
; past the data copy; the `love seed kernel` verb transposes the running binary.

(: (kparams arch)                       ; target, kernel base, entry symbol, image window
    ; the images run in the upper half, leaving the lower half to a process; boot stays physical
    (arch @ "x64"  ['x64   0x200000   "kmain" 0xffffff8000000000]
            "a64"  ['a64 0x40200000 "a64boot" 0xffffff8000000000]
            ; the pi's firmware enters at the start of the flat image, so boot leads
            "a64pi" ['a64 0x80000 "a64boot" 0xffffff8000000000]
            ; entered at the lowest load, not the entry symbol -- transpose lays boot first
            "rv64" ['rv64  0x80200000 "rvboot" 0xffffffe000000000]
            (scare 'transpose-arch arch))
   (kread p) (uread p @ r (two? r ? [p <>r] (scare 'transpose-open p)))

   (transpose pie bootb out arch kobs)
   (: kp (kparams arch)
      tgt (kp 0) kbase (kp 1) entnm (kp 2) xw (kp 3)
      mach (peep elf-machines tgt 0)

      ; --- the pie, parsed: program headers, the named sections, the symtab --
      phoff (rle64 pie 32) shoff (rle64 pie 40)
      phnum (rle16 pie 56) shnum (rle16 pie 60) shstrx (rle16 pie 62)
      (pho i) (phoff + i * 56)
      ; each load: (vaddr fileoff filesz memsz flags)
      pls ((: (go i acc)
                 (? (phnum <= i) (rev acc)
                    (go (i + 1)
                        (? (rle32 pie (pho i) = 1)
                           ([(rle64 pie (pho i + 16)) (rle64 pie (pho i + 8))
                             (rle64 pie (pho i + 32)) (rle64 pie (pho i + 40))
                             (rle32 pie (pho i + 4))] . acc)
                           acc)))) 0 ())
      ; ..and past the last, the first writable load's bytes again, base 0 and unpatched: where a
      ; process laid from this image starts its data
      dl ((: (go l) (? (atom? l) (scare 'transpose-data) (0 < <l 4 & 2) <l (go >l))) pls)
      pend ((: (go l m) (? (atom? l) m (go >l (: e (<l 0 + <l 3) (m < e ? e m))))) pls 0)
      dcopy [(ld-align 4096 pend) (dl 1) (dl 2) (dl 2) 4]
      (sho i) (shoff + i * 64)
      shstro (rle64 pie (sho shstrx + 24))
      (sname i) (ld-cstr pie (shstro + rle32 pie (sho i)))
      loads (pls + [dcopy])
      (shfind nm) ((: (go i) (? (shnum <= i) (scare 'transpose-section nm)
                                (sname i = nm) i (go (i + 1)))) 1)
      relo (: x (shfind ".love.rela") (rle64 pie (sho x + 24)))
      relz (: x (shfind ".love.rela") (rle64 pie (sho x + 32)))
      symo (: x (shfind ".symtab") (rle64 pie (sho x + 24)))
      symz (: x (shfind ".symtab") (rle64 pie (sho x + 32)))
      syminf (: x (shfind ".symtab") (rle32 pie (sho x + 44)))
      stro (: x (shfind ".strtab") (rle64 pie (sho x + 24)))
      strz (: x (shfind ".strtab") (rle64 pie (sho x + 32)))
      (pie-sym nm) ((: (go e)                    ; a defined global's value, or ()
                        (? (symo + symz <= e) ()
                           (: sx (rle16 pie (e + 6))
                              (0 < sx < 0xff00 && ld-cstr pie (stro + rle32 pie e) = nm
                               ? (rle64 pie (e + 8))
                                 (go (e + 24)))))) symo)
      (va2off v) ((: (go l)                      ; a vaddr's file offset, through its load
                      (? (atom? l) (scare 'transpose-va v)
                         (: g <l
                            (g 0 <= v && v < g 0 + g 2
                             ? (v - g 0 + g 1)
                               (go >l))))) loads)

      ; --- boot.o, laid below the image: ldkern's own head, one object -------
      objs [(ld-read "boot.o" bootb mach)]
      ne (ldlay1 'note kbase objs)
      b0 (ld-align 4096 ne) b1 (ldlay1 'boot b0 objs)
      t1 (ldlayn 'text (ldlay1 'text b1 objs) objs)
      o1 (ldlayn 'rodata (ldlay1 'rodata t1 objs) objs)
      d1 (ldlayn 'data (ldlay1 'data o1 objs) objs)
      bootend (ldlayn 'bss (ldlay1 'bss d1 objs) objs)
      bias (xw + ld-align 4096 bootend)
      ; --- the kernel's objects, laid past the image's data copy and linked against its symbols
      (gapz a b) (a < b ? [(ld-zeros (b - a))] ())
      kobjs (map (kb \ ld-read <kb <>kb mach) kobs)
      kv (ld-align 4096 (dcopy 0 + dcopy 3))
      k0 (bias + kv)
      kt1 (ldlayn 'text (ldlay1 'text k0 kobjs) kobjs)
      ko0 (ld-align 64 kt1)
      ko1 (ldlayn 'rodata (ldlay1 'rodata ko0 kobjs) kobjs)
      kd0 (ld-align 64 ko1)
      kd1 (ldlayn 'data (ldlay1 'data kd0 kobjs) kobjs)
      kend (ldlayn 'bss (ldlay1 'bss kd1 kobjs) kobjs)
      kload [kv #pie (kd1 - k0) (kend - k0) 7]
      glo (ldsyms (objs + kobjs))
      kglo (ldsyms kobjs)
      doors {}
      ; the pie's globals join the book (boot's own stand), so a boot reloc can name a kernel symbol;
      ; one the kernel defines too is a door, but a strong one stands over the kernel's weak
      _ ((: (go e)
             (? (symo + symz <= e) 0
                (: sx (rle16 pie (e + 6)) bind (pie (e + 4) >> 4)
                   _ (? (0 < sx < 0xff00 && elem bind '(1 2))
                        (: nm (ld-cstr pie (stro + rle32 pie e))
                           (? (two? (kglo nm) && (bind = 2 || !(kglo nm 1))) (pin doors nm (rle64 pie (e + 8)))
                              (two? (kglo nm)) (pin glo nm [(bias + rle64 pie (e + 8)) 0])
                              (two? (glo nm)) 0
                              (pin glo nm [(bias + rle64 pie (e + 8)) 0])))
                        0)
                   (go (e + 24))))) symo)
      ; each door's slot (love.h's love_door), a word of the image's data: the kernel's body, where
      ; the copy a process lays from keeps the hosted one
      slots ({} @ t ((each (keys doors) (\ nm (pie-sym (nm + "__slot") @ v
                                                (charm? v ? (pin t v <(glo nm)) (scare 'transpose-slot nm))))),
                     t))
      loads2 (loads + [kload])
      top ((: (go l m) (? (atom? l) m
                          (go >l (: e (bias + <l 0 + <l 3) (m < e ? e m)))))
           loads2 0)
      eaddr (: r (glo entnm) (two? r ? <r (scare 'transpose-entry entnm)))
      ; riscv keeps its own reloc numbers, so the machine says which namespace ldpatch reads
      nifx (shfind ".love.nifs")
      nifa (bias + rle64 pie (sho nifx + 16))
      nifz (rle64 pie (sho nifx + 32))
      ; the bracket is whole rows from the first: a skewed one binds every nif to its neighbour
      _ (nifa % 8 = 0 && nifz % 24 = 0 ? 0 (scare 'transpose-nifs [nifa nifz]))
      cx [glo nifa (nifa + nifz) b0 b0 () (mach = 243) () (backends tgt) (ld-extents (objs + kobjs)) ()]
      (ksym nm) (: r (glo nm) (two? r ? (<r - bias) (scare 'transpose-ksym nm)))
      kt (ldemitn cx 'text kobjs (ldemit cx 'text k0 kobjs ()))
      ko (ldemitn cx 'rodata kobjs (ldemit cx 'rodata ko0 kobjs (>kt + (gapz <kt ko0))))
      kd (ldemitn cx 'data kobjs (ldemit cx 'data kd0 kobjs (>ko + (gapz <ko kd0))))
      kbytes (foldl (\ a p (a + (string? p ? p (string (cask p))))) "" >kd)
      ; --- the patch list: love_rela sites slide by bias, but a door's slot takes the kernel's
      ; body; k_image_top, k_pie_base and k_pie_data take the image's far edge (physical), the
      ; pie's base and the data copy. ascending, for the one-pass splice below
      (ins s l) (? (atom? l) [s]
                   (<l 0 < s 0) (<l . ins s >l)
                   (s . l))
      sites (foldl (\ a v (ins [v (slots v)] a))
            (ins [(ksym "k_image_top") (top - xw)]
            (ins [(ksym "k_pie_base") bias]
            (ins [(ksym "k_pie_data") (bias + dcopy 0)]
            (rev ((: (go k acc)
                      (? (relz <= k) acc
                         (: v (rle64 pie (relo + k))
                            (go (k + 8) (!(nil? (peep slots v ())) ? acc
                                           ([v (bias + rle64 pie (va2off v))] . acc))))))
                 0 ())))))
            (sort (keys slots)))
      ; a site within a word of the one before would splice its bytes twice
      _ ((: (go l) (? (atom? >l) 0 (<>l 0 < <l 0 + 8) (scare 'transpose-sites [<l <>l]) (go >l))) sites)
      ; one load's bytes with its patches spliced in
      (spliced go0 va fsz ss)
       (: src (go0 < #pie ? pie kbytes)
          g0 (go0 < #pie ? go0 (go0 - #pie))
          ((: (go c l acc)
               (? (atom? l) (rev (snip src c (g0 + fsz) . acc))
                  (: o (g0 + (<l 0 - va))
                     (go (o + 8) >l (le64 (<l 1) . snip src c o . acc)))))
           g0 (filter (s \ va <= s 0 && s 0 < va + fsz) ss) ()))

      ; --- the output shape: header page (ehdr, phdrs, note), boot, the re-based image, symtab ---
      nsz (foldl (\ a ob (a + ld-lanesz ob 'note)) 0 objs)
      nph (2 + #loads2 - (0 < nsz ? 0 1))
      hdrsz (64 + 56 * nph)
      _ (4096 < hdrsz + nsz ? (scare 'transpose-headers hdrsz))
      (fo a) (a - kbase + 4096)
      ; each load's file offset: dense from where boot stopped, moved only to keep p_offset
      ; congruent to p_vaddr mod the page; address-linear would restore the zeros the link removed.
      (cfo c a) (a % 4096 - c % 4096 @ r (c + (r >= 0 ? r (r + 4096))))
      lds (rev ((: (go l c acc)
                    (? (atom? l) acc
                       (: g <l o (cfo c (bias + g 0))
                          (go >l (o + g 2) ((g + (o . ())) . acc)))))
                loads2 (fo d1) ()))
      phs (: bs [1 7 (fo b0) b0 b0 (d1 - b0) (bootend - b0) 4096]
             ps (map (g \ [1 (g 4) (g 5) (bias + g 0)
                            (bias + g 0 - xw) (g 2) (g 3) 4096])
                     lds)
             (0 < nsz ? ([4 4 hdrsz kbase kbase nsz nsz 4] . bs . ps)
                        (bs . ps)))
      en (ldemit cx 'note kbase objs ())
      ; the boot chain is address-linear from kbase plus a page, so it is seeded with the kbase..b0
      ; gap. each stage takes the pieces of the one before, bridged by its gap; bss is never emitted.
      eb (ldemit cx 'boot b0 objs [(ld-zeros (b0 - kbase))])
      et (ldemitn cx 'text objs (ldemit cx 'text b1 objs (>eb + (gapz <eb b1))))
      eo (ldemitn cx 'rodata objs (ldemit cx 'rodata t1 objs (>et + (gapz <et t1))))
      ed (ldemitn cx 'data objs (ldemit cx 'data o1 objs (>eo + (gapz <eo o1))))
      ; the image bytes, each load at the congruent file spot lds picked for it
      body ((: (go l c acc)
                (? (atom? l) [c acc]
                   (: g <l o (g 5)
                      (go >l (o + g 2)
                          (acc + ([(ld-zeros (o - c))] + spliced (g 1) (g 0) (g 2) sites))))))
           lds (fo d1) ())
      fsz <body
      ; the symtab, values slid: the uefi loader reads `kboot` out of it
      esy ((: (go e acc)
               (? (symo + symz <= e) (rev acc)
                  (: sx (rle16 pie (e + 6))
                     (go (e + 24)
                         (? (0 < sx < 0xff00)
                            ((snip pie (e + 16) (e + 24)) .
                             ((le64 (bias + rle64 pie (e + 8))) .
                              ((snip pie e (e + 8)) . acc)))
                            ((snip pie e (e + 24)) . acc))))))
           symo ())
      ; the kernel's globals join it: they are not in the pie's
      kxn (sort (keys kglo))
      kxs (foldl (\ a nm (a + nm + "\0")) "" kxn)
      kxy (rev <>(foldl (\ [o acc] nm [(o + #nm + 1) ((elf-sym o 1 0 0xfff1 (<(kglo nm)) 0) . acc)]) [strz ()] kxn))
      symz2 (symz + 24 * #kxn)
      strz2 (strz + #kxs)
      shstr (o-strtab '(".symtab" ".strtab" ".shstrtab"))
      (snm k) (<>shstr k)
      syo (ld-align 8 fsz)
      sto (syo + symz2) ssto (sto + strz2) sstz #<shstr
      shto (ld-align 8 (ssto + sstz))
      sht (catall [(elf-shdr 0 0 0 0 0 0 0 0 0 0)
                   (elf-shdr (snm 0) 2 0 0 syo symz2 2 syminf 8 24)
                   (elf-shdr (snm 1) 3 0 0 sto strz2 0 0 1 0)
                   (elf-shdr (snm 2) 3 0 0 ssto sstz 0 0 1 0)])
      hdr (elf64-hdrn 2 eaddr mach [shto 4 3]
                      (map (g \ elf64-phdr <g (g 1) (g 2) (g 3)
                                           (g 4) (g 5) (g 6) (g 7))
                           phs))
      (ld-write out
        (hdr . (>en + [(ld-zeros (4096 - (hdrsz + nsz)))] + >ed
                 + <>body
                 + [(ld-zeros (syo - fsz))]
                 + (esy + kxy + [(snip pie stro (stro + strz)) kxs <shstr
                           (ld-zeros (shto - (ssto + sstz))) sht])))))

   ; the file driver (the Makefile's recipe). arity-gated, since the `love seed kernel` verb evals this
   ; file too. a def, so the outer `:` stays define-mode and the call below is its own form.
   (tdrive as)
    (#as >= 4 ? (transpose <>(kread <as) <>(kread <>as) (as 2) (as 3)
                          (map kread (>(>(>(>as))))))
               0))

(tdrive >argv)
