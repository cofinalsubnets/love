; kiosko -- a static web server over a directory, and nothing else.
; concurrency is the scheduler's: `await` parks the accept loop, each client is a `twirl`
; task, reads yield on a not-ready fd. get and head only; every reply closes the connection.
; the command line is kore's httpd (src/apps/kore/net.l); hesc and penc serve a make hook's pages
(module (kiosko serve serve5 serve1 gulp hesc penc)

; --- little utils -------------------------------------------------------------------
(borrow 'posix)
; segs and pclean, for the request guard below
(borrow 'path)
(: (splits s c) (:- (g 0 0 ())
                    (g i st acc) (i < #s ? (s i = c ? (g (i + 1) (i + 1) (snip s st i . acc))
                                                      (g (i + 1) st acc))
                                   (rev (snip s st #s . acc))))
   (dir? p)     (two? (readdir p))
   (fsize p)    (stat p @ (s . _) s)
   ; fsize is nil for missing and empty alike: presence is stat's answer, not its net
   (fhere? p)   (two? (stat p))
   ; read a whole file in chunks with `swig`, by one of three lanes chosen by what stat promises.
   ; swig's 0 is nothing waiting or EOF; only `see` tells them apart (-1 at the end), and
   ; a byte it returns is real and kept.
   swigp        (lit? (cite 'posix 'swig))       ; pinned before the lanes read it
   ; at or above this size, handing back the cask (two syscalls) beats one copy; measured
   caskfloor    131072
   ; lane 3: chunk into a jug until the reads stop. for what stat cannot size (procfs, a
   ; fifo) and when a lane below finds stat wrong; it reopens, the others consumed theirs
   (gulp-loop f) (open f "r" @ q
                    (? !(hot? q) ()
                       (: j (jug 0) buf (cask 65536)
                          (go _) (swig q buf @ k
                                    (charm? k && 0 < k ?
                                     (say j (snip buf 0 k), go ())
                                     (see q @ -1 0 c (put j c, go ()))))
                          (go (), close q, slurp j))))
   (gulp f)
   (: sz (fsize f)
      n (sz || 0)
      ; a size of 0 promises nothing: procfs reports 0 and its short reads are not the end
      (? !(0 < n) (gulp-loop f)
         !swigp (gulp-loop f)                          ; no cb.c: the slow lane still works
         (open f "r" @ q
            (? !(hot? q) ()
               ; lane 1, zero copies: read exactly n and hand back the cask (say and tally
               ; take one). a full buffer is not the end, so a one-byte probe proves it.
               (caskfloor <= n)
               (: buf (cask n)
                  k (swig q buf)
                  probe (cask 1)
                (k = n && 0 = swig q probe && -1 = see q ?
                 (close q, buf)
                 (close q, gulp-loop f)))    ; it grew, or it shrank
               ; lane 2, one copy: ask for n + 1. a regular file reads short only at the
               ; end, so a short read proves the whole body in one syscall.
               (: buf (cask (n + 1))
                  k (swig q buf)
                (charm? k && 0 < k && k < #buf ?
                 (snip buf 0 k @ s (close q, s))
                 (close q, gulp-loop f)))))))    ; it grew past its own size
   ; "" and () are both nil, and a string is not lit?: only `=` tells them apart
   (got? x)     !(x = ())
   ; the request head, read in chunks up to a blank line (\r\n\r\n, or a bare \n\n).
   ; capped, or a peer that never sends one keeps us reading.
   reqcap       32768
   (reqblk c)   (: buf (cask 2048)
                   (go acc)
                   (? (has? acc "\r\n\r\n" || has? acc "\n\n") acc
                      (reqcap < #acc) acc
                      (swig c buf @ k
                       (charm? k && 0 < k ? (go (acc + snip buf 0 k))
                        (see c @ -1 acc ch (go (acc + string ch))))))
                   (go ""))
   ; the request line: up to the first newline, without its carriage return.
   (line1 s)    (: n #s
                   (go i) (i < n && s i != 10 ? (go (i + 1)) i)
                   e (go 0)
                   (snip s 0 (0 < e && s (e - 1) = 13 ? (e - 1) e)))
   ; the first space-separated word of s, and everything after it
   (word1 s)    (: n #s
                   (go i) (i < n && s i != 32 ? (go (i + 1)) i)
                   (snip s 0 (go 0)))
   (after1 s)   (: n #s
                   (skipw i) (i < n && s i != 32 ? (skipw (i + 1)) i)
                   (skips i) (i < n && s i  = 32 ? (skips (i + 1)) i)
                   (snip s (skips (skipw 0)) n)))

; --- the request line ----------------------------------------------------------------
(: ; percent-decoding; `+` is a space only in a query, already cut. () for a control
   ; byte, raw or decoded, which could otherwise reach a header.
   (pdecode s) (: n #s
                  (step i acc c) (c < 32 || c = 127 ? () (g i (acc + string c)))
                  (g i acc)
                  (!(i < n) ? acc
                     (s i @ c
                        (c = 37 && i + 2 < n
                         ? (: h (hexv (s (i + 1))) l (hexv (s (i + 2)))
                              (-1 < h && -1 < l ? (step (i + 3) acc (16 * h + l))
                                                  (step (i + 1) acc c)))
                           (step (i + 1) acc c))))
                  (g 0 ""))
   ; a path going back out, in a Location or an href: unreserved bytes and / as they are
   hexd "0123456789ABCDEF"
   (penc s) (catmap (c \ (48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122 || c = 45
                          || c = 46 || c = 95 || c = 126 || c = 47) ? (string c)
                         ("%" + string (hexd (c // 16)) + string (hexd (c % 16))))
                    (map (i \ s i) ^#s))
   ; ..and text going into html
   (hesc s) (catmap (c \ c @ 38 "&amp;" 60 "&lt;" 62 "&gt;" 34 "&quot;" 39 "&#39;" (string c))
                    (map (i \ s i) ^#s))
   ; a segment that starts with a dot: .git, .env, .ssh
   (dotted? p) (: n #p (g i) (? (n - 1 <= i) 0 (p i = 47 && p (i + 1) = 46) 1 (g (i + 1)))
                  (g 0))
   (cutq s)    (: n #s (g i) (? (i >= n) s
                                (s i = 63 || s i = 35) (snip s 0 i)
                                (g (i + 1)))
                (g 0))
   ; the one guard: pclean resolves `.` and `..`, and a leading ".." left over is an
   ; escape, so (). downstream is plain string append. a trailing slash is kept for the
   ; directory redirect.
   (rooted p)  (!(0 < #p && p 0 = 47) ? ()
                  (pclean (segs p) () @ cl
                     (two? cl && <cl = ".." ? ()
                        ("/" + join "/" cl + (ends? p "/" && two? cl ? "/" ""))))))

; --- what a file is ------------------------------------------------------------------
(: types '(("html" "text/html; charset=utf-8") ("htm" "text/html; charset=utf-8")
           ("css" "text/css; charset=utf-8")   ("js" "text/javascript; charset=utf-8")
           ; a module is REFUSED on a non-js type, so .mjs owes a row of its own
           ("mjs" "text/javascript; charset=utf-8")
           ("json" "application/json")         ("txt" "text/plain; charset=utf-8")
           ("md" "text/plain; charset=utf-8")  ("xml" "application/xml")
           ("svg" "image/svg+xml")             ("png" "image/png")
           ("jpg" "image/jpeg")                ("jpeg" "image/jpeg")
           ("gif" "image/gif")                 ("webp" "image/webp")
           ("ico" "image/x-icon")              ("pdf" "application/pdf")
           ("woff2" "font/woff2")              ("woff" "font/woff")
           ("wasm" "application/wasm"))
   (extof p) (splits p 46 @ ps (atom? >ps ? "" (: (last l) (two? >l ? (last >l) <l) (last ps))))
   (mime p)  (: e (extof p) (g l) (? (atom? l) "application/octet-stream"
                                     (<<l = e) <><l
                                     (g >l))
              (g types)))

; --- the response --------------------------------------------------------------------
; one shape for every answer. head sends a get's headers, Content-Length included, and no body
(: (reply c code why ctype body head?)
   (say c ("HTTP/1.1 " + show code + " " + why + "\r\n"
                + "Content-Type: " + ctype + "\r\n"
                + "Content-Length: " + show #body + "\r\n"
                + "Cache-Control: no-cache\r\n"
                ; isolation, so a page may use SharedArrayBuffer
                + "Cross-Origin-Opener-Policy: same-origin\r\n"
                + "Cross-Origin-Embedder-Policy: require-corp\r\n"
                + "Connection: close\r\n\r\n"),
    !head? ? (say c body),
    flush c,
    code)
   ; an error is a page too -- small, and readable when a browser shows it
   (oops c code why head?)
   (reply c code why "text/html; charset=utf-8"
          ("<!doctype html><meta charset=\"utf-8\"><title>" + show code + " " + why
           + "</title><body style=\"font:16px ui-serif,Georgia,serif;padding:3rem\">"
           + "<h1>" + show code + " &middot; " + why + "</h1><p>kiosko</p>") head?)
   ; a directory with no index.html: list it, directories first, each entry a link. plain
   ; enough that no stylesheet is needed and no page of the site is shadowed by it.
   (listing c root p head?)
   (: full (root + p)
      names (sort (filter (f \ !(0 < #f && f 0 = 46)) (readdir full)))
      (row f) ((dir? (full + f) ? (f + "/") f) @ sub
                 ("<li><a href=\"" + hesc (penc sub) + "\">" + hesc sub + "</a></li>"))
      body ("<!doctype html><meta charset=\"utf-8\"><title>" + hesc p + "</title>"
            + "<body style=\"font:16px ui-serif,Georgia,serif;padding:2rem\">"
            + "<h1>" + hesc p + "</h1><ul>"
            + (p = "/" ? "" "<li><a href=\"..\">../</a></li>")
            + catmap row names + "</ul>")
      (reply c 200 "OK" "text/html; charset=utf-8" body head?)))

; --- serving one request --------------------------------------------------------------
; headers are read and dropped; consuming them lets the peer finish writing, so the close is
; clean, not a reset. `make`, asked before the disk, takes (path head) and answers
; [ctype body] or () for "not mine"; a () make is the plain static server.
(: (serve1 root make c)
   (: blk (reqblk c)
      line (line1 blk)
      (0 = #blk ? 0                                      ; the peer went away
         (: meth (word1 line)
            raw (word1 (after1 line))
            head? (meth = "HEAD")
            (? !(meth = "GET" || head?) (oops c 405 "Method Not Allowed" 0, [405 meth raw])
               (: d (pdecode (cutq raw))
                  p (rooted d)
                  (? !(string? d) (oops c 400 "Bad Request" head?, [400 meth raw])
                     !(string? p) (oops c 403 "Forbidden" head?, [403 meth raw])
                     (dotted? p) (oops c 404 "Not Found" head?, [404 meth raw])
                     ((make ? (make p blk)) @ m
                        (two? m ?
                           (reply c 200 "OK" <m <>m head?, [200 meth raw])
                     (root + p @ full
                        (? (dir? full)
                           ; redirect to the slashed form so relative links resolve;
                           ; then index.html; then a listing
                           (? !(ends? p "/")
                              (say c ("HTTP/1.1 301 Moved Permanently\r\nLocation: " + penc p
                                      + "/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"),
                               flush c, [301 meth raw])
                              (fhere? (full + "index.html"))
                              (gulp (full + "index.html") @ b
                                 (reply c 200 "OK" "text/html; charset=utf-8" b head?, [200 meth raw]))
                              (listing c root p head?, [200 meth raw]))
                           !(fhere? full) (oops c 404 "Not Found" head?, [404 meth raw])
                           (gulp full @ b
                              (got? b ? (reply c 200 "OK" (mime full) b head?, [200 meth raw])
                                 (oops c 403 "Forbidden" head?, [403 meth raw]))))))))))))))

; --- the loop ---------------------------------------------------------------------------
(: (note quiet l) (!quiet ? (say err $ "kiosko: " + show <l + " " + <>l + " " + <>>l + "\n"))
   ; collect finished sessions: an uncaught task stays on the run ring, walked every switch.
   ; `scoop` answers (pid . retval) or () without blocking; test with two?, a session returns ()
   (drain _)  (two? (scoop 0) ? (drain ()))
   ; `before`, a thunk or (), runs per client in the accept task, so two never overlap
   (accept-loop root l quiet before make)
   (: _ (await l)
      c (accept l)
      (drain (),
       hot? c ? (before ? (before ()),
               ; trapped per session, or one scare takes the server down; nothing unwinds,
               ; so the close sits here, and the client gets a 500
               twirl (_ \ (: r (trap (serve1 root make) c
                                      (a \ b \ (oops c 500 "Internal Server Error" 0, [500 "-" (show a)])))
                                 (r ? (note quiet r), seal c 1, close c))) ()),
       accept-loop root l quiet before make))
   ; `port` a fixnum for loopback or [host port]. answers the listen failure's nom, so a
   ; caller can say why. pass every operand: a partial is a truthy closure, read as success.
   ; serve is serve5 with no make hook
   (serve root port quiet before) (serve5 root port quiet before ())
   (serve5 root port quiet before make)
   (: r (root @ (s + "/") s root)
      a (charm? port ? ["127.0.0.1" port] port)
      l (listen ['tcp <a <>a])
    (hot? l ?
       (!quiet ? (say err $ "kiosko: serving " + r + " on http://" + <a + ":" + show <>a + "/"
                   + (<a = "0.0.0.0" ? " (every address)" "") + "\n"),
        accept-loop r l quiet before make,
        close l,
        1)
       l)))

) ; module kiosko
