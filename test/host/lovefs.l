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

(test_fin ())
(puts "lovefs: ok")
(putc 10)
