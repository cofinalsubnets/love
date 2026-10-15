; test/host/kiosko.l -- the static server over a real socket, server task and client in one
; process: the `..` guard, methods, request reading, paths, escapes, content types, 404
; not in the corpus: the socket nifs are not in love0. run: cat test/00-init.l test/host/kiosko.l | out/love

(borrow 'kiosko)                                 ; the baked module, spliced

(test
 (elem 'kiosko (cite ()))
 (elem 'serve1 (keys (cite 'kiosko)))
 (lit? (cite 'kiosko 'serve))
 !(cite 'kiosco))

; the shelf
(: dir "/tmp/kioskotest"
   (put-file f s) (open (dir + "/" + f) "w" @ q (say q s, close q))
   _ (hark ["rm" "-rf" dir])
   _ (mkdir dir 493)
   _ (mkdir (dir + "/sub") 493)
   _ (mkdir (dir + "/bare") 493)
   _ (put-file "index.html" "<h1>root</h1>")
   _ (put-file "a.css" "body{color:red}")
   _ (put-file "odd name.txt" "spaced")
   _ (put-file "a..b" "not an escape")
   _ (put-file "blob.zzz" "unknown")
   _ (put-file "sub/index.html" "<h1>sub</h1>")
   _ (put-file "bare/one.txt" "listed")
   ; a file past the 64K swig gulps: a tail, a chunk or a byte at the seam is lost only there
   big (: (rep s n) (n < 1 ? "" (s + rep s (n - 1)))
          line "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde\n"
          (rep line 3000))                              ; 64 bytes x 3000 = 192000
   _ (put-file "big.txt" big)

   ; Connection: close, so slurping to EOF is the whole response
   pl (test-listen 0)
   port <pl
   l (pl 1)
   _ (test (lit? l))
   ; `await` parks the task on the listener (a bare `accept` blocks the process); it stops on a
   ; flag rather than a count, so a new assert cannot hang the run
   stop {}
   ; the hook takes two, path and head: short an arg it curries, and every claim reads as a 404
   (mk p head) (? (p = "/made") '("text/plain" "made on the way out")
                  (p = "/a.txt") '("text/plain" "the hook wins over the file")
                  (p = "/echo") ["text/plain" head]
                  ())
   srv (twirl (_ \ ((: (g k) (: _ (await l)
                                c (accept l)
                                ; claims /made, () for everything else, a file on disk too
                                ((hot? c ? (serve1 dir mk c, seal c 1, close c) 0),
                                 (peep stop 0 0 ? 1 (g (k + 1)))))) 0)) 0)
   (ask req) (: c (connect ['tcp "127.0.0.1" port])
                _ (say c req)
                _ (flush c)
                r (slurp c)
                (close c,
                 r))
   (get p)   (ask ("GET " + p + " HTTP/1.1\r\nHost: x\r\n\r\n"))
   (code r)  (#r @ n ((: (g i) (i < n && !(r i = 32) ? (g (i + 1)) (snip r (i + 1) (i + 4)))) 0))

   ; the maker hook is asked before the file on disk; () is the plain static server
   _ (test
      ("200" = code (get "/made"))
      (has? (get "/made") "made on the way out")
      (has? (get "/a.txt") "the hook wins over the file")
      (has? (get "/echo") "GET /echo")
      ("404" = code (get "/nope")))

   ; the guard, first
   _ (test
      (code (get "/../../etc/passwd") = "403")
      (code (get "/sub/../../etc/passwd") = "403")
      (code (get "/%2e%2e/%2e%2e/etc/passwd") = "403")   ; ..the form that is actually tried
      (code (get "..") = "403")                          ; unrooted
      ; a segment test: a name merely containing .. is ordinary
      (code (get "/a..b") = "200")
      (has? (get "/a..b") "not an escape"))

   ; methods
   hd (ask "HEAD /index.html HTTP/1.1\r\nHost: x\r\n\r\n")
   _ (test
      (code (get "/index.html") = "200")
      (code hd = "200")
      (has? hd "Content-Length: 13")
      !(has? hd "<h1>root</h1>")
      (code (ask "PUT / HTTP/1.1\r\nHost: x\r\n\r\n") = "405")
      (code (ask "DELETE / HTTP/1.1\r\nHost: x\r\n\r\n") = "405"))

   ; the head is taken in one swig gulp: a bare-lf blank line and a request in pieces would
   ; wedge rather than fail, so the gate has to find the hang
   _ (test (code (ask "GET /index.html HTTP/1.1\nHost: x\n\n") = "200"))     ; lf only
   split (: c (connect ['tcp "127.0.0.1" port])
            _ (say c "GET /index.htm")
            _ (flush c)
            _ (say c "l HTTP/1.1\r\nHost: x\r\n\r\n")
            _ (flush c)
            r (slurp c)
            (close c,
             r))
   _ (test (code split = "200") (has? split "<h1>root</h1>"))

   ; paths
   _ (test
      (code (get "/") = "200")
      (has? (get "/") "<h1>root</h1>")
      (has? (get "/index.html?v=2") "<h1>root</h1>")   ; a query string is cut
      (has? (get "/odd%20name.txt") "spaced")          ; ..and an escape is decoded
      (code (get "/sub") = "301")
      (has? (get "/sub") "Location: /sub/")
      (has? (get "/sub/") "<h1>sub</h1>")
      (has? (get "/bare/") "one.txt")
      (code (get "/nope.html") = "404"))

   ; a control byte, raw or escaped, is 400 (a NUL cuts the path at open(2), CR LF reaches
   ; Location); a dot segment is 404 and hidden in a listing
   ; a name is escaped for html in a listing, and percent-encoded in an href and a Location
   _ (mkdir (dir + "/d\r\nX-Inj: 1") 493)
   _ (put-file "d\r\nX-Inj: 1/f" "x")
   _ (mkdir (dir + "/sp ace") 493)
   _ (put-file "sp ace/f" "x")
   _ (put-file ".env" "secret")
   _ (mkdir (dir + "/.git") 493)
   _ (put-file ".git/config" "secret")
   _ (put-file "bare/.hid" "secret")
   _ (put-file "bare/<b>\"'&.txt" "odd")
   ls (get "/bare/")
   _ (test
      (code (get "/index.html%00.css") = "400")
      (code (get "/a%0d%0aSet-Cookie:%20x") = "400")
      (code (get "/d%0D%0AX-Inj:%201") = "400")
      !(has? (get "/d%0D%0AX-Inj:%201") "X-Inj")
      (code (get "/a%7fb") = "400")
      (code (get "/.env") = "404")
      (code (get "/%2eenv") = "404")
      (code (get "/sub/../.env") = "404")
      (code (get "/.git/config") = "404")
      (has? (get "/sp%20ace") "Location: /sp%20ace/\r\n")
      (has? ls "one.txt")
      !(has? ls ".hid")
      (has? ls ">&lt;b&gt;&quot;&#39;&amp;.txt</a>")
      (has? ls "href=\"%3Cb%3E%22%27%26.txt\""))

   ; a body past the chunk boundary
   bigr (get "/big.txt")
   _ (: i ((: (g k) (k < #bigr && !(snip bigr k (k + 4) = "\r\n\r\n") ? (g (k + 1)) k)) 0)
        body (snip bigr (i + 4) #bigr)
        _ (test (#big = 192000)
                  (has? bigr "Content-Length: 192000")
                  (#body = #big)
                  (body = big)))

   ; `gulp` hands back its cask at or above kiosko's caskfloor and copies out below it:
   ; one file each side of the line; read caskfloor before touching the sizes
   (dbl s n) (n <= #s ? (snip s 0 n) (dbl (s + s) n))          ; O(n), not (s + rep ..)
   under (dbl "abcdefgh" 131064)
   over  (dbl "abcdefgh" 131080)
   (put-file "under.txt" under,
    put-file "over.txt" over,
    (: (bodyof r) (: n #r
                     i ((: (g k) (k < n && !(snip r k (k + 4) = "\r\n\r\n") ? (g (k + 1)) k)) 0)
                     (snip r (i + 4) n))
       u (get "/under.txt") o (get "/over.txt")
       (test (#under = 131064) (#over = 131080)  ; really either side of 131072
               (bodyof u = under)
               (bodyof o = over)
               (has? u "Content-Length: 131064")
               (has? o "Content-Length: 131080"))),

    ; the read's slow lane: a short read proves the end only when stat's size was not 0,
    ; which procfs breaks; /proc/self/environ is stable and usually past the 4096 buffer
    (: e (gulp "/proc/self/environ")
       r (open "/proc/self/environ" "r" @ q (slurp q))
       big (gulp "/proc/cpuinfo")
       bigr (open "/proc/cpuinfo" "r" @ q (slurp q))
       (test (0 < #e)
               (e = r)
               (#big = #bigr))),

    ; content types
    test (has? (get "/index.html") "Content-Type: text/html")
         (has? (get "/a.css") "Content-Type: text/css")
         (has? (get "/blob.zzz") "Content-Type: application/octet-stream")
         ; every answer framed alike, so the client just slurps
         (has? (get "/a.css") "Connection: close")
         (has? (get "/a.css") "Content-Length: 15"),

    ; raise the flag, then one last request lets the loop see it
    pin stop 0 1,
    test (code (get "/index.html") = "200"),
    catch srv,
    close l,

    test_fin (),
    puts "src/apps/kiosko: ok -- the static web server (guard, methods, paths, types)
",
    0))
