; tools/kinds2uu.l -- the kinds-lattice analog of tools/wm2uu.l: read the abstract
; domain of doc/misc/proto/kinds.l as data and emit test/uukind.l -- the join (and its
; num? guard) compiled into uu terms over a nat-coded carrier, so test/uukindlaw.l
; proves the semilattice laws OF the actual analysis, not a hand transcription. Run:
;
;   love tools/kinds2uu.l > test/uukind.l        (or: make uukind)
;
; the encoding is derived from kinds.l's own `rank`: each kind symbol takes its
; rank as its nat code (bot 0 .. top 5), and `str` -- the incomparable branch, off
; rank's table -- takes the next code up. so `rank` folds to identity here, and the
; translation is otherwise structural: ? -> nested bool_rect, = (and id?) -> nateqb,
; < -> natgtb (swapped), && -> andb, num? -> the emitted numq, a `:` -> a let.
; kind symbols appear only quoted in kinds.l ('bot ..), so a bare nom is a variable.
;
; a body-less `:` -- the k2-* vocabulary leaks; none shadows a nif.
(:
   (k2-pairs (a . b . c)) ([a b] . k2-pairs c)
   (k2-find nm ps) <(filter (((^nm . _) . _) \ 1) ps)
   k2-qmark (cap '(\ x))                     ; the \ head a quote wears as data
   (k2-quoted? e) (two? e && <e = k2-qmark)
   (k2-qdat q) (q 1)                         ; the symbol under a quote

   ; --- the code map, read off kinds.l's `rank` (its ? pairs), then str on top ---
   (k2-rankmap body) (: (go cs) (? (one? >cs) ()             ; the trailing -1 else: stop
                          (: c <cs r <>cs
                             sym (k2-qdat (c 2))             ; c = (= k 'SYM)
                             ([sym r] . go >>cs)))
                        (go >body))
   (k2-max l) (foldl (\ a x (a < x ? x a)) 0 l)
   (k2-codes km) (map (p \ p 1) km)
   (k2-upto n) (: (go i) (i < n ? (i . go (i + 1))) (go 0))   ; 0..n-1
   (k2-kc km s) (: p (assoc s km) (two? p ? (p 1) -1))

   ; --- the translation. ty = the uu result type at this position ---
   (k2-tx km e ty)
    (? (charm? e) e
       (k2-quoted? e) (k2-kc km (k2-qdat e))
       (nom? e) e
       (one? e) e
       (: h <e
          (? (h = '?)    (k2-cond km >e ty)
             (h = ':)    (k2-lets km >e ty)
             ; `=` and id? both: kinds.l compares points, and the sweep that made
             ; every such id? an `=` left this reading only the old spelling.
             (h = 'id? || h = '=)
                         ['nateqb (k2-tx km (e 1) 'nat) (k2-tx km (e 2) 'nat)]
             (h = '<)    ['natgtb (k2-tx km (e 2) 'nat) (k2-tx km (e 1) 'nat)]
             (h = '&&)   ['andb (k2-tx km (e 1) 'bool) (k2-tx km (e 2) 'bool)]
             (h = 'rank) (k2-tx km (e 1) ty)     ; code is rank -- fold
             (h = 'num?) ['numq (k2-tx km (e 1) 'nat)]
             'k2-untranslatable)))
   (k2-cond km cs ty)
    (one? >cs ? (k2-tx km <cs ty)                  ; the bare else
     (: c <cs r <>cs
        ['bool_rect ['lam 'gx ty]
         (k2-tx km r ty) (k2-cond km >>cs ty) (k2-tx km c 'bool)]))
   (k2-lets km bs ty)
    (one? >bs ? (k2-tx km <bs ty)                  ; the trailing body
     ['let <bs (k2-tx km <>bs 'nat) (k2-lets km >>bs ty)])

   ; --- assemble one op: (name (pi params) (lam params body)) ---
   (k2-pi ps res) (two? ps ? ['pi <ps 'nat (k2-pi >ps res)] res)
   (k2-lams ps b) (two? ps ? ['lam <ps (k2-lams >ps b)] b)
   (k2-op km ps pr resty ty) [(k2-pi ps resty) (k2-lams ps (k2-tx km (pr 1) ty))]

   ; --- drive: read kinds.l, lift num? and join ---
   fs (forms (open "doc/misc/proto/kinds.l" "r"))
   big <(filter (\ f (two? f && <f = ':)) fs)
   ps (k2-pairs >big)
   km0 (k2-rankmap ((k2-find 'rank ps) 1))
   km  (['str (k2-max (k2-codes km0) + 1)] . km0)          ; str: the branch off rank
   nump (k2-find 'num? ps) joinp (k2-find 'join ps)
   numq  (k2-op km ><nump  nump  'bool 'bool)
   kjoin (k2-op km ><joinp joinp 'nat  'nat)

   (pl s) (puts ("\n" + s))                            ; a line, newline-led
   (pdefn nm op close) (pl (" (defn " + nm),          ; op = (type term); close = ) or ))
                        pl ("   " + show <op),
                        pl ("   " + show (op 1) + close))

   _ (puts "; test/uukind.l -- generated from doc/misc/proto/kinds.l by tools/kinds2uu.l. Do")
   _ (pl "; not edit; refresh with `make uukind`. The abstract kinds-lattice join (and")
   _ (pl "; its num? guard) compiled into uu over a nat-coded carrier, kind = its rank")
   _ (pl "; (str the branch off the spine). test/uukindlaw.l proves the semilattice laws")
   _ (pl "; of these terms at corpus time -- a law-breaking kinds.l edit fails a check.")
   _ (pl "; Substrate: test/uu.l (natgtb / nateqb / andb / bool_rect).")
   _ (pl "(assert")
   _ (pdefn "numq" numq ")")
   _ (pdefn "kjoin" kjoin "))")
   ; the carrier codes 0..str, for the law file (derived, so drift follows kinds.l)
   _ (pl ("(: uk-codes '" + show (k2-upto (k2-max (k2-codes km) + 1))))
   _ (puts ")\n")
   0)
