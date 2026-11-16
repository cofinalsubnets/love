#!/bin/sh
# test/gate/machobind.sh LOVE -- one C program linked by mooncc as an ELF and as dyld's mach-o,
# the mach-o's binds judged against the ELF's libsys. words (test/gate/machobind.l)
set -u
love=${1:-out/love}
d=out/.machobind && mkdir -p $d
printf '#include <unistd.h>\nint main(void) { return (int) write(1, "", 0); }\n' > $d/t.c
"$love" mooncc -pie $d/t.c -o $d/t.elf && "$love" mooncc -os macos -pie $d/t.c -o $d/t.mac \
  || { echo "FAIL machobind: the links"; exit 1; }
"$love" test/gate/machobind.l $d/t.elf $d/t.mac
