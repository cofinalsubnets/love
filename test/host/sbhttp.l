; test/host/sbhttp.l -- svalbard pulling a store over a real socket, kiosko serving the origin's
; .sb/ in the same process. the claim: an sb remote needs no server logic -- the store is
; content-addressed and immutable, with no listing, and the walk finds everything through what
; it already fetched (/tips, then each patch's deps and hunks). an empty blob rides through too.
(borrow 'sb)                                 ; the baked module: the whole stack, spliced
(borrow 'kiosko)

(: SD (cite 'sb)
   record (SD 'sb-record) sync (SD 'sb-sync) bank (SD 'sb-bank)
   look (SD 'look) lay (SD 'lay) mk (SD 'mk) dirty (SD 'dirty) refof (SD 'refof)
   urlsplit (SD 'url-split) urlp (SD 'url?) digits (SD 'digits) readform (SD 'readform)
   ; every path this lays is the pid's own, so two runs over one out/ keep apart
   root ("out/.sbhttp-" + show (getpid 0))
   _ (mkdir root 493)
   _ (mkdir (root + "/origin") 493, mkdir (root + "/clone") 493)
   home (cwd 0)
   ; the server task shares this process's cwd, and the client chdirs into the
   ; clone before pulling -- so the root it serves must be absolute
   oroot (home + "/" + root + "/origin/.sb")
   ; --- the origin nest: a nested path and an empty file, then a release ---
   _ (chdir (root + "/origin"))
   _ (mkdir "sub" 493)
   _ (lay "a.txt" "v1\n", lay "sub/b.txt" "nested\n", lay "empty.txt" "")
   _ (mk (), record "first")
   _ (lay "a.txt" "v2\n", record "second")
   _ (bank '("v1"))
   nblob #(readdir ".sb/blob")
   _ (chdir home)
   ; --- kiosko over the origin's .sb/, in a task ---
   pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (_ \ ((: (g k) (: _ (await l)
                                c (accept l)
                                ((hot? c ? (cite 'kiosko 'serve1 oroot () c, close c)),
                                 g k)))
                    0)) 0)
   ; --- the pull, from a nest that has never seen the origin ---
   _ (chdir (root + "/clone"))
   got (sync ("http://127.0.0.1:" + show port + "/"))
   a (look "a.txt") b (look "sub/b.txt") e (look "empty.txt")
   clean (dirty ())
   ref (refof "v1")
   npat #(readdir ".sb/patch")
   _ (chdir home)
   _ (hark ["rm" "-rf" root]))

(test
 (urlp "http://h/") !(urlp "https://h/") !(urlp "../peer")     ; the url gate
 (5432 = digits "5432") !(digits "8x")
 (show '("h" 8080 "/a") = show (urlsplit "http://h:8080/a"))
 (show '("h" 80 "/") = show (urlsplit "http://h"))
 !(urlsplit "https://h/") !(urlsplit "http://h:x/") !(urlsplit "http:///a")
 (show '(1 2) = show (readform "(1 2)"))                         ; a form off a string
 (0 < got)                                                           ; the pull went through
 (2 = npat) (4 = nblob)                                              ; every patch, every blob
 (<>a = "v2\n")                                                    ; the head content
 (<>b = "nested\n")                                                ; ...a nested path materialized
 (two? e) (0 = #<>e)                                        ; ...and the empty file, 0 bytes
 (two? ref)                                                          ; the ref rode along
 (0 = clean))                                                        ; the tree matches the snap

(test_fin (), puts "sbhttp: ok", putc 10, 0)
