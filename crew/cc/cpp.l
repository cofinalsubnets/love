; crew/cc/cpp.l -- the C preprocessor (rung 3 stage 5), TOKEN-BASED: it sits
; between clex and cparse, so identifiers inside string/char literals are never
; mistaken for macros (they lexed as one opaque token). a token is (kind val
; line); expansion tacks on a fourth element, a HIDESET (the macros a token may
; no longer be expanded by -- Prosser's blue paint, so FOO expanding to FOO
; stops). the pipeline: text -> clex -> cpp -> cparse. line splicing (\<nl>) and
; # / ## already fell out of the lexer.
;
; (cpp toks incf) -> (1 out-tokens) | (). incf resolves a #include: (incf name
; sys?) -> (1 text) | (), text then lexed and preprocessed sharing the macro
; table (so include guards work); () means no includes (the law harness).
; directives: #define (object + function, # stringize, ## paste, ... variadic
; __VA_ARGS__), #undef, #if/#ifdef/#ifndef/#elif/#else/#endif (with defined and
; an integer constant-expression evaluator, undefined names -> 0), #include,
; #error, #pragma/#line (ignored). predefined __LINE__ __FILE__ __STDC__.
; adjacent string literals concatenate (phase 6). fenced: _Pragma, __COUNTER__,
; the GNU ,##__VA_ARGS__ comma elision, #if with character constants.
(:
   ; -- token parts (a clex token is (kind val line); expansion adds a hideset) --
   (kof t) (cap t)
   (vof t) (caup t)
   (lof t) (cauup t)
   (hof t) (? (< 3 (tally t)) (cap (cup (cup (cup t)))) ())
   (tok k v l) (L k v l)
   (idt? t) (= (kof t) 'id)
   (idv? t v) (&& (= (kof t) 'id) (= (vof t) v))
   (pv? t v) (&& (= (kof t) 'p) (= (vof t) v))
   (kwv? t v) (&& (= (kof t) 'kw) (= (vof t) v))
   (addhide t hs)                                   ; union hs into t's hideset
    (L (kof t) (vof t) (lof t) (dedup (cat (hof t) hs)))
   (dedup l) (: (go l seen) (? (! (two? l)) ()
                              (member? (cap l) seen) (go (cup l) seen)
                              (link (cap l) (go (cup l) (link (cap l) seen))))
                (go l ()))

   ; -- the spelling of a token, for ## paste and # stringize --
   (spell t) (: k (kof t)
                (? (member? k '(num unum ulnum)) (show (vof t))
                   (= k 'kw) (show (vof t))
                   (= k 'str) (+ "\"" (+ (vof t) "\""))
                   (vof t)))                          ; id / p are their text
   (spellraw t) (? (= (kof t) 'str) (vof t) (spell t))  ; string content without the added quotes (for stringize)
   (spellcat ts) (: (go l acc) (? (! (two? l)) acc
                                  (go (cup l) (+ acc (+ (? (= acc "") "" " ") (spellraw (cap l))))))
                    (go ts ""))

   ; -- macro table entries: (obj body) | (fun params body variadic?) --
   (mdef macs name) (peep macs name ())
   (mobj? m) (&& (two? m) (= (cap m) 'obj))
   (mfun? m) (&& (two? m) (= (cap m) 'fun))

   ; -- lex a spelling back into one token (## paste result) --
   (relex s line) (: r (clex s)
                     (? (! (two? r)) ()
                        (: ts (caup r)
                           (? (two? ts) (tok (kof (cap ts)) (vof (cap ts)) line) ()))))

   ; -- split off the first LOGICAL line (tokens sharing the head's line no.) --
   (linesplit toks) (: ln (lof (cap toks))
                       (go ts acc) (? (! (two? ts)) (L (rev acc) ())
                                      (= (lof (cap ts)) ln) (go (cup ts) (link (cap ts) acc))
                                      (L (rev acc) ts))
                       (go toks ()))

   ; -- collect function-macro arguments: TS is positioned just after '('.
   ; returns (args rest) with args a list of token-lists (commas at depth 1
   ; split; nested parens preserved), rest past the closing ')'. () on error. --
   (collargs ts)
    (: (go ts depth cur args)
        (? (! (two? ts)) ()
           (: t (cap ts)
              (? (&& (= depth 1) (pv? t ")")) (L (rev (link (rev cur) args)) (cup ts))
                 (&& (= depth 1) (pv? t ",")) (go (cup ts) depth () (link (rev cur) args))
                 (pv? t "(") (go (cup ts) (+ depth 1) (link t cur) args)
                 (pv? t ")") (go (cup ts) (- depth 1) (link t cur) args)
                 (go (cup ts) depth (link t cur) args))))
       (go ts 1 () ()))
   (argn args i) (: (go l k) (? (! (two? l)) () (< k 1) (cap l) (go (cup l) (- k 1))) (go args i))
   (paramidx params name) (: (go l i) (? (! (two? l)) -1 (= (cap l) name) i (go (cup l) (+ i 1)))
                             (go params 0))

   ; -- ## paste: fold a token list, pasting across every (p "##") by joining
   ; the previous result token's spelling with the next token's. --
   (paste toks line)
    (: (go l acc) (? (! (two? l)) (rev acc)
                     (&& (pv? (cap l) "##") (&& (two? acc) (two? (cup l))))
                      (: a (cap acc) b (cap (cup l))
                         r (relex (+ (spell a) (spell b)) line)
                         (go (cup (cup l)) (link (? r r a) (cup acc))))
                     (go (cup l) (link (cap l) acc)))
       (go toks ()))

   ; -- substitute args into a function-macro body. a param preceded by # is
   ; stringized; a param that is an operand of ## substitutes UNEXPANDED; else
   ; it substitutes the fully-expanded arg. then ## pastes are folded. --
   ; (adjh is a closure-local, not a sibling -- a lambda PARAMETER named after a
   ; sibling :-local gets shadowed by boxfix's shared cell, so the macro-body
   ; array rides as `mb`, a nom bound nowhere else, and its ## check is inlined.)
   (subst mb params args var? line macs)
    (: (adjh i) (|| (&& (< 0 i) (pv? (argn mb (- i 1)) "##"))
                    (&& (< (+ i 1) (tally mb)) (pv? (argn mb (+ i 1)) "##")))
       (go i acc)
        (? (<= (tally mb) i) (rev acc)
           (: t (argn mb i)
              (? (&& (pv? t "#") (< (+ i 1) (tally mb)))    ; # param -> stringize
                  (: p (argn mb (+ i 1))
                     pi (? (idt? p) (paramidx params (vof p)) -1)
                     va (&& var? (idv? p "__VA_ARGS__"))
                     (? (|| (< -1 pi) va)
                        (go (+ i 2) (link (tok 'str (spellcat (? va (vaargs args params) (argn args pi))) line) acc))
                        (go (+ i 1) (link t acc))))
                 (&& (idt? t) (< -1 (paramidx params (vof t))))   ; a named parameter
                  (: pi (paramidx params (vof t))
                     raw (argn args pi)
                     sub (? (adjh i) raw (expand raw macs))
                     (go (+ i 1) (revcat sub acc)))
                 (&& var? (idv? t "__VA_ARGS__"))               ; the variadic tail
                  (: va (vaargs args params)
                     prevhh (&& (< 0 i) (pv? (argn mb (- i 1)) "##"))
                     commahh (&& (&& prevhh (< 1 i)) (pv? (argn mb (- i 2)) ","))
                     (? commahh                                 ; GNU `, ## __VA_ARGS__` elision: the ## is a marker, not a paste
                         (: acc2 (cup acc)                       ; drop the ## already emitted (no join)
                            (? (two? va) (go (+ i 1) (revcat (expand va macs) acc2))         ; args present: keep the comma
                               (go (+ i 1) (? (&& (two? acc2) (pv? (cap acc2) ",")) (cup acc2) acc2))))  ; empty: drop the comma too
                        prevhh (go (+ i 1) (revcat va acc))     ; a real `## __VA_ARGS__` paste: unexpanded, paste folds it
                        (go (+ i 1) (revcat (expand va macs) acc))))
                 (go (+ i 1) (link t acc)))))
       (paste (go 0 ()) line))
   (revcat l acc) (? (! (two? l)) acc (revcat (cup l) (link (cap l) acc)))
   (vaargs args params)                             ; the arg token-lists past the named params, comma-joined
    (: np (tally params)
       (skip l k) (? (|| (< k 1) (! (two? l))) l (skip (cup l) (- k 1)))
       (join l) (? (! (two? l)) ()
                   (! (two? (cup l))) (cap l)
                   (cat (cap l) (link (tok 'p "," 0) (join (cup l)))))
       (join (skip args np)))

   ; -- the expander: rescan TOKS, replacing macro invocations (honoring
   ; hidesets), fully. mutually recursive with subst via expand-of-arg. --
   (expand toks macs)
    (? (! (two? toks)) ()
       (: t (cap toks) rest (cup toks)
          (? (! (idt? t)) (link t (expand rest macs))
             (idv? t "__LINE__") (link (tok 'num (lof t) (lof t)) (expand rest macs))
             (member? (vof t) (hof t)) (link t (expand rest macs))   ; blue-painted: leave it
             (: m (mdef macs (vof t))
                (? (mobj? m)
                    (: hs (link (vof t) (hof t))
                       body (mapadd (caup m) hs (lof t))
                       (expand (cat body rest) macs))
                   (&& (mfun? m) (&& (two? rest) (pv? (cap rest) "(")))
                    (: ca (collargs (cup rest))
                       (? (! (two? ca)) (link t (expand rest macs))
                          (: args (cap ca) after (caup ca)
                             params (caup m) mbody (cap (cup (cup m))) mvar (cap (cup (cup (cup m))))
                             hs (link (vof t) (hof t))
                             body (subst mbody params args mvar (lof t) macs)
                             (expand (cat (mapadd body hs (lof t)) after) macs))))
                   (link t (expand rest macs)))))))
   (mapadd toks hs line)                            ; give body tokens the hideset + the invocation line
    (? (! (two? toks)) ()
       (: t (cap toks) (link (L (kof t) (vof t) line (dedup (cat (hof t) hs))) (mapadd (cup toks) hs line))))

   ; -- #if / #elif integer constant-expression evaluation (undefined ids -> 0,
   ; defined X / defined(X) resolved first, then macro-expanded). --
   (resolve-defined ts macs)                        ; replace `defined X` / `defined ( X )` with 0/1
    (? (! (two? ts)) ()
       (idv? (cap ts) "defined")
        (: r (cup ts)
           (? (&& (two? r) (pv? (cap r) "("))
               (: nm (cap (cup r))
                  (link (tok 'num (? (two? (mdef macs (vof nm))) 1 0) 0)
                        (resolve-defined (cup (cup (cup r))) macs)))    ; skip ( name )
              (&& (two? r) (idt? (cap r)))
               (link (tok 'num (? (two? (mdef macs (vof (cap r)))) 1 0) 0) (resolve-defined (cup r) macs))
              (resolve-defined r macs)))
       (link (cap ts) (resolve-defined (cup ts) macs)))
   (zero-ids ts) (? (! (two? ts)) ()               ; any surviving identifier is 0
                    (: t (cap ts) (link (? (|| (idt? t) (= (kof t) 'kw)) (tok 'num 0 0) t) (zero-ids (cup ts)))))
   (ifval ts macs) (: r0 (resolve-defined ts macs)
                      r1 (expand r0 macs)
                      r2 (zero-ids r1)
                      (ceval r2))

   ; a tiny precedence-climbing evaluator over cpp number tokens -> integer.
   (cprim ts)
    (? (! (two? ts)) (L 0 ())
       (: t (cap ts)
          (? (member? (kof t) '(num unum ulnum)) (L (vof t) (cup ts))
             (pv? t "(") (: r (ccond (cup ts)) (? (&& (two? (caup r)) (pv? (cap (caup r)) ")")) (L (cap r) (cup (caup r))) r))
             (pv? t "!") (: r (cprim (cup ts)) (L (? (nil? (cap r)) 1 0) (caup r)))
             (pv? t "~") (: r (cprim (cup ts)) (L (- (- 0 (cap r)) 1) (caup r)))
             (pv? t "-") (: r (cprim (cup ts)) (L (- 0 (cap r)) (caup r)))
             (pv? t "+") (cprim (cup ts))
             (L 0 (cup ts)))))
   (clevel sub ops ts)
    (: r (sub ts)
       (go v rest) (: t (? (two? rest) (cap rest) ())
                      hit (? (two? t) (cassoc (kof t) (vof t) ops) ())
                      (? (! hit) (L v rest)
                         (: r2 (sub (cup rest)) (go (hit v (cap r2)) (caup r2)))))
       (go (cap r) (caup r)))
   (cassoc k v ops) (: (go l) (? (! (two? l)) () (&& (= (cap (cap l)) k) (= (caup (cap l)) v)) (caup (cup (cap l))) (go (cup l)))
                       (go ops))
   (cmul ts) (clevel cprim (L (L 'p "*" (\ a b (* a b))) (L 'p "/" (\ a b (? (= b 0) 0 (// a b)))) (L 'p "%" (\ a b (? (= b 0) 0 (- a (* (// a b) b)))))) ts)
   (cadd ts) (clevel cmul (L (L 'p "+" (\ a b (+ a b))) (L 'p "-" (\ a b (- a b)))) ts)
   (cshl ts) (clevel cadd (L (L 'p "<<" (\ a b (<< a b))) (L 'p ">>" (\ a b (>> a b)))) ts)
   (crel ts) (clevel cshl (L (L 'p "<" (\ a b (? (< a b) 1 0))) (L 'p "<=" (\ a b (? (<= a b) 1 0)))
                            (L 'p ">" (\ a b (? (< b a) 1 0))) (L 'p ">=" (\ a b (? (<= b a) 1 0)))) ts)
   (ceq ts) (clevel crel (L (L 'p "==" (\ a b (? (= a b) 1 0))) (L 'p "!=" (\ a b (? (= a b) 0 1)))) ts)
   (cband ts) (clevel ceq (L (L 'p "&" (\ a b (& a b)))) ts)
   (cbxor ts) (clevel cband (L (L 'p "^" (\ a b (^ a b)))) ts)
   (cbor ts) (clevel cbxor (L (L 'p "|" (\ a b (| a b)))) ts)
   (cland ts) (: r (cbor ts)
                 (go v rest) (? (&& (two? rest) (pv? (cap rest) "&&"))
                                (: r2 (cbor (cup rest)) (go (? (&& (< 0 v) (< 0 (cap r2))) 1 0) (caup r2)))
                                (L v rest))
                 (go (cap r) (caup r)))
   (clor ts) (: r (cland ts)
                (go v rest) (? (&& (two? rest) (pv? (cap rest) "||"))
                               (: r2 (cland (cup rest)) (go (? (|| (< 0 v) (< 0 (cap r2))) 1 0) (caup r2)))
                               (L v rest))
                (go (cap r) (caup r)))
   (ccond ts) (: r (clor ts)
                 (? (&& (two? (caup r)) (pv? (cap (caup r)) "?"))
                    (: rt (ccond (cup (caup r)))
                       (? (&& (two? (caup rt)) (pv? (cap (caup rt)) ":"))
                          (: re (ccond (cup (caup rt))) (L (? (< 0 (cap r)) (cap rt) (cap re)) (caup re)))
                          r))
                    r))
   (ceval ts) (cap (ccond ts))

   ; -- parse a #define body into a macro entry --
   (defmacro macs line-toks)                        ; line-toks: after the leading (# define)
    (? (! (two? line-toks)) ()
       (: name (vof (cap line-toks))
          r (cup line-toks)
          ; function-like ONLY if '(' immediately follows the name (no space) -- the
          ; lexer marks a glued '(' with a 4th token field (`#define F(x)` vs the
          ; object macro `#define EOF (-1)`, whose '(' is spaced and begins the body).
          (? (&& (two? r) (&& (pv? (cap r) "(") (cauup (cup (cap r)))))
              (: pr (defparams (cup r) () ())
                 (? (! (two? pr)) ()
                    (: params (cap pr) var? (caup pr) body (caup (cup pr))
                       _ (pin macs name (L 'fun params body var?)) 1)))
             (: _ (pin macs name (L 'obj r)) 1))))
   (defparams ts params var?)                        ; -> (params variadic? body) | () ; ts after '('
    (? (! (two? ts)) ()
       (pv? (cap ts) ")") (L (rev params) var? (cup ts))    ; F() -- empty params; body follows the )
       (pv? (cap ts) "...") (: r (cup ts) (? (&& (two? r) (pv? (cap r) ")")) (L (rev params) 1 (cup r)) ()))
       (idt? (cap ts))
        (: nm (vof (cap ts)) r (cup ts)
           (? (&& (two? r) (pv? (cap r) ",")) (defparams (cup r) (link nm params) var?)
              (&& (two? r) (pv? (cap r) ")")) (L (rev (link nm params)) var? (cup r))
              ()))
       ())

   ; -- adjacent string literal concatenation (phase 6) --
   (strcat-pass ts)
    (? (! (two? ts)) ()
       (: t (cap ts)
          (? (&& (= (kof t) 'str) (&& (two? (cup ts)) (= (kof (cap (cup ts))) 'str)))
             (strcat-pass (link (tok 'str (+ (vof t) (vof (cap (cup ts)))) (lof t)) (cup (cup ts))))
             (link t (strcat-pass (cup ts))))))

   ; -- the driver: walk logical lines, run directives, expand active code.
   ; macs is a MUTABLE tablet (so #define/#undef persist and includes share it);
   ; cond is a stack of (active taken) frames; buf accumulates active code
   ; tokens, flushed (expanded) whenever a directive or EOF interrupts. --
   (dirname t) (? (= (kof t) 'kw) (show (vof t)) (vof t))   ; #if/#else lex as keywords -> their text
   (condactive cond) (? (! (two? cond)) 1 (cap (cap cond)))
   (parentactive cond) (? (! (two? cond)) 1 (cap (cap cond)))
   (flush buf macs out) (revcat (expand buf macs) out)
   (cppgo toks macs cond buf out incf)
    (? (! (two? toks)) (? (two? cond) 'unbalanced (rev (flush buf macs out)))
       (: ls (linesplit toks) line (cap ls) rest (caup ls)
          (? (pv? (cap line) "#")
              (: out1 (flush buf macs out)
                 dir (? (two? (cup line)) (dirname (cap (cup line))) ())   ; if/else are keywords; the rest ids
                 body (cup (cup line))
                 (? (member? dir '("if" "ifdef" "ifndef" "elif" "else" "endif"))
                     (: cond2 (docond dir body line macs cond)
                        (? (id? cond2 'err) ()
                           (cppgo rest macs cond2 () out1 incf)))
                    (! (condactive cond)) (cppgo rest macs cond () out1 incf)   ; skipped: ignore non-cond directives
                    (= dir "define") (: _ (defmacro macs body) (cppgo rest macs cond () out1 incf))
                    (= dir "undef") (: _ (pin macs (vof (cap body)) ()) (cppgo rest macs cond () out1 incf))
                    (= dir "include") (doinc body macs cond out1 rest incf)
                    (= dir "error") ()
                    (member? dir '("pragma" "line")) (cppgo rest macs cond () out1 incf)   ; ignored
                    (cppgo rest macs cond () out1 incf)))                              ; unknown directive: ignore
             (! (condactive cond)) (cppgo rest macs cond buf out incf)                 ; skipped code: drop
             (cppgo rest macs cond (cat buf line) out incf))))                          ; active code: accumulate

   ; a directive that manages the conditional stack. dir keyword symbols.
   (docond dir body line macs cond)
    (? (member? dir '("if" "ifdef" "ifndef"))
        (: pa (condactive cond)                        ; parent active?
           v (? (! pa) 0
                (= dir "ifdef") (? (two? (mdef macs (vof (cap body)))) 1 0)
                (= dir "ifndef") (? (two? (mdef macs (vof (cap body)))) 0 1)
                (? (< 0 (ifval body macs)) 1 0))
           (link (L (&& pa (< 0 v)) (&& pa (< 0 v))) cond))
       (= dir "elif")
        (? (! (two? cond)) 'err
           (: fr (cap cond) pa (parentactive (cup cond)) taken (caup fr)
              v (? (|| taken (! pa)) 0 (? (< 0 (ifval body macs)) 1 0))
              (link (L (&& (! taken) (&& pa (< 0 v))) (|| taken (< 0 v))) (cup cond))))
       (= dir "else")
        (? (! (two? cond)) 'err
           (: fr (cap cond) pa (parentactive (cup cond)) taken (caup fr)
              (link (L (&& (! taken) pa) 1) (cup cond))))
       (= dir "endif") (? (two? cond) (cup cond) 'err)
       'err)

   ; #include: resolve via incf, lex, and preprocess sharing macs. incf may
   ; answer (1 text child-incf): the child resolves the INCLUDED file's own
   ; quote includes relative to ITS dir (gcc's rule -- host/cb.c's unity
   ; include of ../port/quay/quay.c needs quay.c's "quay.h" found beside it);
   ; a plain (1 text) keeps this incf (the laws feed includes as data).
   (doinc body macs cond out rest incf)
    (? (! (condactive cond)) (cppgo rest macs cond () out incf)
       (: sys? (&& (two? body) (pv? (cap body) "<"))
          name (incname body)
          txt (? name (incf name sys?) ())
          (? (! (two? txt)) ()                         ; unresolved include -> fail the compile
             (: lr (clex (caup txt))
                (? (! (two? lr)) ()
                   (: itoks (caup lr)
                      chf (: c (cauup txt) (? c c incf))
                      done (cppgo itoks macs () () out chf)   ; recurse with FRESH cond; shares macs; accumulates
                      (? (id? done 'unbalanced) ()
                         (cppgo rest macs cond () (rev done) incf))))))))
   (incname body)                                     ; the header name from #include tokens
    (? (! (two? body)) ()
       (= (kof (cap body)) 'str) (vof (cap body))       ; "file"
       (pv? (cap body) "<") (: (go l acc) (? (! (two? l)) () (pv? (cap l) ">") acc (go (cup l) (+ acc (spell (cap l))))) (go (cup body) ""))
       ())

   (cpp toks incf)                                    ; -> (1 out) | ()
    (: macs (: t (tablet 0)
               _ (pin t "__STDC__" (L 'obj (L (tok 'num 1 0))))
               ; HOSTED: a cc-built object links against libc into a hosted program,
               ; so ai.c must take its hosted lanes -- the W^X mmap+mprotect code
               ; arena (toast/nif), NOT the freestanding heap copy (which is NX, so
               ; a glazed native body jumped into non-executable heap and faulted).
               ; the whole tco=0 corpus missed it: the glaze is the only arena user
               ; and it's gated off on trampoline builds.
               _ (pin t "__STDC_HOSTED__" (L 'obj (L (tok 'num 1 0))))
               ; cc emits x86-64, so say so (ai.c's AI_ARCH/IMAGE_ARCH read it --
               ; a build without it believed its arch was "other" and the glaze
               ; handed holo an unknown target). __SIZEOF_INT128__ stays UNDEFINED,
               ; so the bignum limbs stay the portable 32-bit branch and the lone
               ; `divq` __asm__ (guarded && limb_bits == 64) stays out of reach.
               _ (pin t "__x86_64__" (L 'obj (L (tok 'num 1 0))))
               ; gcc's limit predefines, the ones the host seam reads
               _ (pin t "__INT_MAX__" (L 'obj (L (tok 'num 2147483647 0))))
               _ (pin t "__LONG_MAX__" (L 'obj (L (tok 'num 9223372036854775807 0))))
               t)
       r (cppgo toks macs () () () incf)
       (? (|| (id? r 'unbalanced) (! (two? r))) () (L 1 (strcat-pass r)))))
