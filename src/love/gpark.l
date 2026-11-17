; src/love/gpark.l -- the group lane's park as bytes: glaze.l's gpark assembled per target, laid
; into gpark_gen.h by `make mx`. its only addresses are its own labels and g's reach, so the
; bytes run wherever the link puts them
(:
   _ (borrow "src/love/boot/glaze.l")
   G (cite 'glaze)
   A (cite 'holo 'assemble)
   rows [['x64 "__x86_64__"] ['a64 "__aarch64__"]]
   (bytes t) (A t (G 'gpark t) 'bytes)
   dg "0123456789abcdef"
   (hx n) ("0x" + snip dg (n // 16) (n // 16 + 1) + snip dg (n % 16) (n % 16 + 1))
   (lines l) (atom? l ? ()
                (: n (#l < 16 ? #l 16)
                   (("    \".byte " + join "," (map hx (take n l)) + "\\n\"\n") . lines (drop n l))))
   (arm r) (: t <r m (r 1)
      (cats ["#" (t = 'x64 ? "if" "elif") " defined(" m ")\n"
            "__asm__(\".text\\n.balign 16\\n.globl \" GparkSym \"\\n\" GparkSym \":\\n\"\n"
            (cats (lines (bytes t))) "    );\n"]))
   gpark-h (cats ["// gpark_gen.h -- laid by src/love/gpark.l, `make mx`, from glaze.l's gpark. edit that.\n"
                  "#if defined(__APPLE__)\n#define GparkSym \"_love_gpark\"\n#else\n#define GparkSym \"love_gpark\"\n#endif\n"
                  (cats (map arm rows)) "#endif\n"])
   gpark-ok (all (r \ 0 < #(bytes <r)) rows))
