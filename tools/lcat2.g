; lcat2: lcat + variable-name minification. Like lcat, it serializes a gwen
; source file to a C string literal (re-print each top-level form via inspect,
; space-join, drop spaces the reader doesn't need, C-escape). lcat2 ALSO renames
; local variables to short fresh names before re-printing, shrinking the literal.
;
; --- scope-local renaming with name reuse --- the renamer is a scope-threaded
; walk carrying two things down the scope tree:
;   env  = assoc (orig-sym . new-sym), innermost binding first -- a reference is
;          renamed by the nearest enclosing binding (assq), so kept bindings map to
;          themselves and correctly SHADOW an outer renamed binding of the same name.
;   used = the new names live on the CURRENT path (root..here). A scope may not reuse
;          a name in `used` (would capture an outer reference), but SIBLING scopes
;          reset `used`, so two disjoint functions both get `a`. That reuse is the
;          whole point: the scarce 1-char names recycle across the ~dozens of sibling
;          helper scopes instead of being spent globally.
; New names come from a namespace FRESH to the file: shortlex over a-zA-Z (a..z A..Z
; aa ab ..) skipping any name that already occurs as a source symbol (`cnt`) -- so a
; fresh name can only collide with another fresh name, which `used` already forbids.
; Correctness then needs nothing more: a free ref resolves unchanged (fresh names
; dodge every global), a leaking top-level `:` keeps its names (they're the cross-file
; API the assembled headers share), and quote subtrees are data so they're left whole.
;
; --- count-priority --- within each scope the bindings are assigned in occurrence-
; count order (desc): the most-used local claims the shortest available name, since a
; scope's byte cost is sum(count * newlen). A binding is renamed only when its fresh
; name is strictly shorter than the original; otherwise it is kept (mapped to itself
; so shadowing still works) and costs no name.
;
; --- factoring: a macroexpanded core + a thin surface adapter --- the renaming proper
; lives in `mxrn` (below), which is CORRECT FOR MACROEXPANDED INPUT: it knows only the
; core special forms `\` (lambda, and the one-operand quote) and `:` (letrec*), plus
; application -- on expanded input nothing else can bind. That is the piece meant to
; move into the compiler, which already macroexpands. lcat2 works on UN-expanded source,
; so a surface wrapper `rn` adapts the few binding/quote macros the compiler would have
; expanded away: `:-` (body-first let) is reordered to a `:` and back, `let` maps to `:`,
; and `qq` (quasiquote) is passed whole with its symbols `taint`ed so they're never
; renamed (an unquoted ,x is live code we don't rewrite). mxrn takes the recursion as a
; hook `rec`: the compiler calls (mxrn x env used top mxrn); lcat2 passes `rn`, so nested
; macros get adapted too. Macro names are folded into `cnt` so no fresh name can shadow a
; macro head (which the compiler expands by name even past a local binding).

; cnt = every source symbol -> its occurrence count (also the fresh-name avoid-set);
; taint = the frozen set (here: symbols seen under qq). both mutated in place.
(: cnt %() taint %())

; === CORE -- naming-with-reuse for MACROEXPANDED forms (the part destined for the
; compiler). Knows only `\` / `:` / application; recurses through the hook `rec`.
; Inputs are the two globals above: `cnt` (counts = avoid-set + count order) and
; `taint` (frozen symbols -- empty for genuinely macroexpanded input).
;
; TO LIFT INTO THE COMPILER: take this whole CORE block plus the two globals, and
;   * drop the `rec` parameter in favour of self-recursion -- expanded input has no
;     surface macros to intercept, so mxrn just calls mxrn (and rn-let/rn-binds call
;     mxrn). lcat2 only needs `rec` because it feeds in UN-expanded source.
;   * feed `cnt` from the compiler's symbol info (occurrence counts), and leave `taint`
;     empty -- or repurpose it as a general frozen "do not rename" set.
;   * keep relying on the prelude binding-shape helpers lp/lambp/ln (already present).
; The SURFACE block below (collect/tcollect + rn with its :-/let/qq handling) stays in
; lcat2: it is exactly the un-expanded-source adaptation the compiler no longer needs. ===
(: (sl-char d) (? (< d 26) (+ 97 d) (+ 65 (- d 26)))   ; shortlex over a-zA-Z (bijective base-52):
   (sl-digits n acc) (? (< n 1) acc (: m (+ -1 n) (sl-digits (/ m 52) (X (sl-char (mod m 52)) acc))))
   (shortlex k) (string (sl-digits (+ 1 k) 0))         ; 0->a .. 25->z 26->A .. 51->Z 52->aa
   (freshname? nm) (= 0 (get 0 nm cnt))                ; nm occurs as no source symbol
   (avail? nm u) (&& (freshname? nm) !(memq nm u))     ; ..and not live on this path
   (pickname u) ((: (g k) (: nm (intern (shortlex k)) (? (avail? nm u) nm (g (+ 1 k))))) 0)
   (cntle a b) (: ca (get 0 a cnt) cb (get 0 b cnt)    ; order a scope's bindings: count desc,
       (? (> ca cb) 1 (< ca cb) 0                      ; then length desc, then name -- deterministic
          (: la (len (string a)) lb (len (string b)) (? (> la lb) 1 (< la lb) 0 (< a b)))))
   ; assign fresh names to a scope's co-live bindings (count order). a frozen (tainted)
   ; or can't-shrink binding is kept (mapped to itself, no name spent). -> (env-frame . used').
   (assign syms used) ((: (g ss m u) (? (twop ss)
         (: s (A ss) nm (pickname u)
            (? (&& !(get 0 s taint) (< (len nm) (len (string s))))
               (: i (intern nm) (g (B ss) (X (X s i) m) (X i u)))
               (g (B ss) (X (X s s) m) u)))
         (X m u))) (sort cntle syms) 0 used)
   (mapped s m) (: p (assq s m) (? p (B p) s))
   (flat lhs) (? (symp lhs) (X lhs 0) (: r (flat (A lhs)) (X (A r) (cat (B r) (B lhs)))))  ; unwind : head-sugar
   (lhs-rename lhs bmap am) (? (symp lhs) (mapped lhs (cat am bmap))  ; name via bmap, params via am
       (twop lhs) (X (lhs-rename (A lhs) bmap am) (lhs-rename (B lhs) bmap am)) lhs)
   (bodyless? bs) (? (atomp bs) 1 (atomp (B bs)) 0 (bodyless? (BB bs)))
   ; rebuild a : binding list; each binding's sugar params open a fresh sub-scope of its
   ; value (siblings all assign from u1, so their names recycle). recurse via `rec`.
   (rn-binds bs bmap env1 u1 rec) (?
     (&& (twop bs) (twop (B bs)))
       (: lhs (A bs) val (AB bs) f (flat lhs) r (assign (B f) u1) am (A r) u2 (B r)
          penv (cat am env1) lhs2 (lhs-rename lhs bmap am) val2 (rec val penv u2 0 rec)
          (X lhs2 (X val2 (rn-binds (BB bs) bmap env1 u1 rec))))
     (twop bs) (X (rec (A bs) env1 u1 0 rec) 0)         ; trailing body
     0)
   (rn-let bs env used top rec) (: names (ln bs) leak (? top (bodyless? bs) 0)
       r (? leak (X 0 used) (assign names used)) bmap (A r) u1 (B r) env1 (cat bmap env)
       (X ': (rn-binds bs bmap env1 u1 rec)))
   ; the macroexpanded renamer. top=1 only at a file form; a body-less top-level : leaks
   ; (its names are the global API -> kept). env/used thread scope; a one-operand `\`
   ; (quote) is data and is passed whole.
   (mxrn x env used top rec) (?
     (symp x) (mapped x env)
     (atomp x) x
     (= '\ (A x)) (? (lambp x)
        (: lb (lp x) ps (A lb) bd (B lb) r (assign ps used) am (A r) u2 (B r)
           env2 (cat am env) ps2 (map (\ p (mapped p am)) ps)
           (X '\ (cat ps2 (list (rec bd env2 u2 0 rec)))))
        x)
     (= ': (A x)) (rn-let (B x) env used top rec)
     (map (\ e (rec e env used 0 rec)) x)))

; === lcat2 SURFACE -- builds the core's inputs (cnt/taint) from un-expanded source, and
; adapts the binding/quote macros the compiler would have already expanded away. `rn` is
; the recursion the core threads, so nested `:-`/qq are adapted at every level. ===
(: (collect x) (? (symp x) (put x (+ 1 (get 0 x cnt)) cnt)
     (twop x) (? (= 'qq (A x)) (: _ (collect (A x)) (tcollect (B x)))   ; qq body -> taint
                 (: _ (collect (A x)) (collect (B x)))) 0)
   (tcollect x) (? (symp x) (: _ (put x (+ 1 (get 0 x cnt)) cnt) (put x 1 taint))
                    (twop x) (: _ (tcollect (A x)) (tcollect (B x))) 0)
   (rn x env used top rec) (? (twop x)
       (? (= ':- (A x)) (: rl (rn-let (cat (BB x) (list (AB x))) env used top rec)  ; :- = body-first :
             rb (B rl) (X ':- (X (last rb) (init rb))))                             ; reorder body back
          (= 'let (A x)) (rn-let (B x) env used top rec)                            ; let = :
          (= 'qq (A x)) x                                                           ; quasiquote -> whole
          (mxrn x env used top rec))
       (mxrn x env used top rec)))

; --- minify (identical to lcat): drop a space only where the two flanking bytes
; re-parse to the same datum count without it; then C-escape the survivors. ---
(: (s2cl s) ((: (g i) (? (< i (len s)) (X (get 0 i s) (g (+ 1 i))))) 0)
   (nforms s) ((: (g p e n) (: r (fread p e) (? (| (= e r) (= p r)) n (g p e (+ 1 n)))))
               (strin (s2cl s)) (gensym 0) 0)
   (redundant? a b) (= (nforms (string (L a b))) (nforms (string (L a 32 b))))
   (eb c) (? (= c 10) (fputs out "\\n")
              (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
              (fputc out c)))

(: (readforms p e) (: r (fread p e) (? (= e r) 0 (X r (readforms p e))))
   (joinforms fs) (? (atomp fs) "" (atomp (B fs)) (inspect (rn (A fs) 0 0 1 rn))
       (scat (scat (inspect (rn (A fs) 0 0 1 rn)) " ") (joinforms (B fs))))
   (emit acc) (: _ (fputc out 34)
       _ ((: (g i pc instr) (? (< i (len acc))
            (: c (get 0 i acc) (? instr
               (? (= c 92) (: _ (eb c) _ (eb (get 0 (+ i 1) acc)) (g (+ i 2) 0 1))
                  (: _ (eb c) (g (+ i 1) c (? (= c 34) 0 1))))
               (? (= c 32)
                  (? (redundant? pc (get 0 (+ i 1) acc)) (g (+ i 1) pc 0)
                     (: _ (eb c) (g (+ i 1) c 0)))
                  (: _ (eb c) (g (+ i 1) c (= c 34)))))) 0)) 0 0 0)
       (fputc out 34))
   p (open (A (B argv)) "r")
   _ (? p 0 (: _ (fputs err "lcat2: cannot open input") (exit 1)))
   e (gensym 0)
   forms (readforms p e)
   _ (map (\ m (put m (+ 1 (get 0 m cnt)) cnt)) (hashk macros))  ; macro heads bypass scoping
   _ (map collect forms)                                        ; count symbols + taint qq
   acc (joinforms forms)
   _ (emit acc)
   (fputc out 10))
