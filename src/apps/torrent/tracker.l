; src/apps/torrent/tracker.l -- asking a tracker for peers: http (BEP 3, compact peers by
; BEP 23) and udp (BEP 15).
;
;   (announce url ask) -> {'interval s 'peers ([quad port] ..) 'seeders 'leechers} | why not
;     ask: {'hash 20 bytes 'id 20 bytes 'port 'up 'down 'left 'event ("" started stopped completed)}
;   (peer-id _)        -> twenty bytes, transmission's shape: -LV0300- and twelve digits
;   (urlenc s)         -> s with every byte but the unreserved ones spelled %XX
(module (tracker announce peer-id urlenc tr-url tr-peers tr-udp-ask)
(borrow 'bytes)
(:
 ; "http://host:port/path?q" -> [scheme host port path] | ()
 (tr-url u) (: k (fsub u "://" 0)
               p (0 < k ? (snip u 0 k) "") r (snip u (k + 3) #u)
               d (p @ "http" 80 "https" 443 "udp" 80 0)
               sl (fsub r "/" 0)
               h (0 <= sl ? (snip r 0 sl) r) path (0 <= sl ? (snip r sl #r) "/")
               c (fsub h ":" 0)
               host (0 <= c ? (snip h 0 c) h) port (0 <= c ? (tr-digits (snip h (c + 1) #h)) d)
               (0 < k && 0 < d && 0 < #host && 0 < port ? [p host port path] ()))
 (tr-digits s) (foldl (a \ c \ (48 <= c && c <= 57 ? (a * 10 + c - 48) a)) 0 (map (i \ s i) ^#s))
 (urlenc s) (cats (map (i \ s i @ c ((48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122
                                       || c = 45 || c = 46 || c = 95 || c = 126) ? (string c)
                                      ("%" + b2hex (string c))))
                       ^#s))
 (peer-id _) ("-LV0300-" + cats (map (_ \ show (rand 10)) ^12))
 ; compact peers: six bytes each, the address and the port big end first
 (tr-peers s) (map (k \ [(show (s k) + "." + show (s (k + 1)) + "." + show (s (k + 2)) + "." + show (s (k + 3)))
                         (rdbe s (k + 4) 2)])
                   (filter (k \ k % 6 = 0) ^(#s - #s % 6)))
 ; a dictionary peer list, the older shape: {'ip 'port}
 (tr-dpeers l) (filter two? (map (p \ tablet? p ? [(peep p "ip" "") (peep p "port" 0)]) l))

 ; --- http ---------------------------------------------------------------------------
 (tr-chunks b) (: (go i acc) (: e (fsub b "\r\n" i)
                                  (? (e < 0) acc
                                     (: n (tr-hex (snip b i e))
                                        (n = 0 ? acc (go (e + 2 + n + 2) (acc + snip b (e + 2) (e + 2 + n)))))))
                 (go 0 ""))
 (tr-hex s) (foldl (a \ c \ (? (48 <= c <= 57) (a * 16 + c - 48) (97 <= c <= 102) (a * 16 + c - 87)
                                (65 <= c <= 70) (a * 16 + c - 55) a)) 0 (map (i \ s i) ^#s))
 (tr-http u ask)
  (: q ("info_hash=" + urlenc (ask 'hash) + "&peer_id=" + urlenc (ask 'id) + "&port=" + show (ask 'port)
        + "&uploaded=" + show (ask 'up) + "&downloaded=" + show (ask 'down) + "&left=" + show (ask 'left)
        + "&compact=1&numwant=50" + (0 < #(ask 'event) ? ("&event=" + ask 'event) ""))
     path (u 3 + (0 <= fsub (u 3) "?" 0 ? "&" "?") + q)
     req ("GET " + path + " HTTP/1.1\r\nHost: " + u 1 + "\r\nUser-Agent: love-torrent/0.3\r\n"
          + "Accept-Encoding: identity\r\nConnection: close\r\n\r\n")
     s (cite 'dns 'dial (u 1) (u 2))
     raw (hot? s ? (: _ (say s req) _ (flush s) r (slurp s) (close s, r)))
     k (string? raw ? (fsub raw "\r\n\r\n" 0) -1)
     (? (k < 0) "the tracker did not answer"
        (: head (snip raw 0 k) body (snip raw (k + 4) #raw)
           code (tr-digits (snip head 9 12))
           b (0 <= fsub (lower head) "transfer-encoding: chunked" 0 ? (tr-chunks body) body)
           (code != 200 ? ("the tracker said " + snip head 9 (fsub head "\r\n" 0))
              (cite 'benc 'bdecode b @ [d] (tr-reply d) "the tracker's answer is not bencode")))))
 (tr-reply d) (? !(tablet? d) "the tracker's answer is not a dictionary"
                 (peep d "failure reason" ()) ("the tracker refused: " + d "failure reason")
                 (: ps (peep d "peers" "")
                    {'interval (peep d "interval" 1800) 'seeders (peep d "complete" 0)
                     'leechers (peep d "incomplete" 0)
                     'peers (string? ps ? (tr-peers ps) (tr-dpeers ps))}))

 ; --- udp ----------------------------------------------------------------------------
 ; one datagram out, the first answer from the tracker whose action and transaction match
 ; back, () on none within ms
 (tr-udp-ask p from q ms)
  (: tid (snip q 12 16)
     (take _) (recv p @ d (? !(two? d) () (<d = from && 8 <= #(<>d) && snip (<>d) 4 8 = tid) (<>d) (take 0)))
     _ (send p from q)
     r (twirl take ())
     w (twirl (_ \ (rest ms, freeze r)) ())
     d (catch r)
     (freeze w, string? d ? d))
 (tr-udp u ask)
  (: ip (cite 'dns 'resolve (u 1)) from [(ip ? (cite 'dns 'dns-show <ip) "") (u 2)]
     (tid _) (wrbe (rand 4294967296) 4)
     (ask2 q n) (n = 0 ? () (tr-udp-ask p from q (2000 * (5 - n)) @ r (string? r ? r (ask2 q (n - 1)))))
     p (two? ip ? (bind ['udp 0]))
     ev (ask 'event @ "completed" 1 "started" 2 "stopped" 3 0)
     (? !(hot? p) "the tracker's name does not resolve"
        (: c (ask2 (wrbe 4497486125440 8 + wrbe 0 4 + tid ()) 3)
           (? !(string? c) (close p, "the tracker did not answer")
              (rdbe c 0 4 = 3) (close p, ("the tracker refused: " + snip c 8 #c))
              (: q (snip c 8 16 + wrbe 1 4 + tid () + ask 'hash + ask 'id
                    + wrbe (ask 'down) 8 + wrbe (ask 'left) 8 + wrbe (ask 'up) 8
                    + wrbe ev 4 + wrbe 0 4 + wrbe (rand 4294967296) 4 + wrbe 4294967295 4
                    + wrbe (ask 'port) 2)
                 a (ask2 q 3)
                 (close p,
                  (? (!(string? a) || #a < 20) "the tracker did not answer the announce"
                     (rdbe a 0 4 = 3) ("the tracker refused: " + snip a 8 #a)
                     {'interval (rdbe a 8 4) 'leechers (rdbe a 12 4) 'seeders (rdbe a 16 4)
                      'peers (tr-peers (snip a 20 #a))})))))))

 (announce url ask) (tr-url url @ u (u 0 @ "http" (tr-http u ask) "udp" (tr-udp u ask) ("no " + u 0 + " trackers yet"))
                              ("not a tracker url: " + url))
)) ; module tracker
