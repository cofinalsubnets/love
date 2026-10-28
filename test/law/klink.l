; test/law/klink.l -- holo's kernel link: lld's piece hash, xxh3_64 with seed 0; a -shared
; link's dynamic tables, their hashes against the a64 vdso lld laid; objcopy -S's names

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

(test_fin (), say err "test/law/klink: ok", put err 10, 0)
