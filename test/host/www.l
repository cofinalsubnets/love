; --- test/host/www.l: kore's browser, everything but the screen ---
; the url arithmetic against RFC 3986 5.4's own table, then pages served by kiosko over a
; real socket (test/host/wget.l's shape) fetched, laid and stepped through less's engine by
; the keys www adds. the face -- raw mode and the frames -- is the one part left to a person.
;   cat test/00-init.l test/host/www.l | out/love
(borrow 'kiosko)

(: K (cite 'kore)
   res (K 'ww-resolve) get (K 'ww-get) lay (K 'ww-lay) dump (K 'ww-dump)
   wnew (K 'ww-new) wshow (K 'ww-show) wstep (K 'ww-step)
   ; RFC 3986 5.4.1 and 5.4.2, every row, strict parser
   base "http://a/b/c/d;p?q"
   _ (map (\ r (test (res base <r = <>r)))
          [["g:h" "g:h"] ["g" "http://a/b/c/g"] ["./g" "http://a/b/c/g"] ["g/" "http://a/b/c/g/"]
           ["/g" "http://a/g"] ["//g" "http://g"] ["?y" "http://a/b/c/d;p?y"] ["g?y" "http://a/b/c/g?y"]
           ["#s" "http://a/b/c/d;p?q#s"] ["g#s" "http://a/b/c/g#s"] ["g?y#s" "http://a/b/c/g?y#s"]
           [";x" "http://a/b/c/;x"] ["g;x" "http://a/b/c/g;x"] ["g;x?y#s" "http://a/b/c/g;x?y#s"]
           ["" "http://a/b/c/d;p?q"] ["." "http://a/b/c/"] ["./" "http://a/b/c/"] [".." "http://a/b/"]
           ["../" "http://a/b/"] ["../g" "http://a/b/g"] ["../.." "http://a/"] ["../../" "http://a/"]
           ["../../g" "http://a/g"]
           ["../../../g" "http://a/g"] ["../../../../g" "http://a/g"] ["/./g" "http://a/g"]
           ["/../g" "http://a/g"] ["g." "http://a/b/c/g."] [".g" "http://a/b/c/.g"]
           ["g.." "http://a/b/c/g.."] ["..g" "http://a/b/c/..g"] ["./../g" "http://a/b/g"]
           ["./g/." "http://a/b/c/g/"] ["g/./h" "http://a/b/c/g/h"] ["g/../h" "http://a/b/c/h"]
           ["g;x=1/./y" "http://a/b/c/g;x=1/y"] ["g;x=1/../y" "http://a/b/c/y"]
           ["g?y/./x" "http://a/b/c/g?y/./x"] ["g?y/../x" "http://a/b/c/g?y/../x"]
           ["g#s/./x" "http://a/b/c/g#s/./x"] ["g#s/../x" "http://a/b/c/g#s/../x"] ["http:g" "http:g"]])
   ; a scheme is case-blind and comes back lower; a host with no path takes the root
   _ (test (res "HTTPS://h" "x" = "https://h/x") (res "http://h/a/b" "HTTP://k/../z" = "http://k/z"))
   ; what a person types
   _ (test ((K 'ww-arg) "example.com/a" = "https://example.com/a")
           ((K 'ww-arg) "http://x" = "http://x"))

   root "out/.www"
   _ (hark ["rm" "-rf" root])
   _ (mkdir root 493) _ (mkdir (root + "/site") 493) _ (mkdir (root + "/site/sub") 493)
   sroot (cwd 0 + "/" + root + "/site")
   (wput f s) (: p (open (sroot + f) "w") _ (say p s) (close p))
   ; a page long enough that landing on #here moves the view
   _ (wput "/a.html" ("<h1>Top</h1><p>go <a href=\"sub\">down</a>, <a href=\"#here\">here</a> or <a href=\"mailto:x@y\">mail</a>, not <a href=\"#gone\">gone</a></p>"
                      + catmap (i \ "<p>filler " + show i + "</p>") ^40 + "<p id=\"here\">here it is</p>"))
   ; ..and one whose content sits under a long menu
   _ (wput "/m.html" ("<nav>" + catmap (i \ "<p>menu " + show i + "</p>") ^40 + "</nav><main><h1>Body</h1>" + catmap (i \ "<p>text " + show i + "</p>") ^40 + "</main>"))
   _ (wput "/sub/index.html" "<p><a href=\"../a.html\">up</a> <a href=\"t.txt\">notes</a></p>")
   _ (wput "/sub/t.txt" "plain\ntext\n")
   port 7435
   l (listen port)
   srv (twirl (\ _ ((: (g k) (: _ (await l)
                                c (accept l)
                                _ (hot? c ? ((cite 'kiosko 'serve1) sroot () c, close c) ())
                                (g k)))
                    0)) 0)
   at ("http://127.0.0.1:" + show port)
   ga (get (at + "/a.html") 8)
   ; the redirect is followed, and the page answers where it ended: its links resolve there
   gs (get (at + "/sub") 8)
   gt (get (at + "/sub/t.txt") 8)
   g4 (get (at + "/none.html") 8)
   _ (test (<ga = 0) (ga 2 = 'html) (ga 4 = 200)
           (<gs = 0) (gs 1 = at + "/sub/")
           (lay gs 60 1 = [(at + "/a.html") (at + "/sub/t.txt")])
           (gt 2 = 'text) (<(lay gt 60) = ["plain" "text"])
           (<g4 = 0) (g4 4 = 404)                                    ; a no is still a page
           (<(get "ftp://x/y" 8) = 1) (<(get "http://127.0.0.1:1/" 8) = 1))
   ; the dump: the page plain, then its references
   _ (: p (lay ga 60) d (dump <p (p 1))
        (test (0 <= (K 'wg-find) d "go [1]down, [2]here or [3]mail" 0)
              (0 <= (K 'wg-find) d "References\n\n  1. " 0)
              (0 <= (K 'wg-find) d ("  1. " + at + "/sub\n  2. " + at + "/a.html#here\n  3. mailto:x@y\n") 0)
              ((K 'wg-find) d (string 27) 0 < 0)))
   ; the keys: a count and return follows, U names, B goes back, o opens, h and q are the help
   wkeys (\ st s (map (i \ wstep st (s i)) ^#s))
   ; the face's half of a request: take 'go, land the page it fetched
   wland (\ st g (: q (st 'go) _ (pin st 'go ()) (wshow st g (two? q ? (q 1) 0) (two? q ? (q 2) -1))))
   st (wnew 60 20)
   _ (wland st ga)
   _ (test (st 'url = at + "/a.html") (st 'go = ()) (st 'hist = ()))
   _ (wkeys st "1\r")
   _ (test (st 'go = [(at + "/sub") 1 -1]))
   _ (wland st gs)
   _ (test (st 'url = at + "/sub/") (st 'hist = [[(at + "/a.html") 0]]))
   _ (wkeys st "U")
   _ (test (st 'msg = at + "/sub/"))
   _ (wkeys st "2U")
   _ (test (st 'msg = "2: " + at + "/sub/t.txt") (st 'go = ()))
   _ (wkeys st "9\r")
   _ (test (st 'msg = "no link 9") (st 'go = ()))
   _ (wkeys st "B")
   _ (test (st 'go = [(at + "/a.html") 0 0]) (st 'hist = ()))
   _ (wland st ga)
   _ (wkeys st "B")
   _ (test (st 'msg = "no previous page"))
   ; an in-page link lands with no fetch, and back from it is a scroll; one with no place
   ; on the page stays and says so; a door www has none of stays too
   _ (wkeys st "2\r")
   _ (test (st 'go = ()) (0 < st 'top) (st 'url = at + "/a.html#here") (st 'hist = [[(at + "/a.html") 0]]))
   _ (wkeys st "B")
   _ (test (st 'go = ()) (st 'top = 0) (st 'url = at + "/a.html") (st 'hist = ()))
   _ (wkeys st "4\r")
   _ (test (st 'go = ()) (st 'top = 0) (st 'msg = "no anchor #gone on this page"))
   _ (wkeys st "3\r")
   _ (test (st 'go = ()) (st 'msg = "no door for mailto:x@y"))
   _ (wkeys st "oexample.com/q\r")
   _ (test (st 'go = ["https://example.com/q" 1 -1]) (st 'mode = 'n))
   _ (: _ (pin st 'go ()) _ (wkeys st "h") ls (st 'ls)
        (test (st 'file = "HELP") (0 <= (K 'wg-find) <ls "kore www" 0)))
   _ (wkeys st "q")
   _ (test (st 'file = at + "/a.html") !(st 'quit))
   ; a page opened fresh opens at its <main>, past the menu; g is the top and m goes back.
   ; one with no main says so, and a reload keeps where the reader was
   _ (: s3 (wnew 60 20) _ (wland s3 (get (at + "/m.html") 8)) t0 (s3 'top)
        _ (test (0 < t0) (0 <= (K 'wg-find) ((s3 'ls) (s3 'top)) "Body" 0))
        _ (wkeys s3 "g") _ (test (s3 'top = 0))
        _ (wkeys s3 "m") _ (test (s3 'top = t0))
        _ (wkeys s3 "gr") _ (test (s3 'go = [(at + "/m.html") 0 0]))
        _ (wland s3 (get (at + "/m.html") 8)) _ (test (s3 'top = 0))
        _ (wland s3 ga) _ (wkeys s3 "m")
        (test (s3 'top = 0) (s3 'msg = "no main content marked on this page")))
   ; a page fetched with a fragment opens at its place
   _ (: s2 (wnew 60 20) _ (wland s2 (get (at + "/a.html#here") 8)) (test (0 < s2 'top)))
   ; less's keys still reach less
   _ (wkeys st "G")
   _ (test (0 <= st 'top))
   _ (wkeys st "q")
   _ (test (st 'quit))
   0)

(test_fin (), puts "www: ok", putc 10, 0)
