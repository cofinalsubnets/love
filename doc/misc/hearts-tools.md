# hearts-tools — the outside tools a hearts linux still runs

Release criterion for love 0.4 (queue pre line 5): hearts builds linux 6.19.14 x64 and a64 defconfig
with no outside tool, and both boot. This is the checklist: every outside tool still run, with a
count and where the count came from. A row leaves when its tool does. **holder** names the session
that holds an item: take an open one by writing your name here, so two sessions never take the same one.

Counts are from 2026-10-26 unless a row says otherwise. Sources:

- the clang+kbuild references' `.cmd` files (`savedcmd_` lines): a64 `/var/tmp/census-g21/ref-defconfig`
  (5482 lines), x64 `/var/tmp/census-g21/ref-x64-defconfig` (3887). filechk and `$(call cmd,..)`
  steps leave no `.cmd`; those are counted from hearts' command log (`/var/tmp/hearts/h2/.hearts/commands`,
  a64) or the Makefiles, and link-vmlinux.sh's steps from the script
- mooncc's censuses (census.py, g-21): a64 r24 (gwen 31372f7af) `/var/tmp/census-g21/r24/mix/units.tsv`,
  x64 r21 (gwen caf692cc6) `/var/tmp/census-g21/r21/x64/units.tsv`
- the boots: a64 `/var/tmp/census-g21-mix` (mix.sh), x64 `/var/tmp/census-g21/x64mix` (boot.sh)

Two pipelines exist today, and the criterion is their join:

- `make test_hearts` (src/apps/hearts/build.l): the love-native driver. No GNU make; host programs by
  mooncc, love's lex/yacc, perl's scripts ported, commands through `lush -a`. But clang compiles the
  kernel side, llvm links it, and ARCH is fixed to arm64 (build.l `cl0`)
- the mixed boot (mix.sh, boot.sh): mooncc and holo objects for the kernel, laid over a GNU make +
  clang + ld.lld + `HOSTCC=cc` build, then booted under qemu

## holders

| item | a64 | x64 |
|---|---|---|
| kernel C/asm: mooncc + holo for every unit | g-e9 | g-21 (refused/differ classes, by units) |
| boot of a mooncc kernel | g-e9 (boots: r23) | g-21 (first mixed boot, q35 + OVMF + kvm) |
| the link and binutils: holo for ld.lld, nm, objcopy, strip, objdump, readelf | g-ae (a64 first) | g-ae |
| build driver: kbuild.l end to end, no GNU make | g-05-5f | g-05-5f |
| host programs and their parsers/scripts, the conf `/bin/sh` leak | g-05-5f | g-05-5f |
| archives: kore ar for kbuild (llvm-ar) | g-05-5f | g-05-5f |
| x64 image: setup/realmode `-m16` units (mooncc -t i386), piggy gzip, dd/cat, bzImage as its own PE | — | g-21 (after the boot) |
| x64 relocs, mkpiggy (host programs) | — | g-05-5f |
| x64 boot links: setup.elf, realmode.elf, compressed/vmlinux | — | g-ae |
| objtool's job in mooncc/holo (ORC, retpoline/rethunk/static-call/IBT sites) | — | open |

## 1. kernel C units still compiled by clang

### a64 (r24: 4439 units, 4370 `.c` + 69 `.S`)

3106 `.c` same as clang, 1258 differ, 6 not finished. Every `.S` is holo's.

| class | units | note |
|---|---|---|
| vdso32, `--target=arm-linux-gnueabi` | 2 | the compat vdso: mooncc's arm32 is not wired in |
| timeout (300 s) | 4 | pinctrl-rzg2l; .vmlinux.export, kvm inject_fault, hid-input finish in 320-450 s on a loaded box |

The boots below ran on r23's pool: 4285 mooncc objects, 0 culprits; the share of vmlinux.a members
from mooncc was 4242/4386 = 96.7%; modpost warns 6 (all `__calc_tpm2_event_size`).

### x64 (r21: 3004 units, 2934 `.c` + 70 `.S`; before efwd)

872 `.c` same, 1748 differ, 314 not mooncc's (refused 309, flag 5, plus crash 1, timeout 1):

