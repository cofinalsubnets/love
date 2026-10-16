; test/host/showbig.l -- show over moon's unexported helper graph: past its lim a named
; function shows as its name, a small one in place. host-side for its time.
;   cat test/00-init.l test/host/showbig.l | out/love

(: m (cite 'moon)
   ks ['adims 'specask]
   ss (map (k \ (show (m k))) ks)
   (test (ss = map (k \ ("(cite 'moon '" + show k + ")")) ks)
         (all (k \ (m k = ev <(sound (show (m k))))) ks)
         (has? (show (m 'arr?)) "(\\ ")
         (m 'arr? = ev <(sound (show (m 'arr?)))),
    test_fin (),
    puts "showbig: ok -- moon's adims and specask show as their names, arr? as its lambda",
    putc 10))
