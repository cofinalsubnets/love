; stow -- a value to bytes and back, exactly: (), small ints, reals, complex, strings, names,
; lists, tablets, and int and real trays. (stow v) answers a string, or () where
; v holds anything else; (unstow s) the value, or () for bytes stow did not lay. a tablet
; comes back with its keys pinned in the order keys gave them. the bytes are this machine's:
; a real tray's elements as they lie in memory
(module (stow stow unstow)
(: pinv (cite 'guts 'pinv) peepv (cite 'guts 'peepv) pind (cite 'guts 'pind) peepd (cite 'guts 'peepd)
   magic "lstow 1\n"
   ; ..a tag a node: 0 (), 1 a list cell, 2 an int, 3 a real, 4 a string, 5 a name, 6 a
   ; tablet, 7 an int tray, 8 a real tray, 9 a complex; a tray's rank and dims after its tag.
   ; ints, tags and lengths ride one int stream, reals another, string bytes a third, trays'
   ; elements the last
   (stow v) (: T {'l ()} F {'l ()} S {'l () 'n 0} A {'l () 'n 0}
     (t x) (pin T 'l (x . T 'l))
     (str s) (t #s, pin S 'l (s . S 'l), pin S 'n (S 'n + #s))
     (blob b) (pin A 'l (b . A 'l), pin A 'n (A 'n + #b))
     (dims x) (: ds (map (k \ shape x k) ^(rank x)) (t (rank x), each ds t, foldl (*) 1 ds))
     (enc x) (kind x @
       'mint (x = () ? (t 0) (scare 'stow x))
       'chain (t 1, enc <x, enc >x)
       'charm (t 2, t x)
       'gem (t 3, pin F 'l (x . F 'l))
       'string (t 4, str x)
       'nom (t 5, str (show x))
       'tablet (: ks (keys x) (t 6, t #ks, each ks (k \ (enc k, enc (x k)))))
       'trayz (t 7, dims x @ n (n = 0 ? 0 (blob (string (pinv (cask (8 * n)) 0 8 8 x)))))
       'trayr (t 8, dims x @ n (n = 0 ? 0 (blob (string (pind (cask (8 * n)) 0 x)))))
       'twin (t 9, enc (re x), enc (im x))
       k (scare 'stow x))
     (trap (x \ (enc x, 1)) v (a \ b \ 0) ?
        (: tl (rev (T 'l)) fl (rev (F 'l)) nt #tl nf #fl
           hd (pinv (cask 32) 0 8 8 (star-tray [4] [nt nf (S 'n) (A 'n)]))
           tt (pinv (cask (8 * nt)) 0 8 8 (star-tray [nt] tl))
           ff (pind (cask (8 * nf)) 0 (gem-tray [nf] fl))
           (cats ([magic (string hd) (string tt) (string ff)] + rev (S 'l) + rev (A 'l))))))
   (unstow s) (: m #magic
     (? (!(string? s) || #s < m + 32 || snip s 0 m != magic) ()
        (: H (peepv s m 8 8 4) nt (peep H 0 0) nf (peep H 1 0) ns (peep H 2 0) na (peep H 3 0)
           ot (m + 32) of (ot + 8 * nt) os (of + 8 * nf) oa (os + ns)
           (#s != oa + na ? ()
              (: T (peepv s ot 8 8 nt) F (peepd s of nf) c {'t 0 'f 0 's os 'a oa}
                 (tk _) (: i (c 't) (pin c 't (i + 1), peep T i 0))
                 (fk _) (: i (c 'f) (pin c 'f (i + 1), peep F i 0.0))
                 (sk _) (: n (tk ()) o (c 's) (pin c 's (o + n), snip s o (o + n)))
                 ; ..a tray's dims, then its elements laid by w from their place
                 (ak w) (: r (tk ()) (go i ds) (i < r ? (go (i + 1) (tk () . ds)) (rev ds)) ds (go 0 ())
                          n (foldl (*) 1 ds) o (c 'a)
                          (pin c 'a (o + 8 * n), w o ds))
                 (dec _) (tk () @
                   0 ()
                   1 (cell ())
                   2 (tk ())
                   3 (fk ())
                   4 (sk ())
                   5 (nom (sk ()))
                   6 (: n (tk ()) t {} (go i) (i < n ? (: k (dec ()) (pin t k (dec ()), go (i + 1))) t) (go 0))
                   7 (ak (o \ ds \ peepv s o 8 8 ds))
                   8 (ak (o \ ds \ peepd s o ds))
                   9 (: a (dec ()) (twin a (dec ())))
                   k (scare 'unstow k))
                 ; ..a list's cells in a loop, so a long one asks no deeper stack than a short
                 (cell _) (: (go acc) (: x (dec ())
                                        (peep T (c 't) 0 = 1 ? (pin c 't (c 't + 1), go (x . acc))
                                           (foldl (\ l e (e . l)) (dec ()) (x . acc))))
                            (go ()))
                 (trap dec () (a \ b \ ()))))))))
) ; module stow
