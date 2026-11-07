; src/apps/moon/stage.l -- gen.l's pass contracts as an overlay domain + sig table, checked by
; the moon gate; gen.l is read as data, never evaled. a die is the stage a form list is at: a
; cleanup pass is ((a) a), a staging pass advances a die. a new pass declares its sig here.

(borrow 'posix)

(: ovck (cite 'overlay 'ov-check)
   _ (!!(cite 'overlay) ? 0 (puts ";; moon-stage: no overlay module in this love", quit 1))
   stage-dies '(gst ir-vreg ir-chosen ir-nolab ir-noframe ir-jmpfix ir-final ir-emitted)
   (stage-join x y) (x = y ? x 'top)
   (stage-tr op x y) 'top
   (stage-lit e) 'bot
   (stage-okr bd decl) (elem bd '(top bot) || bd = decl)
   stage-dom (hash 'dice stage-dies 'ctors () 'tr stage-tr 'join stage-join
                   'litdie stage-lit 'okr stage-okr)
   stage-sigs '((cgfn (gst top) top)                ; sigged so its body is walked; a sig variable would ride rigid
                (sibcall (gst a) a) (a4ize (a) a)
                (cmpfuse (a) a)
                (t2nx (gst a) a)
                ; the post-choice chain: one order types
                (csframe (gst ir-nolab) ir-nolab)     ; lays the saves out, before any reader of their shape
                (unframe (gst ir-nolab) ir-noframe)
                (rvunframe (gst ir-noframe) ir-noframe)
                (cskeep (gst ir-final) ir-emitted)
                (csdrop (gst ir-emitted) ir-emitted)
                (jmpm (gst ir-emitted) ir-emitted)
                (tailarm (gst ir-emitted) ir-emitted)
                (swrap (gst ir-emitted) ir-emitted)
                (frrec (gst ir-emitted) ir-emitted)
                (t2pm (gst ir-emitted) ir-emitted))
   (forms text) (sounds text @ 'torn (puts ";; moon-stage: gen.l reads torn", quit 1) fs fs)
   src (open "src/apps/moon/gen.l" "r")
   _ (hot? src ? 0 (puts ";; moon-stage: cannot open src/apps/moon/gen.l", quit 1))
   text (slurp src)
   (tops f) (two? f && <f = 'module ? (filter (g \ two? g && <g = ':) >>f) [f])   ; a module's book is its `:`
   reps (catmap (f \ (two? f && <f = ': ? (ovck stage-dom stage-sigs f) ()))
                (catmap tops (forms text)))
   _ (two? reps ?
        (map (r \ (puts ";; moon-stage: ", putx r, putc 10)) reps, quit 1)
        0)
   (puts "moon-stage: ",
    putx #stage-sigs,
    puts " sigs hold over src/apps/moon/gen.l (the post-choice chain types in one order)",
    putc 10,
    0))
