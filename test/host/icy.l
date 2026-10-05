; test/host/icy.l -- src/apps/icy.l: urls, titles and playlists read; then a station served
; here on loopback -- a playlist, a redirect, and an icy stream of a wav with titles between
; its blocks -- read back through av's door to the wav's own samples, its titles kept; where
; ffmpeg is, it reads the same station to the same samples.
;   cat test/00-init.l test/host/icy.l | out/love
(borrow 'posix)
(borrow 'icy)
(: ic-le (\ v n (string (map (k \ (v >> (8 * k)) & 255) ^n)))
   ; one second of 8 kHz stereo, a different ramp a side
   ic-pcm (: c (cask 32000) (each ^8000 (i \ (pin c (4 * i) (i * 7 & 255), pin c (4 * i + 1) (i // 5 & 255),
                                              pin c (4 * i + 2) (i * 3 & 255), pin c (4 * i + 3) (255 - (i // 9 & 255)))),
                             string c))
   ic-wav ("RIFF" + ic-le (36 + #ic-pcm) 4 + "WAVEfmt " + ic-le 16 4 + ic-le 1 2 + ic-le 2 2 + ic-le 8000 4
           + ic-le 32000 4 + ic-le 4 2 + ic-le 16 2 + "data" + ic-le #ic-pcm 4 + ic-pcm)
   ; a metadata block: its length in sixteens, then the text, zeros to the end
   (ic-block m) (: n ((#m + 15) // 16) (string [n] + m + string (cask (16 * n - #m))))
   ic-titles ["StreamTitle='one';" "" "StreamTitle='two';StreamUrl='';"]
   (ic-icy s mi) (: (go i acc) (? (#s <= i * mi) (cats (rev acc))
                                  (: blk (snip s (i * mi) (min #s (i * mi + mi)))
                                     (go (i + 1) ((#blk < mi ? blk (blk + ic-block (i < #ic-titles ? (ic-titles i) ""))) . acc))))
                    (go 0 ()))
   (ic-answer path)
    (? (path = "/list.pls") "HTTP/1.0 200 OK\r\nContent-Type: audio/x-scpls\r\n\r\n[playlist]\nNumberOfEntries=1\nFile1=/hop\nTitle1=love\n"
       (path = "/hop") "HTTP/1.0 302 Found\r\nLocation: /live\r\n\r\n"
       (path = "/loop") "HTTP/1.0 302 Found\r\nLocation: /loop\r\n\r\n"
       (path = "/hls.m3u8") "HTTP/1.0 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\n\r\n#EXTM3U\n#EXT-X-VERSION:3\n"
       (path = "/live") (ic-live + ic-icy ic-wav 1000)
       (path = "/plain") ("HTTP/1.0 200 OK\r\nContent-Type: audio/wav\r\n\r\n" + ic-wav)
       "HTTP/1.0 404 Not Found\r\n\r\n")
   ic-live "ICY 200 OK\r\nicy-name: love radio\r\nicy-genre: test\r\nicy-br: 256\r\nicy-metaint: 1000\r\nContent-Type: audio/wav\r\n\r\n"
   ; the station: each request read to its blank line, answered, closed
   (ic-req s) (: (go b) (? (0 <= fsub b "\r\n\r\n" 0) b
                           (see s @ -1 b c (unsee s c, go (b + chug s))))
                 (go ""))
   (ic-serve l) (: _ (await l) s (accept l)
                   _ (? (hot? s) (: r (ic-req s) a (fsub r " " 0) e (fsub r " " (a + 1))
                                    (say s (ic-answer (snip r (a + 1) e)), flush s, close s))
                        0)
                   (ic-serve l))
   pl (test-listen 0) srv (twirl (_ \ ic-serve (pl 1)) ())
   base ("http://127.0.0.1:" + show <pl)

   _ (test (icy-url "http://a.b/x?y=1" = [0 "a.b" 80 "/x?y=1"]) (icy-url "https://a:8443" = [1 "a" 8443 "/"])
           (icy-url "ftp://x" = ()) (icy-url "http://" = ())
           (icy-meta "StreamTitle='a b';StreamUrl='';\0\0" = "a b") (icy-meta "StreamTitle='c'\0\0" = "c")
           (icy-meta "StreamUrl='x';" = ())
           (icy-list "[playlist]\nNumberOfEntries=1\nFile1=http://h/s\r\nTitle1=x\n" = "http://h/s")
           (icy-list "#EXTM3U\n#EXTINF:-1,x\nhttp://h/m\n" = "http://h/m") (icy-list "#EXTM3U\n" = ())
           (icy-resolve "http://h/a/b.pls" "c" = "http://h:80/a/c") (icy-resolve "http://h/a/b" "/d" = "http://h:80/d")
           (icy-resolve "http://h/a" "https://x/y" = "https://x/y"))

   ; the station through av's door: the playlist, the hop, then the stream
   (ic-read u) ((cite 'av 'av-uri) u @
                 [q info] ((cite 'av 'av-open) q @
                            [nm m h] (: st {'l ()}
                                        r ((cite 'wav 'wav-pump) q h m (p \ pin st 'l (p . st 'l)))
                                        [nm r (cats (rev (st 'l))) info])
                            why why)
                 why why)
   got (ic-read (base + "/list.pls"))
   _ (test (two? got) (got 0 = "wav") (got 2 = ic-pcm)
           (got 3 'title = "two") (got 3 'titles = 2) (got 3 'name = "love radio") (got 3 'genre = "test")
           (got 3 'br = 256) (got 3 'metaint = 1000) (got 3 'url = base + "/live")
           (got 3 'why = "the stream ended"))
   plain (ic-read (base + "/plain"))
   _ (test (two? plain) (plain 2 = ic-pcm) (plain 3 'title = ()) (plain 3 'metaint = 0))
   ; closed early: the port ends, and says why
   _ (test (icy-open (base + "/live") @ [q info] (: _ (icy-close info) (info 'why = "closed" && string? (slurp q))) _ 0))
   free (test-free 0)
   _ (test (icy-open "ftp://x" = "not an http or https url: ftp://x")
           (icy-open (base + "/nope") = base + "/nope answered HTTP/1.0 404 Not Found")
           (icy-open (base + "/loop") = "too many redirects")
           (icy-open (base + "/hls.m3u8") = "an hls playlist: those are not read yet")
           (icy-open ("http://127.0.0.1:" + show free + "/") = "cannot connect to 127.0.0.1:" + show free))

   ; ffmpeg reads the same station to the same samples (and calls its close premature, as for
   ; any icy stream: none says a length)
   _ (? (hark ["sh" "-c" "command -v ffmpeg >/dev/null"] @ (0 . _) 1 _ 0)
        (test (hark ["ffmpeg" "-loglevel" "fatal" "-i" (base + "/live") "-f" "s16le" "-"] = (0 . ic-pcm)))
        (gate-partly "icy: no ffmpeg here, the station is not held to it"))
   (freeze srv, close (pl 1), 0))

(test_fin (), puts "icy: ok", putc 10, 0)
