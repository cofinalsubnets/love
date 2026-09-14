; u/mkblob.l -- lay any file into an ELF object under a name of the caller's
; choosing, so a build can carry bytes no source tree holds.
;
;   love u/mkblob.l in out.o sym [arch]            arch defaults to x64
;
; the object holds two symbols in .rodata and nothing else:
;
;   <sym>_len   an 8-byte little-endian length, at offset 0 (so it is 8-aligned)
;   <sym>       the bytes, right behind it
;
; u/mksrc.l is the same lay under two fixed names, for the one blob every
; artifact carries; this is the door for the rest. i/doom.c reads a pair.
;
; no (borrow 'holo) here, for mksrc's reason: it resolves off a nest (~/.love),
; which a fresh seed tree does not have. make hands us holo the way it hands
; mksrc its own -- -l $(ho)/.mksys-cat.l.

(borrow 'posix)
(? (lit? (cite 'holo 'objelf)) (borrow 'holo) 0) ; splice the assembler when this love is baked

(: (mkblob-slurp p) (: q (open p "r") (hot? q ? (: s (slurp q) (close q, [1 (s + "")]))))
   (mkblob-die m) (say err $ "mkblob: " + m + "\n", quit 1)

   ; text -> the byte list `raw` takes, built from the tail so the walk is a tail call
   (mkblob-bytes s i acc) (i < 0 ? acc (mkblob-bytes s (i - 1) (s i . acc)))
   ; a little-endian 8-byte word, the width the C side reads it at
   (mkblob-le8 v i acc) (i = 8 ? acc (mkblob-le8 (v >> 8) (i + 1) (acc + [(v & 255)])))

   ; a cross arch's backend joins at runtime (obj.l's law: registered, not merely
   ; named), and an unbaked love has no holo at all -- say so.
   (mkblob-be arch)
    (lit? (cite 'holo 'objelf) ? (mkblob-be2 arch)
       (mkblob-die "no holo aboard -- this love is unbaked (make host bakes it)"))
   (mkblob-be2 arch)
    (lit? (backends arch) ? 0
       ; the backend file is the canonical arch word now -- one spelling, no map
       (: f ("l/holo/" + string arch + ".l")
          q (open f "r")
          (? q (mkblob-rdev (flow q), close q)
           (mkblob-die ("no backend aboard and no text at " + f)))))
   (mkblob-rdev cl)
    (sound cl @ 'torn (mkblob-die "torn backend text")
                (a . u) (ev a, mkblob-rdev u))

   ; a wasm object is the gen tuple as text (a/moon/moon.l), the same label/raw forms
   ; in its data slot and the two names in its globals slot -- u/mksrc.l's lane, the
   ; bytes behind the text as (blob 0) in moon.l's wasm-tu container
   (mkblob-wasm dst forms syms s)
    (: q (open dst "w")
       _ (!(hot? q) ? (mkblob-die ("cannot write " + dst)))
       t (show [() forms () syms () () () () () () () ()])
       _ (say q ("wo1 " + show #t + " " + show #s + "\n" + t + s))
       (close q))

   (mkblob arch src dst sym)
    (: _ (arch = 'wasm ? 0 (mkblob-be arch))
       g (mkblob-slurp src)
       _ (one? g ? (mkblob-die $ "cannot read " + src))
       s <>g
       n #s
       _ (? (0 < n) 0 (mkblob-die (src + " is empty")))
       lsym (sym + "_len")
       ; the payload rides as a BLOB -- the string itself, one item holding every byte
       ; (holo.l's item-len) -- so a wad costs a cell here and not four million
       forms [['label (nom lsym)] ['raw (mkblob-le8 n 0 ())]
              ['label (nom sym)]  ['raw [(arch = 'wasm ? '(blob 0) s)]]]
       (arch = 'wasm ? (mkblob-wasm dst forms [sym lsym] s)
        (write-bytes dst (objelf arch () () () [sym lsym] () () () () () forms))))

   ; `argv` is a list whose head is this script's own path, so the arguments
   ; start at the tail. the arch arrives as TEXT and `name` interns it, so the
   ; answer is the very symbol the backend table is keyed by.
   (mkblob-main av)
    (: n #av
     (3 <= n ? (mkblob (4 <= n ? (nom (av 3)) 'x64) <av <>av <>>av)
      (mkblob-die "usage: mkblob IN OUT.o SYM [ARCH]")))

   (mkblob-main >argv))
