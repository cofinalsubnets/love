; test/law/klink.l -- holo's kernel link: lld's piece hash, xxh3_64 with seed 0; a -shared
; link's dynamic tables, their hashes against the a64 vdso lld laid; objcopy -S's names; the
; RELR probe kbuild links with no script

(borrow 'holo)
(: (klx n) (kl-xxh (string (map (i \ (i * 7 + n) % 256) ^n)))
   (test
      ; --- every length class: empty, 1-3, 4-8, 9-16, 17-128, 129-240, then the stripes
      (klx 0 = 3244421341483603138) (klx 1 = 16226181191752404715)
      (klx 3 = 12180141160879835164) (klx 4 = 6297312323375345790)
      (klx 8 = 12752855198315354378) (klx 9 = 10000907846553926702)
      (klx 16 = 3159599325006435930) (klx 17 = 7070371635116224842)
      (klx 64 = 1953419934939160347) (klx 128 = 16813233705924465638)
      (klx 129 = 13063484349860316345) (klx 240 = 4473034316189165092)
      (klx 241 = 13654115510048419178) (klx 1024 = 15878231082470753371)
      (klx 1025 = 14435947017053915143) (klx 2100 = 1178074104578928781)))

; --- the vdso's .gnu.version_d hashes, and its .gnu.hash chain, the low bit a bucket's end
(test
   (kl-ehash "linux-vdso.so.1" = 233750433) (kl-ehash "LINUX_2.6.39" = 123718537) (kl-ehash "" = 0)
   (kl-ghash "__kernel_clock_gettime" = 3752411645)
   (map (n \ kl-ghash n // 2 * 2) ["__kernel_gettimeofday" "__kernel_clock_getres" "__kernel_rt_sigreturn" "__kernel_getrandom"]
    = [539402308 3627771288 2440597482 1410158116])
   (kl-words " V { global: a ; b ; }" = ["V" "{" "global:" "a" ";" "b" ";" "}"]))

; --- a plan: the list exported in .gnu.hash's order, .dynstr the names, soname, version
(: d (kl-dso {'glob {"a" [0 1] "b" [0 2]} 'order ["a" "x" "b"]} {'soname "s.so" 'symbolic 1 'bti 1}
             " V1 { global: a ; b ; c ; local: * ; } ;")
   sz (: t {} _ (each (d 'synth) (s \ pin t <s (s 1))) t)
   (test
      (d 'syms = ["a" "b"]) (d 'str "s.so" = 5) (d 'str "V1" = 10) (d 'str 'n = 13)
      (sz ".hash" = 32) (sz ".gnu.hash" = 36) (sz ".dynsym" = 72) (sz ".gnu.version" = 6) (sz ".dynamic" = 208)))

; --- llvm-objcopy's .shstrtab: high by reversed spelling, a name ending the one before sharing it
(: st (oc-strtab [".hash" ".gnu.hash" ".dynsym" ".dynstr" ".gnu.version" ".gnu.version_d" ".note" ".text"
                  ".altinstructions" ".dynamic" ".rodata" ".shstrtab"])
   (test
      (<st = "\0.text\0.altinstructions\0.dynstr\0.gnu.version\0.dynsym\0.gnu.hash\0.note\0.gnu.version_d\0.dynamic\0.shstrtab\0.rodata\0")
      (<>st ".hash" = 57) (<>st ".gnu.hash" = 53) (<>st ".rodata" = 103)))

; --- kbuild's $(LD) lines: the vdso's, vmlinux's inputs in order, and what a probe is refused
(: v (kl-args ["-EL" "-maarch64elf" "-z" "norelro" "-z" "noexecstack" "-shared" "-soname=linux-vdso.so.1" "-Bsymbolic"
               "--build-id=sha1" "-n" "-z" "force-bti" "--orphan-handling=warn" "-T" "vdso.lds" "a.o" "b.o" "-o" "vdso.so.dbg"])
   k (kl-args ["-X" "--pack-dyn-relocs=relr" "--script=./vmlinux.lds" "--strip-debug" "-o" "v1" "--whole-archive" "vmlinux.a"
               "x.o" "--no-whole-archive" "--start-group" "lib.a" "--end-group" "ks.o"])
   r (kl-args ["-EL" "-maarch64elf" "-z" "norelro" "-r" "-o" "vmlinux.o"])
   (test
      (v 'script = "vdso.lds") (v 'out = "vdso.so.dbg") (v 'soname = "linux-vdso.so.1") (v 'emu = 'a64)
      (v 'shared = 1) (v 'symbolic = 1) (v 'nmagic = 1) (v 'bti = 1) (v 'bid = 1) (v 'relro = 0) (v 'orphan = "warn")
      (v 'ins = [['in "a.o" 0] ['in "b.o" 0]])
      (k 'script = "./vmlinux.lds") (k 'discard = 'locals) (k 'relr = 1) (k 'strip = 1)
      (k 'ins = [['in "vmlinux.a" 1] ['in "x.o" 1] ['in "lib.a" 0] ['in "ks.o" 0]])
      (r 'reloc = 1) (r 'ins = ())
      (kl-args ["--no-warn-rwx-segments" "-v"] = "ld: unsupported option --no-warn-rwx-segments")
      (kl-args ["-z" "max-page-size=4096"] = "ld: unsupported: -z max-page-size=4096")
      (kl-args ["-o"] = "ld: -o wants a value")
      (kl-args ["-maarch64elfb"] = "ld: unsupported option -maarch64elfb")
      ((kl-args ["-v"]) 'ver = 1)
      (kl-num "0x10000" = 65536) (kl-num "4096" = 4096) (kl-num "4k" = ())))

; --- the a53 erratum: adrp at a page's 0xff8, a load not writing x0, a load through x0 is refused;
; off that word it scans clean, and a section its object names no section symbol for is answered
(: code (string (cats (map (w \ kl-le w 4) [2415919104 4181721153 4181721091])))
   (ob ss) {'id "e.o" 'src code 'nsym (? ss 3 2) 'syms {0 ["" 0 0 0 0 0 0] 1 ["$x" 0 0 1 0 0 0] 2 ["" 0 3 1 0 0 0]}
            'sec {0 ["" 0 0 0 0 0 0 0 0] 1 [".text" 1 6 0 12 4 0 0 0]}}
   (lk a ss) {'ot {0 (ob ss)} 'env {'isa {1 a}} 'outs [{'name ".text" 'flags 6 'steps [['isec 0 1 12 4 ".text"]]}]}
   (test
      (trap (_ \ kl-a53 (lk 4088 0)) () (a \ b \ a) = 'klink-843419)
      (kl-a53 (lk 4096 0) = [[0 1]]) (kl-a53 (lk 4096 1) = ())))

; --- -shared with no script lays lld's own layout: kbuild's RELR probe, `void *p = &p;` as
; clang -c lays it for aarch64 and mooncc -c for x86-64, linked to the bytes ld.lld 22.1.8 writes
(: (klp-dig c) (? (c < 58) (c - 48) (c - 87))
   (klp-bytes t) (: h (filter (c \ c > 32) (map (i \ t i) ^#t))
                    (string (map (i \ klp-dig (h (2 * i)) * 16 + klp-dig (h (2 * i + 1))) ^(#h // 2))))
   (klp-link nm hx)
    (: src ("out/.klp-" + nm + ".o") dst ("out/.klp-" + nm)
       q (open src "w") _ (say q (klp-bytes hx), close q)
       o (kl-args [src "-shared" "-Bsymbolic" "--pack-dyn-relocs=relr" "-o" dst])
       _ (pin o 'banner "Linker: LLD 22.1.8")
       _ (kl-ld o)
       h (sha256 <>(uread dst))
       (unlink src, unlink dst, h))
   (test
      (klp-link "a64" """
        7f454c460201010000000000000000000100b70001000000000000000000000000000000000000004801000000000000
        00000000400000000000400009000100000000000000000000636c616e672076657273696f6e2032322e312e38000000
        0000000000000000000000000000000000000000000000004e0000000400f1ff00000000000000000000000000000000
        300000000000030000000000000000000000000000000000300000000000050000000000000000000000000000000000
        100000001100030000000000000000000800000000000000000000000000000001010000040000000000000000000000
        04002e74657874002e636f6d6d656e740070002e6e6f74652e474e552d737461636b002e6c6c766d5f61646472736967
        002464002e737472746162002e73796d746162002e72656c612e64617461002d00000000000000000000000000000000
        000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        0000000000000000330000000300000000000000000000000000000000000000f1000000000000005000000000000000
        000000000000000001000000000000000000000000000000010000000100000006000000000000000000000000000000
        400000000000000000000000000000000000000000000000040000000000000000000000000000004800000001000000
        030000000000000000000000000000004000000000000000080000000000000000000000000000000800000000000000
        0000000000000000430000000400000040000000000000000000000000000000d8000000000000001800000000000000
        080000000300000008000000000000001800000000000000070000000100000030000000000000000000000000000000
        480000000000000016000000000000000000000000000000010000000000000001000000000000001200000001000000
        000000000000000000000000000000005e00000000000000000000000000000000000000000000000100000000000000
        000000000000000022000000034cff6f00000080000000000000000000000000f0000000000000000100000000000000
        0800000000000000010000000000000000000000000000003b0000000200000000000000000000000000000000000000
        60000000000000007800000000000000010000000400000008000000000000001800000000000000
        """
        = "fa967b085a08d2dac6d8aa5780428c8fb9806f490e90a22d79a626d605bc32fe")
      (klp-link "x64" """
        7f454c4602010100000000000000000001003e0001000000000000000000000000000000000000003201000000000000
        000000004000000000004000090008000000000000000000000000000000000000000000000000000000000000000000
        000000000300010000000000000000000000000000000000000000000300020000000000000000000000000000000000
        000000000300030000000000000000000000000000000000000000000300040000000000000000000000000000000000
        010000001100030000000000000000000800000000000000007000000000000000000001000000050000000000000000
        000000002e74657874002e726f64617461002e64617461002e627373002e73796d746162002e737472746162002e7265
        6c612e64617461002e736873747274616200000000000000000000000000000000000000000000000000000000000000
        000000000000000000000000000000000000000000000000000000000000000000000100000001000000060000000000
        000000000000000000004000000000000000000000000000000000000000000000001000000000000000000000000000
        000007000000010000000200000000000000000000000000000040000000000000000000000000000000000000000000
        0000080000000000000000000000000000000f0000000100000003000000000000000000000000000000400000000000
        000008000000000000000000000000000000080000000000000000000000000000001500000008000000030000000000
        000000000000000000004800000000000000000000000000000000000000000000000800000000000000000000000000
        00001a000000020000000000000000000000000000000000000048000000000000009000000000000000060000000500
        000008000000000000001800000000000000220000000300000000000000000000000000000000000000d80000000000
        000003000000000000000000000000000000010000000000000000000000000000002a00000004000000000000000000
        00000000000000000000db00000000000000180000000000000005000000030000000800000000000000180000000000
        0000350000000300000000000000000000000000000000000000f3000000000000003f00000000000000000000000000
        000001000000000000000000000000000000
        """
        = "13a750f7dcef72e18558d84a2dc81f284649f6165d79287fc9e60a229ef3e5a8")))

; --- ldemit's context is 11 slots, and one short of it is refused, not laid as no bytes
(test
   (trap (_ \ ldemit ^10 'text 0 () ()) () (a \ b \ a) = 'link-cx)
   (ldemit ^11 'text 7 () () = [7]))

(test_fin (), say err "test/law/klink: ok", put err 10, 0)
