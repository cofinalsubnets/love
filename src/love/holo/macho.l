; src/love/holo/macho.l -- the mach-o container: obj.l relocatables laid as a macos executable
; by ldlink's lay and patch (this file rides after link.l in a cat). xnu maps a segment from a
; page-aligned file offset, so the lanes land page-apart in the file as in memory, and .image
; opens the next page past .bss. a dyld exe imports what no object defines through a stub and
; a slot dyld binds by name, flat; a weak import's slot stays 0 where nothing answers it.
; dyld still enters an LC_UNIXTHREAD exe on the kernel's stack, so crt0 is none the wiser.

(module 'holo
(: macho-cpus {'x64 [16777223 3]}      ; cpu_type_x86_64, cpu_subtype_x86_64_all

   ; lc_segment_64 with no sections: the kernel maps the segment, not what it holds
   (macho-seg nm addr vsz off fsz prot)
    (catall [(le32 25) (le32 72) (map nm ^#nm) (ld-zeros (16 - #nm))
             (le64 addr) (le64 vsz) (le64 off) (le64 fsz) (le32 prot) (le32 prot) (le32 0) (le32 0)])
   ; lc_unixthread, x86_thread_state64: 21 words, rip the 17th, the rest zero
   (macho-thread ent)
    (catall [(le32 5) (le32 184) (le32 4) (le32 42) (ld-zeros 128) (le64 ent) (ld-zeros 32)])

   (macho-uleb n) (: b (n % 128) r (n // 128) (r = 0 ? [b] (b + 128 . macho-uleb r)))
   ; a path-bearing load command: the head, the path at `at`, NUL-ended and padded to 8
   (macho-pathcmd cmd at hd path)
    (: n (ld-align 8 (at + #path + 1))
       (catall [(le32 cmd) (le32 n) hd (map path ^#path) (ld-zeros (n - at - #path))]))
   (macho-dylib path) (macho-pathcmd 12 24 (catall [(le32 24) (le32 2) (le32 65536) (le32 65536)]) path)
   macho-dyld (macho-pathcmd 14 12 (le32 12) "/usr/lib/dyld")
   ; dyld wants the platform said (lc_build_version: macos, 10.15 and on) and a uuid
   macho-plat (catall [(le32 50) (le32 24) (le32 1) (le32 659200) (le32 720896) (le32 0)])
   ; the uuid: an fnv-1a fold of what tells the exes apart, from two seeds
   (macho-fnv h s) (foldl (\ a b ((a ^ b) * 1099511628211 & 18446744073709551615)) h (map s ^#s))
   (macho-uuid s) (catall [(le32 27) (le32 24) (le64 (macho-fnv 14695981039346656037 s)) (le64 (macho-fnv 1469598103934665603 s))])

   ; the weak undefined names no object defines: a dyld exe's weak imports
   (macho-weak-undefs objs)
    (: defs {}
       (syms ob) (map (i \ peep (peep ob 'syms 0) i ()) ^(peep ob 'nsym 0))
       _ (map (ob \ map (sy \ two? sy && 0 < sy 3 && elem (sy 1) '(1 2) ? (pin defs <sy 1)) (syms ob)) objs)
       (foldl (\ a ob (foldl (\ a2 sy (two? sy && sy 1 = 2 && sy 3 = 0 && !(defs <sy) && !(elem <sy a2)
                                         && !(elem <sy ldsynth) && !(ld-bracket? <sy)
                                         ? (a2 + [<sy]) a2))
                             a (syms ob)))
              () objs))

   ; link ((id bytes)..), crt0 first, into a mach-o's piece list. dyn? lays a dyld exe loading
   ; libSystem and dylibs; else static
   (macholink target srcs dyn? dylibs)
    (: cpu (peep macho-cpus target ())
       _ (two? cpu || scare 'macho-target target)
       objs0 (map (p \ ld-read <p <>p (peep elf-machines target 0)) srcs)
       wimps (dyn? ? (macho-weak-undefs objs0) ())
       imps (dyn? ? (ld-imports objs0 + wimps) ()) ni #imps
       plt {'id "<stubs>" 'src "" 'secs {1 ['text 0 (16 * ni) 16 'text]} 'lanes {'text [1]}
            'drops {} 'syms {} 'nsym 0 'relas () 'named () 'base {}}
       objs (dyn? ? (objs0 + [plt]) objs0)
       pg 4096
       base elf-base
       img? (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs)
       dycmds (dyn? ? (catall ([macho-dyld] + map macho-dylib ("/usr/lib/libSystem.B.dylib" . dylibs)
                               + [macho-plat (macho-uuid (join " " (imps + dylibs + [(show (map (ob \ ob 'id) objs0))])))])) ())
       nseg (4 + ?img? + ?dyn?)          ; pagezero text rodata data, the image's or the linkedit
       hdrsz (32 + 72 * nseg + 184 + (dyn? ? (48 + 24 + 80 + #dycmds) 0))
       lay (ldlay objs base hdrsz pg 0)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       dend (ld-align 16 end)
       gend (dend + 8 * ni)               ; the import slots, which dyld fills
       bend (ldlayn 'bss (ldlay1 'bss gend objs) objs)
       ioff (ld-align pg (gend - base))   ; .image past the data, __LINKEDIT past that: dyld
       iaddr (ld-align pg bend)           ; wants it last, so a bake that grows the image moves it on
       iend (img? ? (ldlay1 'image iaddr objs) iaddr)
       ; the bind opcodes: flat lookup, pointers, then a name and its slot apiece
       binds (catall ([[62 81]]                              ; dylib special -2, type pointer
                      + map (k \ (: n ("_" + imps k)
                                     (catall [[(elem (imps k) wimps ? 65 64)] (map n ^#n) [0]   ; 65 a weak import
                                              [115] (macho-uleb (dend - d0 + 8 * k)) [144]]))) ^ni
                      + [[0]]))
       bsz (ld-align 8 #binds)
       lesz (bsz + 8)                     ; ..and an empty string table after
       le (catall [binds (ld-zeros (lesz - #binds))])
       loff (ld-align pg (ioff + (iend - iaddr)))
       laddr (ld-align pg iend)
       glo (ldsyms objs)
       p0 (peep (plt 'base) 1 0)
       _ (each ^ni (k \ pin glo (imps k) [(p0 + 16 * k) 0]))
       _ (pin plt 'src (string (catall (map (k \ ld-plt-x64 (p0 + 16 * k) (dend + 8 * k)) ^ni))))
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
                      (macho-seg "__TEXT" base (o0 - base) 0 (o0 - base) 5)   ; dyld wants code's file and memory alike: the pad is in the file
                      (macho-seg "__RODATA" o0 (up (o1 - o0)) (o0 - base) (o1 - o0) 1)
                      (macho-seg "__DATA" d0 (up (bend - d0)) (d0 - base) (gend - d0) 3)]
                     + (img? ? [(macho-seg "__IMAGE" iaddr (up (iend - iaddr)) ioff (iend - iaddr) 3)])
                     + (dyn? ? [(macho-seg "__LINKEDIT" laddr (up lesz) loff lesz 1)])
                     + (dyn? ? [(catall [(le32 2147483682) (le32 48) (ld-zeros 8)       ; lc_dyld_info_only: no rebase
                                         (le32 loff) (le32 #binds) (ld-zeros 24)])
                                (catall [(le32 2) (le32 24) (le32 loff) (le32 0)       ; lc_symtab: none
                                         (le32 (loff + bsz)) (le32 8)])
                                (catall [(le32 11) (le32 80) (ld-zeros 72)])          ; lc_dysymtab: none
                                dycmds])
                     + [(macho-thread ent)]))
       ncmd (nseg + 1 + (dyn? ? (3 + 2 + #dylibs + 2) 0))
       hdr (catall [(le32 4277009103) (le32 <cpu) (le32 <>cpu) (le32 2)   ; mh_magic_64, mh_execute
                    (le32 ncmd) (le32 #cmds) (le32 (dyn? ? 5 1)) (le32 0) cmds])   ; noundefs, dyldlink
       (hdrsz != #hdr ? (scare 'macho-headers #hdr),
        (hdr . (>en + [(ld-zeros (gend - <en))]
                + (img? ? ([(ld-zeros (ioff - (gend - base)))] + >ei))
                + (dyn? ? [(ld-zeros (loff - (img? ? (ioff + (iend - iaddr)) (gend - base)))) le]))))))
) ; module 'holo
