; test/host/torrent.l -- the torrent client, offline: bencode's laws and refusals, a
; metainfo read back from torrents laid here, transmission-show's sizes, the tracker's
; parsing, and a whole download from a seeder on loopback -- one file and two, and the
; ordered port from a byte inside the first piece.
; run: cat test/00-init.l test/host/torrent.l | out/love
(borrow 'posix)
(borrow 'bytes)
(borrow 'benc)
(borrow 'metainfo)
(borrow 'tracker)
(borrow 'peerwire)
(borrow 'swarm)

; --- bencode ---
(test ('(42) = bdecode "i42e") ('(-3) = bdecode "i-3e") ('("spam") = bdecode "4:spam")
      ('(("spam" 3)) = bdecode "l4:spami3ee") ('(()) = bdecode "le") ('("") = bdecode "0:")
      (bdecode "d3:cow3:moo4:spam4:eggse" @ [t] (t "cow" = "moo" && t "spam" = "eggs") 0)
      !(bdecode "i03e") !(bdecode "i-0e") !(bdecode "ie") !(bdecode "4:spa") !(bdecode "i1ei2e")
      !(bdecode "l4:spam") !(bdecode "di1e1:xe")                ; a key that is not a string
      !(bdecode (cats (map (_ \ "l") ^100) + cats (map (_ \ "e") ^100)))   ; deeper than bdepth
      ("d1:ali2e1:xe1:bi1ee" = bencode {"b" 1 "a" [2 "x"]})
      (string [52 58 0 1 2 3] = bencode (string [0 1 2 3]))
      ([10 14] = bspan "d1:ai1e1:bi22ee" "b") !(bspan "d1:ai1ee" "z"))

; --- transmission-show's sizes, as it spells them ---
(test (all ([n s] \ tsize n 1000 ["B" "kB" "MB" "GB"] = s)
           [[1 "1 B"] [999 "999 B"] [1000 "1 kB"] [1023 "1.02 kB"] [1500 "1.50 kB"]
            [9995 "9.99 kB"] [9999 "10.00 kB"] [12345 "12.35 kB"] [99999 "100.0 kB"]
            [100000 "100 kB"] [123456 "123.5 kB"] [999500 "999.5 kB"] [1000000 "1 MB"]
            [5242880 "5.24 MB"] [104857600 "104.9 MB"] [792723456 "792.7 MB"]])
      (all ([n s] \ tsize n 1024 ["B" "KiB" "MiB" "GiB"] = s)
           [[16384 "16 KiB"] [262144 "256 KiB"] [1048576 "1 MiB"] [16777216 "16 MiB"]]))

; --- the tracker's words ---
(test (["http" "t.example" 6969 "/announce"] = tr-url "http://t.example:6969/announce")
      (["udp" "t.example" 80 "/"] = tr-url "udp://t.example") !(tr-url "magnet:?x")
      ("a%20b%00~" = urlenc (string [97 32 98 0 126]))
      ([["1.2.3.4" 6881] ["10.0.0.1" 51413]] = tr-peers (string [1 2 3 4 26 225 10 0 0 1 200 213]))
      (#(peer-id 0) = 20))

; --- a torrent laid here, and a seeder of it on loopback ---
(: dir (cwd 0 + "/out/.torrent")
   _ (hark ["rm" "-rf" dir], mkdir dir 448)
   plen 32768
   data (string (map (i \ i * 7 + i // 300 & 255) ^100000))
   (hashes s) (cats (map (k \ hex2b (sha1 (snip s (k * plen) (min #s (k * plen + plen))))) ^((#s + plen - 1) // plen)))
   one {"name" "t.bin" "piece length" plen "pieces" (hashes data) "length" #data}
   two {"name" "pair" "piece length" plen "pieces" (hashes data)
        "files" [{"length" 70000 "path" ["a" "b.bin"]} {"length" 30000 "path" ["c.txt"]}]}
   (torrent info) (bencode {"announce" "http://t.example/announce" "info" info "comment" "laid here"})
   m1 (tmeta (torrent one)) m2 (tmeta (torrent two))
   ; the seeder: the handshake back, every piece had, unchoked, and each request answered
   (seed l hash)
    (: (serve c) (pw-next c 5000 @ msg
                   (? (atom? msg) (msg = 'alive ? (serve c) 0)
                      (msg 0 = 6) (: p (msg 1) i (rdbe p 0 4) b (rdbe p 4 4) n (rdbe p 8 4)
                                     (pw-send c 7 (wrbe i 4 + wrbe b 4 + snip data (i * plen + b) (i * plen + b + n)),
                                      serve c))
                      (serve c)))
       (one _) (: _ (await l) s (accept l) c (pins {} 's s 'pend "")
                  h (pw-rd c 68)
                  (? (string? h && snip h 28 48 = hash)
                     (pw-wr c (string 19 + pw-proto + wrbe 0 8 + hash + "-XX0000-000000000000"),
                      pw-send c 5 (string [240]),
                      pw-send c 1 "",
                      serve c, close s)
                     (close s)))
       (one ()))
   (fetch m files)
    (: pl (test-listen 0) srv (twirl (_ \ seed (pl 1) (m 'hash)) ())
       t (swarm-new m dir)
       r (swarm-run t [["127.0.0.1" <pl]] {'max 1 'window 2 'id (peer-id 0)})
       (freeze srv, close (pl 1),
        [r (map (f \ uread (dir + "/" + f) @ [1 s] s ()) files)]))
   r1 (fetch m1 ["t.bin"])
   r2 (fetch m2 ["pair/a/b.bin" "pair/c.txt"])
   ; the ordered port, from inside the first piece, the swarm behind it
   pl (test-listen 0) srv (twirl (_ \ seed (pl 1) (m1 'hash)) ())
   _ (hark ["rm" "-f" (dir + "/t.bin")])
   t (swarm-new m1 dir)
   sw (twirl (_ \ swarm-run t [["127.0.0.1" <pl]] {'max 1 'window 2 'id (peer-id 0)}) ())
   q (swarm-port t 0 5)
   (rd acc) (see (q 0) @ b (b = -1 ? acc (: x (string b + chug (q 0)) (rd (acc + x)))))
   streamed (rd "")
   _ (catch sw)
   _ (freeze srv) _ (close (pl 1))
 (test (tablet? m1) (m1 'name = "t.bin") (m1 'count = 4) (m1 'total = 100000) (m1 'plen = plen)
       (m1 'hash = hex2b (sha1 (bencode one))) (m1 'comment = "laid here")
       ([["http://t.example/announce"]] = m1 'tiers)
       (tpiece-len m1 0 = plen) (tpiece-len m1 3 = 100000 - 3 * plen)
       ([[["pair" "a" "b.bin"] 70000 0] [["pair" "c.txt"] 30000 70000]] = m2 'files)
       ("not bencode" = tmeta "d") ("no info dictionary" = tmeta (bencode {"x" 1}))
       ("the pieces do not cover the files" = tmeta (torrent (pins {} "name" "x" "piece length" plen "pieces" (hashes data) "length" 10)))
       (r1 = [1 [data]]) (r2 = [1 [(snip data 0 70000) (snip data 70000 100000)]])
       (q 1 = 100000 - 5) (streamed = snip data 5 100000))
 (hark ["rm" "-rf" dir]))

(test_fin (), puts "torrent: ok -- bencode, a metainfo, transmission's sizes, the tracker's words, a swarm on loopback and its ordered port\n")
