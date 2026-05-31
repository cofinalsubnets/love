#!/usr/bin/env python3
"""vmret.py -- flag g_vm_* VM-instruction handlers that contain a ret.

The gwen VM is threaded: every `g_vm_*` opcode handler is supposed to be
tail-call optimised into a `jmp` to the next handler, never a normal
`ret`. A handler that the compiler failed to TCO emits a real `ret` in
its epilogue, which silently breaks the threaded dispatch. This tool
disassembles an ELF and flags every `g_vm_*` function whose body still
contains a `ret` instruction, so the broken-TCO suspects can be triaged.

It is deliberately a first-pass heuristic: it reports *any* ret in a
matching function, without reasoning about whether that ret is reachable
or whether the handler legitimately returns (a few do -- host I/O bifs,
yield, etc.). Expect false positives; the point is to narrow the search.

Usage:
    vmret.py ELF [--prefix PREFIX] [--objdump PATH]

    --prefix   symbol-name prefix to check (default: g_vm_)
    --objdump  disassembler to use; otherwise $OBJDUMP, then objdump,
               then llvm-objdump

Exit status: 0 if no matching function contains a ret, 1 if any do,
2 on a usage or tool error -- so it can gate a build.
"""
import os, re, shutil, struct, subprocess, sys

EM_X86_64 = 62                                    # ELF e_machine for x86-64

# A disassembly line is a function header `<addr> <name>:` or an
# instruction `<addr>: <text>`. Both GNU objdump and llvm-objdump emit
# this shape (with --no-show-raw-insn the raw bytes are gone).
HEADER_RE = re.compile(r"^\s*[0-9a-fA-F]+\s+<(.+)>:\s*$")
# Instruction lines: <addr>: <text>. Leading whitespace is optional -- some
# objdump builds indent it, others (e.g. GNU objdump on a high-half kernel
# image) print the address flush-left. Requiring the indent silently skipped
# every instruction and made the tool report all functions ret-free.
INSN_RE   = re.compile(r"^\s*([0-9a-fA-F]+):\s+(.*)$")

# Instruction prefixes that can sit in front of `ret` (e.g. `rep ret`,
# the old AMD branch-target padding). Skipped when extracting the mnemonic.
PREFIXES = {"rep", "repz", "repe", "repnz", "repne", "lock", "bnd",
            "notrack", "data16"}
# ret / retq / retf / retfq / retw / lret ... but not e.g. a `jmp` to a
# retpoline thunk, which keeps its jmp/call mnemonic and is a real tail call.
RET_RE = re.compile(r"^l?ret[a-z]*$")


def fail(msg):
    sys.stderr.write("vmret: " + msg + "\n"); sys.exit(2)


def elf_machine(path):
    """Return (e_machine, name) from the ELF header, or fail."""
    try:
        with open(path, "rb") as f:
            hdr = f.read(20)
    except OSError as e:
        fail("%s: %s" % (path, e.strerror))
    if hdr[:4] != b"\x7fELF":
        fail(path + ": not an ELF file")
    if hdr[4] != 2 or hdr[5] != 1:
        fail(path + ": not ELF64 little-endian")
    (machine,) = struct.unpack_from("<H", hdr, 18)
    names = {EM_X86_64: "x86-64", 183: "aarch64", 243: "riscv", 258: "loongarch64"}
    return machine, names.get(machine, "0x%x" % machine)


def find_objdump(explicit):
    for cand in (explicit, os.environ.get("OBJDUMP"), "objdump", "llvm-objdump"):
        if cand and shutil.which(cand):
            return cand
    fail("no disassembler found (tried objdump, llvm-objdump); pass --objdump")


def disassemble(objdump, path):
    cmd = [objdump, "-d", "--no-show-raw-insn", path]
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError as e:
        fail("could not run %s: %s" % (objdump, e.strerror))
    if p.returncode != 0:
        fail("%s failed: %s" % (objdump, p.stderr.decode("utf-8", "replace").strip()))
    return p.stdout.decode("utf-8", "replace").splitlines()


def mnemonic(insn_text):
    """First non-prefix token of an instruction's text."""
    for tok in insn_text.split():
        if tok in PREFIXES:
            continue
        return tok
    return ""


def scan(lines, prefix):
    """Walk the disassembly, grouping by function header. Return
    [(name, [ret_addr, ...]), ...] for matching functions, and the total
    number of matching functions seen (flagged or not)."""
    flagged, total = [], 0
    name, watching, rets = None, False, []

    def close():
        if watching and rets:
            flagged.append((name, rets))

    for line in lines:
        h = HEADER_RE.match(line)
        if h:
            close()
            name = h.group(1)
            watching = name.startswith(prefix)
            rets = []
            if watching:
                total += 1
            continue
        if not watching:
            continue
        m = INSN_RE.match(line)
        if m and RET_RE.match(mnemonic(m.group(2))):
            rets.append(m.group(1))
    close()
    return flagged, total


def main():
    argv = sys.argv[1:]
    path = prefix = objdump = None
    prefix = "g_vm_"
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--prefix" and i + 1 < len(argv):
            prefix = argv[i + 1]; i += 2
        elif a == "--objdump" and i + 1 < len(argv):
            objdump = argv[i + 1]; i += 2
        elif a in ("-h", "--help"):
            sys.stdout.write(__doc__); sys.exit(0)
        elif a.startswith("-"):
            fail("unknown option: " + a)
        elif path is None:
            path = a; i += 1
        else:
            fail("unexpected argument: " + a)
    if path is None:
        fail("usage: vmret.py ELF [--prefix PREFIX] [--objdump PATH]")

    machine, mname = elf_machine(path)
    if machine != EM_X86_64:
        sys.stderr.write("vmret: note: %s is %s, ret-mnemonic match assumes "
                         "x86_64\n" % (path, mname))

    od = find_objdump(objdump)
    flagged, total = scan(disassemble(od, path), prefix)

    base = os.path.basename(path)
    if total == 0:
        sys.stderr.write("vmret: no %s* functions found in %s "
                         "(stripped binary?)\n" % (prefix, base))
        sys.exit(2)
    if not flagged:
        print("%s: all %d %s* functions are ret-free" % (base, total, prefix))
        sys.exit(0)

    print("%s: %d of %d %s* functions contain a ret (TCO suspects):"
          % (base, len(flagged), total, prefix))
    width = max(len(n) for n, _ in flagged)
    for name, rets in sorted(flagged):
        addrs = ", ".join("0x" + a for a in rets)
        print("  %-*s  ret @ %s" % (width, name, addrs))
    sys.exit(1)


if __name__ == "__main__":
    main()
