; src/apps/icy.l -- a web radio stream as a port: http or https, the station's .pls or .m3u
; followed, redirects followed, and a shoutcast or icecast server's in-band titles (icy) taken
; out of the audio and kept. what reads the port is av.l's decoder door, as for a file.
; `(borrow 'icy)`, then:
;
;   (icy-open u)     -> [q info] | why not: q the stream's audio bytes in order, a read
;                       parking until they come; info a tablet: 'url where it ended up,
;                       'name 'genre 'desc 'type 'br 'metaint off the headers, 'title the
;                       latest StreamTitle as the stream goes, 'titles how many came, 'why
;                       once it has ended
;   (icy-close info) -> 0: the stream stopped, q at its end
;   (icy-url u)      -> [tls? host port path] | ()
;   (icy-meta s)     -> a metadata block's StreamTitle | ()
;   (icy-list s)     -> the first stream a .pls or .m3u names | ()
;
; the request is http/1.0, so no server chunks the body. a header past 64 KiB, a playlist
; past 64 KiB and a ninth hop are refused; hls (#EXT-X-) is not read.
(module (icy icy-open icy-close icy-url icy-meta icy-list icy-resolve)
(borrow 'posix)
(:
   close (cite 'posix 'close)
   icy-max 65536
   icy-pltypes ["audio/x-scpls" "audio/scpls" "application/pls+xml" "audio/x-mpegurl" "audio/mpegurl"
                "application/x-mpegurl" "application/vnd.apple.mpegurl"]

   ; --- words ---------------------------------------------------------------------
   (icy-num s) (: (go i a) (? (i >= #s || s i < 48 || s i > 57) a (go (i + 1) (a * 10 + s i - 48)))
                  (go 0 0))
   (icy-sp c) (c = 32 || c = 9 || c = 13)
   (icy-trim s) (: (l i) (? (i < #s && icy-sp (s i)) (l (i + 1)) i)
                   (r j) (? (0 < j && icy-sp (s (j - 1))) (r (j - 1)) j)
                   a (l 0) e (r #s)
                   (snip s a (max a e)))
   (icy-lines s) (: (go i acc) (fsub s "\n" i @ e (? (e < 0) (rev (snip s i #s . acc)) (go (e + 1) (snip s i e . acc))))
                    (map icy-trim (go 0 ())))
   ; the header lines, keys lowercase
   (icy-heads ls) (foldl (\ t l (fsub l ":" 0 @ c (? (c < 1) t (pin t (lower (snip l 0 c)) (icy-trim (snip l (c + 1) #l))))))
                         {} ls)
   (icy-ends? s e) (#e <= #s && snip s (#s - #e) #s = e)

   ; --- where -----------------------------------------------------------------------
   (icy-url u) (? (starts? u "https://") (icy-at 1 (snip u 8 #u))
                  (starts? u "http://") (icy-at 0 (snip u 7 #u))
                  ())
   (icy-at tls? r)
    (: i (fsub r "/" 0) auth (i < 0 ? r (snip r 0 i)) path (i < 0 ? "/" (snip r i #r))
       j (fsub auth ":" 0)
       host (j < 0 ? auth (snip auth 0 j))
       port (j < 0 ? (tls? ? 443 80) (icy-num (snip auth (j + 1) #auth)))
       (? (0 < #host && 0 < port) [tls? host port path] ()))
   ; a location or playlist entry against the url it came from
   (icy-resolve base loc)
    (? (0 < fsub loc "://" 0) loc
       (icy-url base @
         [t h p path] (: d (snip path 0 (1 + foldl (\ a k (path k = 47 ? k a)) 0 ^#path))
                         ((t ? "https://" "http://") + h + ":" + show p + (loc 0 = 47 ? loc (d + loc))))
         _ loc))
   (icy-req [tls? host port path])
    ("GET " + path + " HTTP/1.0\r\nHost: " + host + (port = (tls? ? 443 80) ? "" (":" + show port))
     + "\r\nUser-Agent: love/" + love-version + "\r\nAccept: */*\r\nIcy-MetaData: 1\r\nConnection: close\r\n\r\n")

   ; --- the wire: say, hear (a run, () at the end) and close, over tcp or tls --------------
   (icy-dial [tls? host port path])
    (? tls?
        ((cite 'tls 'tls-open) host port 'verify @
          (why && string? why) why
          t {'say (s \ (cite 'tls 'tls-say) t s)
             'hear (_ \ (cite 'tls 'tls-hear) t @ s (string? s ? s ()))
             'close (_ \ (cite 'tls 'tls-close) t)})
       ((cite 'dns 'dial) host port @
         s (? (hot? s) {'say (x \ (say s x, flush s))
                        'hear (_ \ see s @ -1 () c (unsee s c, chug s))
                        'close (_ \ close s)}
              ("cannot connect to " + host + ":" + show port))))
   ; the header block and the bytes past it -> [head rest] | why not
   (icy-head c) (: (go b) (fsub b "\r\n\r\n" 0 @
                            k (? (0 <= k) [(snip b 0 k) (snip b (k + 4) #b)]
                                 (#b > icy-max) "a header past 64 KiB"
                                 ((c 'hear) () @ g (string? g ? (go (b + g)) "the server closed before its header ended"))))
                   (go ""))
   (icy-all c b) (: (go b) (? (#b > icy-max) b ((c 'hear) () @ g (string? g ? (go (b + g)) b))) (go b))

   ; --- playlists -------------------------------------------------------------------
   (icy-pl? ty u b)
    (: t (lower (fsub ty ";" 0 @ k (k < 0 ? ty (snip ty 0 k)))) p (lower (icy-url u @ [_ _ _ p] p _ ""))
       h (lower (snip b 0 16))
       (elem (icy-trim t) icy-pltypes || icy-ends? p ".pls" || icy-ends? p ".m3u" || icy-ends? p ".m3u8"
        || starts? h "[playlist]" || starts? h "#extm3u"))
   ; a .pls's File1 first, else an .m3u's first line that is no comment
   (icy-list s)
    (: ls (filter (l \ 0 < #l) (icy-lines s))
       fs (filter (l \ starts? (lower l) "file" && 0 < fsub l "=" 0) ls)
       (? (two? fs) (<fs @ l (icy-trim (snip l (fsub l "=" 0 + 1) #l)))
          (filter (l \ l 0 != 35 && l 0 != 91 && !(0 < fsub l "=" 0 && fsub l "://" 0 < 0)) ls @ (l . _) l _ ())))

   ; --- the stream: audio out the pipe, each metadata block read for its title -----------
   (icy-meta m) (: k (fsub m "StreamTitle='" 0)
                   (? (k < 0) ()
                      (: a (k + 13) e (fsub m "';" a) z (fsub m (string [0]) a)
                         t (snip m a (? (0 <= e) e (0 <= z) z #m))
                         (? (0 <= e || !(icy-ends? t "'")) t (snip t 0 (#t - 1))))))
   (icy-run c info b mi w)
    (: (more b) ((c 'hear) () @ g (string? g ? (b + g) ()))
       (out s) (? (0 < #s) (say w s, flush w) 0)
       (fin why) (? (string? (info 'why)) 0
                    (: _ (pin info 'why why) _ (close w) ((c 'close) (), 0)))
       (end b) (fin "the stream ended")
       (go b left)
        (? (mi = 0) (: _ (out b) (more "" @ () (end ()) g (go g 0)))
           (#b = 0) (more "" @ () (end ()) g (go g left))
           (0 < left) (: k (min left #b) _ (out (snip b 0 k)) (go (snip b k #b) (left - k)))
           (: n (16 * b 0)
              (? (#b < n + 1) (more b @ () (end ()) g (go g 0))
                 (: _ (? (0 < n) (icy-meta (snip b 1 (n + 1)) @ () 0 t (pins info 'title t 'titles (info 'titles + 1))) 0)
                    (go (snip b (n + 1) #b) mi)))))
       (go b mi))
   (icy-stream u c h b)
    (: mi (icy-num (peep h "icy-metaint" "0"))
       pp (pipe 0) r (fdopen <pp) w (fdopen >pp)
       info {'url u 'name (peep h "icy-name" ()) 'genre (peep h "icy-genre" ()) 'desc (peep h "icy-description" ())
             'type (peep h "content-type" ()) 'br (icy-num (peep h "icy-br" "0")) 'metaint mi
             'title () 'titles 0 'why () 'w w 'shut (c 'close)}
       (pin info 'task (twirl (_ \ icy-run c info b mi w) ()), [r info]))
   (icy-close info)
    (: _ (peep info 'task () @ () 0 k (freeze k))
       (? (string? (info 'why)) 0
          (: _ (pin info 'why "closed") _ (close (info 'w)) ((info 'shut) (), 0))))

   ; --- one hop: the answer read, then followed, played, or refused ------------------------
   (icy-answer u hops c hd b)
    (: ls (icy-lines hd) st <ls h (icy-heads >ls)
       code (icy-num (snip st (fsub st " " 0 + 1) #st))
       loc (peep h "location" ())
       (? (300 <= code < 400 && string? loc) ((c 'close) (), icy-go (icy-resolve u loc) (hops - 1))
          (code != 200) ((c 'close) (), u + " answered " + st)
          (icy-pl? (peep h "content-type" "") u b)
           (icy-all c b @ s (: _ ((c 'close) ())
                               (? (0 <= fsub s "#EXT-X-" 0) "an hls playlist: those are not read yet"
                                  (icy-list s @ () ("no stream in the playlist at " + u)
                                                l (icy-go (icy-resolve u l) (hops - 1))))))
          (icy-stream u c h b)))
   (icy-go u hops)
    (: p (icy-url u)
       (? !(two? p) ("not an http or https url: " + u)
          (hops < 1) "too many redirects"
          (icy-dial p @
            (why && string? why) why
            c (: _ ((c 'say) (icy-req p))
                 (icy-head c @
                   (why && string? why) ((c 'close) (), why)
                   [hd b] (icy-answer u hops c hd b))))))
   (icy-open u) (icy-go u 9))
) ; module icy
