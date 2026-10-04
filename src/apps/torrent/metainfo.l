; src/apps/torrent/metainfo.l -- a .torrent's metainfo (BEP 3, with BEP 12's tiers and BEP 19's
; web seeds), read into one tablet:
;
;   (tmeta s) -> the metainfo | a string saying why not
;     'hash   the infohash, 20 bytes: the sha1 of the info dictionary as written
;     'hex    ..spelled in hex
;     'name 'plen (a piece's length) 'total 'pieces (each 20 bytes of sha1) 'count
;     'files  [path length offset] each, path a list of words, offset into the whole
;     'tiers  the trackers, a list of tiers of urls      'seeds  web seed urls
;     'private 'comment 'by 'made (unix seconds | ())
;   (tpiece-len m i)  the length of piece i: plen, but the last
;   (tshow m file)    transmission-show's report, the dates in utc
(module (metainfo tmeta tpiece-len tshow tsize)
(borrow 'benc)
(borrow 'bytes)
(borrow 'cal)
(:
 (tm-get t k d) (tablet? t ? (peep t k d) d)
 (tm-str t k) (tm-get t k () @ v (string? v ? v ()))
 (tm-num t k) (tm-get t k () @ v (charm? v ? v ()))
 (tm-chunks s k) (: (go i acc) (#s <= i ? (rev acc) (go (i + k) (snip s i (i + k) . acc))) (go 0 ()))
 ; a file's length and path words; () when either is not what it says
 (tm-file f) (: n (tm-num f "length") p (tm-get f "path.utf-8" (tm-get f "path" ()))
                (charm? n && 0 <= n && two? p && all string? p ? [p n] ()))
 (tm-urls v) (? (string? v) (0 < #v ? [v] ()) (two? v) (filter (u \ string? u && 0 < #u) v) ())
 (tmeta s)
  (bdecode s @ [top]
   (: info (tm-get top "info" ())
      span (bspan s "info")
      name (tm-get info "name.utf-8" (tm-str info "name"))
      plen (tm-num info "piece length")
      ps (tm-str info "pieces")
      one (tm-num info "length")
      ; a file's path is under the torrent's name, as it is laid on the disk
      fs (? (charm? one) [[[name] one]] (map (f \ tm-file f @ [p n] [(name . p) n] ()) (tm-get info "files" ())))
      (? !(tablet? top) "not a dictionary"
         !(tablet? info) "no info dictionary"
         !(string? name) "no name"
         !(charm? plen && 0 < plen) "no piece length"
         !(string? ps && #ps % 20 = 0) "the pieces are not whole hashes"
         !(two? fs && all two? fs) "no files, or a file without a length or a path"
         (: total (net (map (f \ f 1) fs))
            count (#ps // 20)
            offs (: (go l at acc) (atom? l ? (rev acc) (go >l (at + <l 1) ([(<l 0) (<l 1) at] . acc)))
                    (go fs 0 ()))
            raw (snip s (span 0) (span 1))
            tiers (tm-get top "announce-list" () @ al
                     (two? al ? (filter two? (map tm-urls al))
                        ((tm-urls (tm-str top "announce")) @ u (two? u ? [u] ()))))
            (count != (total + plen - 1) // plen ? "the pieces do not cover the files"
               {'hash (hex2b (sha1 raw)) 'hex (sha1 raw) 'name name 'plen plen 'total total
                'pieces (tm-chunks ps 20) 'count count 'files offs 'tiers tiers
                'seeds (tm-urls (tm-get top "url-list" ())) 'private (tm-num info "private" = 1)
                'comment (tm-str top "comment") 'by (tm-str top "created by")
                'made (tm-num top "creation date")}))))
   "not bencode")
 (tpiece-len m i) (i + 1 < m 'count ? (m 'plen) (m 'total - i * m 'plen))

 ; --- transmission-show's words -------------------------------------------------------
 ; sizes as transmission spells them: a file or a total in powers of 1000 (kB MB GB), a
 ; piece in powers of 1024 (KiB MiB). a whole number of the unit has no fraction; else two
 ; places while it rounds under 100, one under 1000, then none
 (tm-fig v whole) (: r2 (floor (v * 100.0 + 0.5)) r1 (floor (v * 10.0 + 0.5))
                     (? whole (show (floor (v + 0.5)))
                        (r2 < 10000) (show (r2 // 100) + "." + pad0 (r2 % 100) 2)
                        (r1 < 10000) (show (r1 // 10) + "." + show (r1 % 10))
                        (show (floor (v + 0.5)))))
 (pad0 n w) (show n @ t (#t < w ? (pad0s (w - #t) + t) t))
 (pad0s n) (n < 1 ? "" ("0" + pad0s (n - 1)))
 (tsize n base us) (: (go v d u) (v < base || atom? >u ? (tm-fig v (n % d = 0) + " " + <u)
                                    (go (v / base) (d * base) >u))
                     (n < base ? (show n + " " + <us) (go (n / base) base >us)))
 (tm-bytes n) (tsize n 1000 ["B" "kB" "MB" "GB" "TB"])
 (tm-piece n) (tsize n 1024 ["B" "KiB" "MiB" "GiB" "TiB"])
 ; "Sat Sep 12 11:32:11 2026", utc
 (tm-date t) (: d (t // 86400) s (t % 86400) c (civil d)
               (wd3 (wday d) + " " + mon3 (c 1 - 1) + " " + pad0 (c 2) 2 + " "
                + pad0 (s // 3600) 2 + ":" + pad0 (s // 60 % 60) 2 + ":" + pad0 (s % 60) 2 + " " + show (c 0)))
 (tshow m file)
  (: (line k v) ("  " + k + ": " + v + "\n")
     (tier i ts) ("\n  Tier #" + show (i + 1) + "\n" + cats (map (u \ "  " + u + "\n") ts))
     (fl f) ("  " + join "/" (f 0) + " (" + tm-bytes (f 1) + ")\n")
     ("Name: " + m 'name + "\nFile: " + file + "\n\nGENERAL\n\n"
      + line "Name" (m 'name) + line "Hash v1" (m 'hex)
      + (m 'by ? (line "Created by" (m 'by)) "")
      + (charm? (m 'made) ? (line "Created on" (tm-date (m 'made))) "")
      + "\n" + (m 'comment ? (line "Comment" (m 'comment)) "")
      + line "Piece Count" (show (m 'count)) + line "Piece Size" (tm-piece (m 'plen))
      + line "Total Size" (tm-bytes (m 'total))
      + line "Privacy" (m 'private ? "Private torrent" "Public torrent")
      + "\nTRACKERS\n" + cats (map (i \ tier i (m 'tiers i)) ^#(m 'tiers))
      + (two? (m 'seeds) ? ("\nWEBSEEDS\n\n" + cats (map (u \ "  " + u + "\n") (m 'seeds))) "")
      + "\nFILES\n\n" + cats (map fl (m 'files)) + "\n"))
)) ; module metainfo
