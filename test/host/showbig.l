; --- test/host/showbig.l: show over a graph of helpers ---
; moon's parser is one letrec of helpers the module does not export, each quoted as a
; constant in many places. read in place wherever it is quoted, the graph reads as a tree;
; the reading counts the bodies it reads, and past its lim a function with a name is its
; name. a small one still reads in place.
;
;   cat test/00-init.l test/host/showbig.l | out/love
;
; host-side and not a corpus member for its time: each big reading runs to lim first.

(: m (cite 'moon)
   ks ['adims 'specask]
   ss (map (\ k (show (m k))) ks)
   _ (test (ss = map (\ k ("(cite 'moon '" + show k + ")")) ks)
           (all (\ k (m k = ev <(sound (show (m k))))) ks)
           (has? (show (m 'arr?)) "(\\ ")
           (m 'arr? = ev <(sound (show (m 'arr?)))))
   _ (test_fin ())
   _ (puts "showbig: ok -- moon's adims and specask show as their names, arr? as its lambda")
 (putc 10))
