; src/tools/mksrc.l -- lay the source container (src/tools/selfpack.l's) into an ELF object, so
; the artifact can hand out its own source with nothing on the box.
;
;   love src/tools/mksrc.l src.tree out.o [arch]     arch defaults to x64
;
; the object holds two symbols in .rodata and nothing else:
;
;   ai_srctree_len   an 8-byte little-endian length, at offset 0 (so it is 8-aligned)
;   ai_srctree       the container's bytes, right behind it
;
; a link that takes no such object names src/love/noblob.c, whose zero length says none
; is carried.
; no unconditional (borrow 'holo): it resolves off a nest (~/.love), which a fresh seed tree
; does not have, so make hands holo in as a cat (-l $(ho)/.mksys-cat.l).

(borrow 'posix)
(lit? (cite 'holo 'objelf) ? (borrow 'holo) 0)   ; splice the assembler when this love is baked; the guard below says so when not

(: (mksrc-slurp p) (uread p @ [1 s] [1 (s + "")] ())
   (mksrc-die m) (udie 1 ("mksrc: " + m))

   ; a little-endian 8-byte word, the width src/love/src.c reads it at
   (mksrc-le8 v i acc) (i = 8 ? acc (mksrc-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a cross arch's backend joins at runtime from the tree text (the baked holo carries the
   ; native one only); an unbaked love has no holo at all, and says so
   (mksrc-be arch)
    (lit? (cite 'holo 'objelf) ? (mksrc-be2 arch)
       (mksrc-die "no holo aboard -- this love is unbaked (make host bakes it)"))
   (mksrc-be2 arch)
    (lit? (backends arch) ? 0
       (: f ("src/love/holo/" + string arch + ".l")
          q (open f "r")
          (q ? (mksrc-rdev (flow q), close q)
             (mksrc-die ("no backend aboard and no text at " + f)))))
   (mksrc-rdev cl)
    (sound cl @ 'torn (mksrc-die "torn backend text")
                (a . u) (ev a, mksrc-rdev u))

   ; a wasm object is the gen tuple as text (src/apps/moon/moon.l): the forms in the data slot,
   ; the two names in the globals slot, and the container behind the text as (blob 0), the
   ; container moon.l's wasm-tu reads
   (mksrc-wasm dst forms s)
    (: q (open dst "w")
       _ (!(hot? q) ? (mksrc-die ("cannot write " + dst)))
       t (show [() forms () '("ai_srctree" "ai_srctree_len") () () () () () () () ()])
       (say q ("wo1 " + show #t + " " + show #s + "\n" + t + s), close q))

   (mksrc arch src dst)
    (: _ (arch = 'wasm ? 0 (mksrc-be arch))
       g (mksrc-slurp src)
       _ (atom? g ? (mksrc-die ("cannot read " + src)))
       s <>g
       n #s
       _ (n < 1 ? (mksrc-die (src + " is empty")))
       ; the container rides as a BLOB -- the string itself, one item carrying every byte
       ; (holo.l's item-len) -- through lay, the walk and the write, on either lane
       forms ['(label ai_srctree_len) ['raw (mksrc-le8 n 0 ())]
              '(label ai_srctree)     ['raw [(arch = 'wasm ? '(blob 0) s)]]]
       (arch = 'wasm ? (mksrc-wasm dst forms s)
        (write-bytes dst (objelf arch () () () '("ai_srctree" "ai_srctree_len") () () () () () forms))))

   ; argv's head is this script's own path. the arch arrives as text and `name` interns it
   ; to the symbol the backend table is keyed by (a `mint` would be == to nothing)
   (mksrc-main av)
    (#av @ n
       (2 <= n ? (mksrc (3 <= n ? (name <>>av) 'x64) <av <>av)
        (mksrc-die "usage: mksrc SRC.TREE OUT.o [ARCH]")))

   (mksrc-main >argv))
