; src/apps/hearts/libelf.l -- elfutils' libelf for objtool, built by mooncc from an unpacked
; elfutils tree: libelf.a, its three public headers, and a pkg-config that answers for it alone
; (objtool's Makefile asks `$(HOSTPKG_CONFIG) libelf`). the sources are elfutils' own lists,
; libelf_a_SOURCES and libeu_a_SOURCES, read off their Makefile.am. no zlib: elf_compress*.c
; stay out and decompression answers no, which objtool never asks; libeu's color.c and
; printversion.c are argp's, the tools' command lines, and libelf calls neither.
; usage: love libelf.l ELFUTILS OUT
(borrow 'posix)
(: argv cmdline
   _ (#argv = 4 || (puts "usage: love libelf.l ELFUTILS OUT\n", quit 2))
   eu (argv 2)
   out (argv 3)
   (die m) (puts ("libelf: " + m + "\n"), quit 1)
   (q s) ("'" + join "'\\''" (split "'" s) + "'")
   ; a Makefile.am variable's words, its backslash-continued lines joined
   (amvar path nm)
    (: ls (uread path @ [1 s] (lines s) (die ("cannot read " + path)))
       (from l) (? (atom? l) () (starts? <l (nm + " =") ? l (from >l)))
       (gather l acc) (? (atom? l) acc
                       (: x <l more (ends? x "\\")
                          a (acc + words (more ? (snip x 0 (#x - 1)) x))
                          (more ? (gather >l a) a)))
       ws (gather (from ls) ())
       (two? ws ? >>ws (die (nm + " is not in " + path))))
   srcs (map (f \ eu + "/libelf/" + f)
             (filter (f \ !(elem f '("elf_compress.c" "elf_compress_gnu.c")))
                     (amvar (eu + "/libelf/Makefile.am") "libelf_a_SOURCES"))
         + map (f \ eu + "/lib/" + f)
               (filter (f \ !(elem f '("color.c" "printversion.c")))
                       (amvar (eu + "/lib/Makefile.am") "libeu_a_SOURCES")))
   cfg (out + "/cfg")
   obj (out + "/o")
   love (selfpath 0)
   _ (hark ["mkdir" "-p" cfg obj (out + "/include")])
   ; configure's answers for mooncc and moonlibc, the few libelf reads
   _ (uwrite (cfg + "/config.h") """
       #define _GNU_SOURCE 1
       #define HAVE_DECL_MEMPCPY 1
       #define HAVE_DECL_REALLOCARRAY 1
       #define HAVE_DECL_MEMRCHR 0
       #define HAVE_DECL_POWEROF2 0
       #define HAVE_DECL_GETRANDOM 0
       #define HAVE_DECL_GETENTROPY 0
       #define HAVE_ERR_H 1
       #define HAVE_FALLTHROUGH 1
       #define HAVE_VISIBILITY 1
       #define HAVE_GCC_STRUCT 1
       #define PACKAGE_NAME "elfutils"
       #define PACKAGE_VERSION "0.197"
       #define PACKAGE_URL "https://sourceware.org/elfutils/"
       #define LOCALEDIR "/usr/share/locale"
       #include <eu-config.h>
       """ + "\n")
   _ (uwrite (out + "/nozlib.c") """
       /* no zlib: a compressed section does not decompress */
       #include <stddef.h>
       void *__libelf_decompress_elf_wrlock(void *scn, size_t *size, size_t *align) { return 0; }
       """ + "\n")
   (cc src o) (hark [love "mooncc" "-std=gnu11" "-O2" "-DHAVE_CONFIG_H" "-I" cfg "-I" (eu + "/libelf")
                     "-I" (eu + "/lib") "-c" src "-o" o] @ r
                (<r = 0 ? o (die ("mooncc refused " + src + "\n" + (two? r ? >r "")))))
   (base p) (split "/" p @ l (last l))
   os (map (s \ cc s (obj + "/" + base s + ".o")) (srcs + [(out + "/nozlib.c")]))
   _ (hark ([love "ar" "rcs" (out + "/libelf.a")] + os) @ r (<r = 0 || die "ar refused"))
   _ (each '("libelf.h" "gelf.h" "nlist.h")
           (h \ hark ["cp" "-f" (eu + "/libelf/" + h) (out + "/include/" + h)]))
   ; only the three: elfutils' libelf/ also holds its own elf.h, and objtool takes moon's
   _ (uwrite (out + "/pkg-config") ("#!" + love + " lush\n" + """
       # the build's pkg-config: libelf is the one package, built by mooncc
       n=; c=; l=
       for a in "$@"; do
         case $a in
           --cflags) c=1;; --libs) l=1;; libelf) n=libelf;; -*) ;; *) n=other;;
         esac
       done
       [ "$n" = libelf ] || exit 1
       """ + "\n"
       + "[ -z \"$c\" ] || printf '%s ' " + q ("-I" + out + "/include") + "\n"
       + "[ -z \"$l\" ] || printf '%s ' " + q (out + "/libelf.a") + "\n"
       + "[ -z \"$c$l\" ] || echo\nexit 0\n"))
   _ (hark ["chmod" "+x" (out + "/pkg-config")])
   (puts ("libelf: " + show #os + " objects in " + out + "/libelf.a\n")))
