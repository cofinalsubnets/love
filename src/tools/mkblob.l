; src/tools/mkblob.l -- lay any file into an ELF object under a name of the caller's
; choosing, so a build can carry bytes no source tree holds.
;
;   love src/tools/mkblob.l in out.o sym [arch]            arch defaults to x64
;
; the object holds two symbols in .rodata and nothing else:
;
;   <sym>_len   an 8-byte little-endian length, at offset 0 (so it is 8-aligned)
;   <sym>       the bytes, right behind it
;
; no unconditional (borrow 'holo): it resolves off a nest, which a fresh seed tree lacks, so
; make hands holo in as a cat.

(borrow 'posix)
(lit? (cite 'holo 'objelf) ? (borrow 'holo) 0)   ; splice the assembler when this love is baked

(: (mkblob-slurp p) (uread p @ [1 s] [1 "\(s)"])
   (mkblob-die m) (udie 1 "mkblob: \(m)")

   ; text -> the byte list `raw` takes
   (mkblob-bytes s i acc) (i < 0 ? acc (mkblob-bytes s (i - 1) (s i . acc)))
   ; a little-endian 8-byte word
   (mkblob-le8 v i acc) (i = 8 ? acc (mkblob-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a cross arch's backend joins at runtime; an unbaked love has no holo at all
   (mkblob-be arch)
    (lit? (cite 'holo 'objelf) ? (mkblob-be2 arch)
       (mkblob-die "no holo aboard -- this love is unbaked (make host bakes it)"))
   (mkblob-be2 arch)
    (lit? (backends arch) ? 0
       ; the backend file is named by the arch word
       (: f "src/love/holo/\(arch).l"
          q (open f "r")
          (q ? (mkblob-rdev (flow q), close q)
           (mkblob-die "no backend aboard and no text at \(f)"))))
   (mkblob-rdev cl)
    (sound cl @ 'torn (mkblob-die "torn backend text")
                (a . u) (ev a, mkblob-rdev u))

   ; a wasm object is moon.l's gen tuple as text: the forms in its data slot, the two names
   ; in its globals slot, the bytes behind the text as (blob 0)
   (mkblob-wasm dst forms syms s)
    (: q (open dst "w")
       _ (!(hot? q) ? (mkblob-die "cannot write \(dst)"))
       t (show [() forms () syms () () () () () () () ()])
       (say q "wo1 \(#t) \(#s)\n\(t)\(s)", close q))

   (mkblob arch src dst sym)
    (: _ (arch @ 'wasm 0 (mkblob-be arch))
       g (mkblob-slurp src)
       _ (atom? g ? (mkblob-die "cannot read \(src)"))
       s <>g
       n #s
       _ (0 < n ? 0 (mkblob-die "\(src) is empty"))
       lsym "\(sym)_len"
       ; the payload rides as the string itself, one item, not a cell a byte
       forms [['label (nom lsym)] ['raw (mkblob-le8 n 0 ())]
              ['label (nom sym)]  ['raw [(arch @ 'wasm '(blob 0) s)]]]
       (arch = 'wasm ? (mkblob-wasm dst forms [sym lsym] s)
        (write-bytes dst (objelf arch () () () [sym lsym] () () () () () forms))))

   ; argv's head is this script's own path; the arch arrives as text
   (mkblob-main av)
    (#av @ n
     (3 <= n ? (mkblob (4 <= n ? (nom (av 3)) 'x64) <av <>av <>>av)
      (mkblob-die "usage: mkblob IN OUT.o SYM [ARCH]")))

   (mkblob-main >argv))
