; src/love/holo/macho.l -- the mach-o container: lay obj.l relocatables into a static
; macos executable instead of an ELF. ldlink's lay and patch (this file rides after
; link.l in a cat); only the clothing differs. a mach_header_64, __PAGEZERO under the
; base, one LC_SEGMENT_64 per lane and LC_UNIXTHREAD naming the entry: no dyld, no
; linkedit. xnu maps a segment from a page-aligned file offset, so the lanes land
; page-apart in the file as in memory (ldlay's dense 0), and .image, past .bss, opens
; the next page of each.

(module 'holo
(: macho-cpus {'x64 [16777223 3]}      ; cpu_type_x86_64, cpu_subtype_x86_64_all

   ; lc_segment_64 with no sections: the kernel maps the segment, not what it holds
   (macho-seg nm addr vsz off fsz prot)
    (catall [(le32 25) (le32 72) (map nm ^#nm) (ld-zeros (16 - #nm))
             (le64 addr) (le64 vsz) (le64 off) (le64 fsz) (le32 prot) (le32 prot) (le32 0) (le32 0)])
   ; lc_unixthread, x86_thread_state64: 21 words, rip the 17th, the rest zero
   (macho-thread ent)
    (catall [(le32 5) (le32 184) (le32 4) (le32 42) (ld-zeros 128) (le64 ent) (ld-zeros 32)])

   ; link a set -- ((id bytes)..), crt0 first -- into a static mach-o's piece list
   (macholink target srcs)
    (: cpu (peep macho-cpus target ())
       _ (two? cpu || scare 'macho-target target)
       objs (map (p \ ld-read <p <>p (peep elf-machines target 0)) srcs)
       pg 4096
       base elf-base
       img? (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs)
       nseg (4 + ?img?)                   ; pagezero text rodata data, and the image's
       hdrsz (32 + 72 * nseg + 184)
       lay (ldlay objs base hdrsz pg 0)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       dend (ld-align 16 end)
       bend (ldlayn 'bss (ldlay1 'bss dend objs) objs)
       ioff (ld-align pg (dend - base))
       iaddr (ld-align pg bend)
       iend (img? ? (ldlay1 'image iaddr objs) iaddr)
       glo (ldsyms objs)
       ent (: e (glo "_start")
              o1 <objs
              (two? e ? <e
                 (peep (peep o1 'base 0) <(peep (peep o1 'lanes 0) 'text ()) 0)))
       cx [glo n0 end end end {0 ()} () () (backends target) (ld-extents objs)]
       et (ldemitn cx 'text objs (ldemit cx 'text (base + hdrsz) objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs (>et + [(ld-zeros (o0 - <et))])))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs (>eo + [(ld-zeros (d0 - <eo))])))
       en (ldemit cx 'nifs <ed objs >ed)
       ei (img? ? (ldemit cx 'image iaddr objs ()) [iaddr])
       (up v) (ld-align pg v)
       cmds (catall ([(macho-seg "__PAGEZERO" 0 base 0 0 0)
                      (macho-seg "__TEXT" base (up (t1 - base)) 0 (t1 - base) 5)
                      (macho-seg "__RODATA" o0 (up (o1 - o0)) (o0 - base) (o1 - o0) 1)
                      (macho-seg "__DATA" d0 (up (bend - d0)) (d0 - base) (dend - d0) 3)]
                     + (img? ? [(macho-seg "__IMAGE" iaddr (up (iend - iaddr)) ioff (iend - iaddr) 3)])
                     + [(macho-thread ent)]))
       hdr (catall [(le32 4277009103) (le32 <cpu) (le32 <>cpu) (le32 2)   ; mh_magic_64, mh_execute
                    (le32 (nseg + 1)) (le32 #cmds) (le32 1) (le32 0) cmds])   ; mh_noundefs
       (hdrsz != #hdr ? (scare 'macho-headers #hdr),
        (hdr . (>en + [(ld-zeros (dend - <en))]
                + (img? ? ([(ld-zeros (ioff - (dend - base)))] + >ei)))))))
) ; module 'holo
