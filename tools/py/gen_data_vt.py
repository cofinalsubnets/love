#!/usr/bin/env python3
"""gen_data_vt.py -- bake the data-sentinel stride into a generated vt.h.

gwen recovers a heap object's kind from its `ap`: the five self-quote sentinels
(core/vt.c, DATA_SENTINEL) are pinned contiguously and in enum order into the
.gwen_data_vt section, so a kind is just a slot index into that section --
g_typ(o) == (ap - start) / unit, unit == (stop - start) / N (see core/vt.h).

Both `start` and `unit` are link-time quantities, so the portable header leaves
that as two runtime divides: one to derive `unit`, one to index by it. The
first can't be constant-folded and the second can't be strength-reduced to a
shift, because the compiler never sees the section's size.

But the sentinels live in their own translation unit (core/vt.c -> vt.o), and
that object already records each sentinel's size as the size of its
gwen_data_vt.NN input section -- before the link, no link needed. This script
reflects on vt.o, recovers that stride, and emits a vt.h that hard-codes
it. Result: `unit` is a literal (the derive-divide folds away) and, when the
stride is a power of two, the index-divide becomes a shift. `start` stays a
link-time symbol -- only the divides go.

The runtime's `unit == (stop - start) / N` is only equal to the per-sentinel
stride when the sentinels tile the section evenly (equal sizes, no inter-section
padding). We verify that here -- unequal sizes or a size that isn't a multiple
of the section alignment would desync the baked constant from the real layout --
and warn if the stride isn't a power of two (the shift path is then unavailable
and g_typ falls back to a divide-by-constant, which the compiler lowers to a
multiply rather than a hardware divide).

Usage: gen_data_vt.py <vt.o> [-o vt.h]   (writes stdout if no -o)
"""

import struct, sys

PREFIX = "gwen_data_vt."   # input subsections: gwen_data_vt.00 .. .04
N = 5                      # enum q: vec/big/two/text/sym -- must match gwen.h


def fail(msg):
    sys.stderr.write("gen_data_vt: error: %s\n" % msg)
    sys.exit(1)


def warn(msg):
    sys.stderr.write("gen_data_vt: warning: %s\n" % msg)


