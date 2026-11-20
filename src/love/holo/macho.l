; src/love/holo/macho.l -- the mach-o container: obj.l relocatables laid as a macos executable
; by ldlink's lay and patch (this file rides after link.l in a cat). xnu maps a segment from a
; page-aligned file offset, so the lanes land page-apart in the file as in memory, and .image
; opens the next page past .bss. a dyld exe imports what no object defines through a stub and
; a slot dyld binds by name, flat; a weak import's slot stays 0 where nothing answers it.
; dyld's exe enters by LC_MAIN once libSystem's initializers have run; -static by LC_UNIXTHREAD.

(module 'holo
(borrow '(hashes bytes))
(: macho-cpus {'x64 [16777223 3]}      ; cpu_type_x86_64, cpu_subtype_x86_64_all

   ; lc_segment_64 and its sections, each (name addr size off align flags): the kernel maps the
   ; segment, and the sections say what it holds to otool and objdump
   (macho-name nm) (catall [(map nm ^#nm) (ld-zeros (16 - #nm))])
   (macho-seg nm addr vsz off fsz prot sects)
    (catall ([(le32 25) (le32 (72 + 80 * #sects)) (macho-name nm)
              (le64 addr) (le64 vsz) (le64 off) (le64 fsz) (le32 prot) (le32 prot) (le32 #sects) (le32 0)]
             + map (x \ catall [(macho-name <x) (macho-name nm) (le64 (x 1)) (le64 (x 2)) (le32 (x 3))
                                (le32 (x 4)) (le32 0) (le32 0) (le32 (x 5)) (ld-zeros 12)])
                   sects))
   ; lc_unixthread, x86_thread_state64: 21 words, rip the 17th, the rest zero
   (macho-thread ent)
    (catall [(le32 5) (le32 184) (le32 4) (le32 42) (ld-zeros 128) (le64 ent) (ld-zeros 32)])
   ; an import's name in libSystem: "libsys.read" asks for read beside an object's own read
   (macho-dyname s) (starts? s "libsys." ? (snip s 7 #s) s)
   ; lc_main, dyld's: the entry's offset in the file, the main thread's stack the default
   (macho-main off) (catall [(le32 2147483688) (le32 24) (le64 off) (le64 0)])

   (macho-uleb n) (: b (n % 128) r (n // 128) (r = 0 ? [b] (b + 128 . macho-uleb r)))
   ; the rebase opcodes over ascending sites: type pointer, then each site a segment and
   ; offset, an add past a gap, or nothing for the next word, and a rebase. segs: (ix lo hi)..
   (macho-rebase segs sites)
    (: (segof a) (: f (filter (sg \ sg 1 <= a && a < sg 2) segs) (atom? f ? (scare 'macho-rebase-site a) <f))
       st (foldl (\ st a (: sg (segof a) nx (st 1)
                             op (? (<st != <sg || a < nx) (32 + <sg . macho-uleb (a - sg 1))
                                   (a = nx) ()
                                   (48 . macho-uleb (a - nx)))
                             [<sg (a + 8) ([81] . op . st 2)]))
                 [-1 0 ()] sites)
       (catall ([[17]] + rev (st 2) + [[0]])))
   ; a path-bearing load command: the head, the path at `at`, NUL-ended and padded to 8
   (macho-pathcmd cmd at hd path)
    (: n (ld-align 8 (at + #path + 1))
       (catall [(le32 cmd) (le32 n) hd (map path ^#path) (ld-zeros (n - at - #path))]))
   (macho-dylib path) (macho-pathcmd 12 24 (catall [(le32 24) (le32 2) (le32 65536) (le32 65536)]) path)
   macho-dyld (macho-pathcmd 14 12 (le32 12) "/usr/lib/dyld")
   ; dyld wants the platform said (lc_build_version: macos, 10.15 and on) and a uuid
   macho-plat (catall [(le32 50) (le32 24) (le32 1) (le32 659200) (le32 720896) (le32 0)])
   ; the uuid: the code's sha-256, so a link and a transpose of it tell the exe alike
   (macho-uuid code) (catall [(le32 27) (le32 24) (snip (hex2b (sha256 code)) 0 16)])
   (macho-str p) (string? p ? p (string (cask p)))
   ; dyld's commands past the segments: its path, the dylibs, the platform and the uuid
   (macho-dycmds imps dylibs code)
    (catall ([macho-dyld] + map macho-dylib ("/usr/lib/libSystem.B.dylib" . dylibs)
             + [macho-plat (macho-uuid code)]))
   (macho-hdrsz dyn? img? imps dylibs)
    (: nseg (4 + ?img? + ?dyn?) nsect (6 + ?img?)
       (32 + 72 * nseg + 80 * nsect + (dyn? ? (24 + 48 + 24 + 80 + 16 + #(macho-dycmds imps dylibs "")) 184)))

   ; the ad-hoc signature, big-endian as the kernel reads it: a superblob of one code
   ; directory (v2.4, linker-signed), a sha-256 a page of the file below it. at the end
   ; of __LINKEDIT, so code limit and offset are one
   (macho-sign pre ident xlim)
    (: n #pre ns ((n + 4095) // 4096) ho (88 + #ident + 1) cdsz (ho + 32 * ns)
       hs (map (k \ hex2b (sha256 (snip pre (4096 * k) (min n (4096 * k + 4096))))) ^ns)
       (join "" ([(wrbe 4208856256 4) (wrbe (20 + cdsz) 4) (wrbe 1 4) (wrbe 0 4) (wrbe 20 4)
                  (wrbe 4208856066 4) (wrbe cdsz 4) (wrbe 132096 4) (wrbe 131074 4)   ; adhoc, linker-signed
                  (wrbe ho 4) (wrbe 88 4) (wrbe 0 4) (wrbe ns 4) (wrbe n 4)
                  (string (cask [32 2 0 12])) (wrbe 0 16) (wrbe 0 8)   ; sha-256, 4k pages
                  (wrbe 0 8) (wrbe xlim 8) (wrbe 1 8) ident (string (cask [0]))]   ; exec segment: __TEXT, main
                 + hs + [(wrbe 0 (padk (20 + cdsz) 16))])))

   ; the weak undefined names no object defines: a dyld exe's weak imports
   (macho-weak-undefs objs)
    (: defs {}
       (syms ob) (map (i \ peep (peep ob 'syms 0) i ()) ^(peep ob 'nsym 0))
       _ (map (ob \ map (sy \ two? sy && 0 < sy 3 && elem (sy 1) '(1 2) ? (pin defs <sy 1)) (syms ob)) objs)
       (foldl (\ a ob (foldl (\ a2 sy (two? sy && sy 1 = 2 && sy 3 = 0 && !(defs <sy) && (nelem <sy a2)
                                         && (nelem <sy ldsynth) && !(ld-bracket? <sy)
                                         ? (a2 + [<sy]) a2))
                             a (syms ob)))
              () objs))

   ; link ((id bytes)..), crt0 first, into a mach-o's piece list. dyn? lays a dyld exe loading
   ; libSystem and dylibs, signed ad hoc as ident; else static. pie (dyn? only): mh_pie, dyld
   ; slides every abs64 site
   (macholink target srcs dyn? dylibs pie ident)
    (: cpu (macho-cpus target)
       _ (two? cpu || scare 'macho-target target)
       objs0 (map (p \ ld-read <p <>p (peep elf-machines target 0)) srcs)
       _ (ld-tls? objs0 ? (scare 'link-tls target))   ; a thread template is ldlink's alone
       wimps (dyn? ? (macho-weak-undefs objs0) ())
       imps (dyn? ? (ld-imports objs0 + wimps) ()) ni #imps
       plt {'id "<stubs>" 'src "" 'secs {1 ['text 0 (16 * ni) 16 'text]} 'lanes {'text [1]}
            'drops {} 'syms {} 'nsym 0 'relas () 'named () 'base {}}
       ; the stubs only when there are imports: an empty one's alignment would lift the text end
       objs (dyn? && 0 < ni ? (objs0 + [plt]) objs0)
       pg 4096
       base elf-base
       img? (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs)
       hdrsz (macho-hdrsz dyn? img? imps dylibs)
       ; laid as ldlink lays the same set, so the code is the same bytes: text at its header
       ; room's place in a page, each cut lifting the address a page, the -pie table past the
       ; nifs, and the image's place in a page its data end's
       ehs (ld-ehsz 0 (5 + ?img?) 1)
       ths (hdrsz + (ehs - hdrsz) % pg @ h (h < hdrsz ? (h + pg) h))
       lay (ldlay objs base ths pg 2)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       nrel (pie ? (ld-nabs objs) 0)
       r0 (pie ? (ld-align 16 end) end) r1 (r0 + 8 * nrel)
       dend (ld-align 16 r1)
       gend (dend + 8 * ni)               ; the import slots, which dyld fills
       bend (ldlayn 'bss (ldlay1 'bss gend objs) objs)
       i0 (ld-align pg bend)              ; .image past the data, __LINKEDIT past that: dyld
       iaddr (img? ? (i0 + (dend - base) % pg) i0)   ; wants it last, so a bake that grows the image moves it on
       iend (img? ? (ldlay1 'image iaddr objs) iaddr)
       glo (ldsyms objs)
       p0 (peep (plt 'base) 1 0)
       _ (each ^ni (k \ pin glo (imps k) [(p0 + 16 * k) 0]))
       ; a "libsys." word an object defines is dyld's to fill, weakly: its code reads it the same
       ; in every container
       lsw (filter (n \ starts? n "libsys.") (sort (keys glo)))
       _ (pin plt 'src (string (catall (map (k \ ld-plt-x64 (p0 + 16 * k) (dend + 8 * k)) ^ni))))
       ent (: e (glo (dyn? ? "__love_main" "_start"))
              o1 <objs
              (two? e ? <e
                 (peep (peep o1 'base 0) <(peep (peep o1 'lanes 0) 'text ()) 0)))
       relbox {0 ()}                      ; abs64 sites
       cx [glo n0 end r0 r1 relbox () () (backends target) (ld-extents objs) ()]
       et (ldemitn cx 'text objs (ldemit cx 'text (base + hdrsz) objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs (>et + [(ld-zeros (o0 - <et))])))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs (>eo + [(ld-zeros (d0 - <eo))])))
       en (ldemit cx 'nifs <ed objs >ed)
       ei (img? ? (ldemit cx 'image iaddr objs ()) [iaddr])
       (macho-pack {'cpu cpu 'dyn? dyn? 'pie pie 'ident ident 'dylibs dylibs 'imps imps 'wimps wimps
                    'lsw (map (n \ [n <(glo n)]) lsw) 'hdrsz hdrsz 't0 (base + ths) 't1 t1
                    'o0 o0 'o1 o1 'd0 d0 'r0 r0 'r1 r1 'dend dend 'gend gend 'bend bend
                    'img? img? 'i0 i0 'iaddr iaddr 'iend iend 'ent ent 'sites (rev (relbox 0))
                    'body >en 'end <en 'image >ei}))

   ; the file from a lay: its addresses, its bytes from past the header to the nifs' end (body)
   ; and from iaddr (image), the pointer sites in their table's order, and lsw's (name addr)
   (macho-pack L)
    (: cpu (L 'cpu) dyn? (L 'dyn?) pie (L 'pie) ident (L 'ident) dylibs (L 'dylibs)
       imps (L 'imps) wimps (L 'wimps) ni #imps lsw (L 'lsw) hdrsz (L 'hdrsz)
       t0 (L 't0) t1 (L 't1) o0 (L 'o0) o1 (L 'o1) d0 (L 'd0) r0 (L 'r0) r1 (L 'r1)
       dend (L 'dend) gend (L 'gend) bend (L 'bend) img? (L 'img?) i0 (L 'i0)
       iaddr (L 'iaddr) iend (L 'iend) ent (L 'ent) sites (L 'sites) body (L 'body) image (L 'image)
       pg 4096
       base elf-base
       nseg (4 + ?img? + ?dyn?)          ; pagezero text rodata data, the image's or the linkedit
       (dn v) (v - (v - base) % pg)       ; a segment starts on its section's page
       rs (dn o0) ds (dn d0)
       ioff (ld-align pg (gend - base))
       ist (ld-align 16 iaddr)
       loff (ld-align pg (ioff + (iend - i0)))
       laddr (ld-align pg iend)
       dycmds (dyn? ? (macho-dycmds imps dylibs (snip (join "" (map macho-str body)) 0 (t1 - base - hdrsz))) ())
       ; the bind opcodes: flat lookup, pointers, then a name and its slot apiece
       (bind nm a w) (: n ("_" + macho-dyname nm)
                        (catall [[(w ? 65 64)] (map n ^#n) [0]          ; 65 a weak import
                                 [115] (macho-uleb (a - ds)) [144]]))
       binds (catall ([[62 81]]                              ; dylib special -2, type pointer
                      + map (k \ bind (imps k) (dend + 8 * k) (elem (imps k) wimps)) ^ni
                      + map (p \ bind <p <>p 1) lsw
                      + [[0]]))
       ro? (pie && any (a \ a < ds) sites)   ; a site in __RODATA: dyld writes it, so rw
       rbs (pie ? (macho-rebase [[2 rs o1] [3 ds gend]] (sort sites)) ())
       ; ldlink's table, dyld's rebases again, so moonlibc leaves it unread here
       rtab ((pie ? (catall (map le64 sites))) + ld-zeros (gend - r1))
       rsz (ld-align 8 #rbs)
       bsz (ld-align 8 #binds)
       lesz (rsz + bsz + 8)               ; rebases, binds, and an empty string table after
       le (catall [rbs (ld-zeros (rsz - #rbs)) binds (ld-zeros (bsz - #binds + 8))])
       soff (ld-align 16 (loff + lesz))   ; the signature, past the rest of __LINKEDIT
       ssz (ld-align 16 (20 + 88 + #ident + 1 + 32 * ((soff + pg - 1) // pg)))
       lfsz (soff - loff + ssz)
       (up v) (ld-align pg v)
       ; section flags: pure and some instructions for code, zerofill for bss
       cmds (catall ([(macho-seg "__PAGEZERO" 0 base 0 0 0 ())
                      (macho-seg "__TEXT" base (rs - base) 0 (rs - base) 5   ; dyld wants code's file and memory alike: the pad is in the file
                                 [["__text" t0 (t1 - t0) (t0 - base) 4 2147484672]])
                      ; a lifted segment opens on __pad, its page's zeros below the section, so a
                      ; reader that counts a segment from its first section counts as dyld does
                      (macho-seg "__RODATA" rs (up (o1 - rs)) (rs - base) (o1 - rs) (ro? ? 3 1)
                                 [["__pad" rs (o0 - rs) (rs - base) 0 0] ["__const" o0 (o1 - o0) (o0 - base) 4 0]])
                      (macho-seg "__DATA" ds (up (bend - ds)) (ds - base) (gend - ds) 3
                                 [["__pad" ds (d0 - ds) (ds - base) 0 0] ["__data" d0 (gend - d0) (d0 - base) 4 0]
                                  ["__bss" gend (bend - gend) 0 4 1]])]
                     + (img? ? [(macho-seg "__IMAGE" i0 (up (iend - i0)) ioff (iend - i0) 3
                                           [["__image" ist (iend - ist) (ioff + (ist - i0)) 4 0]])])
                     + (dyn? ? [(macho-seg "__LINKEDIT" laddr (up lfsz) loff lfsz 1 ())])
                     + (dyn? ? [(catall [(le32 2147483682) (le32 48) (le32 (#rbs && loff)) (le32 #rbs)   ; lc_dyld_info_only
                                         (le32 (loff + rsz)) (le32 #binds) (ld-zeros 24)])
                                (catall [(le32 2) (le32 24) (le32 loff) (le32 0)       ; lc_symtab: none
                                         (le32 (loff + rsz + bsz)) (le32 8)])
                                (catall [(le32 11) (le32 80) (ld-zeros 72)])          ; lc_dysymtab: none
                                (catall [(le32 29) (le32 16) (le32 soff) (le32 ssz)])  ; lc_code_signature
                                dycmds])
                     + [(dyn? ? (macho-main (ent - base)) (macho-thread ent))]))
       ncmd (nseg + 1 + (dyn? ? (4 + 2 + #dylibs + 2) 0))
       hdr (catall [(le32 4277009103) (le32 <cpu) (le32 <>cpu) (le32 2)   ; mh_magic_64, mh_execute
                    (le32 ncmd) (le32 #cmds) (le32 (dyn? ? (pie ? 2097157 5) 1)) (le32 0) cmds])   ; noundefs, dyldlink, pie
       ps (hdr . (body + [(ld-zeros (r0 - L 'end)) rtab]
                  + (img? ? ([(ld-zeros (ioff + (iaddr - i0) - (gend - base)))] + image))
                  + (dyn? ? [(ld-zeros (loff - (img? ? (ioff + (iend - i0)) (gend - base)))) le
                             (ld-zeros (soff - loff - lesz))])))
       pre (dyn? ? (join "" (map macho-str ps)) "")
       _ (hdrsz != #hdr && scare 'macho-headers #hdr)
       _ (dyn? && #pre != soff && scare 'macho-signature #pre)
       (dyn? ? [pre (macho-sign pre ident (rs - base))] ps))

   ; a linked x86-64 ELF of this lay as dyld's mach-o, no objects: every address moves by one
   ; shift, the text's to its place past the mach-o's header, and so does each pointer the
   ; ELF's .love.rela names; dyld binds the libsys words its symbols name
   (macho-of-elf s ident)
    (: _ (s 4 = 2 && rle16 s 18 = 62 || scare 'macho-of-elf-target)
       fs elf64f
       shoff (ld-f fs s 0 'e-shoff) shnum (ld-f fs s 0 'e-shnum)
       (hd i) (shoff + 64 * i)
       stro (ld-f fs s (hd (ld-f fs s 0 'e-shstrx)) 'sh-off)
       tab {}
       ; each section by name: (addr off size)
       _ (each ^shnum (i \ pin tab (ld-cstr s (stro + ld-f fs s (hd i) 'sh-name))
                                [(rle64 s (hd i + 16)) (ld-f fs s (hd i) 'sh-off) (ld-f fs s (hd i) 'sh-size)]))
       (sec n) (tab n @ r (two? r ? r (scare 'macho-of-elf-section n)))
       tx (sec ".text") ro (sec ".rodata") da (sec ".data") nf (sec ".love.nifs")
       rl (sec ".love.rela") bs (sec ".bss") im (tab ".love.image") sy (sec ".symtab") sn (sec ".strtab")
       ; (name value shndx)
       syms (map (k \ (: o (sy 1 + 24 * k) [(ld-cstr s (sn 1 + rle32 s o)) (rle64 s (o + 8)) (rle16 s (o + 6))]))
                 ^(sy 2 // 24))
       _ (any (y \ y 2 = 0 && 0 < #(<y)) syms ? (scare 'macho-of-elf-imports ident))   ; a stub it never laid
       pg 4096
       base elf-base
       img? (two? im && 0 < im 2)          ; an image with bytes, as macholink counts one
       hdrsz (macho-hdrsz 1 img? () ())
       ths (hdrsz + (<tx - hdrsz) % pg @ h (h < hdrsz ? (h + pg) h))
       S (base + ths - <tx)
       (at a) (a + S)
       sites0 (map (k \ rle64 s (rl 1 + 8 * k)) ^(rl 2 // 8))
       ; n bytes at the ELF's address a0, file offset off, each pointer at a site moved
       (span a0 off n)
        (: in (sort (filter (x \ a0 <= x && x < a0 + n) sites0))
           (:- (go in off ())
              (go l o acc) (atom? l ? (rev (snip s o (off + n) . acc))
                              (: k (off + <l - a0)
                                 (go >l (k + 8) (le64 (rle64 s k + S) . snip s o k . acc))))))
       t0 (at <tx) t1 (t0 + tx 2) o0 (at <ro) o1 (o0 + ro 2) d0 (at <da)
       end (at (<nf + nf 2)) r0 (at <rl) r1 (r0 + rl 2)
       dend (ld-align 16 r1) bend (at (<bs + bs 2))
       i0 (ld-align pg bend)
       iaddr (img? ? (at <im) i0) iend (img? ? (iaddr + im 2) iaddr)
       ; the lay ldlink and macholink share, or this is some other ELF
       _ (r0 = ld-align 16 end && (!img? || iaddr = i0 + (dend - base) % pg) || scare 'macho-of-elf-lay ident)
       lt (foldl (\ t y (starts? <y "libsys." && y 2 != 0 ? (pin t <y (at (y 1))) t)) {} syms)
       lsw (map (n \ [n (lt n)]) (sort (keys lt)))
       ent (filter (y \ <y = "__love_main") syms @ e (two? e ? (at (<e 1)) (scare 'macho-of-elf-entry ident)))
       body ([(ld-zeros (t0 - base - hdrsz)) (snip s (tx 1) (tx 1 + tx 2)) (ld-zeros (o0 - t1))]
             + span <ro (ro 1) (ro 2) + [(ld-zeros (d0 - o1))] + span <da (da 1) (end - d0))
       (macho-pack {'cpu (macho-cpus 'x64) 'dyn? 1 'pie 1 'ident ident 'dylibs () 'imps () 'wimps ()
                    'lsw lsw 'hdrsz hdrsz 't0 t0 't1 t1 'o0 o0 'o1 o1 'd0 d0 'r0 r0 'r1 r1
                    'dend dend 'gend dend 'bend bend 'img? img? 'i0 i0 'iaddr iaddr 'iend iend 'ent ent
                    'sites (map at sites0) 'body body 'end end
                    'image (img? ? [(snip s (im 1) (im 1 + im 2))] ())})))
) ; module 'holo
