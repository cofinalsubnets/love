; test/host/selfpack.l -- src/tools/selfpack.l names a tree by its files alone: two trees that
; differ only by an empty directory, or one whose files the ignore law drops, pack the same
; run: cat test/00-init.l test/host/selfpack.l | out/love
(borrow 'posix)
(: dir (cwd 0 + "/out/.selfpackd-" + show (getpid 0))
   pk (cwd 0 + "/src/tools/selfpack.l")
   lv (cwd 0 + "/out/love")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   (put p s) (open p "w" @ q (say q s, close q))
   ; a file in every section; src/apps rides as a link so the borrows find it, and drops
   (tree d) (: r (dir + "/" + d)
               _ (each ["" "/src" "/src/x" "/w"] (s \ mkdir (r + s) 448))
               _ (each [["/VERSION" "0.4\n"] ["/README" "r\n"] ["/src/x/k.l" "1\n"] ["/src/x/f.l" "2\n"]
                        ["/src/x/g.c" "int x;\n"] ["/.sbignore" "w/*.bin\n"]] (p \ put (r + <p) <>p))
               _ (hark ["ln" "-s" (cwd 0 + "/src/apps") (r + "/src/apps")])
               r)
   a (tree "a")
   b (tree "b")
   _ (mkdir (a + "/c") 448, mkdir (a + "/c/d") 448, put (a + "/w/z.bin") "z\n")
   _ (put (dir + "/ros") "src/x/k.l\n")
   (pack r) (: t (r + ".tree")
               rc (hark ["sh" "-c" ("cd '" + r + "' && LOVE_NO_IMAGE= '" + lv + "' '" + pk + "' '" + t
                                    + "' love-x 1000000 '" + dir + "/ros' src/apps >/dev/null")])
               (<rc = 0 ? (uread t @ [1 s] s ()) ()))
   ta (pack a)
   tb (pack b)
   _ (test (string? ta) (string? tb) (ta = tb))
   _ (hark ["rm" "-rf" dir])
   0)
(test_fin (), puts "selfpack: ok", putc 10, 0)