| class | units | note |
|---|---|---|
| enum named before its definition | 224 | fixed (row 543); recheck took all 224 |
| `__attribute__((ms_abi))` | 47 | carried out; a recheck takes 43, the 4 left stop on asm (endbr64, vmcall, a width clash) and an initializer |
| asm immediate input not constant (`nf_hook`) | 16 | |
| inline asm holo lacks | 10 | vmcall, rdpid, a register name, others |
| parse errors | 4 | selinux hooks, nf_nat ×2, net/ax25.h |
| undeclared names | 4 | |
| initializers | 3 | |
| duplicate case value | 1 | |
| flag (`-o` with two inputs, `-fpic` on i386) | 5 | |

A KEEP=1 census on gwen 1065c73ee (g-21) gives the post-efwd numbers.

## 2. kernel `.S` units holo refuses

holo assembles every `.S` the census compiles; only the refused ones stay clang's.

- a64: 0 of 69. entry.o, head.o and hyp-entry.o match clang's code sections but for branches to
  global symbols, which holo resolves inside the object
- x64: of the 64 units with asm, 49 lay (27 as clang does) and 15 refuse: the 16- and 32-bit
  lanes' far transfers and `lidt` 4, operands gas spaces or nests 4, a pushed immediate segment 2,
  `.irpc`, `.uleb128` over labels, x87, others
- the 3 kallsyms `.S` files from link-vmlinux.sh are clang's in both (the link, below)

## 3. clang outside the units

a64 (ref `.cmd`): 5 `-S` offset files (bounds, rq-offsets, devicetable-offsets, asm-offsets,
hyp-constants), 4 `-E` linker scripts (vmlinux.lds, vdso.lds, vdso32, hyp.lds), the 3 kallsyms `.S`,
1 `.dtb.S`. Make-side probes: 47 `cc-option`, 5 `ld-option`, 3 `cc-option-yn`, 2 `cc-disable-warning`,
1 `as-instr`, 1 `as-option`. Kconfig probes run through conf, by moonlibc's popen.
x64 adds the 37 `-m16` units of setup.bin and realmode (in the 3004).

## 4. the link (ld.lld) — g-ae

| step | a64 | x64 |
|---|---|---|
| vmlinux.o, `ld.lld -r` of vmlinux.a + libstub lib.a | 1 | 1 |
| .tmp_vmlinux1, .tmp_vmlinux2, vmlinux.unstripped (link-vmlinux.sh) | 3 | 3 |
| vdso `-shared` (vdso.so.dbg; x64 vdso64 + vdso32) | 1 + vdso32 raw | 2 |
| kvm nvhe `-r -T hyp.lds`, then `-r` | 2 | — |
| boot: compressed/vmlinux `-pie`, setup.elf, realmode.elf | — | 3 |

No love linker links a kernel yet: holo's `link.l` is a static ELF linker (`ldkern` for inle,
`ldshared`); kore's `ld` takes no `-T`, `-r` or archives.

## 5. binutils — g-ae; archives g-05-5f

| tool | a64 | x64 | love today |
|---|---|---|---|
| llvm-ar | 899 (`cDPrST` built-in.a / vmlinux.a, `t`, `mPiT`) | 767 | kore `ar` does `rcs`/`t` only |
| llvm-objcopy | 46: libstub 33, pi 7, vdso 2, kvm, modinfo, vmlinux ×2, Image | 29: libstub 19, `-O binary` ×3, `-S`, `--prefix-symbols` ×2, vmlinux | holo `copy.l` does `-O binary`/ihex only |
| llvm-strip | 33 (libstub `--strip-debug`) | 19 | kore `strip`, unused |
| llvm-objdump | 33 (libstub `-r` checks) | 19 | none |
| llvm-readelf | 2 (vdso dynamic-reloc check) | 2 | kore `readelf`, unused |
| llvm-nm | 1 + 4 in link-vmlinux + 1 check-function-names | 3 (voffset, zoffset, pasyms) + 4 | kore `nm`, unused |

`LLVM=1` names `llvm-*` directly, so kore's verbs never shadow them. The pinned llvm-22.1.8 is built
ARM-only; the x64 side needs no X86 one once it is off clang.

## 6. build driver — g-05-5f

