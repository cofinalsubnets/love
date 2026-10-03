; test/host/lovefs.l -- /love on the host: the tree the binary carries, read-only and seen by
; love's own file doors alone. it mirrors the checkout's root, so a file reads the same through
; /love as it does here.
; run: cat test/00-init.l test/host/lovefs.l | out/love

(borrow 'posix)
(: (lf-rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   ver (lf-rd "VERSION")
   s (stat "/love/VERSION")
   d (stat "/love/src/apps")
 (test
   ; a file reads as the checkout's, through any spelling that lands under /love
   (ver = lf-rd "/love/VERSION")
   (lf-rd "src/love/lovefs.c" = lf-rd "/love/src/love/lovefs.c")
   (ver = lf-rd "/love/src/../VERSION")
   (ver = lf-rd "/tmp/../love/VERSION")
   ; stat: a file is read-only and its size, a directory a directory, and lstat agrees
   (#ver = <s)
   (32768 = 61440 & s 2)
   (0 = 146 & s 2)                                ; no write bit for anyone
   (16384 = 61440 & d 2)
   (16384 = 61440 & (stat "/love") 2)
   (lstat "/love/VERSION" = s)
   ; readdir lists one component per name, deduped
   (elem "src" (readdir "/love"))
   (elem "VERSION" (readdir "/love"))
   (elem "json.l" (readdir "/love/src/apps"))
   (elem "kore" (readdir "/love/src/apps"))
   (nelem "kore/kore.l" (readdir "/love/src/apps"))
   (readdir "/love/src/apps" @ l (all (n \ 1 = #(filter (= n) l)) l))
   ; absence, the read-only rule and the kinds answer as the OS's would
   ('enoent = stat "/love/no-such-file")
   ('enoent = open "/love/no-such-file" "r")
   ('erofs = open "/love/VERSION" "w")
   ('erofs = open "/love/new-file" "a")
   ('eisdir = open "/love/src" "r")
   ('enotdir = readdir "/love/VERSION")
   ('enoent = readdir "/love/nope")
   ('einval = readlink "/love/VERSION")
   ; a name that only starts the same is the OS's
   ('enoent = stat "/lovers-lane")
   ; a child that is not love does not see it
   (: r (hark ["sh" "-c" "cat /love/VERSION 2>/dev/null; echo $?"]) (>r != ver + "0\n"))))

;; the container under it (src/love/lib/srctree.h): an index, then six tar sections, each
;; decoded at the first read of a file in it. a fresh process shows which.
(: (lf-rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   h (tree-head 0)
   tars >h
   whole (tree-tar 0)
   moon (tree-tar "moon")
   (lf-fresh e) (hark [(selfpath 0) "-e" ("(borrow 'posix) " + e + " (puts (show (map (r \\ r 5) (tree-head 0)))) (quit 0)")])
 (test
   ((map cap h) = ["index" "moon" "bake" "seat" "lisp" "c" "rest"])
   ((map (r \ r 1) h) = [1 1 1 1 2 2 3])               ; deflate where a run reads, else bzip2, lzma2
   (all (r \ 0 < r 3) h)
   (#whole = +(map (r \ r 2) tars))                     ; the sections joined are the whole tar
   (#moon = 1024 + (tars 0 2))                         ; one alone ends as a tar does
   (has? moon "/src/apps/moon/include/stdio.h")
   (has? moon (lf-rd "src/apps/moon/include/stdio.h"))
   (!(has? moon "/src/apps/kore/text.l"))
   (has? (tree-tar "bake") "/src/apps/kore/text.l")   ; the roster a carried bake reads
   (nil? (tree-tar "index"))
   (nil? (tree-tar "nope"))
   ; opening decodes the index alone; a stat and a listing read no section; a read, its own
   (>(lf-fresh "0") = "(1 0 0 0 0 0 0)")
   (>(lf-fresh "(stat \"/love/src/apps/json.l\") (readdir \"/love/src/apps\")") = "(1 0 0 0 0 0 0)")
   (>(lf-fresh "(slurp (open \"/love/src/apps/moon/include/stdio.h\" \"r\"))") = "(1 1 0 0 0 0 0)")
   (>(lf-fresh "(slurp (open \"/love/src/apps/tls/roots.pem\" \"r\"))") = "(1 0 0 1 0 0 0)")
   (>(lf-fresh "(slurp (open \"/love/src/apps/sat/flat.l\" \"r\"))") = "(1 0 0 0 1 0 0)")
   (>(lf-fresh "(slurp (open \"/love/src/love/love.c\" \"r\"))") = "(1 0 0 0 0 1 0)")
   (>(lf-fresh "(slurp (open \"/love/VERSION\" \"r\"))") = "(1 0 0 0 0 0 1)")
   ; each codec answers the file the tree holds
   (all (p \ lf-rd ("/love/" + p) = lf-rd p) ["src/apps/sat/flat.l" "src/love/love.c" "VERSION"])))

(test_fin ())
(puts "lovefs: ok")
(putc 10)
