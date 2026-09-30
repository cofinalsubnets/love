; --- test/host/wget.l: kore's wget over a real socket, and the tls floor under it ---
; not in the test/*.l corpus: the socket nifs are src/love/sock.c's. kiosko is twirled onto
; a listener over a scratch directory and wget pulls a file back through it -- love
; serving love, test/host/sbhttp.l's shape. the https half is held to the RFC vectors
; the handshake stands on (x25519 from 7748, hmac from 4231): a live peer is
; test/host/wgetnet.l, opt-in, because a gate must not need the internet.
;   cat test/00-init.l test/host/wget.l | out/love
(borrow 'kiosko)
(borrow 'tls)

(: T (cite 'tls)
   unhex (T 'unhex) hex (T 'hex)
   wget (cite 'kore 'wget-main)
   ; every path this lays is the pid's own, so two runs over one out/ keep apart
   root ("out/.wget-" + show (getpid 0))
   _ (mkdir root 493) _ (mkdir (root + "/site") 493)
   home (cwd 0)
   sroot (home + "/" + root + "/site")
   ; a 70000-byte file: bigger than one socket gulp, so the read runs to the peer's close
   blob (string (map (\ i (i & 255)) ^70000))
   _ (: p (open (sroot + "/blob.bin") "w") _ (say p blob) (close p))
   pl (test-listen 0)
   port <pl
   l (pl 1)
   srv (twirl (\ _ ((: (g k) (: _ (await l)
                                c (accept l)
                                _ (hot? c ? ((cite 'kiosko 'serve1) sroot () c,
                                               close c) ())
                                (g k)))
                    0)) 0)
   out1 (root + "/got.bin")
   rc (wget ["-q" "-O" out1 ("http://127.0.0.1:" + show port + "/blob.bin")])
   got (: p (open out1 "r") (hot? p ? (: s (slurp p) _ (close p) s) ()))
   rc404 (wget ["-q" "-O" (root + "/none") ("http://127.0.0.1:" + show port + "/absent.bin")])
   rcbad (wget ["-q" "-O" (root + "/none") "ftp://nowhere/x"])
   ; -O - in a process of its own, against kiosko in another (a hark waits out its child,
   ; so an in-process server would never be served): stdout is the body and only the body,
   ; loud or quiet, through a redirect too; a fetch that fails writes nothing there
   _ (mkdir (sroot + "/sub") 493)
   page "<p>the sub page</p>\n"
   _ (: p (open (sroot + "/sub/index.html") "w") _ (say p page) (close p))
   love <cmdline
   hp (test-free 0)
   hs (tether [love "kore" "httpd" "-p" (show hp) "-h" sroot])
   _ (test-up hp)
   none (test-free 0)                      ; a port of ours, its listener gone
   hbase ("http://127.0.0.1:" + show hp)
   (wo args) (hark ([love "kore" "wget"] + args))
   (wq args) (hark ["sh" "-c" (foldl (a \ w \ a + " '" + w + "'") ("'" + love + "' kore wget") args + " 2>/dev/null")])
   so (wq ["-O" "-" (hbase + "/blob.bin")])                           ; not -q: its words are err's, dropped
   sq (wo ["-q" "-O" "-" (hbase + "/blob.bin")])
   sr (wo ["-q" "-O" "-" (hbase + "/sub")])                           ; 301 to /sub/, its index
   s404 (wq ["-O" "-" (hbase + "/absent.bin")])                    ; its complaint is err's, dropped
   sdead (wq ["-O" "-" ("http://127.0.0.1:" + show none + "/x")])      ; nobody listens there
   _ (still <hs 15)
   (reap pid) (: g (gather pid) (? (two? g || nom? g) g (rest 2, reap pid)))
   _ (reap <hs)
   _ (hark ["rm" "-rf" root])
   (test
    (so = (0 . blob)) (sq = (0 . blob)) (sr = (0 . page))
    (s404 = (8 . "")) (sdead = (1 . ""))
    (0 = rc) (got = blob)                                              ; the bytes came back whole
    (8 = rc404)                                                        ; a server's no is wget's 8
    (1 = rcbad)                                                        ; not a url
    ; the tls floor: RFC 7748 6.1's alice, RFC 4231's first case
    ("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a" = hex (T 'x25519-pub (unhex "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")))
    ("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7" = hex (T 'hmac (T 'bytes 20 (\ i 11)) "Hi There"))
    ; an aead round trip: what seal made, open takes back, and a flipped byte it refuses
    (: k (T 'bytes 32 (\ i i)) iv (T 'bytes 12 (\ i (i + 7)))
       ct (T 'aead-seal k iv 3 "aad" "the plaintext")
       ok (T 'aead-open k iv 3 "aad" ct)
       bad (T 'aead-open k iv 3 "aad" (T 'bytes #ct (\ i (i = 0 ? (ct 0 ^ 1) (ct i)))))
       (&& (two? ok) ("the plaintext" = <>ok) (atom? bad)))))

;; https, where openssl is here: a leaf for 127.0.0.1 under a root laid here. named by
; SSL_CERT_FILE the root verifies it; the host's own bundle refuses it (exit 5, and the check
; and the certificate said); --no-check-certificate takes it; a pin in ~/.love/tls_pins takes it
(: W (cite 'kore 'wget-main)
   os? (two? (stat "/usr/bin/openssl"))
   odir ((cwd 0) + "/out/.wgett-" + show (getpid 0))
   (osh c) (hark ["sh" "-c" ("exec 2>/dev/null; cd " + odir + " && " + c)])
   (srv port) (: p (tether ["openssl" "s_server" "-quiet" "-tls1_3" "-naccept" "1" "-www" "-accept" ("127.0.0.1:" + show port)
                            "-key" (odir + "/leaf.key") "-cert" (odir + "/leaf.pem")])
                 p)
   (reap p) (: _ (still <p 15) (: g (gather <p) (? (two? g || nom? g) g (rest 2, reap p))))
   cf0 (getenv "SSL_CERT_FILE") home0 (getenv "HOME")
   _ (? os? (: _ (hark ["mkdir" "-p" (odir + "/.love")])
               _ (osh ("openssl req -x509 -newkey rsa:2048 -nodes -keyout root.key -out root.pem -days 2 -subj /CN=t-root"
                       + " -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign"))
               (osh ("printf 'basicConstraints=critical,CA:FALSE\\nsubjectAltName=IP:127.0.0.1\\n' > l.cnf"
                     + " && openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout leaf.key -subj /CN=t-leaf -out leaf.csr"
                     + " && openssl x509 -req -in leaf.csr -CA root.pem -CAkey root.key -days 2 -extfile l.cnf -out leaf.pem")))
          0)
   (fetch port as) (: p (srv port) o (odir + "/got" + show port)
                      ; 1 is refused: the server is not listening yet
                      rc (test-until (\ r (r = 1)) (\ _ (W (as + ["-q" "-O" o ("https://127.0.0.1:" + show port + "/")]))))
                      _ (reap p)
                      [rc (: r (uread o) (? (two? r) <>r ""))])
   (has s x) (0 <= (cite 'kore 'wg-find) s x 0)
   _ (? os?
        (: _ (setenv "SSL_CERT_FILE" (odir + "/root.pem"))
           a (fetch (test-free 0) [])
           _ (setenv "SSL_CERT_FILE" "/nonexistent/bundle.pem")
           b (fetch (test-free 0) [])
           c (fetch (test-free 0) ["--no-check-certificate"])
           spki (: r (hark ["sh" "-c" ("cd " + odir + " && openssl x509 -in leaf.pem -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum")])
                   (snip >r 0 64))
           _ (setenv "HOME" odir)
           dp (test-free 0)
           _ (: q (open (odir + "/.love/tls_pins") "w") _ (say q ("127.0.0.1:" + show dp + " spki:" + spki + "\n")) (close q))
           d (fetch dp [])
           _ (setenv "HOME" (? (string? home0) home0 ""))
           _ (setenv "SSL_CERT_FILE" (? (string? cf0) cf0 ""))
           _ (hark ["rm" "-rf" odir])
           (test (<a = 0) (has (a 1) "TLSv1.3") (<b = 5) (<c = 0) (has (c 1) "TLSv1.3")
                 (<d = 0) (has (d 1) "TLSv1.3")))
        0)
   0)

;; a plain answer short of its Content-Length is cut short: exit 4, and no file. a chunked
; body runs to its last chunk, or is nothing
(: pl (test-listen 0)
   s (twirl (_ \ (: c (accept (pl 1)) _ (see c) _ (chug c)
                    (say c "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabc", flush c, close c))) ())
   o ("out/.wgetc-" + show (getpid 0))
   rc ((cite 'kore 'wget-main) ["-q" "-O" o ("http://127.0.0.1:" + show <pl + "/")])
   _ (catch s) _ (close (pl 1))
   U (cite 'kore 'wg-unchunk)
   (test (rc = 4) !(two? (uread o))
         (U "5\r\nhello\r\n0\r\n\r\n" = "hello") !(U "5\r\nhello\r\n") !(U "9\r\nhello\r\n0\r\n\r\n")))

(test_fin (), puts "wget: ok", putc 10, 0)
