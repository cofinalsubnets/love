; test/host/www.l -- kore's browser, everything but the screen
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
   _ (map (r \ (test (res base <r = <>r)))
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
   ; where a server may send us: up to https, http to http, gemini to gemini, never elsewhere
   _ (K 'ww-hop? @ hop
        (test (hop "http://a/" "https://b/") (hop "http://a/" "http://b/") (hop "https://a/" "https://b/")
              (hop "gemini://a/" "gemini://b/")
              !(hop "https://a/" "http://b/") !(hop "http://a/" "file:///etc/passwd")
              !(hop "https://a/" "gopher://b/") !(hop "gemini://a/" "https://b/")
              !(hop "http://a/" "gemini://b/") !(hop "http://a/" "ftp://b/")))
   ; ..and what a peer said is echoed without its controls
   _ (test (K 'wg-plain ("a" + string 27 + "]0;x" + string 7 + "b\tc\n" + string 127 + string 0) = "a]0;xb\tc\n"))
   ; what a person types
   _ (test (K 'ww-arg "example.com/a" = "https://example.com/a")
           (K 'ww-arg "http://x" = "http://x"))

   ; every path this lays is the pid's own, so two runs over one out/ keep apart
   root ("out/.www-" + show (getpid 0))
   _ (mkdir root 493, mkdir (root + "/site") 493, mkdir (root + "/site/sub") 493)
   sroot (cwd 0 + "/" + root + "/site")
   (wput f s) (open (sroot + f) "w" @ p (say p s, close p))
   ; a page long enough that landing on #here moves the view
   _ (wput "/a.html" ("<h1>Top</h1><p>go <a href=\"sub\">down</a>, <a href=\"#here\">here</a> or <a href=\"mailto:x@y\">mail</a>, not <a href=\"#gone\">gone</a></p>"
                      + catmap (i \ "<p>filler " + show i + "</p>") ^40 + "<p id=\"here\">here it is <a href=\"sub\">again</a></p>"))
   ; ..and one whose content sits under a long menu
   _ (wput "/m.html" ("<nav>" + catmap (i \ "<p>menu " + show i + "</p>") ^40 + "</nav><main><h1>Body</h1>" + catmap (i \ "<p>text " + show i + "</p>") ^40 + "</main>"))
   _ (wput "/sub/index.html" "<p><a href=\"../a.html\">up</a> <a href=\"t.txt\">notes</a></p>")
   _ (wput "/sub/t.txt" "plain\ntext\n")
   ; a form that sends by get, an image, a page in latin-1 by its <meta>, and a <base>
   _ (wput "/f.html" "<form action=\"sub/t.txt?x=1\"><input type=hidden name=lang value=en><input name=q value=\"old one\"><input type=submit value=Go></form><p><img src=l.png alt=\"logo\"> x</p><form method=post><input name=p></form>")
   _ (wput "/l.html" ("<meta charset=\"ISO-8859-1\"><p>caf" + string 233 + " " + string 147 + "q" + string 148 + "</p>"))
   _ (wput "/b.html" "<base href=\"/sub/\"><p><a href=\"t.txt\">t</a></p>")
   pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (_ \ ((: (g k) (: _ (await l)
                                c (accept l)
                                ((hot? c ? ((cite 'kiosko 'serve1) sroot () c, close c) ()),
                                 g k)))
                    0)) 0)
   at ("http://127.0.0.1:" + show port)
   ; a server that sends every request to file: -- www does not follow it
   pl3 (test-listen 0)
   p3 <pl3
   l3 (pl3 1)
   (w3head c acc) (ends? acc "\r\n\r\n" ? acc (see c @ ch (ch < 0 ? acc (w3head c (acc + string ch)))))
   srv3 (twirl (_ \ ((: (g k) (: _ (await l3)
                                 c (accept l3)
                                 ((hot? c ? ((w3head c "", say c "HTTP/1.1 302 Found\r\nLocation: file:///etc/passwd\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                                             , flush c, close c) ()),
                                  g k)))
                     0)) 0)
   gf (get ("http://127.0.0.1:" + show p3 + "/") 8)
   _ (test (<gf = 1) (0 <= fsub <>gf "file:///etc/passwd, which is not followed" 0))
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
        (test (0 <= fsub d "go [1]down, [2]here or [3]mail" 0)
              (0 <= fsub d "References\n\n  1. " 0)
              (0 <= fsub d ("  1. " + at + "/sub\n  2. " + at + "/a.html#here\n  3. mailto:x@y\n") 0)
              (fsub d (string 27) 0 < 0)))
   ; the keys: a count and return follows, U names, B goes back, o opens, h and q are the help
   wkeys (st \ s \ (map (i \ wstep st (s i)) ^#s))
   ; the face's half of a request: take 'go, land the page it fetched
   wland (st \ g \ (st 'go @ q (pin st 'go (), wshow st g (two? q ? (q 1) 0) (two? q ? (q 2) -1))))
   st (wnew 60 20)
   (wland st ga,
    test (st 'url = at + "/a.html") (st 'go = ()) (st 'hist = ()),
    wkeys st "1\r",
    test (st 'go = [(at + "/sub") 1 -1]),
    wland st gs,
    test (st 'url = at + "/sub/") (st 'hist = [[(at + "/a.html") 0]]),
    wkeys st "U",
    test (st 'msg = at + "/sub/"),
    wkeys st "2U",
    test (st 'msg = "2: " + at + "/sub/t.txt") (st 'go = ()),
    wkeys st "9\r",
    test (st 'msg = "no link 9") (st 'go = ()),
    wkeys st "B",
    test (st 'go = [(at + "/a.html") 0 0]) (st 'hist = ()),
    wland st ga,
    wkeys st "B",
    test (st 'msg = "no previous page"),
    ; an in-page link lands with no fetch, and back from it is a scroll; one with no place
    ; on the page stays and says so; a door www has none of stays too
    wkeys st "2\r",
    test (st 'go = ()) (0 < st 'top) (st 'url = at + "/a.html#here") (st 'hist = [[(at + "/a.html") 0]]),
    wkeys st "B",
    test (st 'go = ()) (st 'top = 0) (st 'url = at + "/a.html") (st 'hist = ()),
    wkeys st "4\r",
    test (st 'go = ()) (st 'top = 0) (st 'msg = "no anchor #gone on this page"),
    wkeys st "3\r",
    test (st 'go = ()) (st 'msg = "no door for mailto:x@y"),
    wkeys st "oexample.com/q\r",
    test (st 'go = ["https://example.com/q" 1 -1]) (st 'mode = 'n),
    (: _ (pin st 'go (), wkeys st "h") ls (st 'ls)
       (test (st 'file = "HELP") (0 <= fsub <ls "kore www" 0))),
    wkeys st "q",
    test (st 'file = at + "/a.html") !(st 'quit),
    ; a page opened fresh opens at its <main>, past the menu; g is the top and m goes back.
    ; one with no main says so, and a reload keeps where the reader was
    (: s3 (wnew 60 20) _ (wland s3 (get (at + "/m.html") 8)) t0 (s3 'top)
       (test (0 < t0) (0 <= fsub (s3 'ls (s3 'top)) "Body" 0),
        wkeys s3 "g", test (s3 'top = 0),
        wkeys s3 "m", test (s3 'top = t0),
        wkeys s3 "gr", test (s3 'go = [(at + "/m.html") 0 0]),
        wland s3 (get (at + "/m.html") 8), test (s3 'top = 0),
        wland s3 ga, wkeys s3 "m",
        test (s3 'top = 0) (s3 'msg = "no main content marked on this page"))),
    ; TAB walks the links on the screen and shift-TAB back, the current one in standout;
    ; RETURN follows it, and a count still wins
    (wnew 60 20 @ s4
     (wland s4 ga,
      wkeys s4 (string 9), test (s4 'cur = 1) (s4 'hi = "[1]") (s4 'msg = "1: " + at + "/sub"),
      wkeys s4 (string 9 + string 9), test (s4 'cur = 3),
      wstep s4 265, test (s4 'cur = 2) (s4 'hi = "[2]"),
      wkeys s4 "\r", test (s4 'go = ()) (s4 'url = at + "/a.html#here"),
      ; the current link is off the screen now, so TAB takes the first on it: the one
      ; beside the place landed on
      wkeys s4 (string 9), test (s4 'cur = 5),
      wkeys s4 "1\r", test (s4 'go = [(at + "/sub") 1 -1]),
      wland s4 gs, test (s4 'cur = 0) (s4 'hi = ""),
      wstep s4 265, test (s4 'cur = 2))),
    ; a form's text field is a link; following it asks for the text, what it held typed in,
    ; and RETURN sends the form by get with it. a post form lays none; an image is its alt
    (: s5 (wnew 60 20) gf (get (at + "/f.html") 8) _ (wland s5 gf)
       (unlines l) (catmap (x \ x + "\n") l)
       (test (s5 'urls = [("form:" + at + "/sub/t.txt?lang=en&q=old+one")])
             (0 <= fsub (unlines (s5 'ls)) "[1][old one_____]" 0)
             (0 <= fsub (unlines (s5 'ls)) "[logo] x" 0),
        wkeys s5 "1\r", test (s5 'mode = 'c) (s5 'lead = "q: ") (s5 'cmd = "old one") (s5 'go = ()),
        map (_ \ wstep s5 127) ^7,
        wkeys s5 "caf\xc3\xa9 & tea\r",
        test (s5 'mode = 'n) (s5 'go = [(at + "/sub/t.txt?lang=en&q=caf%C3%A9+%26+tea") 1 -1]),
        ; ESC leaves the field, and TAB and RETURN reach it too
        (pin s5 'go (), wkeys s5 (string 9 + "\r"), test (s5 'mode = 'c),
         wstep s5 27, test (s5 'mode = 'n) (s5 'go = ())),
        0)),
    ; the window changing width lays the page again, the link that was first on the screen
    ; still first on it
    (: s6 (wnew 60 3) _ (wland s6 (get (at + "/a.html#here") 8))
       ; link 5 sits on the page's last line, which a screen of two rows shows
       (seen? l) (s6 'top <= l < s6 'top + 2)
       _ (test (seen? (s6 'links 4)) (0 <= fsub (s6 'ls (s6 'links 4)) "here it is" 0))
       n0 (s6 'nl)
       (pin s6 'w 30, K 'ww-fit s6,
        test (s6 'lw = 30) (n0 < s6 'nl) (seen? (s6 'links 4))
             (0 <= fsub (s6 'ls (s6 'links 4)) "here it is" 0)
             (aall (map (l \ #l <= 30) (s6 'ls))),
        test (K 'ww-fit s6 = 0))),
    ; a latin-1 file by its own <meta> reads as utf-8 (kiosko's header says utf-8, and a
    ; header wins), and a body by its header; a gzip body unzips, and a torn one is no page;
    ; a <base> is what links resolve against
    (: gl (get ("file://" + sroot + "/l.html") 8) body (K 'ww-body)
       (test (0 <= fsub (gl 3) "caf\xc3\xa9 \xe2\x80\x9cq\xe2\x80\x9d" 0)
             (body "text/html; charset=\"windows-1252\"" () (string 128) = "\xe2\x82\xac")
             (body "text/html; charset=utf-8" () "caf\xc3\xa9" = "caf\xc3\xa9")
             (body "text/html" "gzip" (cite 'gz 'gz-zip "<p>hi</p>" "" 0) = "<p>hi</p>")
             (body "text/html" "gzip" "<p>hi</p>" = ())
             (lay (get (at + "/b.html") 8) 60 1 = [(at + "/sub/t.txt")]))),
    ; a page fetched with a fragment opens at its place
    (wnew 60 20 @ s2 (wland s2 (get (at + "/a.html#here") 8), test (0 < s2 'top))),
    ; a png drawn under its mark, two pixels a cell: its rows spliced in after the alt text's
    ; line, the link below moved down by them, a missing picture drawn as nothing, and the
    ; rows kept through a re-lay at a narrower width
    (: (be4 v) (foldl (a \ k \ (a + string (v >> k & 255))) "" [24 16 8 0])
       (chunk ty d) (be4 #d + ty + d + be4 (cite 'gz 'gz-crc32 (ty + d)))
       (adler s) (: (go i a b) (#s <= i ? (b << 16 | a)
                                ((a + s i) % 65521 @ a2 (go (i + 1) a2 ((b + a2) % 65521))))
                    (go 0 1 0))
       (colour x y) [(x * 30) (y * 40) 200 255]
       raw (foldl (acc \ y \ (acc + string 0
                               + foldl (a \ x \ (a + foldl (a \ c \ (a + string c)) "" (colour x y))) "" ^8))
                  "" ^6)
       png (string 137 + "PNG\r\n" + string 26 + "\n"
            + chunk "IHDR" (be4 8 + be4 6 + string 8 + string 6 + string 0 + string 0 + string 0)
            + chunk "IDAT" (string 120 + string 1 + (cite 'gz 'gz-deflate) raw + be4 (adler raw))
            + chunk "IEND" "")
       _ (wput "/dot.png" png)
       _ (wput "/p.html" ("<h1>Pic</h1><p>see <img src=\"dot.png\" alt=\"dot\"> and "
                          + "<img src=\"nope.png\" alt=\"gone\"></p><p><a href=\"a.html\">after</a></p>"))
       _ (setenv "COLORTERM" "truecolor")
       s7 (wnew 60 20)
       _ (wland s7 (get ("file://" + sroot + "/p.html") 8))
       l0 (s7 'links 0) n0 (s7 'nl)
       (cells? l) (0 <= fsub l "\xe2\x96\x80" 0)
       m <>(<(filter (a \ fsub <a " img " 0 = 0) (s7 'anchors)))
       _ (K 'ww-pictures s7)
       ls (s7 'ls)
       _ (test (s7 'links 0 = l0 + 3) (s7 'nl = n0 + 3)
               (0 <= fsub (ls m) "[dot]" 0) !(cells? (ls m))
               (cells? (ls (m + 1))) (cells? (ls (m + 3))) !(cells? (ls (m + 4)))
               (0 <= fsub (ls (m + 1)) "\e[38;2;0;0;200m\e[48;2;0;40;200m" 0)
               (0 <= fsub (ls (s7 'links 0)) "after" 0)
               (s7 'imgs ("file://" + sroot + "/nope.png") = 'none))
       _ (pin s7 'w 30, K 'ww-fit s7)
       _ (test (#(filter cells? (s7 'ls)) = 3))
       ; a jpeg the same, its pixels the size its header says
       jp (cask (8 * 6 * 4) @ c
           ((map (i \ (pins c i (i % 4 = 3 ? 255 (i % 4 * 100)))) ^(8 * 6 * 4)),
            jpeg-encode 8 6 (string c) 95))
       _ (wput "/dot.jpg" jp)
       _ (wput "/q.html" "<p>see <img src=\"dot.jpg\" alt=\"dot\"></p><p><a href=\"a.html\">after</a></p>")
       s8 (wnew 60 20)
       _ (wland s8 (get ("file://" + sroot + "/q.html") 8))
       l8 (s8 'links 0)
       _ (K 'ww-pictures s8)
       pic (s8 'imgs ("file://" + sroot + "/dot.jpg"))
       ; ..and a file: picture on an http page is not read
       _ (wput "/r.html" ("<p>see <img src=\"file://" + sroot + "/dot.png\" alt=\"dot\"></p>"))
       s9 (wnew 60 20)
       _ (wland s9 (get (at + "/r.html") 8))
       _ (K 'ww-pictures s9)
       rp (s9 'imgs ("file://" + sroot + "/dot.png"))
       (test (two? pic) (pic 0 = 8) (pic 1 = 6) (#(pic 2) = 8 * 6 * 4)
             (s8 'links 0 = l8 + 3) (#(filter cells? (s8 'ls)) = 3)
             (rp = 'none))),
    ; less's keys still reach less
    wkeys st "G",
    test (0 <= st 'top),
    wkeys st "q",
    test (st 'quit),
    hark ["rm" "-rf" root],
    0))

;; https, where openssl is here: a page off openssl's s_server, its leaf under a root laid
; here -- taken with that root named by SSL_CERT_FILE, refused under the host's own bundle
; with the reason said
(: G (cite 'kore 'ww-get)
   os? (two? (stat "/usr/bin/openssl"))
   odir (cwd 0 + "/out/.wwwt-" + show (getpid 0))
   (osh c) (hark ["sh" "-c" ("exec 2>/dev/null; cd " + odir + " && " + c)])
   (srv port) (: p (tether ["openssl" "s_server" "-quiet" "-tls1_3" "-naccept" "1" "-www" "-accept" ("127.0.0.1:" + show port)
                            "-key" (odir + "/leaf.key") "-cert" (odir + "/leaf.pem")])
                 p)
   (reap p) (still <p 15, (gather <p @ g (two? g || nom? g ? g (rest 2, reap p))))
   cf0 (getenv "SSL_CERT_FILE") home0 (getenv "HOME")
   _ (os? ? (hark ["mkdir" "-p" (odir + "/.love")],
             osh ("openssl req -x509 -newkey rsa:2048 -nodes -keyout root.key -out root.pem -days 2 -subj /CN=t-root"
                  + " -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign"),
             osh ("printf 'basicConstraints=critical,CA:FALSE\\nsubjectAltName=IP:127.0.0.1\\n' > l.cnf"
                  + " && openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout leaf.key -subj /CN=t-leaf -out leaf.csr"
                  + " && openssl x509 -req -in leaf.csr -CA root.pem -CAkey root.key -days 2 -extfile l.cnf -out leaf.pem"))
          0)
   ; "cannot connect" is the server not listening yet
   (page port) (: p (srv port)
                  g (test-until (r \ (has (r 1) "cannot connect")) (_ \ (G ("https://127.0.0.1:" + show port + "/") 1)))
                  (reap p, g))
   (has s x) (string? s && 0 <= fsub s x 0)
   ((os? ?
       (: _ (setenv "SSL_CERT_FILE" (odir + "/root.pem"))
          a (page (test-free 0))
          _ (setenv "SSL_CERT_FILE" "/nonexistent/bundle.pem")
          b (page (test-free 0))
          (setenv "SSL_CERT_FILE" (string? cf0 ? cf0 ""),
           hark ["rm" "-rf" odir],
           test (<a = 0) (has (a 3) "TLSv1.3") (<b = 1) (has (b 1) "no root certificates") (has (b 1) "tls_pins")))
       0),
    0))

(test_fin (), puts "www: ok", putc 10, 0)
