; src/apps/torrent/benc.l -- bencode, bittorrent's data: integers i42e, byte strings
; 4:spam, lists l..e, dictionaries d..e with their keys in byte order (BEP 3).
;
;   (bdecode s)        -> [the value] | () when s is not one bencoded value, whole
;   (bencode v)        -> the bytes: a number, a string, a list, a tablet (string keys)
;   (bspan s key)      -> [start end] of key's value in the dictionary s is, raw -- the
;                         infohash is the sha1 of the info dictionary as it was written
;
; a string stays bytes; a dictionary is a tablet. keys out of order are read as they come,
; as the clients in the wild write them; bencode lays them in order. a nesting past bdepth
; is refused, so a hostile file cannot run the reader off the stack.
(module (benc bdecode bencode bspan bdec)
(:
 bdepth 64
 (bdigit? c) (48 <= c && c <= 57)
 ; a run of digits at i -> [n j], j past them | () when there are none
 (bnum s i) (: n #s
              (go j a) (j < n && bdigit? (s j) ? (go (j + 1) (a * 10 + s j - 48)) [a j])
              (i < n && bdigit? (s i) ? (go i 0) ()))
 ; the value at i -> [v j], j past it | ()
 (bdec s i d) (: n #s c (i < n ? (s i) -1)
   (? (bdepth < d || n <= i) ()
      (c = 105)                                               ; i -12e
       (: ng (i + 1 < n && s (i + 1) = 45) at (ng ? (i + 2) (i + 1))
          (bnum s at @ [v j]
             (j < n && s j = 101 && (!ng || 0 < v)
                && !(s at = 48 && at + 1 < j) ?                 ; i-0e and i03e are not
                [(ng ? (0 - v) v) (j + 1)] ())
             ()))
      (bdigit? c)                                             ; 4:spam
       (bnum s i @ [k j]
          (j < n && s j = 58 && j + 1 + k <= n ? [(snip s (j + 1) (j + 1 + k)) (j + 1 + k)] ())
          ())
      (c = 108)                                               ; l .. e
       (: (go j acc) (? (n <= j) ()
                        (s j = 101) [(rev acc) (j + 1)]
                        (bdec s j (d + 1) @ [v k] (go k (v . acc)) ()))
          (go (i + 1) ()))
      (c = 100)                                               ; d .. e, string keys
       (: t {}
          (go j) (? (n <= j) ()
                    (s j = 101) [t (j + 1)]
                    (bdec s j (d + 1) @ [k v0]
                       (string? k ? (bdec s v0 (d + 1) @ [v v1] (pin t k v, go v1) ()) ())
                       ()))
          (go (i + 1)))
      ()))
 (bdecode s) (bdec s 0 0 @ [v j] (j = #s ? [v] ()) ())
 (bencode v) (? (charm? v) ("i" + show v + "e")
                (string? v) (show #v + ":" + v)
                (tablet? v) ("d" + cats (map (k \ bencode k + bencode (v k)) (sort (keys v))) + "e")
                ("l" + cats (map bencode v) + "e"))
 ; the top dictionary's keys walked in turn, each value's span kept until key's
 (bspan s key) (: n #s
   (go j) (? (n <= j || s j = 101) ()
             (bdec s j 1 @ [k v0] (bdec s v0 1 @ [_ v1] (k = key ? [v0 v1] (go v1)) ()) ()))
   (0 < n && s 0 = 100 ? (go 1) ()))
)) ; module benc
