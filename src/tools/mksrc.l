; src/tools/mksrc.l -- lay the source container (selfpack.l's) into an ELF object
;   love src/tools/mksrc.l src.tree out.o [arch]     arch defaults to x64
; .rodata holds srctree_len (8-byte le, offset 0) then srctree, the bytes
; holo comes in as a cat (-l), not a borrow: a fresh seed tree has no nest

(borrow 'posix)
(lit? (cite 'holo 'objelf) ? (borrow 'holo) 0)   ; splice the assembler when baked

(: (mksrc-slurp p) (uread p @ [1 s] [1 (s + "")] ())
   (mksrc-die m) (udie 1 ("mksrc: " + m))

   (mksrc-le8 v i acc) (i = 8 ? acc (mksrc-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a cross backend loads from the tree text; an unbaked love has no holo
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

   ; a wasm object is the gen tuple as text, the container behind it as (blob 0)
   (mksrc-wasm dst forms s)
    (: q (open dst "w")
       _ (!(hot? q) ? (mksrc-die ("cannot write " + dst)))
       t (show [() forms () '("srctree" "srctree_len") () () () () () () () ()])
       (say q ("wo1 " + show #t + " " + show #s + "\n" + t + s), close q))

   (mksrc arch src dst)
    (: _ (arch = 'wasm ? 0 (mksrc-be arch))
       g (mksrc-slurp src)
       _ (atom? g ? (mksrc-die ("cannot read " + src)))
       s <>g
       n #s
       _ (n < 1 ? (mksrc-die (src + " is empty")))
       ; the container rides as one blob item carrying every byte
       forms ['(label srctree_len) ['raw (mksrc-le8 n 0 ())]
              '(label srctree)     ['raw [(arch = 'wasm ? '(blob 0) s)]]]
       (arch = 'wasm ? (mksrc-wasm dst forms s)
        (write-bytes dst (objelf arch () () () '("srctree" "srctree_len") () () () () () forms))))

   ; `name` interns the arch to the symbol backends is keyed by (a `mint` would match nothing)
   (mksrc-main av)
    (#av @ n
       (2 <= n ? (mksrc (3 <= n ? (name <>>av) 'x64) <av <>av)
        (mksrc-die "usage: mksrc SRC.TREE OUT.o [ARCH]")))

   (mksrc-main >argv))
