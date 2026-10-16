; src/love/holo/pe.l -- the pe32+ container: lay obj.l relocatables into a uefi
; application (subsystem 10). same lay/patch heart as link.l's ldlink, which
; binds ld-read/ldlay/ldpatch/ldsyms (this file rides after it in a cat).
; sections: .text (text + rodata, r-x), .data (data + nifs, bss the zero tail
; past SizeOfRawData, rw-), and .reloc: the abs64 sites ldpatch collects,
; re-encoded as base relocations, so firmware slides the image itself.
; entry is the first object's text (the mkefi.l thunk). only the coff machine
; is arch-bound.
;
; text and data must be separate sections: firmware makes every executable
; section read-only (a64 firmware does), so an rwx one faults on a static write.
;
; pe headers live below the first section, so ldlay gets a header reserve of
; zero and the first text byte lands at ImageBase + 0x1000.

(module 'holo
(: pe-ibase 65536                        ; the preferred base; .reloc frees the loader from it
   pe-hraw 512                           ; file bytes reserved for every header
   pe-falign 512

   (pe-secname s) (map s ^#s + map (_ \ 0) ^(8 - #s))
   (pe-sect nm vsz rva raw off ch)
    (catall [(pe-secname nm) (le32 vsz) (le32 rva) (le32 raw) (le32 off)
             (le32 0) (le32 0) (le16 0) (le16 0) (le32 ch)])

   ;; ascending site addresses -> per-page blocks (page-rva u32, block-size u32,
   ;; u16 entries, type in the high nibble, 10 = DIR64), padded to 4 by a type-0
   ;; entry. no sites still lays one empty block: a .reloc marks the image relocatable.
   (pe-relocs sites)
    (!(two? sites) ? (catall [(le32 4096) (le32 12) (le16 0) (le16 0)])
       (: (blocks ss acc)
           (!(two? ss) ? (rev acc)
              (: pg (<ss - pe-ibase & -4096)
                 (grab l es) (two? l && <l - pe-ibase <  pg + 4096 ?
                               (grab >l ((40960 | <l - pe-ibase & 4095) . es))
                               [l (rev es)])
                 g (grab ss ())
                 es <>g
                 es (#es & 1 ? (es + '(0)) es)
                 (blocks <g (catall [(le32 pg) (le32 (8 + 2 * #es)) (catall (map le16 es))] . acc))))
          (catall (blocks sites ()))))

   ;; the coff machine, elf.l's elf-machines in the other clothing
   pe-machines {'x64 34404                          ; 0x8664
                'a64 43620}                       ; 0xaa64

   ;; link a set -- ((id bytes)..), the mkefi thunk first -- into a pe32+ at out.
   (pelink target srcs out)
    (: mach (peep pe-machines target 0)
       emach (peep elf-machines target 0)
       _ (0 < mach ? 0 (scare 'pe-target target))
       objs (map (p \ ld-read <p <>p emach) srcs)
       base (pe-ibase + 4096)
       lay (ldlay objs base 0 4096 0)     ; the lanes land page-apart: rodata at o0, data at d0
       end (lay 0) n0 (lay 1) o0 (lay 2) d0 (lay 3)
       bend (ldlay1 'bss end objs)
       relbox {0 ()}
       glo (ldsyms objs)
       o1 <objs
       ent (peep (peep o1 'base 0) <(peep (peep o1 'lanes 0) 'text ()) 0)
       ;; ldpatch destructures ten wide; no -pie table (r0 = r1 = end), no riscv, no arm32.
       cx [glo n0 end end end relbox () () (backends target) (ld-extents objs)]
       ;; the read-only half; the alignment gap before rodata is written as zeros.
       et (ldemitn cx 'text objs (ldemit cx 'text base objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs (>et + [(ld-zeros (o0 - <et))])))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs ()))
       en (ldemit cx 'nifs n0 objs (>ed + [(ld-zeros (n0 - <ed))]))
       tfsz (<eo - base)                  ; .text: text + rodata
       traw (aup tfsz pe-falign)
       dfsz (<en - d0)                    ; .data: data + nifs, and bss past it
       draw (aup dfsz pe-falign)
       text-vsz (d0 - base)
       data-rva (d0 - pe-ibase)
       data-vsz (bend - d0)
       reloc-rva (aup (data-rva + data-vsz) 4096)
       reloc (pe-relocs (rev (peep relbox 0 ())))
       rsz #reloc
       rraw (aup rsz pe-falign)
       img-sz (reloc-rva + aup rsz 4096)
       opt (catall [
         (le16 523) '(0 0)                               ; pe32+ magic, linker 0.0
         (le32 traw) (le32 draw) (le32 0)
         (le32 (ent - pe-ibase)) (le32 4096)             ; entry rva, base of code
         (le64 pe-ibase)
         (le32 4096) (le32 pe-falign)                    ; section / file alignment
         (le16 0) (le16 0) (le16 0) (le16 0) (le16 0) (le16 0) (le32 0)
         (le32 img-sz) (le32 pe-hraw)
         (le32 0) (le16 10) (le16 0)                     ; subsystem efi_application
         (le64 1048576) (le64 4096) (le64 1048576) (le64 4096)
         (le32 0) (le32 16)
         (le64 0) (le64 0) (le64 0) (le64 0) (le64 0)
         (le32 reloc-rva) (le32 rsz)                     ; dir 5: base relocations
         (le64 0) (le64 0) (le64 0) (le64 0) (le64 0)
         (le64 0) (le64 0) (le64 0) (le64 0) (le64 0)])
       hdr (catall [
         '(77 90) (map (_ \ 0) ^58) (le32 64)       ; mz, e_lfanew = 64
         '(80 69 0 0)
         (le16 mach) (le16 3)                            ; the coff machine, three sections
         (le32 0) (le32 0) (le32 0)
         (le16 #opt) (le16 34)                    ; exe | large_address_aware
         opt
         (pe-sect ".text" tfsz 4096 traw pe-hraw 1610612768)           ; 0x60000020 code|r-x
         (pe-sect ".data" data-vsz data-rva draw (pe-hraw + traw) 3221225536)    ; 0xc0000040 data|rw-
         (pe-sect ".reloc" rsz reloc-rva rraw (pe-hraw + traw + draw) 1107296320)])   ; 0x42000040
       (pe-hraw < #hdr ? (scare 'pe-headers-overflow #hdr),
        ld-write out
          ([hdr (ld-zeros (pe-hraw - #hdr))]
           + >eo + [(ld-zeros (traw - tfsz))]
           + >en + [(ld-zeros (draw - dfsz)) reloc (ld-zeros (rraw - rsz))]))))
) ; module 'holo
