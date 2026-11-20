#!/bin/sh
# test/gate/machobind.sh LOVE -- one C program linked by mooncc as an ELF and as dyld's mach-o.
# love objdump reads the mach-o's dyld_info as llvm-objdump does, byte for byte where llvm is
# here, and the binds are judged against the ELF's libsys. words (test/gate/machobind.l)
set -u
love=${1:-out/love}
d=out/.machobind && mkdir -p $d
printf '#include <unistd.h>\nint main(void) { return (int) write(1, "", 0); }\n' > $d/t.c
"$love" mooncc -pie $d/t.c -o $d/t.elf && "$love" mooncc -os macos -pie $d/t.c -o $d/t.mac \
  || { echo "FAIL machobind: the links"; exit 1; }
"$love" objdump --macho --rebase --bind --weak-bind $d/t.mac > $d/ours || { echo "FAIL machobind: love objdump"; exit 1; }
if lo=$(command -v llvm-objdump 2>/dev/null); then
  "$lo" --macho --rebase --bind --weak-bind $d/t.mac > $d/llvm \
    && cmp -s $d/ours $d/llvm || { echo "FAIL machobind: love objdump and llvm-objdump read the mach-o apart"; diff $d/ours $d/llvm | head -5; exit 1; }
fi
"$love" objdump --macho --bind $d/t.mac > $d/binds && "$love" test/gate/machobind.l $d/t.elf $d/binds || exit 1
# the ELF alone transposes to the mach-o link (test/gate/machox.l)
"$love" test/gate/machox.l $d/t.elf $d/t.mac || exit 1
# the same code bytes in both: an image, a nif row, a data pointer and bss to reach (test/gate/macform.l)
cat > $d/f.c <<'EOF'
#include <unistd.h>
static char buf[4096];
static char const *msg = "hi";
__attribute__((section(".love.image"))) long img[2] = {1};
__attribute__((section("love_nifs"))) long nif[2] = {3, 4};
int main(int c, char **v) { buf[c] = 1; return (int) write(1, msg, 0) + (int) (img[0] + nif[1]) + buf[1] + (v == 0); }
EOF
"$love" mooncc -pie $d/f.c -o $d/f.elf && "$love" mooncc -os macos -pie $d/f.c -o $d/f.mac \
  || { echo "FAIL macform: the links"; exit 1; }
"$love" test/gate/macform.l $d/f.elf $d/f.mac || exit 1
"$love" test/gate/machox.l $d/f.elf $d/f.mac