- a64, test_hearts: no GNU make. build.l evaluates kbuild's make text (kbuild.l); a recipe's `$(MAKE)`
  (link-vmlinux.sh's sub-make) goes to `hk-make` = `build.l --sub`. Goals `defconfig syncconfig Image`;
  modules not built
- x64: build.l fixes ARCH=arm64; image.l and test/gate/hearts*.sh are a64 throughout
- the mixed boots still link through GNU make (kmake.sh, boot.sh)
- objtool builds through tools/build, a second make system kbuild.l does not take

## 7. host programs — g-05-5f

a64, all by mooncc through `hk-hostcc` (55 commands = the reference's 55):

| program | units | runs | note |
|---|---|---|---|
| fixdep | 1 | 0 | hearts records no deps |
| conf | 8 + lexer/parser | 2 | Kconfig `$(shell)` probes exec `/bin/sh` (moonlibc num.c popen): host bash, not lush |
| dtc (+ fdtoverlay) | 9 + libfdt | 1 | `drivers/of/empty_root.dtb` only; qemu virt brings its own dtb |
| kallsyms | 1 | 3 | |
| sorttable | 2, `-lpthread` | 1 | |
| modpost + mk_elfconfig | 4 + 1 | 1 + 1 | |
| asn1_compiler | 1 | 5 | |
| gen_init_cpio, vdsomunge, gen_crc32table, gen_crc64table, pnmtologo, conmakehash, gen-hyprel | 1 each | 1 each | |
| relacheck | 1 | 7 | |
| extract-cert | `-lcrypto` | 2 | xcert.l stands in |

x64 adds, none built by mooncc yet:

| program | units | note |
|---|---|---|
| arch/x86/tools/relocs | 3 | vmlinux.relocs, realmode relocs |
| boot/compressed/mkpiggy, boot/mkcpustr, entry/vdso/vdso2c | 1 each | |
| selinux genheaders, scripts/selinux/mdp | 1 each | SELINUX=y |
| objtool (+ libsubcmd) | 28 | libelf, libz, libzstd, libxxhash; mooncc has no libelf. Its job belongs in mooncc/holo (ORC, retpoline/rethunk/static-call/IBT site lists), not a port |

## 8. scripts and interpreters

All commands run under `lush -a`, so kore's verbs answer sh, sed, awk, grep, xargs, sha1sum, bc, tr,
uniq, cut, sort, cmp, cat, gzip, cpio; `#!/bin/sh` scripts run as lush's sh.

| tool | a64 | x64 | love |
|---|---|---|---|
| perl | 3: sha2-armv8.pl ×2, build_OID_registry | 1: build_OID_registry | perlasm.l, oidreg.l |
| flex / bison | 2 / 2 | 1 / 1 | love lex / love yacc, their C back ends (flex's `-o$@ -L`, bison's `-o -d -t -l`) |
| awk | 2 (gen-cpucaps, gen-sysreg) | 3 (orc_hash, cpufeaturemasks.h, gen-insn-attr-x86.awk) | kore awk; x64 scripts untried |
| bc | 1 (timeconst) | 1 | kore bc |
| gzip | 1 (config_data) | 1 (vmlinux.bin.gz) | love gzip (KGZIP) |
| sh scripts | 15 | 10 + link-vmlinux, gen_initramfs | lush |
| git | setlocalversion probes | same | untried whether host git runs |
| python, openssl, xz, lz4, zstd | 0 | 0 | |

## 9. image steps

- a64: Image = `llvm-objcopy -O binary -R .note -R .note.gnu.build-id -R .comment -S vmlinux`.
  EFI_STUB=y makes it a PE; no zboot. hearts' image.l gzips it, lays GPT + FAT + squashfs + ext4,
  and BOOTAA64.EFI (src/inle/uefi/slot.c by mooncc + holo) inflates and starts it. Only the objcopy
  is outside
- x64 (none of it in hearts yet; g-21, relocs/mkpiggy g-05-5f, links g-ae): setup.bin (37 `-m16` units, mkcpustr, nm|sed zoffset.h, ld.lld
  setup.elf, objcopy -O binary); realmode (relocs --realmode, objcopy); vmlinux.relocs (relocs);
  piggy (objcopy -R .comment -S, `cat vmlinux.bin vmlinux.relocs | gzip -n -9`, mkpiggy);
  compressed/vmlinux (17 units + 19 libstub, ld.lld -pie); bzImage = `dd setup.bin bs=4k conv=sync;
  cat vmlinux.bin`. EFI_STUB + EFI_MIXED: bzImage is the PE, no separate BOOTX64.EFI.
  6.19 has no arch/x86/boot/tools/build

## 10. the boot

- a64: boots to init under qemu virt (tcg) on r23's 4285 mooncc objects, clang for the rest, linked
  by GNU make + ld.lld (mix.sh). test_hearts_boot boots the all-clang certified Image under kvm-a64
- x64: never booted with mooncc objects. The clang reference boots to init in 1.3 s under q35 +
  OVMF + kvm (x64mix/boot.sh) — g-21
- qemu and OVMF are the test harness, not the build
