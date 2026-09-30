; src/apps/sb/http.l -- the smallest HTTP/1.1 get that can walk a store, over the
; `connect` socket floor (src/love/sock.c).
;
; a client only, and only get: the store is content-addressed, so every fetch is a plain
; get on a known name, verified by sha256 on arrival; any static file server is a remote.
; we send `Connection: close` and read to EOF: prel's slurp draws to end-of-stream, so a
; keep-alive response would park the task forever.
;
; rides module 'sb, so these names never reach the book; `dial` comes off module 'dns,
; scoped here to the wrap's own compile.
(module 'sb
(borrow 'dns)
(borrow 'posix)
(:
   ; "80" -> 80. `int` is a truncation, not a parser, so digits are ours.
   (digits s)
    (: n #s
       (go i a) (n <= i ? (0 < n ? a)
                   (s i @ c
                      (47 < c && c < 58 ? (go (i + 1) (a * 10 + (c - 48))))))
       (go 0 0))

   ; the index of `sub` in `s` at or after `cite`, searching at most `cap`
   ; positions -- headers sit in the first few KB and a whole-body scan would be
   ; O(n*m) for nothing. -1 when absent.
   (findsub s sub cite cap)
    (: n #s m #sub lim (n - m < cap ? (n - m) cap)
       (go i) (? (lim < i) -1
                 (snip s i (i + m) = sub) i
                 (go (i + 1)))
       (go cite))

   (url? u) (7 <= tally u && snip u 0 7 = "http://")
   ; "http://host[:port]/path" -> (host port path) | ()
   (url-split u) ((cite 'kore 'wg-url u) @ w (w && !<w ? >w))        ; wget's split, http only

   ; one get -> (status body) | (). () is a dead socket or an unreadable
   ; response; a 404 is a perfectly good answer and comes back as (404 ..), so
   ; the caller can tell "no such object" from "no such host".
   (http-get host port path)
    (dial host port @ s
       (? !(hot? s) ()
          (: _ (say s ("GET " + path + " HTTP/1.1\r\nHost: " + host
                       + "\r\nConnection: close\r\nUser-Agent: sb\r\n\r\n"))
             _ (flush s)
             r (slurp s)
             (close s,
              (? !(0 < tally r) ()
                 (findsub r "\r\n\r\n" 0 8192 @ k
                    (k < 0 ? ()
                       (: head (snip r 0 k)
                          body (snip r (k + 4) #r)
                          sp (findsub head " " 0 64)
                          code (sp < 0 ? () (digits (snip head (sp + 1) (sp + 4))))
                          (code ? [code body])))))))))

   ; get a store object under a base url -> (1 body) | (). the presence wrapper,
   ; not the bare body: a 0-byte blob is a legitimate object and `!""` is true,
   ; so a bare body would read as absence -- the same law the empty-file fix set
   ; down (presence is the wrapper, never the net). anything but 200 is absence,
   ; which is all a walk needs to know.
   (http-fetch base rel)
    (url-split (base + rel) @ u
       (two? u ?
          (http-get <u <>u <>>u @ r
             (two? r && 200 = <r ? [1 <>r]))))

   ; the first form of a string, if it is a list; () for anything else.
   (readform s)
    (: r (sound s)
       d (two? r ? <r)
       (two? d ? d)))

) ; module 'sb
