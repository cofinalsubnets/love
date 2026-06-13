# jit — the `(call ...)` trampoline and the `(forge ...)` loader

The floor under a love JIT: a nif that jumps into machine code stored in a
`buf` and runs it natively, and a loader that puts the bytes somewhere they can
run on either target.

```
(call b x)        ; jump into buf b's bytes, arg x, fixnum result
(forge src)       ; an EXECUTABLE buf holding a copy of src's bytes
```

`call` jumps into the bytes of buf `b`, passing `x` as the sole argument and
wrapping the returned machine word as a fixnum. The calling convention is the
platform C ABI — SysV AMD64 puts the argument in `%rdi` and takes the result in
`%rax`; AArch64 uses `x0` for both. The bytes inside `b` are entirely the
caller's responsibility: an ill-formed body is a hard crash, by design. A
non-buf argument runs nothing and returns nothing (`0`).

`forge` is how you get a `call`-able buf that works on **both** targets. The
portable idiom is `(call (forge bytes) x)`:

- **Host** — the Linux malloc heap is mapped no-execute, so a raw
  `(call <heap buf> ...)` SIGSEGVs on the jump. `forge` copies the bytes into a
  **W^X code arena** instead: `mmap` a page-rounded region read/write, write a
  `g_str` header + the bytes, `mprotect` it to read+execute, and never write it
  again. Writable *xor* executable is honored throughout, so hardened systems
  that forbid RWX still run it. The arena lives outside the GC pool — the
  returned buf is an ordinary buf whose backing-string pointer the collector
  leaves untouched (`gcp`'s out-of-pool short-circuit) — and a finalizer
  `munmap`s the region when the buf is collected (mirrors `io_close`).
- **Kernel** — the HHDM is already executable (the finding below), so `forge`
  is just a heap-buf copy; the bytes run in place.

`src` may be a string or a buf; a non-byte value or an empty one forges to `0`.

Both nifs live in `love.c` — search `lvm_call` and `lvm_forge`; each is three
lines of wiring (a forward-decl in the `lvm_t` block, the body, one nif-table
entry). The host arena helpers (`code_maplen`, `code_unmap`) sit just above
`lvm_forge` under `#if __STDC_HOSTED__`, so the freestanding kernel never sees
`mmap`.

## The finding: the kernel substrate is *just* this trampoline

`jit/probe.l` builds a buf holding six AMD64 bytes —

```
B8 2A 00 00 00   mov eax, 42      ; imm32 little-endian
C3               ret
```

— then `(call b 0)` and prints the result. Run on the **kernel** target under
qemu it returns the immediate exactly (verified at 42 and at 12345). So Limine
maps the HHDM — which backs the kernel heap, hence every `buf` — **without the
NX bit**: kernel data memory is already executable. No page-table work, no
`mprotect`: a love JIT is just love emitting bytes into a `buf` and calling it.

The **host** is the opposite: Linux maps the malloc heap no-execute, so a raw
`(call <heap buf> ...)` SIGSEGVs on the jump. `(forge ...)` lifts exactly that
limitation (the W^X arena above), so executing real bytes is no longer
kernel-only — `out/host/love jit/forge.l` runs the same immediates plus an
argument-echo natively on an x86_64 host, no qemu. The corpus test
(`test/jit.l`) still stays architecture-neutral — x86_64 opcodes would crash an
aarch64 or wasm host — so it covers the guards and that `forge` round-trips
bytes into a buf; the real execution lives in the two standalone files
(`jit/forge.l` on the host, `jit/probe.l` on the kernel).

## Reproducing the probe (x86_64 + qemu)

```sh
make host                                  # builds love0 + the bake tools
cp jit/probe.l out/lib/ktests.l            # make the probe the whole K_TEST corpus
out/host/love0 -l love/prelude.l tools/lcatv.l out/lib/ktests.l > out/lib/ktests.h
touch out/lib/ktests.l out/lib/ktests.h
make -s K_TEST=1 out/free/love-x86_64-test.iso
qemu-system-x86_64 -m 256M -M q35 -serial stdio -display none -no-reboot \
  -drive if=pflash,unit=0,format=raw,file=out/dl/edk2-ovmf/ovmf-code-x86_64.fd,readonly=on \
  -cdrom out/free/love-x86_64-test.iso \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04
# expect:  JIT-PROBE-START / JIT-PROBE-RESULT=42 / JIT-PROBE-END
# then restore the real corpus:  make out/lib/ktests.h   (or rm it; the next build re-bakes)
```

`probe.l` ends in `(exit 0)`, which the kernel routes to qemu's isa-debug-exit.

## Caveats / TODO

- **Always `forge` before you `call` on the host.** A bare `(call <heap buf>
  ...)` of real code still faults — the NX heap is unchanged. `forge` is the
  only host-safe way to obtain executable bytes; the arena it returns is W^X
  and freed by a finalizer, so no `mprotect` juggling or leaks on the caller.
- **AArch64 cache.** `lvm_call` omits the I-cache flush AArch64 needs after
  `forge` writes code (`__builtin___clear_cache(base, base+len)` before the
  first `call`). Correct on x86_64 only until that is added — and on AArch64 the
  flush belongs in `forge` (where the bytes are written), not `call`.
- **The contract across `call`.** The argument arrives as its *raw tagged* love
  word (`putfix A`) and the result is re-tagged (`putfix r`), so an identity
  body double-tags; `jit/forge.l`'s third demo shifts right by one to cancel the
  incoming tag and echo the love argument cleanly. A real codegen untags at the
  boundary. Keep what crosses `call` to unboxed machine words: no allocation, no
  heap pointers held inside — that is what keeps the JIT GC-safe.
- **No verification.** This is the raw trampoline plus a safe loader — no
  semantics, no proof that the bytes mean the love they claim to. A *verified*
  JIT is a separate, much larger effort (and the place love's in-tree prover
  could eventually earn its keep).