def read_sections(path):
    """Return [(name, size, addralign)] for every section in an ELF object.

    A small purpose-built reader rather than a shell-out to readelf: the
    sentinel bodies compile to whatever the *target* arch emits (16 bytes on
    x86_64, fewer on Thumb, ...), so this runs against objects for any arch the
    host toolchain produced, including 32-bit ones."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        fail("cannot read %s: %s" % (path, e))

    if data[:4] != b"\x7fELF":
        fail("%s is not an ELF object" % path)
    is64 = data[4] == 2
    end = "<" if data[5] == 1 else ">"

    if is64:
        shoff, = struct.unpack_from(end + "Q", data, 0x28)
        shentsize, shnum, shstrndx = struct.unpack_from(end + "HHH", data, 0x3a)
        # sh_name(u32) sh_type(u32) sh_flags(u64) sh_addr(u64) sh_offset(u64)
        # sh_size(u64) sh_link(u32) sh_info(u32) sh_addralign(u64) ...
        def shdr(off):
            name, = struct.unpack_from(end + "I", data, off)
            size, = struct.unpack_from(end + "Q", data, off + 0x20)
            align, = struct.unpack_from(end + "Q", data, off + 0x30)
            return name, size, align
    else:
        shoff, = struct.unpack_from(end + "I", data, 0x20)
        shentsize, shnum, shstrndx = struct.unpack_from(end + "HHH", data, 0x2e)
        # sh_name(u32) sh_type(u32) sh_flags(u32) sh_addr(u32) sh_offset(u32)
        # sh_size(u32) sh_link(u32) sh_info(u32) sh_addralign(u32) ...
        def shdr(off):
            name, = struct.unpack_from(end + "I", data, off)
            size, = struct.unpack_from(end + "I", data, off + 0x14)
            align, = struct.unpack_from(end + "I", data, off + 0x20)
            return name, size, align

    # section-header string table backs every sh_name
    str_name, str_size, _ = shdr(shoff + shstrndx * shentsize)
    if is64:
        stroff, = struct.unpack_from(end + "Q", data, shoff + shstrndx * shentsize + 0x18)
    else:
        stroff, = struct.unpack_from(end + "I", data, shoff + shstrndx * shentsize + 0x10)

    def name_at(idx):
        e = data.index(b"\x00", stroff + idx)
        return data[stroff + idx:e].decode("ascii", "replace")

    out = []
    for i in range(shnum):
        nm, size, align = shdr(shoff + i * shentsize)
        out.append((name_at(nm), size, align))
    return out


def stride_from(path):
    """Recover the per-sentinel byte stride from vt.o.

    The sentinels share one body, so every gwen_data_vt.NN section has the same
    size S and the same alignment A. The linker bumps each to its own alignment,
    so consecutive sentinels sit align_up(S, A) apart -- that padded value, not
    the raw S, is the real stride (on Thumb the 24-byte body is 16-aligned, so
    the stride is 32, not 24). We return it; the portable header's runtime
    (stop-start)/N only approximates it (152/5 = 30 there) and survives by
    flooring, but a baked constant has to be exact."""
    secs = [(n, sz, al) for (n, sz, al) in read_sections(path) if n.startswith(PREFIX)]
    secs.sort(key=lambda s: s[0])   # gwen_data_vt.00 .. .04, enum order
    if len(secs) != N:
        fail("found %d %s* sections in %s, expected %d (enum q in i.h)"
             % (len(secs), PREFIX, path, N))

    sizes = {sz for _, sz, _ in secs}
    if len(sizes) != 1:
        fail("sentinel sections have unequal sizes %s -- they no longer tile "
             "evenly, so there is no single stride" % sorted(sizes))
    size = sizes.pop()
    if size == 0:
        fail("sentinel section size is 0 (stripped object?)")

    align = max(al for _, _, al in secs) or 1
    return (size + align - 1) & ~(align - 1)   # align_up(size, align)


def is_pow2(n):
    return n > 0 and (n & (n - 1)) == 0


HEADER = """\
#ifndef _g_vt_h
#define _g_vt_h
// GENERATED by tools/gen_data_vt.py from vt.o -- do not edit by hand.
//
// Same contract as the portable core/vt.h, but the sentinel stride is baked
// in at build time (reflected out of vt.o) instead of left as the link-time
// expression (stop-start)/N. That removes both divides from g_typ: the derive-
// divide folds away (UNIT is a literal) and the index-divide %s.
// `start` stays a link-time symbol, so only the divides go, not the subtract.
extern char __start_gwen_data_vt[], __stop_gwen_data_vt[];
#define G_DATA_VT_UNIT %du   // sentinel stride in bytes, from vt.o
static g_inline bool in_data_vt(void *a) {
 return (uintptr_t) a >= (uintptr_t) __start_gwen_data_vt
     && (uintptr_t) a <  (uintptr_t) __stop_gwen_data_vt; }
static g_inline enum q g_typ(union u *o) {
 return (enum q) (((uintptr_t) o->ap - (uintptr_t) __start_gwen_data_vt) %s); }
#endif
"""


def main():
    args = sys.argv[1:]
    out = None
    if "-o" in args:
        i = args.index("-o")
        out = args[i + 1]
        del args[i:i + 2]
    if len(args) != 1:
        fail("usage: gen_data_vt.py <vt.o> [-o vt.h]")

    unit = stride_from(args[0])

    if is_pow2(unit):
        shift = unit.bit_length() - 1
        index = ">> %d" % shift                 # /UNIT as a shift
        note = "is a shift (UNIT == 2^%d)" % shift
    else:
        warn("data_vt stride %d is not a power of two; g_typ will divide by a "
             "constant (lowered to a multiply) rather than shift" % unit)
        index = "/ G_DATA_VT_UNIT"
        note = "is a divide by the constant UNIT (lowered to a multiply)"

    text = HEADER % (note, unit, index)
    if out:
        with open(out, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
