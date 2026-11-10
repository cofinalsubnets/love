; test/gate/clayeq.l -- moon-uu rung 1: mooncc's parse of the C file that includes vc.l's headers
; holds each spec's function equal, as data, to the clay vc.l laid, up to what cparse drops or
; folds: a typedef's name, a definition's return type and attributes, x op= e as x = x op
; e, a sizeof as some size, and a name a laid header defines to a number as that number. any
; other name the clay spells (LZ_LT, LD64, wideld) reaches the parse as spelled: around a laid
; header each is pushed and undefined, its macro the ledger's. loaded after a spec file:
;   love -l src/love/compress/lz.l -l test/gate/clayeq.l -e '(ceq-run "lz" "src/love/compress/xz.c" ["lz_gen.h"] lz-specs)'
(:
   _ (borrow 'posix)
   _ (borrow 'moon)
   ceq-is ["src/love/" "src/inle/" "out/lib/"]
   ; a laid header from disk, wrapped; any other through the resolver, its children likewise
   (ceq-inc gs dir)
    (n \ s \ (peep gs n () @ t
       (string? t ? [1 t (ceq-inc gs dir) n]
          (incload () ceq-is dir n s @ r (two? r ? [1 (r 1) (ceq-inc gs (cdir (r 3))) (r 3)] r)))))
   ; the unit's top-level forms, a refusal as ()
   (ceq-unit path gs)
    (uread path @ r
       (atom? r ? ()
        (clex (deftext (archdefs 'x64) + <>r) @ lx
           (!(okv? lx) ? ()
              (cpp <>lx (ceq-inc gs (cdir path)) path @ pp
                 (!(okv? pp) ? ()
                    (cparse-t <>pp 'x64 @ ps (okv? ps ? (caup ps 1)))))))))
   ; what the clay spells: typedef names, and the names a laid header may not have expanded
   (ceq-walk k c) (atom? c || string? c ? () (two? c && <c = k && string? (c 1) ? [(c 1)] (foldl (a \ x \ a + ceq-walk k x) () c)))
   (ceq-uniq l) (sort (keys (foldl (a \ n \ pin a n 1) {} l)))
   (ceq-wrap vs txt)
    (cats (map (v \ "#pragma push_macro(\"\(v)\")\n#undef \(v)\n") vs) + txt
     + cats (map (v \ "#pragma pop_macro(\"\(v)\")\n") vs))
   ; the typedef names as the parser resolves them, through the same headers
   (ceq-tdefs ns)
    (: src (cats ["#include <stdint.h>\n#include <stddef.h>\ntypedef uint16_t lzp;\n" (cats (map (k \ "\(k) ceq_\(k);\n") ns))])
       fs (clex src @ lx (cpp <>lx (ceq-inc {} ".") "<clayeq>" @ pp (? (okv? pp) (cparse-t <>pp 'x64 @ ps (? (okv? ps) (caup ps 1) ())) ())))
     (atom? fs ? {}
      (foldl (t \ f \ (f @ ('gdecl ((v . ty . _) . _)) (? (#v > 4 && (snip v 0 4) = "ceq_") (pin t (snip v 4 #v) ty) t) _ t)) {} fs)))
   ; clay as cparse keeps it
   (ceq-drop tt c)
    (? (atom? c || string? c) c
       (two? c && <c = 'named) (peep tt (c 1) c)
       (two? c && <c = 'var && charm? (peep tt ("#" + (c 1)) ())) ['num (tt ("#" + (c 1)))]
       (two? c && <c = 'fn && #c = 6) (map (ceq-drop tt) (snip c 0 4))
       (two? c && <c = 'rmw && #c = 4) (ceq-drop tt ['asn (c 2) ['bin (c 1) (c 2) (c 3)]])
       (map (ceq-drop tt) c))
   ; the first place two trees part: [path a b]
   (ceq-part p a b)
    (? (a = b) ()
       (two? b && <b = 'szof) (a @ ('cast 'ulong ('num _)) () _ [(rev p) a b])
       (atom? a || atom? b || string? a || string? b || #a != #b || <a != <b) [(rev p) a b]
       (: (go i) (? (#a <= i) ()
                    (: r (ceq-part (i . p) (a i) (b i)) (? (atom? r) (go (i + 1)) r)))
        (go 0)))
   (ceq-cut s) (#s < 300 ? s (snip s 0 300) + " ..")
   (ceq-say s) (puts (s + (string 10)))

   (ceq-run tag tu hs specs)
    (: cs (map cl-fn specs)
       tt0 (ceq-tdefs (ceq-uniq (foldl (a \ c \ a + ceq-walk 'named c) () cs)))
       txts (foldl (a \ h \ uread (cdir tu + h) @ r (atom? r ? a (a + [<>r]))) () hs)
       defs (foldl (a \ t \ a + filter two? (map (l \ l @ "#define \(n) \(v)" [n (read v)] ()) (lines t))) () txts)
       tt (foldl (t \ d \ (? (charm? (d 1)) (pin t ("#" + <d) (d 1)) t)) tt0 defs)
       vs (filter (v \ !(charm? (peep tt ("#" + v) ()))) (ceq-uniq (foldl (a \ c \ a + ceq-walk 'var c) () cs)))
       want (map (ceq-drop tt) cs)
       gs (foldl (t \ h \ uread (cdir tu + h) @ r (atom? r ? t (pin t h (ceq-wrap vs <>r)))) {} hs)
       u (ceq-unit tu gs)
       fns (filter (f \ two? f && <f = 'fn) u)
       (named n) (filter (f \ f 1 = n) fns)
       bad
        ((atom? u ? ["\(tu) does not parse"] ())
         + map (h \ "\(h) is not beside \(tu)") (filter (h \ !(string? (gs h))) hs)
         + foldl (a \ w \ (named (w 1) @ fs
                   (? (#fs != 1) (a + ["\(w 1): \(#fs) in \(tu)"])
                      (atom? (ceq-part () <fs w)) a
                      (: r (ceq-part () <fs w)
                       (a + ["\(w 1) parts at \(show (r 0)): parsed \(ceq-cut (show (r 1))) laid \(ceq-cut (show (r 2)))"])))))
                 () want)
     (each bad (b \ ceq-say ("clayeq \(tag): FAIL " + b)),
      (atom? bad && 0 < #want ? (ceq-say "clayeq \(tag): \(#want) functions parse to the clay laid", quit 0)
         (ceq-say "clayeq \(tag): FAIL", quit 1)))))
