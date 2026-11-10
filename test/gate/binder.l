; test/gate/binder.l -- the first of FILES that binds NAME, as the reader reads it: a name a
; (: ..) or (:- ..) binds, a symbol or the head of a (name args ..), or uu's (defn NAME ..) and
; its kin. gcshard.sh asks it for the file a shard carries when it misses a name
; usage: out/love test/gate/binder.l NAME FILE ..
(borrow 'posix)
(: k (nom (argv 1))
   (rd p) (open p "r" @ q (hot? q ? (slurp q @ t (close q, t)) ""))
   (head x) (two? x ? <x x)
   (pairs l) (two? l && two? >l ? (head <l . pairs >>l) ())
   (def? x) (nom? x && (show x @ s (3 <= #s && snip s 0 3 = "def")))
   (names f) (? (<f = (nom ":")) (pairs >f)
                (<f = (nom ":-")) (pairs >>f)
                (def? <f && two? >f) [<>f]
                ())
   (binds? f) (two? f && (elem k (names f) || any binds? f))
   (seek ps) (? !(two? ps) ()
                 (trap sounds (rd <ps) (a \ b \ ()) @ fs (any binds? fs ? <ps (seek >ps))))
   (seek (drop 2 argv) @ f (string? f ? (puts (f + "\n")) 0)))
