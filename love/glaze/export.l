; love/glaze/export.l -- the glaze's MODULE BOUNDARY (mark/sweep; holo uses the scope layer now). emit.l +
; auto.l leak every helper and analysis pass onto the global book (autogroup, jitir,
; loopinfo, dechurch, the cf-*/cb-*/anat-* families, the memo cache ..); this trailer
; sweeps the whole span into ONE book pinned under `glaze` and pulls the names back off.
; the glaze has NO public entry points -- auto-ev installed itself as `ev` and that is
; its entire interface -- so the book is diagnostic: the gate streams (test/glaze-x86.l,
; hook.l) and main.c's image-dump cache-empty reach the internals through it, and a dev
; probe is one read away ((glaze 'loopinfo)); (glaze 'keys) lists them. `glaze` is a lookup-only
; CLOSURE over a private tablet -- (glaze 'cache) still reaches the memo cache, but a stray
; (pin glaze ..) has no tablet to poison. the span is MEASURED, never listed:
; emit.l opens with glaze-mark = (names ()) and auto.l closes with glaze-load; the diff
; is the module. `ev` itself predates the mark (the egg bound it), so the REBIND stays
; global -- rebinding is not a new name. evaled by host/main.c right after auto.l,
; under the same arch gate; love0/kernel/wasm never load the glaze and never load this.
(: seen (: t (tablet 0) _ (each glaze-mark (\ k (pin t k 1))) t)
   m (tablet 0)
   _ (each glaze-load
        (\ k (? (peep seen k 0) 0
                (: _ (pin m k (peep book k 0)) _ (pull book k 0) 0))))
   _ (pull book 'glaze-mark 0)                   ; the mark itself is post-mark: swept above,
   _ (pull m 'glaze-mark 0)                      ;   cleaned out of the module here
   _ (pull book 'glaze-load 0)                   ; the snap is post-snap: never swept, pulled here
   _ (pin book 'glaze (\ k (? (id? k 'keys) (keys m) (peep m k 0))))  ; lookup-only closure: m stays
   0)                                                                 ;   private, so (pin glaze ..) can't poison it; (glaze 'keys) introspects
