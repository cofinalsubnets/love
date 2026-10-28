# moon-x64-size — mooncc's x64 code against gcc's, by size

A living ledger for the arc that shrinks mooncc's x64 `.text`. The unit is opus.c, one file,
all codegen: its data is even with gcc's. Rows go when they land.

## the measure

```
out/love mooncc -D tco=1 -Iout -I. -Isrc/love -Isrc/inle -Iout/lib -c src/love/audio/opus.c -o o.o
size -A o.o; objdump -d -M intel o.o
```

against `gcc -O2 -fno-inline -fno-ipa-cp -fno-ipa-sra -fno-partial-inlining`, alignment off:
80589 B, 20.2k instructions. mooncc at gwen 04c784e10: 137579 B, 36.5k.

## what this branch carries

- `li r 0` lays `xor r r` past a jump whose label lies ahead and writes the flags before reading them
  (holo.l `flagjump`): `mov r,0` 276 -> 62
- holo's `movapd` lays movaps, a byte shorter (x64.l `x86-sse`; gas's table keeps its own): 865
- `imul r, r, k` takes the imm8 form where k fits a byte
- a zx4 whose bits reach only a narrowing or a narrow store, through low-half ops, copies and forms
  that leave the register alone, is dropped (gen.l `lo32` in hz4): `mov r32,r32` 560 -> 399
- `imul t i s` (s 2, 4, 8) feeding the next indexed form's index at scale 1 rides the scale (gen.l `xscale`)

together 137579 -> 134563 B.

## open, biggest first

1. frame traffic: ~5.9k `[rsp]`/`[rbp]` forms (31 KB) against gcc's 3.3k (17.5 KB), ~14 KB:
   register allocation, the same gap as on zstd
2. address arithmetic: lea 2.5k vs 1.1k, imul 1.1k vs 0.5k (~7 KB). most of the 210 imuls by
   2/4/8 left feed a mov, sub, lea or add rather than an indexed form: an add of a scaled index
   to a base is a leax, and a scaled index computed before a copy wants the copy seen through
3. movsxd: ~1.2k register to register (after calls, the ABI; after int + int typed long, kept on
   purpose, since 1<<31 and int hashes wrap; after reloads of unknown width, which widths across
   spills would recover) and ~2.6k as loads, a REX byte each where mov r32 would do
4. movsx 1156 vs gcc's 387: narrow re-extensions (~3 KB)
5. the 399 `mov r32,r32` left are mostly a call's 32-bit answer, which the ABI leaves undefined
   above bit 31; doing the arithmetic in 32-bit registers zero-extends for free, as gcc does
6. `mov eax,0; movd xmm0,eax` for a float 0 is `pxor xmm0,xmm0`
7. `li 0` before a cmov (the cmov reads the flags) could lay the xor before the compare
