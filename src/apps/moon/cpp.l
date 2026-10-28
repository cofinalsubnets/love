; src/apps/moon/cpp.l -- the C preprocessor, on clex tokens, so a name inside a literal is never
; a macro. a token is (kind val line); expansion adds a hideset (Prosser's blue paint).
; (cpp toks incf fname) -> (1 out-tokens) | a gripe. (incf name sys?) -> (1 text ..) | () resolves
; a #include, preprocessed on the shared macro table; () incf means no includes.
(module 'moon
(borrow 'kore)
(:
   ; at the head: love0's single-pass compiler folds a pure global at its definition, so one
   ; bound mid-list reads `;; missing m64` in the #if evaluator (only the mooncc0 bake fails)
   inames {}                                       ; a macro name -> its interned string
   guards {}                                       ; a header's path -> (text guard), the guard () when it has none
   m64 18446744073709551616                        ; 2^64: #if arithmetic is 64-bit (C11 6.10.1)
   h64 9223372036854775808                         ; 2^63: intmax's top, so the sign boundary
   b32 4294967296                                  ; 2^32: the limb cbit splits on
   cvv cap                                         ; a #if value is (v u): the pattern, and its two faces
   ; gcc 8.1's attributes: 'do carries it out, 'hint skips exactly, 'no refuses by name (parse's
   ; attrcheck). __has_attribute answers 1 for do/hint; an unknown name is skipped and answers 0
   gnuattrs {"aligned" 'do "packed" 'do "section" 'do "weak" 'do "alias" 'do "always_inline" 'do
             "noinline" 'do "cleanup" 'do "used" 'do "gnu_inline" 'do "musttail" 'do "ms_abi" 'do "holo" 'do
             "unused" 'hint "maybe_unused" 'hint "noreturn" 'hint "cold" 'hint "hot" 'hint "pure" 'hint
             "const" 'hint "format" 'hint "format_arg" 'hint "malloc" 'hint "warn_unused_result" 'hint
             "deprecated" 'hint "nonnull" 'hint "returns_nonnull" 'hint "visibility" 'hint
             "externally_visible" 'hint "noclone" 'hint "noipa" 'hint "optimize" 'hint "target" 'hint
             "designated_init" 'hint "fallthrough" 'hint "no_instrument_function" 'hint
             "no_sanitize" 'hint "no_sanitize_address" 'hint "no_sanitize_undefined" 'hint
             "no_sanitize_thread" 'hint "no_address_safety_analysis" 'hint "no_stack_protector" 'hint
             "stack_protect" 'hint "no_split_stack" 'hint "nonstring" 'hint "assume_aligned" 'hint
             "alloc_size" 'hint "alloc_align" 'hint "sentinel" 'hint "leaf" 'hint "nothrow" 'hint
             "artificial" 'hint "flatten" 'hint "no_reorder" 'hint "error" 'hint "warning" 'hint
             "may_alias" 'hint "warn_if_not_aligned" 'hint "tls_model" 'hint "returns_twice" 'hint
             "noplt" 'hint "nocf_check" 'hint "indirect_branch" 'hint "function_return" 'hint
             "common" 'hint "nocommon" 'hint
             "constructor" 'no "destructor" 'no "ifunc" 'no "weakref" 'no "mode" 'do "vector_size" 'no
             "transparent_union" 'do "naked" 'no "interrupt" 'no "patchable_function_entry" 'do
             ; i386's conventions: gcc ignores them on every target here
             "regparm" 'hint "stdcall" 'hint "fastcall" 'hint "thiscall" 'hint "pcs" 'no
             "long_call" 'no "short_call" 'no "scalar_storage_order" 'no "target_clones" 'no
             "symver" 'no "no_caller_saved_registers" 'no}
   ; an attribute's name, either spelling: __aligned__ is aligned
   (attrname s) (4 < #s && s 0 = 95 && s 1 = 95 && s (#s - 1) = 95 && s (#s - 2) = 95 ? (snip s 2 (#s - 2)) s)
   (attrdoes s) (gnuattrs (attrname s))
   ; the names #if may ask about that are not macros, and that defined() says are there
   hasnames '("__has_attribute" "__has_include" "__has_include_next")
   cvu caup
   ; -- token parts (a clex token is (kind val line); expansion adds a hideset) --
   (kof t) <t
   (vof t) <>t
   (lof t) <>>t
   (hof (_ . _ . _ . h . _)) h                  ; by shape, never a tally: these run per token
   ; a numeric token's source spelling (0777 vs 511, 1u vs 1), which # owes (C11 6.10.3.2).
   ; () on a cpp-minted token, whose value is its spelling. parse reuses the slot
   (sof (_ . _ . _ . _ . s . _)) s
   (spaced? (_ . _ . _ . _ . _ . _ . _)) 1      ; clexw's mark: whitespace followed it
   ; a rebuild hands the mark on; bare drops it, so parse meets the shapes it always has
   (retok t l h) (spaced? t ? [(kof t) (vof t) l h (sof t) 1] [(kof t) (vof t) l h (sof t)])
   (bare t) (? !(spaced? t) t
               !(() = sof t) [(kof t) (vof t) (lof t) (hof t) (sof t)]
               !(() = hof t) [(kof t) (vof t) (lof t) (hof t)]
               [(kof t) (vof t) (lof t)])
   (tok k v l) [k v l]
   ; -- #line (C11 6.10.4) -- the delta rides macs. replace the line, never rebuild with tok,
   ; which would drop sof
   (lndel macs) (peep macs 'lndelta 0 @ d (charm? d ? d 0))
   (lnbump d (p . q . r . s)) (p . q . r + d . s)
   (lnshift macs l)
    (lndel macs @ d
       (d = 0 ? l (: (go k) (atom? k ? () (lnbump d <k . go >k)) (go l))))
   ; -- include markers -- bracket each included run, since spliced line numbers can't say the
   ; file. strcat-pass retires them into spans for parse. 'in carries the header's name, 'out pops.
   (fmin name path) ['fmark 'in name path]
   fmout ['fmark 'out ()]
   (idt? ('id . _)) 1
   ; the value is a guard, never a second pattern variable: `(pv? ('p v) v)` would rebind v
   (idv? ('id . v . _) s) (v = s)
   (pv? ('p . v . _) s) (v = s)
   (kwv? ('kw . v . _) s) (v = s)

   ; -- the spelling of a token, for ## paste and # stringize --
   numks '(num unum lnum ulnum llnum ullnum flo flof iflo)
   (spell t) (: k (kof t) s (sof t)
                (? (0 < #s) s                            ; the spelling the lexer kept
                   (elem k numks) (show (vof t))           ; ..or a cpp-minted decimal
                   (k = 'kw) (show (vof t))
                   (k = 'str) "\"\(vof t)\""
                   (elem k '(wstr str16 str32))                       ; a wide literal, prefix restored
                    "\((? (k = 'wstr) "L\"" (k = 'str16) "u\"" "U\""))\(vof t)\""
                   (vof t)))                          ; id / p are their text
   ; C11 6.10.3.2's stringize: the spelling as is (never re-lexed, so no extra escapes); one
   ; space where the source had any. a stray `\\` outside a literal (gas's macro argument) is one backslash
   (bs? t) (spell t = "\\")
   (spellcat ts) (: (go l acc gap) (? (atom? l) acc
                                      (bs? <l && !(spaced? <l) && two? >l && bs? <>l)
                                       (go >>l "\(acc)\(gap && acc != "" ? " " "")\\" (spaced? <>l))
                                      (go >l (acc + (gap && acc != "" ? " " "") + spell <l)
                                          (spaced? <l)))
                    (go ts "" 0))

   ; -- macro table entries: (obj body) | (fun params body variadic?) --
   (mdef macs name) (macs name)
   ; phase 4 knows no keywords (`#define auto __auto_type`): the table is keyed by text, and
   ; 'kwmac says whether a keyword was ever defined, so a keyword token pays a lookup only then
   (macnm t) (kof t = 'kw ? (show (vof t)) (vof t))
   (macat? t macs) (idt? t ? 1 (kof t = 'kw && macs 'kwmac))
   (pnm t) (idt? t ? (vof t) (kof t = 'kw ? (show (vof t)) ()))   ; a parameter's name: a keyword may be one (gnulib's `signed`)
   (mobj? ('obj . _)) 1
   (mfun? ('fun . _)) 1

   ; -- lex a spelling back into one token (## paste result), keeping the spelling --
   (relex s line)
    (clex s @ [_ (t . _)] [<t <>t line () s])   ; clex answers (1 toks) -- reach inside

   ; -- split off the first logical line (tokens sharing the head's line no.) --
   (linesplit toks) (: ln (lof <toks)
                       (go ts acc) (? (atom? ts) [(rev acc) ()]
                                      (lof <ts = ln) (go >ts (<ts . acc))
                                      [(rev acc) ts])
                       (go toks ()))

   ; -- collect function-macro arguments, ts just after '(': -> (args rest seps close) | ().
   ; commas at depth 1 split; seps are those commas, whose spacing #__VA_ARGS__ spells --
   (collargs ts)
    (: (go ts depth cur args seps)
        (atom? ts ? ()
           (<ts @ t
              (? (depth = 1 && pv? t ")") [(rev (rev cur . args)) >ts (rev seps) t]
                 (depth = 1 && pv? t ",") (go >ts depth () (rev cur . args) (t . seps))
                 (pv? t "(") (go >ts (depth + 1) (t . cur) args seps)
                 (pv? t ")") (go >ts (depth - 1) (t . cur) args seps)
                 (go >ts depth (t . cur) args seps))))
       (go ts 1 () () ()))
   (paramidx params name) (: (go l i) (? (atom? l) -1 (<l = name) i (go >l (i + 1)))
                             (go params 0))

   ; -- ## paste: fold every (p "##") by joining the spellings either side. an empty operand is
   ; a placemarker (C11 6.10.3.3p2): it pastes to anything and vanishes; leftovers drop at the end --
   (pmk? ('pmark . _)) 1
   (paste toks line)
    (!(any (t \ pv? t "##" || pmk? t) toks) ? toks         ; nothing to fold: the list as it came
     (: (nopm l) (? (atom? l) () (pmk? <l) (nopm >l) (<l . nopm >l))
        (go l acc) (? (atom? l) (nopm (rev acc))
                      (pv? <l "##" && two? acc && two? >l)
                       (: a <acc b <>l
                          (? (pmk? a) (go >>l (b . >acc))     ; placemarker ## x -> x
                             (pmk? b) (go >>l acc)             ; x ## placemarker -> x
                             (relex (spell a + spell b) line @ r
                                (go >>l ((r ? r a) . >acc)))))
                      (go >l (<l . acc)))
        (go toks ())))

   ; -- substitute args into a function-macro body: # param stringizes, a ## operand goes in
   ; unexpanded, else the fully-expanded arg; then ## pastes fold --
   (subst mb params args var? line macs seps)
    (: ; each argument expands once (C11 6.10.3.1): a __COUNTER__ in it is one number
       exa {}
       (ex xk xr) (peep exa xk () @ e (two? e ? <e (expand xr macs @ r (pin exa xk [r], r))))
       ; __VA_OPT__'s parenthesised run: (inner-tokens close-token rest) | ()
       (vopt l d acc) (? (atom? l) ()
                         (pv? <l "(") (vopt >l (d + 1) (<l . acc))
                         (pv? <l ")") (d = 1 ? [(rev acc) <l >l] (vopt >l (d - 1) (<l . acc)))
                         (vopt >l d (<l . acc)))
       (go ml q1 q2 acc)                                ; q1 q2: the two body tokens before <ml
        (atom? ml ? (rev acc)
           (<ml @ t
              (? (pv? t "#" && two? >ml)                ; # param -> stringize
                  (: p <>ml
                     pi (paramidx params (pnm p))
                     va (var? && idv? p "__VA_ARGS__")
                     (-1 < pi || va ?
                        (go >>ml p t (tok 'str (spellcat (va ? (vaargs args params seps) (args pi))) line . acc))
                        (go >ml t q1 (t . acc))))
                 ; __VA_OPT__(x): x when the variadic tail has a token, else a placemarker
                 (var? && idv? t "__VA_OPT__" && two? >ml && pv? <>ml "(")
                  (vopt >>ml 1 () @ r
                     (atom? r ? (go >ml t q1 (t . acc))
                        (: sub (two? (vaargs args params seps) ? (subst <r params args var? line macs seps)
                                  [(tok 'pmark "" line)])
                           (go <>>r <>r t (revcat sub acc)))))
                 (-1 < paramidx params (pnm t))                 ; a named parameter
                  (: pi (paramidx params (pnm t))
                     raw (args pi)
                     ; an empty argument beside a ## is a placemarker, not nothing
                     sub (? !(pv? q1 "##" || (two? >ml && pv? <>ml "##")) (ex pi raw)
                            (two? raw) raw
                            [(tok 'pmark "" line)])
                     (go >ml t q1 (revcat sub acc)))
                 (var? && idv? t "__VA_ARGS__")                 ; the variadic tail
                  (: va (vaargs args params seps)
                     prevhh (pv? q1 "##")
                     commahh (prevhh && pv? q2 ",")
                     (? commahh                                 ; GNU `, ## __VA_ARGS__` elision: the ## is a marker, not a paste
                         (>acc @ acc2                       ; drop the ## already emitted (no join)
                            (two? va ? (go >ml t q1 (revcat (ex 'va va) acc2))         ; args present: keep the comma
                               (go >ml t q1 (two? acc2 && pv? <acc2 "," ? >acc2 acc2))))      ; empty: drop the comma too
                        ; a real `## __VA_ARGS__` paste: unexpanded; an empty tail is a placemarker
                        prevhh (go >ml t q1 (revcat (two? va ? va [(tok 'pmark "" line)]) acc))
                        (go >ml t q1 (revcat (ex 'va va) acc))))
                 (go >ml t q1 (t . acc)))))
       (paste (go mb () () ()) line))
   (vaargs args params seps)                        ; the arg token-lists past the named params, comma-joined
    (: np #params
       (skip l k) (k < 1 || atom? l ? l (skip >l (k - 1)))
       (comma c) (two? c && spaced? <c ? ['p "," 0 () () 1] (tok 'p "," 0))
       (join l cs) (? (atom? l) ()
                      (atom? >l) <l
                      (<l + (comma cs . join >l (two? cs ? >cs))))
       (join (skip args np) (skip seps np)))

   ; -- the expander: rescan toks, replacing macro invocations (honoring
   ; hidesets), fully. mutually recursive with subst via expand-of-arg. --
   (expand toks macs)
    (atom? toks ? ()
       (: t <toks rest >toks
          (? !(macat? t macs) (t . expand rest macs)
             (idv? t "__LINE__") (tok 'num (lof t) (lof t) . expand rest macs)
             ; __COUNTER__: per TU, in expansion order, in macs under a key no identifier spells
             (idv? t "__COUNTER__" && !(mdef macs "__COUNTER__"))
              (peep macs "#counter" 0 @ n (pin macs "#counter" (n + 1), tok 'num n (lof t) . expand rest macs))
             ; _Pragma(".."): dropped, but for a pack, left for parse to refuse by name
             (idv? t "_Pragma" && two? rest && pv? <rest "(" && two? >rest && kof <>rest = 'str
              && two? >>rest && pv? <>>rest ")" && !(starts? (vof <>rest) "pack"))
              (expand >>>rest macs)
             ; ..and one a macro spells (the kernel's __diag): expanded first
             (idv? t "_Pragma" && two? rest && pv? <rest "(")
              (collargs >rest @ ca
                 (atom? ca ? (t . expand rest macs)
                    (: x (expand <(<ca) macs)
                       (two? x && atom? >x && kof <x = 'str && !(starts? (vof <x) "pack") && #(<ca) = 1
                          ? (expand <>ca macs)
                          (t . expand rest macs)))))
             (macnm t @ nm
                (mdef macs nm @ m
                   (? (atom? m) (t . expand rest macs)          ; no macro, so no hideset to walk
                      (eleq (iname nm) (hof t)) (t . expand rest macs)  ; blue-painted: leave it
                      (mobj? m)
                       (: hs (iname nm . hof t)
                          body (mapadd <>m hs (lof t) (spaced? t))
                          (expand (body + rest) macs))
                      (mfun? m && two? rest && pv? <rest "(")
                       (collargs >rest @ ca
                          (atom? ca ? (t . expand rest macs)
                             (: args <ca after <>ca
                                params <>m mbody <>>m mvar <>>>m
                                hs (iname nm . hof t)
                                body (subst mbody params args mvar (lof t) macs <>>ca)
                                (expand (mapadd body hs (lof t) (spaced? (ca 3)) + after) macs))))
                      (t . expand rest macs)))))))
   ; give body tokens the hideset + the invocation line; the last takes the invocation's own
   ; spacing (w), not its definition line's end
   (mapadd toks hs line w)
    (atom? toks ? ()
       (<toks @ t
          (atom? >toks ? [(w ? [(kof t) (vof t) line (hunion (hof t) hs) (sof t) 1]
                             [(kof t) (vof t) line (hunion (hof t) hs) (sof t)])]
             (retok t line (hunion (hof t) hs) . mapadd >toks hs line w))))
   ; a hideset holds interned names, found by identity. the union is h's names hs lacks, then
   ; hs; often h is a tail of hs already
   (iname nm) (inames nm @ c (string? c ? c (: _ (pin inames nm nm) nm)))
   (hunion h hs) (? (atom? h) hs
                    (sufq? h hs) hs
                    (: (go l) (? (atom? l) hs (eleq <l hs) (go >l) (<l . go >l)) (go h)))
   (sufq? h l) (? (h == l) 1 (atom? l) 0 (sufq? h >l))
   ; -- #line's operand: a digit sequence, or what one macro-expands to (C11 6.10.4p3).
   ; () when it is neither, which is the directive doing nothing. --
   (lnum body macs)
    (: b (two? body && kof <body = 'num ? body (expand body macs))
       (two? b && kof <b = 'num ? (vof <b)))

   ; -- #if / #elif integer constant-expression evaluation (undefined ids -> 0,
   ; defined X / defined(X) resolved first, then macro-expanded). --
   (resolve-defined ts macs incf)                   ; replace `defined X` / `defined ( X )` with 0/1
    (? (atom? ts) ()
       ; __has_attribute(x): 1 for one mooncc carries out or may skip exactly (gnuattrs)
       (idv? <ts "__has_attribute" && two? >ts && pv? <>ts "(")
        (: r >>ts nm (two? r ? (pnm <r))
           (two? >r && pv? <>r ")" ?
              (tok 'num (attrdoes nm @ d (d = 'do || d = 'hint ? 1 0)) 0 . resolve-defined >>r macs incf)
              (<ts . resolve-defined >ts macs incf)))
       ; __has_include(<h>) / ("h"): whether #include would find it, read without including it
       ((idv? <ts "__has_include" || idv? <ts "__has_include_next") && two? >ts && pv? <>ts "(")
        (: (close l acc) (? (atom? l) () (pv? <l ")") [(rev acc) >l] (close >l (<l . acc)))
           c (close >>ts ())
           (? (atom? c) (<ts . resolve-defined >ts macs incf)
              (: b <c nm (incname b) sys? (two? b && pv? <b "<")
                 (tok 'num (nm && incf && two? (incf nm sys?) ? 1 0) 0 . resolve-defined <>c macs incf))))
       (idv? <ts "defined")
        (>ts @ r
           (? (two? r && pv? <r "(")
               (<>r @ nm
                  (tok 'num (isdef macs nm ? 1 0) 0 . resolve-defined >>>r macs incf))    ; skip ( name )
              (two? r && (idt? <r || kof <r = 'kw))
               (tok 'num (isdef macs <r ? 1 0) 0 . resolve-defined >r macs incf)
              (resolve-defined r macs incf)))
       (<ts . resolve-defined >ts macs incf))
   (isdef macs t) (two? (mdef macs (macnm t)) || elem (pnm t) hasnames)
   (zero-ids ts) (atom? ts ? ()                  ; any surviving identifier is 0
                    (<ts @ t ((idt? t || kof t = 'kw ? (tok 'num 0 0) t) . zero-ids >ts)))
   (ifval ts macs incf) (: r0 (resolve-defined ts macs incf)
                      r1 (expand r0 macs)
                      r2 (zero-ids r1)
                      (ceval (two? (mdef macs "__CHAR_UNSIGNED__") ? r2 (map chsx r2))))
   ; a one-char constant is (char) c, so where plain char is signed '\xc8' is -56, as parse.l reads it
   (chsx t) (kof t = 'num && 127 < vof t && vof t < 256 && chq? t ? (tok 'num (vof t - 256) (lof t)) t)

   ; -- #if's value model (C11 6.10.1) -- (v u): a 64-bit pattern v in [0,2^64) and a
   ; signedness, since love's integers are unbounded: `1UL - 2` must wrap
   (w64 x) (x - m64 * (x // m64) @ r (r < 0 ? (r + m64) r))
   (cv v u) [(w64 v) !!u]
   (csg p) (<p @ v (cvu p || v < h64 ? v (v - m64)))   ; the value as C reads it
   ; truth is `!= 0`, never `0 <`: `#if -1` is true
   (ctrue p) (0 = <p ? 0 1)
   ; love's bit ops answer nothing on a big: split into 32-bit limbs. shifts go through * and //
   (cbit fn x y) (: xh (x // b32) yh (y // b32)
                    (fn xh yh * b32 + fn (x - xh * b32) (y - yh * b32)))
   (cru a b) (cvu a || cvu b ? 1 0)          ; the usual arithmetic conversions, one rank
   (cbin f a b) (cv (f (cvv a) (cvv b)) (cru a b)) ; + - * and the bitwise trio: two's complement is blind to sign
   (cabs x) (x < 0 ? -x x)
   (ctdiv a b) (cabs a // cabs b @ q ((a < 0) = (b < 0) ? q -q))    ; C truncates toward zero
   (cdiv a b) (: va (cvv a) vb (cvv b) u (cru a b)
                 (? (vb = 0) (cv 0 u)              ; a divide by zero is ub; answer 0 rather than raise
                    u (cv (va // vb) 1)
                    (cv (ctdiv (csg a) (csg b)) 0)))
   (cmod a b) (: va (cvv a) vb (cvv b) u (cru a b)
                 (? (vb = 0) (cv 0 u)
                    u (cv (va - (va // vb) * vb) 1)
                    (: x (csg a) y (csg b) (cv (x - ctdiv x y * y) 0))))
   ; a shift takes the left operand's type -- no conversion pairs the two here
   (cshift a b left)
    (: p (cvv b @ k (64 <= k ? 0 (k 2)))       ; 2**k, and a shift past the word is 0
       (? (p = 0) (cv 0 (cvu a))
          left (cv (cvv a * p) (cvu a))
          (cvu a || 0 <= csg a) (cv (cvv a // p) (cvu a))
          (csg a @ s (cv -((-s + p - 1) // p) 0))))   ; arithmetic: floor, gcc's answer
   (ccmp f a b) (cru a b @ u
                   (cv (f (u ? (cvv a) (csg a)) (u ? (cvv b) (csg b)) ? 1 0) 0))

   ; a tiny precedence-climbing evaluator over cpp number tokens -> a (v u) value.
   (cprim ts)
    (atom? ts ? [(cv 0 0) ()]
       (<ts @ t
          (? (elem (kof t) '(num unum lnum ulnum llnum ullnum))
              ; a U suffix says unsigned, and so does a value past intmax's top --
              ; 0xffffffffffffffff has no signed type to land in (C11 6.4.4.1)
              [(cv (vof t) (elem (kof t) '(unum ulnum ullnum) || h64 <= vof t)) >ts]
             (pv? t "(") (ccond >ts @ r (two? <>r && pv? <<>r ")" ? [<r ><>r] r))
             (pv? t "!") (cprim >ts @ r [(cv !(ctrue <r) 0) <>r])
             (pv? t "~") (cprim >ts @ r [(cv (m64 - 1 - cvv <r) (cvu <r)) <>r])
             (pv? t "-") (cprim >ts @ r [(cv -(cvv <r) (cvu <r)) <>r])
             (pv? t "+") (cprim >ts)
             [(cv 0 0) >ts])))
   (clevel sub ops ts)
    (: r (sub ts)
       (go v rest) (: t (two? rest ? <rest)
                      hit (two? t ? (cassoc (kof t) (vof t) ops))
                      (!hit ? [v rest]
                         (sub >rest @ r2 (go (hit v <r2) <>r2))))
       (go <r <>r))
   (cassoc k v ops) (: (go l) (? (atom? l) () (<<l = k && <><l = v) <>><l (go >l))
                       (go ops))
   (cmul ts) (clevel cprim [['p "*" (a \ b \ cbin (x \ y \ x * y) a b)]
                             ['p "/" cdiv] ['p "%" cmod]] ts)
   (cadd ts) (clevel cmul [['p "+" (a \ b \ cbin (x \ y \ x + y) a b)]
                            ['p "-" (a \ b \ cbin (x \ y \ x - y) a b)]] ts)
   (cshl ts) (clevel cadd [['p "<<" (a \ b \ cshift a b 1)] ['p ">>" (a \ b \ cshift a b 0)]] ts)
   (crel ts) (clevel cshl [['p "<" (a \ b \ ccmp (x \ y \ x < y) a b)]
                            ['p "<=" (a \ b \ ccmp (x \ y \ x <= y) a b)]
                            ['p ">" (a \ b \ ccmp (x \ y \ y < x) a b)]
                            ['p ">=" (a \ b \ ccmp (x \ y \ y <= x) a b)]] ts)
   (ceq ts) (clevel crel [['p "==" (a \ b \ ccmp (x \ y \ x = y) a b)]
                           ['p "!=" (a \ b \ ccmp (x \ y \ x != y) a b)]] ts)
   (cband ts) (clevel ceq [['p "&" (a \ b \ cbin (x \ y \ cbit (p \ q \ p & q) x y) a b)]] ts)
   (cbxor ts) (clevel cband [['p "^" (a \ b \ cbin (x \ y \ cbit (p \ q \ p ^ q) x y) a b)]] ts)
   (cbor ts) (clevel cbxor [['p "|" (a \ b \ cbin (x \ y \ cbit (p \ q \ p | q) x y) a b)]] ts)
   (cland ts) (: r (cbor ts)
                 (go v rest) (two? rest && pv? <rest "&&" ?
                                (cbor >rest @ r2 (go (cv (ctrue v && ctrue <r2 ? 1 0) 0) <>r2))
                                [v rest])
                 (go <r <>r))
   (clor ts) (: r (cland ts)
                (go v rest) (two? rest && pv? <rest "||" ?
                               (cland >rest @ r2 (go (cv (ctrue v || ctrue <r2 ? 1 0) 0) <>r2))
                               [v rest])
                (go <r <>r))
   (ccond ts) (clor ts @ r
                 (two? <>r && pv? <<>r "?" ?
                    (ccond ><>r @ rt
                       (two? <>rt && pv? <<>rt ":" ?
                          (ccond ><>rt @ re [(ctrue <r ? <rt <re) <>re])
                          r))
                    r))
   (ceval ts) (ctrue <(ccond ts))                  ; the bit -- docond only ever wanted truth

   ; -- parse a #define body into a macro entry --
   (defmacro macs line-toks)                        ; line-toks: after the leading (# define)
    (atom? line-toks ? ()
       (: name (macnm <line-toks)
          _ (kof <line-toks = 'kw ? (pin macs 'kwmac 1))
          r >line-toks
          ; function-like only if '(' is glued to the name (the lexer's 4th field):
          ; `#define F(x)` vs `#define EOF (-1)`
          (two? r && pv? <r "(" && <>>><r ?
              (defparams >r () () @ pr
                 (atom? pr ? ()
                    (: params <pr var? <>pr body <>>pr
                       (pin macs name ['fun params body var?], 1))))
             (pin macs name ['obj r], 1))))
   (defparams ts params var?)                        ; -> (params variadic? body) | () ; ts after '('
    (? (atom? ts) ()
       (pv? <ts ")") [(rev params) var? >ts]    ; F() -- empty params; body follows the )
       (pv? <ts "...") (>ts @ r (two? r && pv? <r ")" ? [(rev params) 1 >r]))
       (pnm <ts)
        (: nm (pnm <ts) r >ts
           (? (two? r && pv? <r ",") (defparams >r (nm . params) var?)
              (two? r && pv? <r ")") [(rev (nm . params)) var? >r]
              ; gcc's named tail `fmt...`: __VA_ARGS__ under another name
              (two? r && pv? <r "..." && two? >r && pv? <>r ")")
               [(rev params) 1 (map (t \ idv? t nm ? ('id . "__VA_ARGS__" . >>t) t) >>r)]
              ()))
       ())

   ; #pragma pack's operand: () | (N) | (push[, N]) | (pop[, N]), the stack under "#pack" (its
   ; head the cap in force). -> the cap now in force | () when the operand is none of those
   (dopack macs b)
    (: stk (peep macs "#pack" [0])
       (num? t) (kof t = 'num && elem (vof t) '(1 2 4 8 16))
       (set stk2) (pin macs "#pack" stk2, <stk2)
       (shut? l) (two? l && pv? <l ")")
       n #b
       (? !(two? b && pv? <b "(") ()
          (n = 2 && shut? >b) (set (0 . >stk))
          (n = 3 && num? <>b && shut? >>b) (set (vof <>b . >stk))
          (n = 3 && idv? <>b "push" && shut? >>b) (set (<stk . stk))
          (n = 5 && idv? <>b "push" && pv? <>>b "," && num? <>>>b && shut? >>>>b) (set (vof <>>>b . stk))
          (n = 3 && idv? <>b "pop" && shut? >>b) (set (two? >stk ? >stk [0]))
          ()))
   ; -- #pragma push_macro/pop_macro: a per-name stack in macs under a key no identifier spells,
   ; each cell the entry saved (() = undefined). a pop with nothing saved does nothing, as gcc --
   (pragmac? body) (two? body && idt? <body &&
                    elem (vof <body) '("push_macro" "pop_macro"))
   (dopragmac macs body)
    (>body @ r
       (!(two? r && pv? <r "(" && two? >r && (kof <>r = 'str) &&
         two? >>r && pv? <>>r ")") ? ()
          (: nm (vof <>r) key "#save:\(nm)" stk (macs key)
             (? (vof <body = "push_macro") (pin macs key (mdef macs nm . stk))
                (two? stk) (pin macs nm <stk, pin macs key >stk)
                ()))))

   ; -- adjacent string literal concatenation (phase 6) --
   ; also retires the file marks, stashing their spans ((index file)..) in spanacc rather than
   ; returning them, so this per-token pass keeps its shape. the join sees through a mark (a
   ; header may be bare string literals); a mark consumed mid-join takes effect after the merged
   ; token. a narrow piece joins a wide one as its kind (C11 6.4.5p5); two wide keep the first
   (strk? k) (elem k '(str wstr str16 str32))
   (jork a b) (? (a = b) a (a = 'str) b (b = 'str) a a)
   (fmark? ('fmark . _)) 1
   (fmpush t files) (vof t = 'in ? (lof t . files) >files)
   (fmtop files) (two? files ? <files)
   spanacc {}                               ; the spans, reversed, of the strcat-pass now running
   (spanat n files) (pin spanacc 'l ([n (fmtop files)] . spanacc 'l))
   ; -> the rest after a run of marks, and the file stack they leave
   (skipfm ts files) (two? ts && fmark? <ts ? (skipfm >ts (fmpush <ts files)) [ts files])
   ; fin finishes each token: bare for C, which parse reads; an assembly source keeps the
   ; whitespace marks, so asmspell spaces where the source did
   (strcat-pass ts n files fin)
    (atom? ts ? ()
       (<ts @ t
          (? (fmark? t)
              (fmpush t files @ fs (spanat n fs, strcat-pass >ts n fs fin))
             !(strk? (kof t)) (fin t . strcat-pass >ts (n + 1) files fin)
             (: sr (skipfm >ts files) nxt <sr fs <>sr
                (!(two? nxt && strk? (kof <nxt)) ? (fin t . strcat-pass >ts (n + 1) files fin)
                   ; the marks we just consumed take effect after the merged token
                   (? (fmtop fs = fmtop files) () (spanat (n + 1) fs),
                    strcat-pass (tok (jork (kof t) (kof <nxt)) (vof t + vof <nxt) (lof t) . >nxt) n fs fin))))))

   ; -- the driver: walk logical lines, run directives, expand active code. macs is a mutable
   ; tablet shared with includes; cond a stack of (active taken line); buf the pending active tokens --
   (dirname t) (t @ ('kw . q . _) (show q) (_ . q . _) q) ; #if/#else lex as keywords -> their text
   ; the refusal channel: gripeat mints a gripe at the failing directive; gripein stamps the
   ; file on the way out of an #include
   (gripeat line msg) (gripe () (two? line ? (lof <line) ()) () msg)
   (gripein g f) (<>g ? g (gripe f <>>g <>>>g <>>>>g))
   (condactive cond) (atom? cond ? 1 <<cond)
   (parentactive cond) (atom? cond ? 1 <<cond)
   ; buf accumulates reversed (a run can be ~50k tokens); tokflush restores order. not `flush`,
   ; which would shadow the core port
   (tokflush buf macs out) (revcat (expand (rev buf) macs) out)
   ; -- the header memo -- a TU's first include is recorded as (path text pre toks post deps);
   ; a later TU matching path, text and pre-state replays the tokens and table. __FILE__ is held
   ; out of the snapshots, and mleak? declines a header that expanded it
   memo {}                                       ; 'l -> the entries, newest first
   ; the files a TU's #includes opened, newest first, for -MD; a memo entry carries its share
   cppdeps {}
   (mkey? k) (string? k && !(k = "__FILE__"))
   (msnap macs)                                  ; the table as a value `=` can compare
    (sortby (a \ b \ <a <= <b)
            (foldl (acc \ k \ mkey? k ? (acc + [[k (macs k)]]) acc) () (keys macs)))
   ; a header only adds or blanks names, so pinning the post pairs over a matching table
   ; reproduces it exactly
   (mrestore macs snap) (foldl (_ \ e \ (pin macs <e <>e, 0)) 0 snap)
   (mleak? toks fname) (any (t \ (kof t = 'str) && (vof t = fname)) toks)
   ; compared, never digested: cheaper than hashing. the key cannot see the -I list, so it
   ; assumes a process never compiles one -D set under two search paths
   (mfind ip txt pre)
    (: (go l) (atom? l ? ()
                 (<l @ e (ip = <e && txt = <>e && pre = <>>e ? e (go >l))))
       (go (memo 'l)))
   ; bounded, oldest dropped: a handful covers a build
   (mput e) (pin memo 'l (e . mfew (memo 'l) 3))
   (mfew l n) (n < 1 || atom? l ? () (<l . mfew >l (n - 1)))

   ; a function-like macro, or an object-like one whose text ends in one (`#define cpu_to_le64 __cpu_to_le64`)
   (fnish? d macs k) (? (mfun? d) 1
                        (k < 1 || !(mobj? d) || !(two? <>d)) ()
                        (last <>d @ t (macat? t macs && fnish? (mdef macs (macnm t)) macs (k - 1))))
   ; buf (reversed) ends inside a call of a function-like macro: an unmatched ( right after its name
   (callopen? buf macs)
    (: (go l d) (? (atom? l) 0
                   (pv? <l ")") (go >l (d + 1))
                   (pv? <l "(") (? (0 < d) (go >l (d - 1))
                                    (two? >l && macat? <>l macs && fnish? (mdef macs (macnm <>l)) macs 8) 1
                                    (go >l 0))
                   (go >l d))
       (go buf 0))
   (cppgo toks macs cond buf out incf)
    (atom? toks ? (two? cond ? (gripe () <>><cond () "unterminated #if -- no #endif")
                        (rev (tokflush buf macs out)))
       (: ls (linesplit toks) line <ls rest <>ls
          (? (pv? <line "#")
              (: dir (two? >line ? (dirname <>line))   ; if/else are keywords; the rest ids
                 ; inside a function-like macro's open argument list the run is held, as
                 ; gcc reads it, never across an #include
                 held (dir != "include" && callopen? buf macs)
                 out1 (held ? out (tokflush buf macs out))
                 nb (held ? buf ())
                 dirk (two? >line ? (kof <>line))      ; ..and its kind, which is how a line marker is known
                 body >>line
                 ; the #line shift lands here too, or `#if __LINE__` reads the physical
                 ; line; `line` stays raw
                 sline (lnshift macs line)
                 sbody (two? sline ? >>sline)
                 (? (elem dir '("if" "ifdef" "ifndef" "elif" "else" "endif"))
                     (docond dir sbody sline macs cond incf @ cond2
                        (cond2 = 'err ? (gripeat sline "#\(dir) without #if")   ; unbalanced -- fatal, not empty
                           (cppgo rest macs cond2 nb out1 incf)))
                    !(condactive cond) (cppgo rest macs cond nb out1 incf)      ; skipped: ignore non-cond directives
                    (dir = "define") (defmacro macs body, cppgo rest macs cond nb out1 incf)
                    (dir = "undef") (pin macs (macnm <body) (), cppgo rest macs cond nb out1 incf)
                    (dir = "include") (doinc body macs cond out1 rest incf)
                    ; say the text: an #error is the program's own words
                    (dir = "error") (gripeat sline "#error: \(spellcat body)")
                    ; a #warning is not fatal (glibc and gnulib deprecate through it); said unlocated
                    (dir = "warning")
                     (say err "cc: warning: \(spellcat body)\n",
                      cppgo rest macs cond nb out1 incf)
                    (dir = "pragma" && pragmac? body)
                     (dopragmac macs body, cppgo rest macs cond nb out1 incf)
                    ; #pragma pack: the stack rides macs, and the cap in force goes down the stream
                    ; as a ('pack N) mark parse takes between top-level forms (0, no cap)
                    (dir = "pragma" && two? body && idv? <body "pack")
                     (dopack macs >body @ n
                        (? (charm? n) (cppgo rest macs cond nb (['pack n (lof <sline)] . out1) incf)
                           (gripeat sline "#pragma pack\(spellcat >body) is not one mooncc reads")))
                    ; #line N ["file"]: a token at physical P reports P + (N - L - 1); the file
                    ; is dropped. an operand not a digit sequence is macro-expanded (C11 6.10.4p3)
                    (dir = "line")
                     (lnum body macs @ n
                        (n ? (pin macs 'lndelta (n - lof <line - 1)) 0,
                         cppgo rest macs cond nb out1 incf))
                    ; ignored: the null directive `#` (C11 6.10.7) and gcc -E's line marker
                    (elem dir '("pragma" "ident" "sccs" "assert" "unassert") ||
                        atom? >line || dirk = 'num)
                     (cppgo rest macs cond nb out1 incf)
                    ; anything else is refused (#include_next, `#cmakedefine`); an assembler
                    ; source keeps it as text (a device tree's #address-cells)
                    (two? (mdef macs "__ASSEMBLER__")) (lnshift macs line @ sl
                        (held ? (cppgo rest macs cond (revcat sl buf) out incf) (cppgo rest macs cond () (revcat sl out1) incf)))
                    (gripeat sline "invalid preprocessing directive #\(spellcat [<>line])")))
             !(condactive cond) (cppgo rest macs cond buf out incf)                    ; skipped code: drop
             (cppgo rest macs cond (revcat (lnshift macs line) buf) out incf))))         ; active code: accumulate (reversed)

   ; the conditional stack. a frame is (active taken line), line the #if's own, carried by
   ; #elif/#else so an unterminated one can be named
   (docond dir body line macs cond incf)
    (? (elem dir '("if" "ifdef" "ifndef"))
        (: pa (condactive cond)                        ; parent active?
           v (? !pa 0
                (dir = "ifdef") (isdef macs <body ? 1 0)
                (dir = "ifndef") (isdef macs <body ? 0 1)
                !!(0 < ifval body macs incf))
           ([(pa && 0 < v) (pa && 0 < v) (lof <line)] . cond))
       (dir = "elif")
        (atom? cond ? 'err
           (: fr <cond pa (parentactive >cond) taken <>fr
              v (!taken && pa && 0 < ifval body macs incf)
              ([(!taken && pa && 0 < v) (taken || 0 < v) <>>fr] . >cond)))
       (dir = "else")
        (atom? cond ? 'err
           (: fr <cond pa (parentactive >cond) taken <>fr
              ([(!taken && pa) 1 <>>fr] . >cond)))
       (dir = "endif") (two? cond ? >cond 'err)
       'err)

   ; #include: resolve via incf, lex, preprocess on the shared macs. incf may answer
   ; (1 text child-incf path): the child finds the header's quote includes beside it, as gcc
   (doinc body macs cond out rest incf)
    (!(condactive cond) ? (cppgo rest macs cond () out incf)
       ; the third form (C89 6.8.2): other tokens macro-expand to <h> or "h"
       (: b (incname body ? body (expand body macs))
          sys? (two? b && pv? <b "<")
          name (incname b)
          txt (name ? (incf name sys?))
          spelt (sys? ? "<\(name)>" "\"\(name)\"")
          ; only a TU's first include is a memo candidate: a deeper one's pre-state is its includer's
          nth (peep macs 'ninc 0)
          (pin macs 'ninc (nth + 1),
           atom? txt ? (gripeat body "cannot resolve #include \(spelt)")      ; unresolved -> fatal
             (: ipath (3 < #txt ? <>>>txt "")   ; incload's resolved path; "" from a bare (1 text)
                ; #pragma once: a header that says it is read once per TU, by its folded path
                okey "#once:\(pnorm ipath)"
                seen (0 < #ipath && two? (macs okey))
                _ (!seen && 0 < #ipath && oncep <>txt && pin macs okey [1])
                pre (nth = 0 ? (msnap macs))
                got (nth = 0 ? (mfind ipath <>txt pre))
                ; the marks bracket the header's run (out is reversed); minted here, never memoized
                (rejoin toks)
                 (cppgo rest macs cond () (fmout . rev toks + (fmin name ipath . out)) incf)
                d0 #(peep cppdeps 'l ())
                (? seen (cppgo rest macs cond () out incf)
                   (two? got) (mrestore macs <>>>>got, pin cppdeps 'l (got 5 + peep cppdeps 'l ()), rejoin <>>>got)
                   (: _ (0 < #ipath && pin cppdeps 'l (ipath . peep cppdeps 'l ()))
                   (lexinc ipath <>txt macs @ lr
                      ; okv?, not two?: a gripe is a pair. a located gripe is the header's;
                      ; a bare one stays at the #include
                      (!(okv? lr) ? (gripe? lr ? (gripein lr name) (gripeat body "lex error in \(spelt)"))
                         (: itoks <>lr
                            chf (<>>txt @ c (c ? c incf))
                            ; the #line delta is the header's own: saved across the recursion
                            sv (lndel macs)
                            _ (pin macs 'lndelta 0)
                            raw (cppgo itoks macs () () () chf)       ; recurse with fresh cond; shares macs
                            (pin macs 'lndelta sv,
                            ; a nested failure propagates up wearing its file; never answer (),
                            ; which reads as an empty include
                             gripe? raw ? (gripein raw name)
                               (? (nth = 0 && !(mleak? raw (peep macs 'fname "")))
                                  (mput [ipath <>txt pre raw (msnap macs)
                                         (peep cppdeps 'l () @ l (take (#l - d0) l))]) 0,
                                rejoin raw)))))))))))
   ; a path with . and .. folded away: "a/sys/../b.h" and "a/b.h" are one key; a leading /
   ; and a .. with nothing left to fold stay
   (pnorm p)
    (: n #p
       (go i st ps) (? (n < i) ps
                       (i = n || p i = 47)
                        (snip p st i @ c
                         (go (i + 1) (i + 1)
                          (c @ ("" || ".") ps
                               ".." (two? ps && <ps != ".." ? >ps (c . ps))
                               (c . ps))))
                       (go (i + 1) st ps))
       (jn l a) (!(two? l) ? a (jn >l (<l + (#a ? "/\(a)" a))))
       ((0 < n && p 0 = 47 ? "/" "") + jn (go 0 0 ()) ""))
   ; does a header's text say `#pragma once` on a line of its own?
   (oncep s)
    (: (ws? c) (c = 32 || c = 9)
       (skip i) (i < #s && ws? (s i) ? (skip (i + 1)) i)
       (word? i w) (: n #w (i + n <= #s && snip s i (i + n) = w))
       (line i) (: a (skip i)
                   (a < #s && s a = 35 &&
                    (skip (a + 1) @ b (word? b "pragma" && (skip (b + 6) @ c (c > b + 6 && word? c "once"))))))
       (go i) (? (#s <= i) ()
                 (line i) 1
                 (: j (go2 i) (go (j + 1))))
       (go2 i) (i < #s && s i != 10 ? (go2 (i + 1)) i)
       (go 0))
   ; -- the multiple-include rule: a header wholly inside `#ifndef G .. #endif` reads as nothing
   ; once G is defined (the marks still bracket it). an assembly source's headers lex as assembly --
   (lexinc ip txt macs)
    (peep guards ip () @ e
       (? (two? e && <e = txt && two? (mdef macs <>e)) [1 ()]
          ((two? (mdef macs "__ASSEMBLER__") ? (clexasm txt 1 (armgas? macs)) (clexw txt 1)) @ lr
             (: _ (okv? lr && 0 < #ip && pin guards ip [txt (guardof <>lr)])
                lr))))
   (armgas? macs) (two? (mdef macs "__aarch64__") || two? (mdef macs "__arm__"))  ; `#` past code marks an immediate
   (dirat? l) (two? l && pv? <l "#" && two? >l)      ; l opens a directive, its name next
   (guardof ts)
    (: (go l ln d)                                   ; d: the conditional depth, 1 inside the guard
        (? (atom? l) ()
           (lof <l = ln) (go >l ln d)                ; the rest of a line already read
           !(dirat? l) (go >l (lof <l) d)
           (dirname <>l @ dn
              (? (elem dn '("if" "ifdef" "ifndef")) (go >l (lof <l) (d + 1))
                 (dn = "endif") (d = 1 ? (tail >l (lof <l)) (go >l (lof <l) (d - 1)))
                 (d = 1 && elem dn '("else" "elif")) ()
                 (go >l (lof <l) d))))
       (tail l ln) (? (atom? l) 1 (lof <l = ln) (tail >l ln) ())
       (dirat? ts && dirname <>ts = "ifndef" && two? >>ts && idt? <>>ts &&
        (atom? >>>ts || lof <>>>ts != lof <ts) && go >>>ts (lof <ts) 1 ? (vof <>>ts)))
   (incname body)                                     ; the header name from #include tokens
    (? (atom? body) ()
       (kof <body = 'str) (vof <body)         ; "file"
       (pv? <body "<") (: (go l acc) (? (atom? l) () (pv? <l ">") acc (go >l (acc + spell <l))) (go >body ""))
       ())

   ; the table a TU's preprocessing starts from: the language's and the compiler's predefines
   (cppmacs fname)
           ({} @ t
               (pin t "__STDC__" ['obj [(tok 'num 1 0)]],
               ; who is compiling: a source picks a spelling only mooncc takes (the kernel's asmops.h)
                pin t "__mooncc__" ['obj [(tok 'num 1 0)]],
               ; __FILE__: the TU's path throughout, includes too
                pin t "__FILE__" ['obj [(tok 'str fname 0)]],
                pin t 'fname fname,      ; the same name unwrapped, for the memo's leak check
               ; C11; 201112 lets gnulib take its _Static_assert lane
                pin t "__STDC_VERSION__" ['obj [(tok 'num 201112 0)]],
               ; hosted: love.c takes its hosted lanes (the w^x code arena)
                pin t "__STDC_HOSTED__" ['obj [(tok 'num 1 0)]],
               ; the arch, OS, __sizeof_int128__ and word-width limits are the driver's
               ; (moon.l), down the -D channel. cpp says the language and the compiler
                pin t "__INT_MAX__" ['obj [(tok 'num 2147483647 0)]],
               ; flt_max exactly, (2 - 2^-23) * 2^127
                pin t "__FLT_MAX__" ['obj [(tok 'flo ((2.0 - 1.0 / 8388608.0) * 127 2.0) 0)]],
               ; dbl_max, (2 - 2^-52) * 2^1023
                pin t "__DBL_MAX__" ['obj [(tok 'flo ((2.0 - 1.0 / 4503599627370496.0) * 1023 2.0) 0)]],
               ; bool/true/false are the driver's (moon.l cc-defs)
                t))
   (cpp toks incf fname) (cpp-fin toks incf fname bare)   ; -> (1 out) | a gripe (test with okv?, never two?)
   (cppasm toks incf fname) (cpp-fin toks incf fname (t \ t))
   (cpp-fin toks incf fname fin)
    (: macs (cppmacs fname)
       r (cppgo toks macs () () () incf)
       ; the spans ride the head as one 'fspans token, so cpp keeps its (1 out) channel
       (gripe? r ? r
          (: _ (pin spanacc 'l ())
             out (strcat-pass r 0 () fin)
             [1 (tok 'fspans (rev (spanacc 'l)) 0 . out)])))       ; an empty list is a valid empty TU

   ; -E: the TU as text in gcc -E's shape: tokens by line, a `# N "file"` marker where the file
   ; changes or the line jumps. -> (1 text) | a gripe. a space goes back where the source had one
   ; or where two tokens would lex as others (gcc's rule): pastes? asks that
   cpuncts '("->" "++" "--" "<<" ">>" "<=" ">=" "==" "!=" "&&" "||" "*=" "/=" "%=" "+=" "-="
             "&=" "^=" "|=" "##" "<<=" ">>=" "...")
   (wordc? c) (c = 95 || 48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122 || 127 < c)
   (pastes? x y)
    (? (#x < 1 || #y < 1) ()
       (: c (y 0) z (x (#x - 1)) xy (x + string c) n #xy
          (? (wordc? z && (wordc? c || c = 34 || c = 39)) 1
             ((48 <= x 0 <= 57 || x 0 = 46) && (c = 46 || (c = 43 || c = 45) && elem z '(101 69 112 80))) 1
             (z = 46 && 48 <= c <= 57) 1
             (z = 47 && (c = 47 || c = 42)) 1
             (any (p \ n <= #p && snip p 0 n = xy) cpuncts))))
   (cpp-text toks incf fname)
    (: r (cppgo toks (cppmacs fname) () () () incf)
       (qesc s) "\"\(string (catmap (c \ (c @ 34 [92 34] 92 [92 92] 10 [92 110] 9 [92 116]
                                                   (c < 32 || 126 < c ? (c & 255 @ o [92 (48 + (o >> 6)) (48 + ((o >> 3) & 7)) (48 + (o & 7))]) [c])))
                                        (chars s)))\""
       (sp t) (? (kof t = 'str) (0 < #(sof t) ? (sof t) (qesc (vof t))) (spell t))
       (mark l f) "\n# \(l < 1 ? 1 l) \"\(f)\"\n"
       ; files: the stack of open paths; cl the line the text stands on, cf its file
       (go ts files cl cf acc prev)
        (atom? ts ? (join "" (rev ("\n" . acc)))
           (<ts @ t
              (? (fmark? t) (vof t = 'in ? (go >ts ((t 3) . files) 1 (t 3) (mark 1 (t 3) . acc) ())
                                             (go >ts >files 0 () acc ()))
                 (elem (kof t) '(pmark pack)) (go >ts files cl cf acc prev)
                 (: f (two? files ? <files fname) l (lof t)
                    (? (f != cf || l < cl || cl + 8 < l) (go >ts files l f (sp t . mark l f . acc) t)
                       (l > cl) (go >ts files l f (sp t . string (map (_ \ 10) ^(l - cl)) . acc) t)
                       (two? prev && !(spaced? prev) && !(pastes? (sp prev) (sp t))) (go >ts files l f (sp t . acc) t)
                       (go >ts files l f (sp t . " " . acc) t))))))
       (gripe? r ? r [1 (go r () 1 fname [(mark 1 fname)] ())])))
) ; module 'moon
