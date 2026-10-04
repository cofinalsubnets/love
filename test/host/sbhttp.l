; --- test/host/sbhttp.l: svalbard pulling a store over a real socket ---
; not in the test/*.l corpus: the socket nifs live in src/love/sock.c, which love0 does
; not link, and this loads two crew files and splices their modules.
;
; the whole thing runs in one process, test/host/kiosko.l's shape: kiosko twirled
; onto a listener over the origin nest's .sb/, svalbard.s client in the main task,
; the two interleaving through the cooperative scheduler. so this is a real HTTP
; pull off a real socket, and the two crew members meet the way they would in
; anger -- love serving love.
;
; what it proves is the claim the design rests on: an sb remote needs no server
; logic. the store is content-addressed and immutable, there is no listing
; endpoint, and the walk discovers everything by reading what it already fetched
; -- /tips names the heads, each patch names its `deps` and its `hunks`. an
; empty blob rides through too, which is the case that found kiosko's 404.
(borrow 'sb)                                 ; the baked module: the whole stack, spliced
(borrow 'kiosko)

(: SD (cite 'sb)
   record (SD 'sb-record) sync (SD 'sb-sync) bank (SD 'sb-bank)
   look (SD 'look) lay (SD 'lay) mk (SD 'mk) dirty (SD 'dirty) refof (SD 'refof)
   urlsplit (SD 'url-split) urlp (SD 'url?) digits (SD 'digits) readform (SD 'readform)
   ; every path this lays is the pid's own, so two runs over one out/ keep apart
   root ("out/.sbhttp-" + show (getpid 0))
   _ (mkdir root 493)
   _ (mkdir (root + "/origin") 493) _ (mkdir (root + "/clone") 493)
   home (cwd 0)
   ; the server task shares this process's cwd, and the client chdirs into the
   ; clone before pulling -- so the root it serves must be absolute
   oroot (home + "/" + root + "/origin/.sb")
   ; --- the origin nest: a nested path and an empty file, then a release ---
   _ (chdir (root + "/origin"))
   _ (mkdir "sub" 493)
   _ (lay "a.txt" "v1\n") _ (lay "sub/b.txt" "nested\n") _ (lay "empty.txt" "")
   _ (mk ()) _ (record "first")
   _ (lay "a.txt" "v2\n") _ (record "second")
   _ (bank '("v1"))
   nblob (#(readdir ".sb/blob") + #(readdir ".sb/z"))
   _ (chdir home)
   ; --- kiosko over the origin's .sb/, in a task ---
   pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (\ _ ((: (g k) (: _ (await l)
                                c (accept l)
                                _ (hot? c ? (cite 'kiosko 'serve1 oroot () c, close c))
                                (g k)))
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

; --- a hostile mirror: every object hashes honestly, but each tip's patch aims at the
;     puller's git config, sb's own store, or out through a symlink in the tree. the one
;     plain patch lands; the rest are refused, and git's config is never touched ---
(: SD (cite 'sb)
   sync (SD 'sb-sync) look (SD 'look) lay (SD 'lay) mk (SD 'mk) refof (SD 'refof)
   root ("out/.sbevil-" + show (getpid 0))
   home (cwd 0)
   _ (mkdir root 493)
   _ (: e (root + "/evil/.sb/") (mkdir (root + "/evil") 493, mkdir e 493,
                                  mkdir (e + "blob") 493, mkdir (e + "patch") 493))
   eroot (home + "/" + root + "/evil/.sb")
   (blob s) (: h (sha256 s) _ (lay (eroot + "/blob/" + h) s) h)
   (patch p h) (: t (show ['patch ['note "evil"] ['time 0] ['deps] ['hunks [p () h]]])
                  i (sha256 t) _ (lay (eroot + "/patch/" + i) t) i)
   cfg (blob "[core]\n\tfsmonitor = touch pwned\n")
   own (blob "owned\n")
   tips (map (p \ patch p (p = ".git/config" ? cfg own))
             [".git/config" ".GIT/config" ".git./hooks/post-checkout" "sub/.git/config"
              ".sb/refs" "sub/.sb/tips" "link/planted" (string [97 10 98]) "ok.txt"])
   _ (lay (eroot + "/tips") (show tips))
   _ (lay (eroot + "/refs") (show [["v1" ["zz"] 0]]))       ; a ref whose tip is no id
   ; the victim: a git checkout with a link out of the tree
   _ (mkdir (root + "/outside") 493)
   _ (mkdir (root + "/victim") 493) _ (mkdir (root + "/victim/.git") 493)
   _ (lay (root + "/victim/.git/config") "orig\n")
   _ (symlink "../outside" (root + "/victim/link"))
   pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (\ _ ((: (g k) (: _ (await l)
                                c (accept l)
                                _ (hot? c ? (cite 'kiosko 'serve1 eroot () c, close c))
                                (g k)))
                    0)) 0)
   _ (chdir (root + "/victim"))
   _ (mk ())
   got (sync ("http://127.0.0.1:" + show port + "/"))
   gcfg (look ".git/config")
   ok (look "ok.txt")
   planted (look "../outside/planted")
   stray (map (p \ two? (look p)) [".GIT/config" ".git./hooks/post-checkout" "sub/.git/config"
                                    "sub/.sb/tips" (string [97 10 98])])
   srefs (look ".sb/refs")
   ref (refof "v1")
   _ (chdir home)
   _ (hark ["rm" "-rf" root]))

(test
 (<>gcfg = "orig\n")                                               ; git's config untouched
 (<>ok = "owned\n")                                                ; the plain patch landed
 !(two? planted)                                                   ; nothing through the link
 (show stray = show [0 0 0 0 0])                                   ; nor under any store name
 !(two? srefs) !ref                                                ; the malformed ref was dropped
 !got)                                                             ; and the pull says it was refused

(test_fin (), puts "sbhttp: ok", putc 10, 0)
