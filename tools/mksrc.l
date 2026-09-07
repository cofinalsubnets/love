; tools/mksrc.l -- lay the source tarball into an ELF object, so the artifact can
; hand out its own source with nothing on the box.
;
;   love tools/mksrc.l archive.tar.gz out.o [arch]     arch defaults to x64
;
; the object holds two symbols in .rodata and nothing else:
;
;   ai_srcgz_len   an 8-byte little-endian length, at offset 0 (so it is 8-aligned)
;   ai_srcgz       the .tar.gz bytes, right behind it
;
; host/src.c declares both weak and reads them, so an ordinary `love` links with no
; blob at all and answers nothing when asked -- only the dist link supplies one.
;
; no linker work buys this. `__start_/__stop_` brackets exist for a region packed
; across many objects (the nif lane), and link.l's ldsynth is a fixed list of them; a
; blob is one object of known size, so ordinary globals land in the symbol book like
; any other and nothing in the linker has to learn a new name.
; no (use 'holo) here: that resolves off a nest (~/.love), which a fresh
; seed tree does not have. make hands us holo the way it hands mksys its own:
; -l $(ho)/.mksys-cat.l (kore text/core/asbook + holo elf/obj), the lane
; sys.o already rides.

(? (lit? (from 'holo 'objelf)) (use 'holo) 0) ; splice the assembler when this love is baked; the guard below says so when not

(: (mksrc-slurp p) (: q (open p "r") (hot? q ? (: s (slurp q) (close q, [1 (s + "")]))))
   (mksrc-die m) (say err ("mksrc: " + m + "\n"), quit 1)

   ; text -> the byte list `raw` takes. Built from the tail so the walk is a tail call
   ; and the list comes out in order; ~0.25 s over a 3.6 MB archive.
   (mksrc-bytes s i acc) (i < 0 ? acc (mksrc-bytes s (i - 1) (s i . acc)))
   ; a little-endian 8-byte word, the width host/src.c reads it at
   (mksrc-le8 v i acc) (i = 8 ? acc (mksrc-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a cross arch's backend joins at runtime (obj.l's law: registered, not
   ; merely named -- the baked holo carries the native one only). the text
   ; rides the tree beside us; make runs this from the root. and an unbaked
   ; love has no holo at all -- say so, instead of a bare ;; note.
   (mksrc-be arch)
    (? (lit? (from 'holo 'objelf)) (mksrc-be2 arch)
       (mksrc-die "no holo aboard -- this love is unbaked (make host bakes it)"))
   (mksrc-be2 arch)
    (? (lit? (backends arch)) 0
       ; the backend file is the canonical arch word now -- one spelling, no map
       (: f ("core/holo/" + string arch + ".l")
          q (open f "r")
          (? q (mksrc-rdev (flow q), close q)
             (mksrc-die ("no backend aboard and no text at " + f)))))
   (mksrc-rdev cl)
    (sound cl @ 'torn (mksrc-die "torn backend text")
                (a . u) (ev a, mksrc-rdev u))

   ; a wasm object is the gen tuple as text (apps/moon/moon.l), and the link's data lane
   ; reads the same label/raw forms objelf takes -- so this one is the forms in the data
   ; slot, the two names in the globals slot, and nothing else. no backend to join.
   (mksrc-wasm dst forms)
    (: q (open dst "w")
       _ (!(hot? q) ? (mksrc-die ("cannot write " + dst)))
       _ (say q (show [() forms () '("ai_srcgz" "ai_srcgz_len") () () () () () () () ()]))
       (close q))

   (mksrc arch src dst)
    (: _ (arch = 'wasm ? 0 (mksrc-be arch))
       g (mksrc-slurp src)
       _ (one? g ? (mksrc-die ("cannot read " + src)))
       s <>g
       n #s
       _ (n < 1 ? (mksrc-die (src + " is empty")))
       forms ['(label ai_srcgz_len) ['raw (mksrc-le8 n 0 ())]
              '(label ai_srcgz)     ['raw (mksrc-bytes s (n - 1) ())]]
       _ (arch = 'wasm ? (mksrc-wasm dst forms)
          (write-bytes dst (objelf arch () () () '("ai_srcgz" "ai_srcgz_len") () () () () () forms)))
       (say out $ "MKSRC\t" + dst + " (" + show n + " bytes)\n"))

   ; `argv` is a list and its head is this script's own path, so the arguments
   ; start at the tail -- tools/tgz.l says the same thing at its own foot.
   ; and the arch arrives as TEXT: `name` interns it, so the answer is the very
   ; symbol the backend table is keyed by. `mint` makes a fresh one instead --
   ; equal-looking, `id?` to nothing, and objsecs refuses it as an unknown target one
   ; call later.
   (mksrc-main av)
    (: n #av
       (2 <= n ? (mksrc (3 <= n ? (name <>>av) 'x64) <av <>av)
        (mksrc-die "usage: mksrc ARCHIVE.tar.gz OUT.o [ARCH]")))

   (mksrc-main >argv))
