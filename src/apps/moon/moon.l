; src/apps/moon/moon.l -- the C compiler's driver: lex -> cpp -> parse -> gen -> the holo book.
;   mooncc [-c] [-I dir] [-D name[=val]] [-o out] in.c|in.o|lib.a ..
; -c lays objects; without it every input links (holo's link.l) with crt0 and the runtime. our
; headers are the only standard set. advisory gcc flags ride through (tol?); a link owing libc
; symbols pulls moonlibc + lm + sys by need, unless -nostdlib. errors exit 1, usage 2. moon-main
; quits with the status; moon-run answers it, for a caller in the image.
(module 'moon
(borrow 'kore)
(borrow 'holo) ; the assembler module: asm-text, arbytes, the linker
(borrow 'gz)
(borrow 'hashes)

(borrow 'posix)
(borrow 'glob) ; match and ones, under the wildcard
(borrow 'path) ; lastslash, under cdir
(borrow 'bytes)

(:
   ; the directory portion of a path (up to and including the last '/'), or ""
   (cdir path) (lastslash path @ d (0 < d ? (snip path 0 d) ""))
   ; the toolchain slice's place in the tree, spelled once
   mtree "src/apps/moon/"
   ; the toolchain roots, in order: the dev tree off the cwd, then the installed nest beside the
   ; binary (../lib/love/moon/). read at each call, never bound: a baked image would keep the path
   (mseat _) (selfpath 0 @ x
                (string? x && "\(cdir x)../lib/love/moon/"))
   (mroots _) (mseat () @ s (string? s ? [mtree s] [mtree]))
   ; the runtime home: the first root that carries the sources, by read (core.c is in every link)
   (mhome _) (: (go rs) (? !(two? rs) ()
                           (two? (uread "\(<rs)lib/moonlibc/core.c")) <rs
                           (go >rs))
                (go (mroots ())))
   ; a path with . and .. folded away: "a/sys/../b.h" and "a/b.h" are one key
   (pnorm p)
    (: n #p
       (go i st ps) (? (n < i) ps
                       (i = n || p i = 47)
                        (snip p st i @ c
                         (go (i + 1) (i + 1)
                          (c @ ("" || ".") ps ".." (two? ps ? >ps) (c . ps))))
                       (go (i + 1) st ps))
       (jn l a) (!(two? l) ? a (jn >l (<l + (#a ? "/\(a)" a))))
       (jn (go 0 0 ()) ""))
   ; a read-only ustar walk: nom (prefix + name), size, body
   (ttxt s o k) (: (go i) (k <= i || s (o + i) = 0 ? i (go (i + 1)))
                   m (go 0)
                   (m ? (cask m @ c (pour c 0 s o m, string c)) ""))
   ; noms are "[./]<top>/apps/moon/..": strip the top
   (strip1 nom) (: s (nom @ ("./" + t) t nom)
                   m #s
                   (go i) (? (m <= i) ""
                             (s i = 47) (snip s (i + 1) m)
                             (go (i + 1)))
                   (go 0))
   (tarfiles s)                             ; -> [[nom body] ..], files only
    (: n #s
       (go o acc) (n < o + 512 || s o = 0 ? acc
                     (: nm (ttxt s o 100)
                        pf (ttxt s (o + 345) 155)
                        nom (#pf ? "\(pf)/\(nm)" nm)
                        sz (rdoct s (o + 124) 12)
                        k (s (o + 156))
                        acc2 (k = 48 || k = 0
                                ? (cask sz @ c (pour c 0 s (o + 512) sz,
                                                [nom (string c)] . acc))
                                acc)
                        (go (o + 512 + 512 * ((sz + 511) // 512)) acc2)))
       (go 0 ()))
   ; no nest on disk: the toolchain slice (include/ and lib/) the binary carries, as a table
   ; keyed by nest-relative path. () when nothing is carried (love0)
   (msub nom) (: rel (strip1 nom) sub (starts? rel mtree ? (snip rel #mtree #rel) "")
                 (starts? sub "include/" || starts? sub "lib/" ? sub))
   (mblob _)
    (tree-tar "moon" @ s
       (!(string? s) ? ()
          (foldl (a \ e \ msub <e @ sub (sub ? (pin a sub <>e) a)) {} (tarfiles s))))
   ; the first three of a name list, comma-joined, with a count of the rest
   (mfew ns)
    (: n #ns
       (go l k acc) (!(two? l) || 3 <= k ? acc
                       (go >l (k + 1) (0 < k ? "\(acc), \(<l)" <l)))
       s (go ns 0 "")
       (3 < n ? "\(s) (+\(n - 3) more)" s))
   ; #include resolver for a source dir + the -I list: "" searches the src dir, the cwd, then
   ; -I; <> the -I dirs; both end at our headers. vb, the carried source's table, in the same
   ; order. -> (1 text child-incf path) | (), the child resolving the hit's own quote includes
   (incload vb is srcdir name sys?)
    (: ours (map (r \ "\(r)include/") (mroots ()))
       dirs (sys? ? (is + ours) ([srcdir ""] + is + ours))
       (go ds) (!(two? ds) ? ()
                  (uread (<ds + name) @ r
                     (two? r ?
                        (cdir (<ds + name) @ hd
                           ; the resolved path keys cpp's header memo beside the text
                           [1 <>r (n2 \ s2 \ incload vb is hd n2 s2) (<ds + name)])
                        (go >ds))))
       r (go dirs)
       (? (two? r) r
          !vb ()
          ; the carried source: beside the includer, then our headers -- the disk walk's order
          (: k1 (pnorm (srcdir + name))
             h1 (!sys? && vb k1)
             (string? h1 ? [1 h1 (n2 \ s2 \ incload vb is (cdir k1) n2 s2) k1]
                (: k2 "include/\(name)"
                   h2 (vb k2)
                   (string? h2 ? [1 h2 (n2 \ s2 \ incload vb is (cdir k2) n2 s2) k2]))))))
   ; a -D as #define text: the first = becomes a space (-DX -> "X 1", -DF(x)=x -> "F(x) x",
   ; function-like since the ( stays glued)
   (eqsp d) (d @ (k + "=" + v) (k + " " + v) (d + " 1"))
   ; one line per entry keeps clexat's skew exact; a -U rides as ('u name), in line order
   (deftext ds) (foldl (a \ d \ string? d ? "\(a)#define \(eqsp d)\n" "\(a)#undef \(<>d)\n") "" ds)
   ; the -t names, spelled as the prel's arch-canon. the arch predefine rides the -D channel,
   ; so cpp stays target-blind
   (totgt s) (archof s @ t (t || udie 2 "cc: unknown target \(s)"))

   ; the arch predefines, both spellings where gcc gives two (pdclib asks `defined(__x86_64)`)
   (archdefs tgt)
   ; __CHAR_UNSIGNED__ where plain char is unsigned (parse.l's pchar), as gcc and clang predefine it
   (tgt @ 'a64                          '("__aarch64__" "__CHAR_UNSIGNED__")
          'rv64                        '("__riscv" "__CHAR_UNSIGNED__")
          'wasm                        '("__wasm__" "__wasm64__")   ; plain char signed, as wasm's C conventions (emcc)
          ('thumb2 || 'thumb2sp)       '("__arm__" "__arm" "__CHAR_UNSIGNED__")
          'arm                         '("__arm__" "__arm" "__CHAR_UNSIGNED__" "__ILP32__" "__ARM_EABI__" "__thumb__" "__thumb2__")
          'thumb1                      '("__arm__" "__arm" "__CHAR_UNSIGNED__" "__ARM_ARCH_6M__")   ; gcc's for -mcpu=cortex-m0
          ('i386 || 'i386m16)          '("__i386__" "__i386" "__ILP32__")
                                          '("__x86_64__" "__x86_64" "__amd64__" "__amd64"))
   ; __CHAR_UNSIGNED__ follows the target and -f[un]signed-char
   (uchar? tgt uc) (uc @ 'u 1 's 0 (elem "__CHAR_UNSIGNED__" (archdefs tgt) ? 1 0))
   ; gcc's spelling of the -fstack-protector level
   (sspdefs sp) (sp @ 1 ["__SSP__=1"] 2 ["__SSP_STRONG__=2"] 3 ["__SSP_ALL__=3"] 4 ["__SSP_EXPLICIT__=4"] ())
   (chdefs tgt uc) (filter (d \ d != "__CHAR_UNSIGNED__") (archdefs tgt) + (uchar? tgt uc = 1 ? ["__CHAR_UNSIGNED__"] ()))
   ; the OS predefines: gcc's spellings but the unprefixed linux/unix, which collide with
   ; identifiers. takes a flag's text or love-os's nom; 'inle refuses: a compile there owes -os
   (toos s) ((string? s ? (name s) s) @
    'linux   'linux
    'none    'none
    'freebsd 'freebsd
    'netbsd  'netbsd
    'macos   'macos
             (udie 2 "cc: unknown os \(string s)"))
   ; the ground: main.c pins `love-os` per run, since one binary meets three kernels. read as
   ; data (a bare ref would fold the bake's absence in); unpinned owes a diagnostic, not a guess
   (host-os _)
    (elem 'love-os (names ()) && ev 'love-os @ n
       (nom? n ? (toos n)
                 (udie 2 "cc: cannot tell which kernel this is -- name one with -os")))
   (osdefs os0)
    (: os (!os0 ? (host-os 0) os0)
       (os @ 'none    ()
             'freebsd '("__FreeBSD__=14" "__unix__" "__unix")   ; stable/14, whose syscall.h the tables speak
             'netbsd  '("__NetBSD__" "__unix__" "__unix")
             'macos   '("__APPLE__" "__MACH__")
             'linux   '("__linux__" "__linux" "__unix__" "__unix")
                      (udie 2 "cc: no predefines for os \(os)")))
   ; what -mbranch-protection lays, as acle names it (gen.l's bprot): the a key, non-leaf
   (bpdefs bp) ((elem 'bti bp ? '("__ARM_FEATURE_BTI_DEFAULT=1")) + (elem 'pac bp ? '("__ARM_FEATURE_PAC_DEFAULT=1")))
   ; gcc's atomic predefines: a width's lock-free answer as gen lays it, 2 or 0 (rv64 has no
   ; sub-word rmw, thumb2 no doubleword, thumb1 no exclusives)
   (atomdefs tgt sw)
    (: ws (tgt @ 'thumb1 () 'rv64 '(4 8) ('thumb2 || 'thumb2sp || 'arm || 'i386 || 'i386m16) '(1 2 4) '(1 2 4 8))
       lw (elem tgt '(thumb2 thumb2sp arm thumb1 i386 i386m16) ? 4 8)
       (lf n) (elem n ws ? "2" "0")
       ('("__ATOMIC_RELAXED=0" "__ATOMIC_CONSUME=1" "__ATOMIC_ACQUIRE=2" "__ATOMIC_RELEASE=3"
          "__ATOMIC_ACQ_REL=4" "__ATOMIC_SEQ_CST=5" "__GCC_ATOMIC_TEST_AND_SET_TRUEVAL=1")
        + map (p \ "__GCC_ATOMIC_\(<p)_LOCK_FREE=\(lf (p 1))")
                [["BOOL" 1] ["CHAR" 1] ["CHAR16_T" 2] ["CHAR32_T" 4] ["WCHAR_T" (sw ? 2 4)]
                 ["SHORT" 2] ["INT" 4] ["LONG" lw] ["LLONG" 8] ["POINTER" lw]]
        + map (n \ "__GCC_HAVE_SYNC_COMPARE_AND_SWAP_\(n)") ws))
   ; C11's conditional features (6.10.8.3), each absence target-true; u"" is utf-16, U"" utf-32
   (featdefs tgt)
    ('("__STDC_NO_ATOMICS__=1" "__STDC_NO_THREADS__=1"
       "__STDC_UTF_16__=1" "__STDC_UTF_32__=1")
     + (elem tgt '(x64 i386 i386m16 a64 thumb2 arm) ? () '("__STDC_NO_COMPLEX__=1"))
     + (elem tgt '(x64 a64 i386 i386m16 thumb2 thumb2sp arm) ? () '("__STDC_NO_VLA__=1")))
   ; gcc's <stdint>/<limits>/<float.h> predefines, forked on word width and wchar, each gcc's
   ; value on that target. __LDBL_* answer double's: there is no long double here. a -D wins.
   stdcommon
    ; __mooncc__ says the compiler, __moonlibc__ the libc; __moon__ (cc-defs) the dialect
    '("__mooncc__=1" "__moonlibc__=1"
      "__CHAR_BIT__=8" "__SCHAR_MAX__=0x7f" "__SHRT_MAX__=0x7fff"
      "__SCHAR_WIDTH__=8" "__SHRT_WIDTH__=16" "__INT_WIDTH__=32"
      "__LONG_LONG_MAX__=0x7fffffffffffffffLL" "__LONG_LONG_WIDTH__=64"
      "__ORDER_LITTLE_ENDIAN__=1234" "__ORDER_BIG_ENDIAN__=4321" "__ORDER_PDP_ENDIAN__=3412"
      "__BYTE_ORDER__=__ORDER_LITTLE_ENDIAN__" "__FLOAT_WORD_ORDER__=__ORDER_LITTLE_ENDIAN__"
      "__INT8_TYPE__=signed char" "__UINT8_TYPE__=unsigned char"
      "__INT8_MAX__=0x7f" "__UINT8_MAX__=0xff" "__INT8_C(c)=c" "__UINT8_C(c)=c"
      "__INT16_TYPE__=short int" "__UINT16_TYPE__=short unsigned int"
      "__INT16_MAX__=0x7fff" "__UINT16_MAX__=0xffff" "__INT16_C(c)=c" "__UINT16_C(c)=c"
      "__INT32_TYPE__=int" "__UINT32_TYPE__=unsigned int"
      "__INT32_MAX__=0x7fffffff" "__UINT32_MAX__=0xffffffffU"
      "__INT32_C(c)=c" "__UINT32_C(c)=c ## U"
      "__INT_LEAST8_TYPE__=signed char" "__UINT_LEAST8_TYPE__=unsigned char"
      "__INT_LEAST8_MAX__=0x7f" "__UINT_LEAST8_MAX__=0xff" "__INT_LEAST8_WIDTH__=8"
      "__INT_LEAST16_TYPE__=short int" "__UINT_LEAST16_TYPE__=short unsigned int"
      "__INT_LEAST16_MAX__=0x7fff" "__UINT_LEAST16_MAX__=0xffff" "__INT_LEAST16_WIDTH__=16"
      "__INT_LEAST32_TYPE__=int" "__UINT_LEAST32_TYPE__=unsigned int"
      "__INT_LEAST32_MAX__=0x7fffffff" "__UINT_LEAST32_MAX__=0xffffffffU" "__INT_LEAST32_WIDTH__=32"
      "__WINT_TYPE__=unsigned int" "__WINT_MAX__=0xffffffffU" "__WINT_MIN__=0U" "__WINT_WIDTH__=32"
      "__SIZEOF_SHORT__=2" "__SIZEOF_INT__=4" "__SIZEOF_LONG_LONG__=8"
      "__SIZEOF_FLOAT__=4" "__SIZEOF_DOUBLE__=8" "__SIZEOF_WINT_T__=4"
      "__FLT_RADIX__=2"
      "__FLT_MANT_DIG__=24" "__FLT_DIG__=6" "__FLT_DECIMAL_DIG__=9"
      "__FLT_MIN_EXP__=(-125)" "__FLT_MIN_10_EXP__=(-37)" "__FLT_MAX_EXP__=128" "__FLT_MAX_10_EXP__=38"
      "__FLT_MIN__=1.17549435082228750796873653722224568e-38F"
      "__FLT_EPSILON__=1.19209289550781250000000000000000000e-7F"
      "__FLT_DENORM_MIN__=1.40129846432481707092372958328991613e-45F"
      "__FLT_NORM_MAX__=3.40282346638528859811704183484516925e+38F"
      "__FLT_HAS_DENORM__=1" "__FLT_HAS_INFINITY__=1" "__FLT_HAS_QUIET_NAN__=1"
      "__DBL_MANT_DIG__=53" "__DBL_DIG__=15" "__DBL_DECIMAL_DIG__=17"
      "__DBL_MIN_EXP__=(-1021)" "__DBL_MIN_10_EXP__=(-307)" "__DBL_MAX_EXP__=1024" "__DBL_MAX_10_EXP__=308"
      "__DBL_MIN__=2.22507385850720138309023271733240406e-308"
      "__DBL_EPSILON__=2.22044604925031308084726333618164062e-16"
      "__DBL_DENORM_MIN__=4.94065645841246544176568792868221372e-324"
      "__DBL_NORM_MAX__=1.79769313486231570814527423731704357e+308"
      "__DBL_HAS_DENORM__=1" "__DBL_HAS_INFINITY__=1" "__DBL_HAS_QUIET_NAN__=1"
      "__LDBL_MANT_DIG__=53" "__LDBL_DIG__=15" "__LDBL_DECIMAL_DIG__=17"
      "__LDBL_MIN_EXP__=(-1021)" "__LDBL_MIN_10_EXP__=(-307)" "__LDBL_MAX_EXP__=1024" "__LDBL_MAX_10_EXP__=308"
      "__LDBL_MIN__=2.22507385850720138309023271733240406e-308"
      "__LDBL_MAX__=1.79769313486231570814527423731704357e+308"
      "__LDBL_EPSILON__=2.22044604925031308084726333618164062e-16"
      "__LDBL_DENORM_MIN__=4.94065645841246544176568792868221372e-324"
      "__LDBL_NORM_MAX__=1.79769313486231570814527423731704357e+308"
      "__LDBL_HAS_DENORM__=1" "__LDBL_HAS_INFINITY__=1" "__LDBL_HAS_QUIET_NAN__=1"
      "__DECIMAL_DIG__=17")
   stdlp64
    '("__LP64__=1" "_LP64=1"
      "__LONG_MAX__=0x7fffffffffffffffL" "__LONG_WIDTH__=64"
      "__SIZEOF_LONG__=8" "__SIZEOF_POINTER__=8" "__SIZEOF_SIZE_T__=8" "__SIZEOF_PTRDIFF_T__=8"
      "__INT64_TYPE__=long int" "__UINT64_TYPE__=long unsigned int"
      "__INT64_MAX__=0x7fffffffffffffffL" "__UINT64_MAX__=0xffffffffffffffffUL"
      "__INT64_C(c)=c ## L" "__UINT64_C(c)=c ## UL"
      "__INT_LEAST64_TYPE__=long int" "__UINT_LEAST64_TYPE__=long unsigned int"
      "__INT_LEAST64_MAX__=0x7fffffffffffffffL" "__UINT_LEAST64_MAX__=0xffffffffffffffffUL"
      "__INT_LEAST64_WIDTH__=64"
      "__INT_FAST8_TYPE__=signed char" "__UINT_FAST8_TYPE__=unsigned char"
      "__INT_FAST8_MAX__=0x7f" "__UINT_FAST8_MAX__=0xff" "__INT_FAST8_WIDTH__=8"
      "__INT_FAST16_TYPE__=long int" "__UINT_FAST16_TYPE__=long unsigned int"
      "__INT_FAST16_MAX__=0x7fffffffffffffffL" "__UINT_FAST16_MAX__=0xffffffffffffffffUL"
      "__INT_FAST16_WIDTH__=64"
      "__INT_FAST32_TYPE__=long int" "__UINT_FAST32_TYPE__=long unsigned int"
      "__INT_FAST32_MAX__=0x7fffffffffffffffL" "__UINT_FAST32_MAX__=0xffffffffffffffffUL"
      "__INT_FAST32_WIDTH__=64"
      "__INT_FAST64_TYPE__=long int" "__UINT_FAST64_TYPE__=long unsigned int"
      "__INT_FAST64_MAX__=0x7fffffffffffffffL" "__UINT_FAST64_MAX__=0xffffffffffffffffUL"
      "__INT_FAST64_WIDTH__=64"
      "__INTMAX_TYPE__=long int" "__UINTMAX_TYPE__=long unsigned int"
      "__INTMAX_MAX__=0x7fffffffffffffffL" "__UINTMAX_MAX__=0xffffffffffffffffUL"
      "__INTMAX_C(c)=c ## L" "__UINTMAX_C(c)=c ## UL" "__INTMAX_WIDTH__=64"
      "__INTPTR_TYPE__=long int" "__UINTPTR_TYPE__=long unsigned int"
      "__INTPTR_MAX__=0x7fffffffffffffffL" "__UINTPTR_MAX__=0xffffffffffffffffUL" "__INTPTR_WIDTH__=64"
      "__SIZE_TYPE__=long unsigned int" "__SIZE_MAX__=0xffffffffffffffffUL" "__SIZE_WIDTH__=64"
      "__PTRDIFF_TYPE__=long int" "__PTRDIFF_MAX__=0x7fffffffffffffffL" "__PTRDIFF_WIDTH__=64"
      "__BIGGEST_ALIGNMENT__=16")                    ; the widest ask, and bare aligned
   stdt32
    '("__LONG_MAX__=0x7fffffffL" "__LONG_WIDTH__=32"
      "__SIZEOF_LONG__=4" "__SIZEOF_POINTER__=4" "__SIZEOF_SIZE_T__=4" "__SIZEOF_PTRDIFF_T__=4"
      "__INT64_TYPE__=long long int" "__UINT64_TYPE__=long long unsigned int"
      "__INT64_MAX__=0x7fffffffffffffffLL" "__UINT64_MAX__=0xffffffffffffffffULL"
      "__INT64_C(c)=c ## LL" "__UINT64_C(c)=c ## ULL"
      "__INT_LEAST64_TYPE__=long long int" "__UINT_LEAST64_TYPE__=long long unsigned int"
      "__INT_LEAST64_MAX__=0x7fffffffffffffffLL" "__UINT_LEAST64_MAX__=0xffffffffffffffffULL"
      "__INT_LEAST64_WIDTH__=64"
      "__INT_FAST8_TYPE__=int" "__UINT_FAST8_TYPE__=unsigned int"
      "__INT_FAST8_MAX__=0x7fffffff" "__UINT_FAST8_MAX__=0xffffffffU" "__INT_FAST8_WIDTH__=32"
      "__INT_FAST16_TYPE__=int" "__UINT_FAST16_TYPE__=unsigned int"
      "__INT_FAST16_MAX__=0x7fffffff" "__UINT_FAST16_MAX__=0xffffffffU" "__INT_FAST16_WIDTH__=32"
      "__INT_FAST32_TYPE__=int" "__UINT_FAST32_TYPE__=unsigned int"
      "__INT_FAST32_MAX__=0x7fffffff" "__UINT_FAST32_MAX__=0xffffffffU" "__INT_FAST32_WIDTH__=32"
      "__INT_FAST64_TYPE__=long long int" "__UINT_FAST64_TYPE__=long long unsigned int"
      "__INT_FAST64_MAX__=0x7fffffffffffffffLL" "__UINT_FAST64_MAX__=0xffffffffffffffffULL"
      "__INT_FAST64_WIDTH__=64"
      "__INTMAX_TYPE__=long long int" "__UINTMAX_TYPE__=long long unsigned int"
      "__INTMAX_MAX__=0x7fffffffffffffffLL" "__UINTMAX_MAX__=0xffffffffffffffffULL"
      "__INTMAX_C(c)=c ## LL" "__UINTMAX_C(c)=c ## ULL" "__INTMAX_WIDTH__=64"
      "__INTPTR_TYPE__=int" "__UINTPTR_TYPE__=unsigned int"
      "__INTPTR_MAX__=0x7fffffff" "__UINTPTR_MAX__=0xffffffffU" "__INTPTR_WIDTH__=32"
      "__SIZE_TYPE__=unsigned int" "__SIZE_MAX__=0xffffffffU" "__SIZE_WIDTH__=32"
      "__PTRDIFF_TYPE__=int" "__PTRDIFF_MAX__=0x7fffffff" "__PTRDIFF_WIDTH__=32"
      "__BIGGEST_ALIGNMENT__=8")                     ; AAPCS's widest ask, and bare aligned
   ; wchar_t forks by ABI: int on SysV, unsigned int on AAPCS; -fshort-wchar unsigned short
   (wchdefs tgt sw)
    (? sw '("__WCHAR_TYPE__=short unsigned int" "__WCHAR_MAX__=0xffff" "__WCHAR_MIN__=0" "__WCHAR_WIDTH__=16"
            "__SIZEOF_WCHAR_T__=2")
       (tgt = 'a64 || arm32? tgt)
       '("__WCHAR_TYPE__=unsigned int" "__WCHAR_MAX__=0xffffffffU" "__WCHAR_MIN__=0U" "__WCHAR_WIDTH__=32"
         "__SIZEOF_WCHAR_T__=4")
       '("__WCHAR_TYPE__=int" "__WCHAR_MAX__=0x7fffffff" "__WCHAR_MIN__=(-__WCHAR_MAX__ - 1)" "__WCHAR_WIDTH__=32"
         "__SIZEOF_WCHAR_T__=4"))
   ; i386 is the 32-bit table but where SysV i386 parts from AAPCS: the fast-8 types a
   ; byte, the widest alignment SSE's 16, and wchar_t a long
   stdi386
    (: own '("__INT_FAST8_TYPE__=signed char" "__INT_FAST8_MAX__=0x7f" "__INT_FAST8_WIDTH__=8"
             "__UINT_FAST8_TYPE__=unsigned char" "__UINT_FAST8_MAX__=0xff" "__BIGGEST_ALIGNMENT__=16")
       (key d) <(usplit 61 d)
       (filter (d \ !(elem (key d) (map key own))) stdt32 + own))
   (stddefs tgt sw)
    (? (i386? tgt)
       (stdi386 + (sw ? (wchdefs tgt sw)
                      '("__WCHAR_TYPE__=long int" "__WCHAR_MAX__=0x7fffffffL" "__WCHAR_MIN__=(-__WCHAR_MAX__ - 1)"
                        "__WCHAR_WIDTH__=32" "__SIZEOF_WCHAR_T__=4"))
        + stdcommon)
       ((arm32? tgt ? stdt32 stdlp64) + wchdefs tgt sw + stdcommon))
   ; a gripe prints "cc: <file>:<line>:<col>: msg" (no file: the source; no line/col: elided);
   ; anything else prints plain. both exit 1
   (ccdie val src plain)
    (gripe? val ?
       (: file (val 1 @ f (f || src))
          ln (val 2) col (val 3) msg (val 4)
          loc (file + (ln ? ":\(ln)" "") + (col ? ":\(col)" ""))
          (udie 1 "cc: \(loc): \(msg)"))
       (udie 1 plain))
   ; `.incbin "path"[, skip[, count]]` in assembly text: the file's bytes, found from the working
   ; directory then the -I dirs as gas finds them, laid as the .base64 gas-top reads whole
   b64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (b64s s) (: n #s
               (q i) (: b (i + 1 < n ? (s (i + 1)) 0) c (i + 2 < n ? (s (i + 2)) 0) w (s i << 16 | b << 8 | c)
                        [(b64set ((w >> 18) & 63)) (b64set ((w >> 12) & 63))
                         (i + 1 < n ? (b64set ((w >> 6) & 63)) 61) (i + 2 < n ? (b64set (w & 63)) 61)])
               (string (catmap q (filter (i \ i % 3 = 0) ^n))))
   (incbins txt is src)
    (: (one ln) (: t (xa-trim ln)
                   (? (!(starts? t ".incbin") || (7 < #t && !(blank? (t 7)))) ln
                      (: xs (xa-oplist (snip t 7 #t)) nm (xa-unquote (xa-trim <xs))
                         r (foldl (\ a d (two? a ? a (uread (d + nm)))) () ("" . is))
                         _ (two? r || udie 1 "cc: \(src): .incbin: cannot open \(nm)")
                         k (two? >xs ? (gimm (gtoks (xs 1))) 0) n (two? >>xs ? (gimm (gtoks (xs 2))) (#<>r - k))
                         (? (k < 0 || n < 0 || k + n > #<>r) (udie 1 "cc: \(src): .incbin: past the end of \(nm)")
                            "\t.base64 \"\(b64s (snip <>r k (k + n)))\""))))
       ls (gsplit txt 10)
       (any (ln \ starts? (xa-trim ln) ".incbin") ls ? (xa-join "\n" (map one ls)) txt))
   ; an assembly source as C: one file-scope asm holding its text, which gen hands gas-top
   (asmwrap s) "__asm__(\"\(string (catmap (c \ (c @ 92 [92 92] 34 [92 34] 10 [92 110] 9 [92 116] 13 () [c])) (chars s)))\");\n"
   ; a .S: the assembly lexed on its own terms, preprocessed as C is (includes, macros, #if),
   ; spelled back into lines, and taken as a .s is
   (asmcpp src s ds is vb)
    (: d2 ("__ASSEMBLER__=1" . ds)
       lx (clexasm (deftext d2 + s) (1 - #d2) (elem "__aarch64__" ds || elem "__arm__" ds))
       _ (okv? lx || ccdie lx src "cc: lex error in \(src)")
       pp (cppasm <>lx (name \ sys? \ incload vb is (cdir src) name sys?) src)
       (okv? pp || ccdie pp src "cc: preprocessor error in \(src)",
        asmwrap (incbins (asmspell <>pp) is src)))
   ; tokens back to assembly text: an unexpanded token from a later line opens a new one; a
   ; space where the source had one and between two words
   (asmspell ts)
    (: (word? t) (<t != 'p && <t != 'str)
       (qesc s) "\"\(string (catmap (c \ (c @ 34 [92 34] 92 [92 92] 10 [92 110] 9 [92 116]
                                                   (c < 32 || 126 < c ? (c & 255 @ o [92 (48 + (o >> 6)) (48 + ((o >> 3) & 7)) (48 + (o & 7))]) [c])))
                                        (chars s)))\""
       (spell t) (: sp (4 < #t && string? (t 4) ? (t 4))
                    (<t @ 'id <>t 'kw (show <>t) 'p <>t 'str (sp ? sp (qesc <>t)) (sp ? sp (show <>t))))
       (go l prev acc)
        (atom? l ? (string (catall (rev acc)))
           (<l @ t
              (? (<t = 'fspans) (go >l prev acc)                  ; cpp's file-span record, not text
                 (<t = 'p && <>t = "\n") (go >l () ([10] . acc))
                 (: sep (? (atom? prev) () (spaced? prev || (word? prev && word? t)) [32] ())
                    (go >l t (chars (spell t) . sep . acc))))))
       (go ts () ()))
   ; the -D lines a TU starts from: the machine's, the OS's, the libc's and the dialect's, then
   ; the command line's. GNU C 8.1, each extension a header reaches carried or refused by name;
   ; __GNUC_STDC_INLINE__: inline is C99's under every -std
   gnudefs '("__GNUC__=8" "__GNUC_MINOR__=1" "__GNUC_PATCHLEVEL__=0" "__GNUC_STDC_INLINE__=1")
   ; bool/true/false bare, as C23; an iso -std keeps them plain names
   (booldefs dia) (dia != 'c && '("bool=_Bool" "true=1" "false=0"))
   (cc-defs {'ds ds 'tgt tgt 'os os 'dia dia 'undef un 'swch sw 'bp bp 'uch uc 'cfb cf 'ssp sp})
    (un ? (stddefs tgt sw + booldefs dia + ds) (chdefs tgt uc + osdefs os + featdefs tgt + atomdefs tgt sw + bpdefs bp + (cf ? ["__CET__=\(cf)"]) + (sspdefs sp) + stddefs tgt sw
                 ; our libc carries its whole surface on every kernel: a source asks it, not the kernel
                 + '("LvMoonlibc=1")
                 + (dia = 'moon && '("__moon__=1"))       ; the dialect's own macro: extensions on
                 + booldefs dia
                 + gnudefs
                 +
                 (elem tgt '(x64 a64) ? ("__SIZEOF_INT128__=16" . ds) ds)))      ; the wide pair (gen's d128 lane), as gcc on both
   ; -fmacro-prefix-map=OLD=NEW: __FILE__ with a leading OLD spelled NEW, the last match winning
   ; (gcc's); laid as a -D over cpp's predefine
   (filedef src mp)
    (: (go l) (? !(two? l) ()
                 (<l @ [o n] (starts? src o ? (n + snip src #o #src) (go >l))))
       f (go mp)
       (f ? ["__FILE__=\"\(string (catmap (c \ (c @ 92 [92 92] 34 [92 34] [c])) (chars f)))\""]))
   ; the shared front end: source -> (1 ast stag sigs ..) | a fatal exit. the -D lines prepend
   ; to the text before the one lex, stamped 1-k..0, so every source line keeps its number
   (cc-parse src (t @ {'is is 'ds ds 'tgt tgt 'os os 'vb vb 'dia dia 'swch sw 'mpm mp 'uch uc 'ssp sp}))
    (: ds9 (cc-defs t + filedef src mp)
       ; `-` is stdin, for every door; cdir answers "" (the cwd). then disk, then vb by key
       r (src = "-" ? [1 (slurp in)]
            (uread src @ q
               (? (two? q) q
                  !vb ()
                  (vb src @ h (string? h && [1 h])))))
       _ (two? r || udie 1 "cc: cannot open \(src)")
       txt (? (dotS? src) (asmcpp src <>r ds9 is vb) (dots? src) (asmwrap (incbins <>r is src)) <>r)
       lx (clexw (deftext ds9 + txt) (1 - #ds9))
       _ (okv? lx || ccdie lx src "cc: lex error in \(src)")
       pp (cpp <>lx (name \ sys? \ incload vb is (cdir src) name sys?) src)
       _ (okv? pp || ccdie pp src "cc: preprocessor error in \(src)")
       ps (cparse-o <>pp tgt dia {'swch sw 'uch (uchar? tgt uc) 'ssp sp})   ; the target sizes pointers/longs at the ABI width; the dialect says what grammar
       (okv? ps || ccdie ps src "cc: parse error in \(src)",
        ps))
   ; a relocatable object: the standard sections + symbols + relocations, plus one section per
   ; other section(NAME) the TU used, in declaration order (its address is the program's to fix).
   ; the wide tuples are named once, here; `[]` is strict, so a changed arity refuses
   ; the marks a -mbranch-protection object carries, clang's bytes: the gnu property note (a
   ; linker ands every input's feature bits) and the aeabi_feature_and_bits build attributes
   (bpsecs bp)
    (!(two? bp) ? ()
       (: b (elem 'bti bp ? 1 0) p (elem 'pac bp ? 1 0)
          [[".note.gnu.property" 7 2 8
             [['raw (le32 4 + le32 16 + le32 5 + o-strbytes "GNU" + [0]
                     + le32 3221225472 + le32 4 + le32 (b | p << 1) + le32 0)]]]   ; aarch64 feature_1_and
           [".ARM.attributes" 1879048195 0 1                                         ; SHT_AARCH64_ATTRIBUTES
             [['raw ([65] + le32 35 + o-strbytes "aeabi_feature_and_bits"
                     + [0 1 0 0 b 1 p 2 0])]]]]))                              ; optional, uleb; bti pac gcs
   ; -fcf-protection's mark, gcc's bytes: x86's feature_1_and, ibt 1 and shstk 2, its data
   ; padded to the class's word
   (cfsecs cf tgt)
    (!cf ? ()
       (: w (tgt = 'x64 ? 8 4)
          [[".note.gnu.property" 7 2 w
             [['raw (le32 4 + le32 (w + 8) + le32 5 + o-strbytes "GNU" + [0]
                     + le32 3221225474 + le32 4 + le32 cf + (w = 8 ? (le32 0)))]]]]))
   ; the stack protector's guard, (mode reg symbol offset): 'global a symbol's word, 'tls x86's
   ; segment off fs or gs, 'sysreg an a64 system register's pointer
   (sspguard f)
    (: tgt (f 'tgt) x86 (elem tgt '(x64 i386))
       m (f 'sspm || (f 'sspr || f 'ssps ? (x86 ? 'tls 'sysreg) 'global))
       r (f 'sspr || (m = 'tls ? (tgt = 'x64 ? "fs" "gs")))
       o (charm? (f 'sspo) ? (f 'sspo) (m = 'tls ? (tgt = 'x64 ? 40 20) 0))
       (? !(elem tgt '(x64 i386 a64)) (udie 2 "cc: -fstack-protector -- no canary lane on \(tgt)")
          (x86 ? (m = 'sysreg) (m = 'tls)) (udie 2 "cc: -mstack-protector-guard=\(m) -- no such guard on \(tgt)")
          (m = 'tls && !(elem r '("fs" "gs"))) (udie 2 "cc: -mstack-protector-guard-reg=\(r) -- x86's guard sits off fs or gs")
          (m = 'sysreg && !(elem r '("sp_el0" "tpidr_el0" "tpidr_el1" "tpidrro_el0")))
           (udie 2 "cc: -mstack-protector-guard-reg=\(r) -- no lane for that system register")
          (m = 'sysreg && !(0 <= o <= 32760 && o % 8 = 0))
           (udie 2 "cc: -mstack-protector-guard-offset=\(o) -- a64's is a word offset under 32768")
          (!x86 && f 'ssps) (udie 2 "cc: -mstack-protector-guard-symbol -- x86 only")
          [m r (f 'ssps || (m = 'global ? "__stack_chk_guard")) o]))
   ; an asm's own labels, local in the symtab as gas lays them: modpost finds an export by its
   ; __export_symbol_ label. gas's numbered (l911.1, a function's fn.asm.3.l911.1) and pool (.L..) labels stay out
   (asmlocs secs)
    (: (digs? s) (0 < #s && all digit? (map (i \ s i) (jot #s)))
       (lnum? sp) (rev (split "." sp) @ p (1 < #p && starts? <>p "l" && digs? (snip <>p 1 #(<>p)) && digs? <p))
       (lab f) (two? f && <f = 'label && !(fn-mark? <>f) ? (show <>f @ sp (lnum? sp || starts? sp ".L" ? () sp)))
       (filter string? (catall (map (s \ map lab (s 3)) secs))))
   ; a64: an undefined weak's address is a literal word, not adrp+add. a pie link (the kernel's)
   ; refuses a page reach of a symbol that may be absent; an abs64 there answers 0
   (wkla tgt wu fs)
    (: wn (map name wu)
       (la? f) (two? f && <f = 'la && (elem (f 2) wu || elem (f 2) wn))
       (tgt != 'a64 || !(two? wu) ? fs (catall (map (f \ (la? f ? [['align 8] ['lia (f 1) (f 2)]] [f])) fs))))
   (cc-objbytes src (t @ {'ni ni 'tgt tgt 'sal sal 'bp bp 'rp rp 'old old 'nofp nofp 'osz osz 'uch uc 'njt njt 'nbi nbi 'falg fa 'nsib ns 'avz av 'cfb cf 'wrapv wv 'pfe pfe 'sspg sg 'xk xk 'npic np}))
    (@ (cc-parse src t)
       [_ ast stag sigs weaks sfns svars sects alias aligns ainl noinl consts rstrs gregs vol anames pfes]
       ; wasm rides gen's rv64 lane and lays no ELF: its object is the gen tuple as text
       (: ob (cgen-obj ast stag sigs weaks
                       [sfns svars sects alias aligns ainl noinl consts rstrs ni gregs vol [sal bp rp old osz nofp (uchar? tgt uc) njt nbi fa ns av (cf && cf & 1) wv pfe sg xk np] pfes] tgt)
          (okv? ob || ccdie ob src "cc: codegen error in \(src)",
           ; -mno-sse and kin: a float register anywhere in the code is the refusal, by the file
           !(nofp && fpuse? (ob 1)) || udie 1 "cc: \(src): floating-point code, and -mno-sse (or its kin) rules it out",
           (@ ob [_ tforms dforms fnames gnames nforms iforms lnames xsecs bforms rforms xfns asecs]
              (: ; the file-scope asm's sections, and the names its .globl exports by where they landed
                 at (two? asecs ? asecs [() () () ()])
                 fns (fnames + filter (s \ !(elem s fnames)) (at 1))
                 gns (gnames + filter (s \ !(elem s gnames)) (at 2))
                 wks (weaks + filter (s \ !(elem s weaks)) (at 3))   ; ..and those its .weak binds weak
                 wu (filter (s \ !(elem s fns || elem s gns)) wks)       ; weak and not laid here
                 tforms (wkla tgt wu tforms)
                 xfns (map ([nm forms al] \ [nm (wkla tgt wu forms) al]) xfns)
                 xs (map ([nm forms ro] \ objsec-named nm forms ro) xsecs
                     + map ([nm forms al] \ objsec-code nm forms al) xfns   ; ..and the fns that named a section
                     + bpsecs bp + cfsecs cf tgt)
                 ; arm32 has no .image lane and no local func symbols (objsecs3 refuses the first)
                 (? (tgt = 'wasm)
                    (? (two? <at) (udie 1 "cc: a file-scope asm has no wasm lane, in \(src)")
                       (two? (filter (k \ anames k != k) (keys anames)))
                        (udie 1 "cc: an asm label that renames has no wasm lane, in \(src)")
                       (show [tforms dforms fnames gnames nforms iforms lnames xsecs bforms rforms xfns weaks]))
                    (elf32? tgt)
                    (objsecs32n tgt (objsec-merge (objsecs3 tgt tforms dforms nforms iforms bforms rforms + xs) <at)
                                fns gns wks anames)
                    (objsecsn tgt (objsec-merge (objsecs4 tforms dforms nforms iforms bforms rforms + xs) <at)
                              fns gns wks (lnames + filter (s \ !(elem s fns || elem s gns || elem s lnames)) (asmlocs <at)) anames)))
              (udie 1 "cc: the code generator answered an unexpected shape for \(src)"))))
       (udie 1 "cc: the parser answered an unexpected shape for \(src)"))
   ; -E: the source preprocessed, to -o or stdout; a refusal exits as a compile's does, which is
   ; how a configure script tells a header that is there from one that is not
   (cc-pre src dst (t @ {'is is 'vb vb 'xasm xasm 'mpm mp}))
    (: ds9 ((xasm ? ("__ASSEMBLER__=1" . cc-defs t) (cc-defs t)) + filedef src mp)
       r (src = "-" ? [1 (slurp in)]
            (uread src @ q (? (two? q) q !vb () (vb src @ h (string? h && [1 h])))))
       _ (two? r || udie 1 "cc: cannot open \(src)")
       lx (xasm ? (clexm (deftext ds9 + <>r) (1 - #ds9) 2 1) (clexw (deftext ds9 + <>r) (1 - #ds9)))
       _ (okv? lx || ccdie lx src "cc: lex error in \(src)")
       _ (pin cppdeps 'l ())
       pp (cpp-text <>lx (incload vb is (cdir src)) src)
       _ (okv? pp || ccdie pp src "cc: preprocessor error in \(src)")
       _ (t 'md && cc-deps src dst t)                ; -E -MD writes the dependencies as a compile does
       (dst ? (open dst "w" @ q (!(hot? q) ? (udie 1 "cc: cannot write \(dst)"), say q <>pp, close q))
              (puts <>pp, flush out)))
   ; a wasm object is text: write-bytes walks a byte list, and a string lands as an empty file
   (cc-obj src dst (t @ {'tgt tgt}))
    (pin cppdeps 'l (),
     cc-objbytes src t @ b
       (tgt != 'wasm ? (write-bytes dst b)
        (open dst "w" @ q
           (!(hot? q) ? (udie 1 "cc: cannot write \(dst)"),
            say q b,
            close q))),
     t 'md && cc-deps src dst t)
   ; the rule -MD asks for: the object, then its source and every file the #includes opened,
   ; in the order they opened, each once; -MMD leaves our own headers out. -MF names the file,
   ; else the object's with .d; -MT the target, else the object
   (cc-deps src dst t)
    (: ours (map (r \ "\(r)include/") (mroots ()))
       (sys? p) (any (d \ starts? p d) ours || (t 'vb && starts? p "include/"))
       hs (filter (p \ !(t 'mmd && sys? p)) (uniq (rev (peep cppdeps 'l ()))))
       df (t 'mf || (dst @ (b + ".o") "\(b).d" "\(dst).d"))
       txt ("\(t 'mt || dst): \(join " \\\n  " (src . hs))\n"
            + (t 'mp ? (join "" (map (h \ "\n\(h):\n") hs)) ""))
       (open df "w" @ q
          (!(hot? q) ? (udie 1 "cc: cannot write \(df)"),
           say q txt,
           close q)))
   ; the link path: every input lands as object bytes, crt0 first (its text is the entry), and
   ; ldlink binds the static exe. __love_start is weak here (calls main); moonlibc overrides it.
   ; x64's entry serves every kernel: linux zeroes rdi, freebsd hands the vector base there with
   ; a pad word maybe below argc, so zero says linux and freebsd pushes once to restore parity.
   ; netbsd rides the linux side, where 60 is umask: it returns, and 1 exits
   crt0 '((cmp r6 0)
          (br ne c0-fb)
          (mov r6 sp)
          (li r5 0)
          (call __love_start)
          (mov r3 r0)
          (mov r6 r3) (li r0 60) (sys)
          (mov r6 r3) (li r0 1) (sys)
          (label c0-fb)
          (push r6)
          (li r5 0)
          (call __love_start)
          (mov r6 r0) (li r0 1) (sys)
          (label __love_start)
          (push r6)
          (lea r5 r6 8)
          (ld r6 r6 0)
          (call main)
          (pop r6)
          (ret))
   ; the macos entry: one kernel, so the second word says which. dyld aligns the stack on 8
   ; alone, so it is aligned here, as crt1.o does
   crt0-macos '((mov r6 sp)
                (and sp sp -16)
                (li r5 4)
                (call __love_start)
                (mov r6 r0) (li r0 33554433) (sys)
                (label __love_start)
                (push r6)
                (lea r5 r6 8)
                (ld r6 r6 0)
                (call main)
                (pop r6)
                (ret))
   ; dyld's exe enters by lc_main as main(argc, argv, envp, apple) on an aligned stack;
   ; argv still points into the kernel's block, so argc is the word below it
   crt0-macmain '((lea r6 r5 -8)
                  (and sp sp -16)
                  (li r5 4)
                  (call __love_start)
                  (mov r6 r0) (li r0 33554433) (sys)
                  (label __love_start)
                  (push r6)
                  (lea r5 r6 8)
                  (ld r6 r6 0)
                  (call main)
                  (pop r6)
                  (ret))
   ; the i386 entry: argc at [esp], the vector's address and what ebx says of the kernel handed to
   ; __love_start as cdecl arguments with esp 16-aligned at the call, then exit_group 252 (exit 1,
   ; a BSD's, if it returns)
   crt0-i386 '((mov r0 sp)
               (and sp sp -16)
               (sub sp sp 8)
               (li r1 1)                ; linux zeroes ebx at entry: osv 1
               (cmp r3 0)
               (br eq c0i-lx)
               (li r1 0)                ; both BSDs hand ps_strings there: os.c asks which
               (label c0i-lx)
               (push r1)
               (push r0)
               (call __love_start)
               (mov r3 r0) (li r0 252) (sys)
               (li r0 1) (sys)
               (label __love_start)
               (push r4) (mov r4 sp)
               (ld r1 r4 8)
               (ld r0 r1 0)
               (lea r2 r1 4)
               (push r2) (push r0)
               (call main)
               (mov sp r4) (pop r4)
               (ret))
   ; the arm entry: linux and freebsd zero r0, freebsd's 32-bit lane on arm64 hands the vector
   ; there, netbsd ps_strings -- zero is asked later (os.c), sp is freebsd, else netbsd. two
   ; pushes keep the alignment
   crt0-arm '((mov r2 sp)
              (cmp r0 0)
              (br eq c0r-ask)
              (cmp r0 r2)
              (br eq c0r-fb)
              (mov r0 r2)
              (li r1 3)
              (call __love_start)
              (mov r12 r0)
              (li r0 1) (raw (255 223))
              (label c0r-fb)
              (mov r0 r2)
              (li r1 2)
              (call __love_start)
              (li r7 1) (sys)
              (label c0r-ask)
              (mov r0 r2)
              (li r1 0)
              (call __love_start)
              (li r7 248) (sys)
              (li r7 1) (sys)
              (label __love_start)
              (push lr) (push r4)
              (lea r1 r0 4)
              (ld r0 r0 0)
              (call main)
              (pop r4) (pop lr)
              (ret))
   ; the a64 entry: linux zeroes x0 (sp is the vector), freebsd hands the vector base in x0.
   ; a64 cannot probe blind (netbsd's number is the svc immediate, freebsd sigills any but zero),
   ; so freebsd answers 2 and linux/netbsd are asked, sharing one exit (x8 93, svc 1).
   ; mov from sp must be lea: orr reads xzr at 31.
   crt0-a64 '((cmp r0 0)
              (br ne c0a-fb)
              (lea r0 sp 0)
              (li r1 0)
              (call __love_start)
              (li r8 93) (svcn 1)
              (label c0a-fb)
              (li r1 2)
              (call __love_start)
              (li r8 1) (sys)
              (label __love_start)
              (push lr)
              (lea r1 r0 8)
              (ld r0 r0 0)
              (call main)
              (pop lr)
              (ret))
   ; the riscv entry: a non-zero a0 is freebsd's vector, handed down as 2; linux and netbsd
   ; are asked. linux exits by 94 in a7, netbsd 1 in t6 (holo's scratch, set raw), freebsd 1 in t0
   crt0-rv '((cmp r0 0)
             (br ne c0r-fb)
             (lea r0 sp 0)
             (li r1 0)
             (call __love_start)
             (li r7 94)
             (raw (147 15 16 0))      ; li t6, 1
             (sys)
             (label c0r-fb)
             (li r1 2)
             (call __love_start)
             (li r8 1) (sys)
             (label __love_start)
             (push lr)
             (lea r1 r0 8)
             (ld r0 r0 0)
             (call main)
             (pop lr)
             (ret))
   ; the driver's libc: a link still owing strong symbols pulls moonlibc + lm + sys, compiled
   ; from the sources beside us, member by need. -nostdlib leaves it off. noms still owed are
   ; said at once (a misspelling, an undefined function, a goto label gen spells main.<lbl>)
   (qfew ns) (mfew (map (n \ "'\(n)'") ns))       ; a taste of the bag, each nom quoted
   (undie us) (udie 1 "cc: undefined reference to \(qfew us)")
   ; every .a on the line, read here so an unopenable one says `cc: cannot open x`
   (arload srcs paths tgt)
    (!(two? paths) ? ()
       (ldarch srcs
               (map (p \ (uread p @ r
                              (two? r || udie 1 "cc: cannot open \(p)",
                               ld-ar? <>r || udie 1 "cc: not an archive: \(p)",
                               [p <>r])))
                    paths)
               tgt))
   ; -- the runtime cache -- a member must be compiled to know what it defines, so the compiled
   ; runtime rides out/cache/moon/<sha256>.a, one archive per (compiler, target, os), its ranlib
   ; index answering the pull. the carried archives answer a stock tree; this, an edited one.
   ; the compiler's identity is the baked image's bytes, never the .l sources (a link before the
   ; image catches up would wear old codegen). no identity, no cache
   (sdir? st) (two? st && st 2 & 61440 = 16384)
   ; the cache lives in the checkout's own out/, never created here
   (mcdir _)
    ("out/cache/moon/" @ d
       (sdir? (stat "out") && map (s \ mkdir s 493) '("out/cache" "out/cache/moon"),
        sdir? (stat d) && d))
   ; the input-name predicates, ahead of every reader of them.
   (dota? p) (#p @ n (2 < n && p (n - 2) = 46 && p (n - 1) = 97))
   (dotc? p) (#p @ n (2 < n && p (n - 2) = 46 && p (n - 1) = 99))
   (dots? p) (#p @ n (2 < n && p (n - 2) = 46 && p (n - 1) = 115))   ; assembly
   (dotS? p) (#p @ n (2 < n && p (n - 2) = 46 && p (n - 1) = 83))    ; ..that the preprocessor reads first
   (dotsrc? p) (dotc? p || dots? p || dotS? p)                         ; a source this compiler lays an object from
   (doto? p) (#p @ n (2 < n && p (n - 2) = 46 && p (n - 1) = 111))
   (dotim? p) (p @ ((s && 0 < #s) + ".image") 1 0)
   (dotcid? p) (p @ ((s && 0 < #s) + ".cid") 1 0)
   ; the images: beside the love in a build tree, lib/love/ in a nest. not point-free: the
   ; lambda reads `d`
   (mcims d) (map (f \ [f (mccid (d + f))]) (sort (filter dotim? (readdir d))))
   ; a directory's whole text, names and bytes, sorted and recursive (the headers are input too)
   (mctree d)
    (foldl (a \ f \ (: p (d + f)
                       st (stat p)
                       (? !(two? st) a
                          (sdir? st) "\(a)\(f)/\n\(mctree "\(p)/")"
                          (uread p @ r "\(a)\(f)\n\(two? r ? <>r "")\n"))))
           "" (sort (readdir d)))
   ; the same walk with stats for bytes: it moves whenever an edit does, enough for a key
   (mcshape d)
    (foldl (a \ f \ (: p (d + f)
                       st (stat p)
                       (? !(two? st) a
                          (sdir? st) "\(a)\(f)/\n\(mcshape "\(p)/")"
                          "\(a)\(f)\n\(st)\n")))
           "" (sort (readdir d)))
   ; the toolchain dirs, as bytes and as shape
   (mcsrctext home) (mctree "\(home)include/" + mctree "\(home)lib/")
   (mcsrcshape home) (mcshape "\(home)include/" + mcshape "\(home)lib/")
   ; a digest memoized under a shape: `mk` is the real read, tag parts the memos
   (mcmemo tag shape mk)
    (: d (mcdir ())
       k (string? d && sha256 "\(tag)\n\(shape)")
       hit (string? k && mcget d "\(k).cid" "cid1 ")
       (two? hit && utime "\(d)\(k).cid" (clock ()),        ; the sweep orders by use
        two? hit ? (snip <>hit 5 69)
          (mk () @ h
             (string? k && mcput d "\(k).cid" "cid1 \(h)\n",
              h))))
   (mcsrcid home)
    (mcmemo "moon-src 1" (mcsrcshape home) (_ \ sha256 (mcsrctext home)))
   ; the exe's path rides beside its content (two worktrees share cwd-relative include paths).
   ; the image is main.c's `love-image` pin, read as data (mooncc lives baked: a bare ref folds
   ; in the bake's value); unpinned, every *.image beside the binary. "<baked>" is the binary's own
   (mcid home)
    (: x (selfpath 0)
       d (string? x && cdir x)
       w (elem 'love-image (names ()) && [1 (ev 'love-image)])
       ims (two? w ? (<>w @ im
                        (? !(string? im) ()
                           (im = "<baked>") ["<baked>"]
                           [[im (mccid im)]]))
                     (string? d && mcims d + mcims "\(d)../lib/love/"))
       src (two? ims ? (mcsrcid home) "")
       ; the ablation knob compiles a different runtime; unset stays out of the key
       ab (getenv "MOON_ABLATE" @ s (string? s && 0 < #s ? "\nabl \(s)" ""))
       (two? ims ? (sha256 "moon-rt 2\n\(x)\n\(mccid x)\n\(ims)\n\(src)\(ab)")))
   ; an entry, read back and checked for its magic -> (1 bytes) | ()
   (mcget d f mag)
    (: r (uread (d + f))
       s (two? r ? <>r "")
       (#mag <= #s && snip s 0 #mag = mag ? [1 s] ()))
   ; write beside, then rename onto: racing links land the same bytes and none reads a torn one.
   ; failures are silent: a cache is never owed a link's correctness
   (mcput d f bs)
    (: p (d + f)
       t "\(p).\(getpid ())"
       q (open t "w")
       (hot? q ? (say q bs, close q),
        hot? q && !(rename t p) ? () (unlink t),       ; anything but (): the rename lost
        ()))
   ; a file's identity is its bytes, memoized under its stat; with no cache the stat stands in
   (mccid p)
    (: st (stat p)
       d (mcdir ())
       k (string? d && two? st && sha256 "moon-cid 1\n\(p)\n\(st)")
       hit (string? k && mcget d "\(k).cid" "cid1 ")
       (two? hit && utime "\(d)\(k).cid" (clock ()),        ; the sweep orders by use
        two? hit ? (snip <>hit 5 69)
          (uread p @ r
             (!(two? r) ? (show st)
                (sha256 <>r @ h
                   (string? k && mcput d "\(k).cid" "cid1 \(h)\n",
                    h))))))
   ; bounded by count, not age (rebuilds mint generations fast), swept on every link, ordered
   ; by use -- the touch on a hit
   (mcsweep d)
    (: mckeep 32                                       ; ~400K each
       ; one generation per (worktree, lane, target), hence the room. archives and .cid memos
       ; are each bounded; anything else goes
       _ (foldl (a \ f \ dota? f || dotcid? f ? a (unlink (d + f), a)) 0 (readdir d))
       (ages pk) (foldl (a \ f \ stat (d + f) @ st
                                   (pk f && two? st ? (a + [[(st 1) f]]) a))
                        () (readdir d))
       (go l k most) (!(two? l) ? 0
                       (<l @ e
                          (most <= k && unlink (d + <>e),
                           go >l (k + 1) most)))
       (old pk most) (go (sortby (a \ b \ <b <= <a) (ages pk)) 0 most)
       (old dota? mckeep,
        old dotcid? mckeep))
   ; the pure runtime identity: names and bytes of the headers + lib sources, nothing of the
   ; machine. mkrt.l stamps it beside the carried archives; it travels, so the formula is fixed
   (rtcid home)
    (mcmemo "moon-rtcid 1" (mcsrcshape home)
     (_ \ sha256 "moon-rtc 1\n\(mcsrctext home)"))
   ; the carried runtime: each ISA's compiled archive beside the source blob (runtime-gz), served
   ; only when the home hashes to the stamped id. cut under -os linux: impl.h parts the kernels
   ; at run time. i386 and arm have no translation tables, so their BSDs owe a compile (#error)
   (rtcarried home tgt os)
    (? (os = 'none) ()                                     ; freestanding owes no runtime
       (elem tgt '(i386 arm) && elem os '(freebsd netbsd)) ()
       (elem tgt '(x64 a64 rv64 i386) && string tgt @ nm
          (!(string? nm) ? ()
             (runtime-gz nm @ z
                (!(string? z) ? ()
                   (: ok (string? home ? (rtcid home = runtime-gz "id") 1)
                      ; inflate does not validate, so the archive magic is the check
                      a (ok && inflate z 0)
                      (string? a && 8 <= #a && snip a 0 8 = "!<arch>\n" ? a ())))))))
   ; the carried archive first; the cache key is cut only on the lane it refused
   (rtarch home tgt os vb)
    (rtcarried home tgt os @ cr
       (string? cr ? cr
          ; the key carries the OS: two kernels' archives can share a target name
          (: id (string? home && mcid home)
             cd (string? id && mcdir ())        ; no identity, no cache, no directory made
             k (string? cd && string? id && sha256 "\(id)\n\(tgt)\n\(os)")
             hit (string? k && mcget cd "\(k).a" "!<arch>\n")
             _ (two? hit && utime "\(cd)\(k).a" (clock ()))        ; the sweep orders by use
             bs (two? hit ? <>hit
                   (arbytes (rtmems home tgt os vb) @ b
                      (string? k && mcput cd "\(k).a" b,
                       b)))
             (string? cd && mcsweep cd,
              bs))))
   ; the roster: [name source includes] per member, an empty source naming one laid, not
   ; compiled. moonlibc's .c files and one level down, flattened with _ (an archive resolves by
   ; name alone; time.c and sys/time.c share a basename)
   (rtplan home tgt os vb)
    (: disk (string? home)                ; () home = the blob lane: paths are vb keys
       ndir (disk ? "\(home)lib/moonlibc/" "lib/moonlibc/")
       inc  (disk ? "\(home)include/" "include/")
       (dotobj n) (dotc? n ? "\(snip n 0 (#n - 2)).o" n)
       (swap47 s) (: n #s c (cask n)
                     _ (pour c 0 s 0 n)
                     (each ^n (i \ peep c i 0 = 47 && pin c i 95), string c))
       (nlmems d)
        (disk ?
           (foldl (a \ e \ d + e @ p
                             (? (dotc? e) (a + [[(dotobj e) p]])
                                (sdir? (stat p))
                                 (a + foldl (a2 \ f \ a2 + [[(dotobj "\(e)_\(f)") "\(p)/\(f)"]])
                                            () (sort (filter dotc? (readdir p))))
                                a))
                  () (sort (readdir d)))
           ; the carried source: the same pairs off vb's keys
           (foldl (a \ k \ snip k #d #k @ sub
                             (dotc? sub ? (a + [[(dotobj (swap47 sub)) k]]) a))
                  () (sort (filter (k \ starts? k d) (keys vb)))))
       ; i386 and arm32 have no 64-bit divide: gen calls rt.c's __udivdi3 and kin
       (map ((a b) \ [a b [inc]]) (nlmems ndir + (elem tgt '(i386 arm) ? [["rt.o" (disk ? "\(home)lib/rt.c" "lib/rt.c")]] ()))
        + (elem tgt '(x64 a64 rv64 i386 arm) ? [["mksys.o" "" ()]] ())))
   ; the members compile under the link's os (impl.h's table opens on it)
   (rtflags tgt os vb is) (pins (fseed tgt 'moon) 'os os 'is is 'vb vb)
   ; one roster member, compiled -> [name bytes]
   (rtmem1 tgt os vb e)
    (: nm (e 0) src (e 1) is (e 2)
       [nm (!#src ? (string (mksys-bytes tgt))
                    (string (cc-objbytes src (rtflags tgt os vb is))))])
   ; every member compiled, ready to index -- our own sources reaching only our own headers.
   (rtmems home tgt os vb) (map (rtmem1 tgt os vb) (rtplan home tgt os vb))
   (rtpull srcs tgt os nostd vb imp?)
    (: mach (peep elf-machines tgt 0)
       lg (ldledger srcs mach) dt <lg owed <>lg
       ; -nostdlib: no runtime, so an owed nom is undefined
       _ (nostd && two? owed && undie owed)
       home (two? owed && !nostd && mhome ())
       ; owed and no runtime in reach: the certain fact first
       (two? owed && !(string? home) && !vb
        && udie 1 "cc: undefined reference to \(qfew owed); no runtime in reach to supply it either (looked in \(mfew (mroots ()))) -- check the spelling, then the nest",
        nostd || !(string? home) && !vb ? ()
          (arpull "moon-runtime" (rtarch home tgt os vb) dt owed mach @ pr
             ; the owe left at the end is exactly what nothing defines, said whole
             (two? <>pr && !imp? && undie <>pr,
              <pr))))
   ; -- the wasm link -- objects are gen tuples as text (or a container, wasm-tu-read), the
   ; runtime the same members for wasm, by need; __love_sys, the page loader's, is the one import.
   ; crt0 lays a stack in data for __love_start
   (wasm-tu text) (wasm-tu-read text @ r (two? r ? r (udie 1 "cc: not a wasm object")))
   crt0-wasm '(((label _start) (la r0 __love_osstack) (call __love_start) (mov r1 r0) (li r0 231) (call __love_sys) (ret)
                (label __love_start) (push lr) (lea r1 r0 8) (ld r0 r0 0) (call main) (pop lr) (ret))
               ((label __love_osstack) (raw (1 0 0 0 0 0 0 0 (fix 8 abs64 __love_argv0 0) 0 0 0 0 0 0 0 0
                                           0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))
                (label __love_argv0) (raw (97 46 111 117 116 0)))
               ("_start" "__love_start") ("__love_osstack") () () () () () () () ("__love_start"))
   ; the runtime for wasm: rtmems' members under the wasm target (text objects), cached
   ; whole as one text under the same key law as the ELF archives -> ((name text) ..)
   (wasm-rt home os vb)
    (: id (string? home && mcid home)
       cd (string? id && mcdir ())
       k (string? cd && string? id && sha256 "\(id)\nwasm\n\(os)")
       hit (string? k && mcget cd "\(k).wrt" "wrt1\n")
       _ (two? hit && utime "\(cd)\(k).wrt" (clock ()))
       txt (two? hit ? (snip <>hit 5 #<>hit)
              (show (rtmems home 'wasm os vb) @ s
                 (string? k && mcput cd "\(k).wrt" "wrt1\n\(s)",
                  s)))
       <(sound txt))
   ; the inputs stay TEXT until the link reads them, and what is held of each here is its
   ; ledger alone: the link's live set is one copy of the program, not three
   (cc-wasm ins dst (t @ {'tgt tgt 'os os 'nostd nostd 'vb vb}))
    (: os9 (!os ? 'linux os)                          ; the loader speaks linux's numbers
       t9 (pin t 'os os9)
       texts (map (f \ (? (dotsrc? f) (cc-objbytes f t9)
                          (doto? f) (uread f @ r (two? r ? <>r (udie 1 "cc: cannot open \(f)")))
                          (udie 2 "cc: not a .c/.o input for wasm: \(f)")))
                  ins)
       tsyms (map (x \ wasm-tu-syms (wasm-tu x)) texts)          ; (defs . refs) each
       ; the runtime by need: a member whose defs meet an owed name joins, and its own
       ; wants join the owe, until nothing more is owed or nothing more answers
       ledger (ss \ (: defs {} refs {}
                       (map (s \ (map (d \ pin defs d 1) <s,
                                   map (r \ pin refs r 1) >s))
                            ss,
                        filter (r \ !(defs r)) (keys refs))))
       ; crt0 rides when an input defines main; a module with a face of its own needs no entry
       entry? (foldl (a \ s \ a || elem 'main <s) 0 tsyms)      ; a ledger names noms
       base (entry? ? (crt0-wasm . texts) texts)
       bsyms (entry? ? (wasm-tu-syms crt0-wasm . tsyms) tsyms)
       owed0 (ledger bsyms)
       home (two? owed0 && !nostd && mhome ())
       rt (two? owed0 && !nostd && wasm-rt home os9 vb)
       mems (map (m \ [(m 0) (m 1) (wasm-tu-syms (wasm-tu (m 1)))]) rt)   ; name, text, ledger
       (pull set owed)
        (: hit (filter (m \ foldl (a \ d \ a || elem d owed) 0 <(m 2)) mems)
           new (filter (m \ !(elem m set)) hit)
           (!(two? new) ? set
              (set + new @ set2 (pull set2 (ledger (bsyms + map (m \ m 2) set2))))))
       picked (pull () owed0)
       all (base + map (m \ m 1) picked)
       m (wasm-link all {'imports '("__love_sys") 'exports 'all})
       q (open dst "w")
       (!(hot? q) ? (udie 1 "cc: cannot write \(dst)"),
        say q (wasm-emit m),
        close q,
        0))
   (cc-link ins dst t) (t 'tgt @ 'wasm (cc-wasm ins dst t) (cc-link-elf ins dst t))
   (cc-link-elf ins dst (t @ {'is is 'ds ds 'tgt tgt 'os os 'pie pie 'org org 'dorg dorg
                          'nostd nostd 'vb vb 'ni ni 'rdme rdme 'relo relo 'so so 'libs libs 'fws fws 'static static}))
    ; a BSD links where mksys lays the translation tail (impl.h's LvOsTranslate):
    ; x64, a64 and rv64. elsewhere os.c has no tables for it, so it is refused here
    (: _ (elem os '(freebsd netbsd) && !(elem tgt '(x64 a64 rv64))
          && udie 1 "cc: -os \(os) links on x64, a64 and rv64 only")
       ; a mach-o: static, fixed-base, its entry knowing the kernel
       mac? (os = 'macos)
       ; ..dyld's by default: libSystem, -framework and -l load, and what the runtime lacks is
       ; imported. -static keeps xnu's calls alone
       dyld? (mac? && !static)
       _ (mac? && static && (two? fws || two? libs) && udie 2 "cc: -static on macos loads no framework or library")
       dylibs (mac? ? (map (f \ "/System/Library/Frameworks/\(f).framework/Versions/A/\(f)") fws
                       + map (l \ "/usr/lib/lib\(l).dylib") (filter (l \ !(elem l ["c" "m" "dl" "pthread" "System"])) libs)) ())
       _ (mac? && tgt != 'x64 && udie 1 "cc: -os macos links on x64 only")
       ; a mach-o is an executable at a fixed base
       _ (mac? && (so || charm? org) && udie 2 "cc: -os macos lays an executable: no -shared or -Ttext")
       ars (filter dota? ins)
       srcs (map (f \ (? (dotsrc? f) [f (string (cc-objbytes f t))]
                         (doto? f) (uread f @ r
                                      (two? r ? [f <>r]
                                                (udie 1 "cc: cannot open \(f)")))
                         (udie 2 "cc: not a .c/.s/.o/.a input: \(f)")))
                 (filter (f \ !(dota? f)) ins))
       ; a thumb link is a board's: the image lays at the address the core boots from, and
       ; no crt0 rides first: the first text byte is the vector table. -t arm is linux's,
       ; hosted as i386 is
       arm? (arm32? tgt && tgt != 'arm)
       _ (arm? && pie && udie 2 "cc: -pie needs an MMU; an arm32 link is bare metal")
       _ (mac? && pie && !dyld? && udie 2 "cc: -pie on macos is dyld's: -static lays a fixed base")
       _ (so && (pie || arm?) && udie 2 "cc: -shared lays a shared object alone, on a 64-bit target")
       _ (arm? && !(charm? org) && udie 2 "cc: an arm32 link needs -Ttext <addr>")
       ; the two --emit-relocs cannot answer: 64-bit has its own table under -pie, and thumb2's
       ; `la` splits an address across MOVW/MOVT
       _ (relo && !arm? && udie 2 "cc: --emit-relocs is the arm32 lane's; a 64-bit link carries its own table under -pie")
       _ (relo && tgt = 'thumb2 && udie 2 "cc: --emit-relocs cannot answer -t thumb2: its `la` splits an address across MOVW/MOVT, which no loader can slide -- -t thumb2sp pools it")
       ; the board's map: -Ttext alone is one region (code and data share a memory); -Tdata
       ; splits it as an xip mcu wants -- .data stored after the code, copied off __data_load__
       runs (charm? dorg ? [['at org 'text 'rodata 'nifs]
                            ['copy dorg 'data 'bss]]
                           [['at org 'text 'rodata 'data 'nifs 'bss]])
       c9 (mac? ? (dyld? ? crt0-macmain crt0-macos) (tgt @ 'a64 crt0-a64 'rv64 crt0-rv ('i386 || 'i386m16) crt0-i386 'arm crt0-arm crt0))   ; x64's serves every kernel
       all (arm? || so ? srcs
                   (["crt0" (string (objelf tgt c9 () '("__love_start") () '("__love_start") () () () () ()))] . srcs))
       ; the archives first, then whatever the runtime still owes: a library the
       ; line named is what the link meant, and the implicit one is the fallback.
       lib (all + arload all ars tgt)
       ; a shared object pulls no runtime: what it owes it imports, from the -l libraries
       set (so ? lib (lib + rtpull lib tgt os nostd vb dyld?))
       prod "love \(<(usplit 43 love-version))"
       ps (? arm? (ldbare32 tgt runs set () relo)
             mac? (macholink tgt set dyld? dylibs pie (last (usplit 47 dst)))
             so (ldshared tgt (last (usplit 47 dst)) (map (l \ "lib\(l).so") libs) set prod)
             (ldlink tgt pie org set prod rdme))
       ; the ei_osabi brand is ldlink's, so kore's `ld` and this driver agree
       nw (ld-write dst ps)
       (nom? nw && udie 1 "cc: cannot write \(dst) -- \(nw)",
        chmod dst 493))
   usage "usage: mooncc [-c] [-pie] [-shared] [--emit-relocs] [-x c] [-t x64|a64|rv64|arm] [-os linux|none|freebsd|netbsd|macos] [-Ttext addr] [-Tdata addr] [-I dir] [-D name[=val]] [-U name] [-lname] [-freadme=F] [-o out] in.c|in.o|lib.a|- .."
   ; a flag's numeric argument: 0x.. hex or decimal (-Ttext 0x80000000)
   (tonum s)
    (: n #s
       hex (2 < n && s 0 = 48 && (s 1 = 120 || s 1 = 88))
       (go i acc b) (n <= i ? acc
                       (: c (s i)
                          d (? (48 <= c <= 57) (c - 48)
                               (97 <= c <= 102) (c - 87)
                               (65 <= c <= 70) (c - 55)
                               (udie 2 usage))
                          (d < b || udie 2 usage,
                           go (i + 1) (acc * b + d) b)))
       (hex ? (go 2 0 16) (go 0 0 10)))
   ; -pie links an et_dyn static-pie that slides its abs64 pointers at startup; the default is
   ; a fixed-base et_exec
   (glu? a ch) (2 < #a && a 0 = 45 && a 1 = ch)
   ; the cc tolerance: advisory families (-W, -O, -g, -pipe) ride through so `CC=mooncc`
   ; drives a gcc recipe; an -f or -m is honoured or refuses by name (fok?), and -Wl,/-Wa,/-Wp,
   ; carry real arguments and refuse. -L: we search no library
   ; path. -l/-L glued only, so a bare one refuses rather than eat the next word
   ; -- the dialects --
   ; -std= is loud: reading one dialect as another is worse than refusing. `moon`, the default, is
   ; C plus extensions C rejects outright (a strict superset); `c` is strict C (C11; the iso names
   ; are one dialect to codegen). no `holyc` row: real HolyC would fail on line 1
   stds {"moon" 'moon
         "c" 'c "c89" 'c "c90" 'c "c99" 'c "c11" 'c "c17" 'c "c18" 'c "c23" 'c23
         "gnu89" 'c "gnu90" 'c "gnu99" 'c "gnu11" 'c "gnu17" 'c "gnu18" 'c "gnu23" 'c23}
   (stdof w) (stds w)                            ; a tablet indexes itself; () is the miss
   ; sorted: `keys` answers hash order
   (stdnames _) (ujoin (sort (keys stds)))
   ; a pre-pass: -std= interacts with nothing else on the line
   (std-take as)                                   ; -> (dialect args-without-std)
    (: (go l dia acc)
        (!(two? l) ? [dia (rev acc)]
           (<l @ a
              (a @ ("-std=" + w)
                 (: d (stdof w)
                    (d || udie 2 "cc: unknown -std=\(w) -- mooncc reads: \(stdnames ())",
                     go >l d acc))
                 (go >l dia (a . acc)))))
       (go as 'moon ()))          ; unsaid means moon: our C, extensions and all
   ; `none` is gcc's word for "read the suffix again", which for us is the default.
   (xlang? w) (w = "c" || w = "none")
   (xdie w) "cc: -x \(w) -- mooncc reads: c none assembler-with-cpp"
   ; a float register named anywhere in a function's forms (the xmm file, f0..f15)
   (fpuse? l) (? (two? l) (any fpuse? l)
                 (name? l) (show l @ s (#s > 1 && s 0 = 102 && 48 <= s 1 && s 1 <= 57))
                 0)
   (tol? a) (a = "-pipe" || a = "-static" ||
             starts? a "-g" || starts? a "-O" ||
             glu? a 108 || glu? a 76 ||
             starts? a "-W" &&
             !(starts? a "-Wl," || starts? a "-Wa," || starts? a "-Wp,"))
   ; the -nostdlib family: no runtime, so an owed symbol is an undefined reference
   ; the -f flags taken as they stand, the code already being what each asks (no unwind table,
   ; canary or ident laid, pc-relative where fpic? allows), and the hints that change nothing seen
   fsound '("-fno-strict-aliasing" "-fstrict-aliasing" "-fno-delete-null-pointer-checks" "-fdelete-null-pointer-checks" "-fno-common"
            "-fno-pie" "-fno-PIE" "-fno-pic" "-fno-PIC" "-fomit-frame-pointer" "-fno-plt"
            "-fno-asynchronous-unwind-tables" "-fno-unwind-tables" "-fno-exceptions" "-fno-stack-check"
            "-fno-stack-clash-protection" "-fno-addrsig" "-fno-ident"
            "-fno-dwarf2-cfi-asm" "-fno-semantic-interposition" "-fintegrated-as" "-fno-integrated-as"
            "-fvisibility=default" "-fstrict-flex-arrays" "-fms-extensions")
   fhint '("-ffunction-sections" "-fno-function-sections" "-fdata-sections" "-fno-data-sections"
           "-fconserve-stack" "-fno-inline-functions-called-once" "-fno-partial-inlining"
           "-fno-tree-vectorize" "-fno-unroll-loops" "-fno-reorder-blocks" "-fno-gcse"
           "-fno-var-tracking" "-fno-var-tracking-assignments" "-fcolor-diagnostics"
           "-fno-color-diagnostics" "-fno-caret-diagnostics" "-fno-diagnostics-show-caret")
   (fok? a) (elem a fsound || elem a fhint || starts? a "-fstrict-flex-arrays=" ||
             starts? a "-falign-loops" || starts? a "-falign-jumps" || starts? a "-falign-labels" ||
             starts? a "-fno-align-loops" || starts? a "-fno-align-jumps" || starts? a "-fno-align-labels" ||
             starts? a "-fdiagnostics-" || starts? a "-fmessage-length=" || starts? a "-fdebug-prefix-map=")
   ; the -m flags taken as they stand: x64 never stores below sp, and a tuning is a hint
   (mok? a) (a = "-mno-red-zone" || a = "-mred-zone" || starts? a "-mtune=")
   (nostd? a) (a = "-nostdlib" || a = "-nostartfiles" ||
               a = "-nodefaultlibs" || a = "-ffreestanding")
   ; -mbranch-protection's words: clang's leaf, b-key, pc and standard (gcs) have no lane here
   bps {"none" 'none "bti" '(bti) "pac-ret" '(pac) "pac-ret+bti" '(bti pac) "bti+pac-ret" '(bti pac)}
   (bpof w) (peep bps w () @ v
              (? (v = 'none) () v v
                 (udie 2 "cc: -mbranch-protection=\(w) -- mooncc lays: none bti pac-ret pac-ret+bti")))
   (dirn d) (#d @ n (? !n d (d (n - 1) = 47) d "\(d)/"))
   (obase p) (pbase p @ b "\(snip b 0 (#b - 1))o")   ; dir/x.c -> x.o (in the cwd, gcc-shaped)
   ; the flags are one tablet, each a pin at its own arm; is ds ins libs fws collect reversed
   ; and are righted at the end, every other key last-one-wins
   (fpush t k v) (pin t k (v . t k))
   (xkon t k) (elem k (t 'xk) ? t (fpush t 'xk k))
   ; every key seeded: a map pattern matches on presence, so a key pinned only with its flag
   ; would fail the consumers' destructure exactly when the flag is absent
   (fseed tgt dia) {'c () 'is () 'ds () 'o () 'ins () 'tgt tgt 'os () 'pie () 'org () 'dorg ()
                    'nostd () 'vb () 'ni () 'rdme () 'relo () 'so () 'libs () 'fws () 'static () 'dia dia 'md () 'mmd () 'mf () 'mt () 'mp () 'E () 'xasm () 'undef ()
                    'swch () 'mpm () 'fx18 () 'sal () 'bp () 'rp () 'old () 'nofp () 'osz () 'uch () 'njt () 'nbi () 'falg () 'nsib () 'kfp () 'pic () 'senum () 'avz () 'cfb () 'wrapv () 'pfe ()
                   'ssp () 'sspm () 'sspr () 'ssps () 'sspo () 'sspg () 'xk () 'x6f () 'npic ()}
   ; one arm per flag, matched on the line itself: a flag that takes a word binds it in its
   ; pattern, and one with none after it falls through to the dash refusal below
   (flags as t)
    (as @ ()
          (pins t 'is (rev (t 'is))
                  'ds (rev (t 'ds))
                  'ins (rev (t 'ins))
                  'libs (rev (t 'libs)) 'fws (rev (t 'fws)))
          ("-c" . r) (flags r (pin t 'c 1))
          ("-E" . r) (flags r (pin t 'E 1))
          ; love's own version: mooncc is a verb on the love binary
          (("--version" || "-v") . _)
           (puts (uvers "mooncc"), putc 10, flush out, uleave 0)
          (("--help" || "-h") . _)
           (puts usage, putc 10, flush out, uleave 0)
          ("-pie" . r) (flags r (pin t 'pie 1))
          ; -shared: an et_dyn whose undefined names are imports, -lNAME naming the
          ; library each comes from (a DT_NEEDED libNAME.so). without -shared, -l rides through
          ("-shared" . r) (flags r (pin t 'so 1))
          ((("-l" + w) . r) && #w) (flags r (fpush t 'libs w))
          ; -framework NAME: a macos framework, dyld's to load; what no object defines is
          ; imported from it (or from libSystem, always loaded)
          ("-framework" . w . r) (flags r (fpush t 'fws w))
          ; -static: the output already is, but on macos, where dyld's exe is the default
          ("-static" . r) (flags r (pin t 'static 1))
          ; --emit-relocs: keep the ABS32 sites in .rel.* beside a linked image, for a loader
          ; that slides it (arm32 only)
          ("--emit-relocs" . r) (flags r (pin t 'relo 1))
          ("-I" . d . r) (flags r (fpush t 'is d))
          ("-D" . d . r) (flags r (fpush t 'ds d))
          ("-U" . d . r) (flags r (fpush t 'ds ['u d]))
          ("-o" . o . r) (flags r (pin t 'o o))
          ("-t" . w . r) (flags r (pin t 'tgt (totgt w)))
          ("-os" . w . r) (flags r (pin t 'os (toos w)))
          ("-Ttext" . w . r) (flags r (pin t 'org (tonum w)))
          ; -Tdata: .data runs there, stored after the code (xip)
          ("-Tdata" . w . r) (flags r (pin t 'dorg (tonum w)))
          ; -fno-inline bars every splice, as noinline does one name
          (("-fno-inline" || "-fno-inline-functions") . r) (flags r (pin t 'ni 1))
          ; -fshort-wchar: wchar_t is unsigned short and L"" lays 16-bit units
          ("-fshort-wchar" . r) (flags r (pin t 'swch 1))
          ("-fno-short-wchar" . r) (flags r (pin t 'swch ()))
          ; -f[un]signed-char: plain char's sign over the target's
          (("-funsigned-char" || "-fno-signed-char") . r) (flags r (pin t 'uch 'u))
          (("-fsigned-char" || "-fno-unsigned-char") . r) (flags r (pin t 'uch 's))
          ("-fno-jump-tables" . r) (flags r (pin t 'njt 1))
          ("-fjump-tables" . r) (flags r (pin t 'njt ()))
          ; -fno-builtin[-NAME]: a plain memset or memcpy stays a call
          ("-fno-builtin" . r) (flags r (pin t 'nbi 1))
          ((("-fno-builtin-" + w) . r) && #w) (flags r (t 'nbi = 1 ? t (fpush t 'nbi w)))
          ("-fbuiltin" . r) (flags r (pin t 'nbi ()))
          ; -falign-functions=N: every fn at N or its own wider; bare, gcc's 16
          ((("-falign-functions=" + w) . r) && #w) (flags r (pin t 'falg (tonum w)))
          ("-falign-functions" . r) (flags r (pin t 'falg 16))
          ("-fno-align-functions" . r) (flags r (pin t 'falg ()))
          ("-fno-optimize-sibling-calls" . r) (flags r (pin t 'nsib 1))
          ("-foptimize-sibling-calls" . r) (flags r (pin t 'nsib ()))
          ; -fwrapv, -fno-strict-overflow: an int's arithmetic wraps at 32 bits where it is read
          ((a . r) && elem a '("-fwrapv" "-fno-strict-overflow")) (flags r (pin t 'wrapv 1))
          ((a . r) && elem a '("-fno-wrapv" "-fstrict-overflow")) (flags r (pin t 'wrapv ()))
          ("-fno-omit-frame-pointer" . r) (flags r (pin t 'kfp 1))   ; a64's frame record (refused elsewhere)
          ((a . r) && elem a '("-fpic" "-fPIC" "-fpie" "-fPIE")) (flags r (pins t 'pic a 'npic ()))
          ; -fno-pie said outright (the kernel's): no load base moves the image, so a const the
          ; linker writes rides .rodata, as clang lays it
          ((a . r) && elem a '("-fno-pie" "-fno-PIE" "-fno-pic" "-fno-PIC")) (flags r (pins t 'pic () 'npic 1))
          ("-ftrivial-auto-var-init=zero" . r) (flags r (pin t 'avz 1))
          ("-ftrivial-auto-var-init=uninitialized" . r) (flags r (pin t 'avz ()))
          ; -fcf-protection: 1 endbr (ibt), 2 the shadow stack's mark alone, 3 both
          ((a . r) && elem a '("-fcf-protection=branch" "-fcf-protection=full" "-fcf-protection")) (flags r (pin t 'cfb (a = "-fcf-protection=branch" ? 1 3)))
          ("-fcf-protection=return" . r) (flags r (pin t 'cfb 2))
          ("-fcf-protection=none" . r) (flags r (pin t 'cfb ()))
          ; -fpatchable-function-entry=N[,M]: N nops at each entry, M of them ahead of it
          ((("-fpatchable-function-entry=" + w) . r) && #w)
           (: ws (split "," w) n (tonum <ws) k (two? >ws ? (tonum <>ws) 0)
              (charm? n && charm? k && 0 <= k <= n ? (flags r (pin t 'pfe (n = 0 ? () [n k])))
                 (udie 2 "cc: -fpatchable-function-entry=\(w) -- N, or N,M with M at most N")))
          ; -fstack-protector*: 1 and 2 protect as -strong, 3 every fn, 4 the stack_protect attribute's
          ("-fstack-protector" . r) (flags r (pin t 'ssp 1))
          ("-fstack-protector-strong" . r) (flags r (pin t 'ssp 2))
          ("-fstack-protector-all" . r) (flags r (pin t 'ssp 3))
          ("-fstack-protector-explicit" . r) (flags r (pin t 'ssp 4))
          ("-fno-stack-protector" . r) (flags r (pin t 'ssp ()))
          ((("-mstack-protector-guard=" + w) . r) && elem w '("global" "tls" "sysreg")) (flags r (pin t 'sspm (intern w)))
          ((("-mstack-protector-guard-reg=" + w) . r) && #w) (flags r (pin t 'sspr w))
          ((("-mstack-protector-guard-symbol=" + w) . r) && #w) (flags r (pin t 'ssps w))
          ((("-mstack-protector-guard-offset=" + w) . r) && #w) (flags r (pin t 'sspo (tonum w)))
          ; an enum's width is the ABI's (parse.l's ety): short on the AAPCS32 targets alone
          ("-fshort-enums" . r) (flags r (pin t 'senum 's))
          ("-fno-short-enums" . r) (flags r (pin t 'senum 'n))
          ; -ffixed-x18: a64 never allocates x18 anyway; any other -ffixed- refuses
          ("-ffixed-x18" . r) (flags r (pin t 'fx18 1))
          (("-ffixed-" + w) . _) (udie 2 "cc: -ffixed-\(w) -- mooncc reserves x18 on a64 only")
          ; -fmacro-prefix-map=OLD=NEW, or -ffile-prefix-map (no debug map here): newest first
          ((("-fmacro-prefix-map=" + m) || ("-ffile-prefix-map=" + m)) . r)
           (m @ (o + "=" + n) (flags r (fpush t 'mpm [o n]))
                (udie 2 "cc: \(<as) -- wants OLD=NEW"))
          ; -freadme=file: plain text into the output's `.love.README` section, ignored with -c.
          ; ahead of tol?, which swallows every other -f
          (("-freadme=" + f) . r)
           (uread f @ rt (two? rt ? (flags r (pin t 'rdme <>rt))
                                    (udie 1 "cc: cannot open \(f)")))
          ; gcc's dependency rule: -MD, -MMD (our headers left out), -MF file, -MT/-MQ target,
          ; -MP an empty rule per header, and kbuild's -Wp,-MD,FILE
          ("-MD" . r) (flags r (pin t 'md 1))
          ("-MMD" . r) (flags r (pins t 'md 1 'mmd 1))
          ("-MP" . r) (flags r (pin t 'mp 1))
          ("-MF" . f . r) (flags r (pin t 'mf f))
          (("-MT" || "-MQ") . w . r) (flags r (pin t 'mt w))
          (("-Wp,-MD," + f) . r) (flags r (pins t 'md 1 'mf f))
          (("-Wp,-MMD," + f) . r) (flags r (pins t 'md 1 'mmd 1 'mf f))
          ((("-I" + d) . r) && #d) (flags r (fpush t 'is d))
          ((("-D" + d) . r) && #d) (flags r (fpush t 'ds d))
          ((("-t" + w) . r) && #w) (flags r (pin t 'tgt (totgt w)))
          ; -nostdinc: our headers are the only standard set already
          ("-nostdinc" . r) (flags r t)
          ; -ffreestanding also defines __STDC_HOSTED__ 0 (cpp applies -D after its predefines)
          ; and pins -os none, which a later -os overrides. -nostdlib alone stays hosted
          ("-ffreestanding" . r)
           (flags r (pins (fpush t 'ds "__STDC_HOSTED__=0") 'nostd 1 'os 'none))
          ((a . r) && nostd? a) (flags r (pin t 'nostd 1))
          ; -x: loud like -std= (`-x c++` names a compiler we are not); assembler-with-cpp is a .S
          (("-x" . w . r) || ((("-x" + w) . r) && #w))
           (w @ "assembler-with-cpp" (flags r (pin t 'xasm 1))
                (xlang? w ? (flags r (pin t 'xasm ())) (udie 2 (xdie w))))
          ; -undef: none of the system's or the compiler's predefines, only the standard's
          ("-undef" . r) (flags r (pin t 'undef 1))
          ; a64 only: no access its alignment cannot carry (gen.l)
          ("-mstrict-align" . r) (flags r (pin t 'sal 1))
          ("-mno-strict-align" . r) (flags r (pin t 'sal ()))
          ; gcc's x86 widths: -m32 the i386 ABI, -m16 its 16-bit face, -m64 x86-64
          ("-m32" . r) (flags r (pin t 'tgt 'i386))
          ("-m16" . r) (flags r (pin t 'tgt 'i386m16))
          ("-m64" . r) (flags r (pin t 'tgt 'x64))
          (("-mbranch-protection=" + w) . r) (flags r (pin t 'bp (bpof w)))
          ; the x86 cpu named: one before the 686 has no cmov, so a select branches instead
          (("-march=" + w) . r) (flags r (pin t 'old (elem w ["i386" "i486" "i586" "pentium" "pentium-mmx" "lakemont"])))
          ; the float file refused: code that would touch an xmm or x87 register is a refusal
          ((a . r) && elem a ["-mno-sse" "-mno-sse2" "-mno-80387" "-msoft-float" "-mgeneral-regs-only"]) (flags r (pin t 'nofp 1))
          ; no lane of ours would use these, so asking for none of them asks nothing
          ((a . r) && elem a ["-mno-mmx" "-mno-3dnow" "-mno-avx" "-mno-sse4a"]) (flags r t)
          ; every call keeps esp 16-aligned, which satisfies any boundary asked for
          (("-mpreferred-stack-boundary=" + _) . r) (flags r t)
          ; i386's register arguments: the first n words in eax edx ecx (the kernel's realmode
          ; and 32-bit units ask for 3)
          (("-mregparm=" + w) . r) (flags r (pin t 'rp (elem w ["0" "1" "2" "3"] ? (tonum w)
                                                     (udie 2 "cc: -mregparm=\(w) -- 0 to 3"))))
          ; the x86-64 kernel's asks, words in 'xk: x64 code is rip-relative and its data words abs64,
          ; which the kernel model and the small one both take; long double is double, returned in xmm0
          ((a . r) && elem a ["-mcmodel=small" "-mcmodel=kernel" "-mno-fp-ret-in-387" "-mno-skip-rax-setup"
                              "-mindirect-branch=keep" "-mfunction-return=keep"]) (flags r (fpush t 'x6f a))
          (("-mcmodel=" + w) . r) (udie 2 "cc: -mcmodel=\(w) -- x64's code is rip-relative within 2GB: small and kernel")
          ; an 8-aligned incoming stack: a local asking more is realigned through a pointer
          (("-mstack-alignment=" + w) . r)
           (? (w = "16") (flags r t)
              (w = "8") (flags r (fpush (xkon t 'sa8) 'x6f "-mstack-alignment=8"))
              (udie 2 "cc: -mstack-alignment=\(w) -- 8 or 16"))
          ; varargs calls skip al, the count of vector registers
          ("-mskip-rax-setup" . r) (flags r (fpush (xkon t 'nal) 'x6f "-mskip-rax-setup"))
          ; indirect calls and jumps go through __x86_indirect_thunk_REG, returns through
          ; __x86_return_thunk: the kernel lays both, mooncc only names them
          ((a . r) && elem a ["-mindirect-branch=thunk-extern" "-mretpoline-external-thunk"]) (flags r (fpush (xkon t 'thk) 'x6f a))
          ((("-mindirect-branch=" + w) . r) && elem w ["thunk" "thunk-inline"])
           (udie 2 "cc: -mindirect-branch=\(w) -- mooncc lays no thunk body: thunk-extern names the kernel's")
          ("-mfunction-return=thunk-extern" . r) (flags r (fpush (xkon t 'rth) 'x6f "-mfunction-return=thunk-extern"))
          ((("-mfunction-return=" + w) . r) && elem w ["thunk" "thunk-inline"])
           (udie 2 "cc: -mfunction-return=\(w) -- mooncc lays no thunk body: thunk-extern names the kernel's")
          ; an indirect call or jump reads its target from a register, never memory
          ("-mindirect-branch-register" . r) (flags r (fpush (xkon t 'ibr) 'x6f "-mindirect-branch-register"))
          ; a cs prefix on a thunk call through r8-r15, room for the kernel to patch it inline
          ("-mindirect-branch-cs-prefix" . r) (flags r (fpush (xkon t 'cs) 'x6f "-mindirect-branch-cs-prefix"))
          ; -Os/-Oz ask for size: returns share one epilogue. any other -O asks it back off
          ((a . r) && starts? a "-O") (flags r (pin t 'osz (elem a ["-Os" "-Oz"])))
          ((a . r) && tol? a) (flags r t)
          ((a . r) && (fok? a || mok? a)) (flags r t)
          ; a bare `-` is an input, the source on stdin
          ("-" . r) (flags r (fpush t 'ins "-"))
          ((a . _) && (starts? a "-f" || starts? a "-m")) (udie 2 "cc: \(a) -- mooncc does not honour it")
          (("-" + _) . _) (udie 2 usage)
          (a . r) (flags r (fpush t 'ins a)))
   ; every cc says its sentence: an internal raise from gen or holo becomes `cc: internal error`.
   ; moon-run answers the status, so a caller in this image survives a failed compile. 'leave is
   ; the exit door (udie), not a fault: it keeps usage's 2
   (moon-run as)
    (trap (x \ (moon-cc x @ r (charm? r ? r 0))) as
          (a \ b \ a @ 'leave b
                     (say err "cc: internal error: \(show a) \(show b)\n",
                      flush err,
                      1)))
   ; moon-main quits with the status
   (moon-main as) (quit (moon-run as))
   (moon-cc as)
    ; the default target is love-arch, the running binary's; -t is the cross flag
    (: sd (std-take as)
       dia <sd
       as9 <>sd                                    ; the line with -std= lifted off it
       ntv (elem love-arch '(x64 a64 rv64) ? love-arch 'x64)     ; unknown grounds keep x64
       f (flags as9 (fseed ntv dia))       ; the flag set, seeded whole
       ; -I dirs want a trailing slash: normalised in the tablet, before anything reads
       _ (pin f 'is (map dirn (f 'is)))
       _ (f 'fx18 && f 'tgt != 'a64 && udie 2 "cc: -ffixed-x18 names an a64 register, and the target is \(f 'tgt)")
       ; wasm's kernel is the page's loader, which speaks linux's numbers: the os unless named
       _ (f 'tgt = 'wasm && !(f 'os) && pin f 'os 'linux)
       ; on macos an x64 link is a mach-o unless -os names another kernel: it meets no ELF
       _ (f 'tgt = 'x64 && !(f 'os) && elem 'love-os (names ()) && host-os 0 = 'macos && pin f 'os 'macos)
       _ ((f 'sal || two? (f 'bp)) && f 'tgt != 'a64 &&
          udie 2 "cc: -mstrict-align and -mbranch-protection lay on a64 only")
       _ (f 'rp && !(elem (f 'tgt) '(i386 i386m16)) && udie 2 "cc: -mregparm lays on i386 only")
       _ (f 'kfp && f 'tgt != 'a64 && udie 2 "cc: -fno-omit-frame-pointer -- mooncc keeps no frame pointer on \(f 'tgt)")
       _ (f 'senum && (elem (f 'tgt) '(thumb1 thumb2 thumb2sp arm) @ a32 (f 'senum = 's ? !a32 a32)) &&
          udie 2 "cc: \((f 'senum = 's ? "-fshort-enums" "-fno-short-enums")) -- an enum's width is the ABI's on \(f 'tgt)")
       _ (f 'cfb && !(elem (f 'tgt) '(x64 i386 i386m16)) && udie 2 "cc: -fcf-protection lays on x86 only")
       _ (f 'pfe && !(elem (f 'tgt) '(x64 i386 a64 rv64)) && udie 2 "cc: -fpatchable-function-entry -- no nop pad on \(f 'tgt)")
       _ (f 'pic && !(elem (f 'tgt) '(x64 a64 rv64 wasm)) && udie 2 "cc: \(f 'pic) -- mooncc's code is absolute on \(f 'tgt)")
       _ (f 'ssp && pin f 'sspg (sspguard f))
       _ (two? (f 'x6f) && f 'tgt != 'x64 && udie 2 "cc: \(<(f 'x6f)) -- an x86-64 ask; no lane on \(f 'tgt)")
       _ (elem 'thk (f 'xk) && pin f 'njt 1)   ; a table jump is an indirect one: a switch compares instead
       ; no nest on disk: the carried source, pinned once so every TU shares one inflate
       _ (!(string? (mhome ())) && pin f 'vb (mblob ()))
       c (f 'c) o (f 'o) ins (f 'ins)
       ; -c lays objects, anything else links (a configure line binds a libc). the arms are
       ; ordered; `(? g)` fits anything g holds for, and a failing guard falls through
       (? (f 'E) (: (go l) (? !(two? l) 0 (cc-pre <l o f, go >l))
                    (two? ins ? (go ins) (udie 2 usage)))
       (ins @
        []      (udie 2 usage)
        (? o)   (c ? (two? >ins ? (udie 2 "cc: -o takes one input")
                                  (cc-obj <ins o f, 0))
                     (cc-link ins o f, 0))
        ; the legacy pair `in out`: a .c/.o mix is a link, and a .a is never an out
        (? (!(dotsrc? b) && !(dota? a) && !(dota? b)
            && (c || (!(doto? a) && !(doto? b)))) [a b])
                (c ? (cc-obj a b f) (cc-link [a] b f), 0)
        (? c)   (: (go l) (? !(two? l) 0
                             ; stdin has no name to derive an .o from
                             (<l = "-") (udie 2 "cc: a source on stdin needs -o")
                             !(dotsrc? <l) (udie 2 "cc: not a .c or .s input: \(<l)")
                             (cc-obj <l (obase <l) f, go >l))
                   (go ins))
                (cc-link ins "a.out" f, 0)))))

; fire moon-main iff mooncc is the real command line's program (positional or a `-l` preload),
; taking the args after it. every image carrying moon.l answers `love mooncc ..` and `love cc ..`
; (a Makefile's default CC), each quitting with moon-run's status
(: E (cite 'verbs 'enlist)
   _ (E 'mooncc moon-run ['self])
   _ (E 'cc moon-run ['self])
   s (cite 'verbs 'fire ["mooncc" "mooncc.l" "moon.l"])
   (two? s && moon-main >s))
) ; module 'moon
