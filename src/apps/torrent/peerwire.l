; src/apps/torrent/peerwire.l -- the peer wire protocol (BEP 3): a handshake, then messages,
; each a four-byte length and an id.
;
;   (pw-dial ip port hash id ms) -> a connection | why not: tcp, the handshake both ways,
;                                   the peer's infohash checked
;   (pw-next c ms)  -> [id payload] | 'alive (a keepalive) | () on the end or ms of quiet
;   (pw-send c id payload)
;   (pw-request c i begin len)   a block of piece i
;   (within ms f)   -> (f ()) | () if it has not answered in ms
; ids: 0 choke 1 unchoke 2 interested 3 not interested 4 have 5 bitfield 6 request 7 piece
; 8 cancel. a connection is a tablet: the socket 's, bytes read ahead 'pend, the peer's id.
(module (peerwire pw-dial pw-next pw-send pw-request pw-close within pw-has? pw-proto)
(borrow 'bytes)
(:
 (close q) (cite 'posix 'close q)
 pw-proto "BitTorrent protocol"
 ; f on a task of its own, a watchdog on the clock: the first to finish wins
 (within ms f) (: r (twirl (_ \ [(f ())]) ())
                  w (twirl (_ \ (rest ms, freeze r)) ())
                  v (catch r)
                  (freeze w, two? v ? <v))
 ; exactly n bytes off the socket -> them | () at the end
 (pw-rd c n) (: s (c 's)
               (go acc have) (? (n <= have) (join "" (rev acc))
                                (: b (see s) (? (b = -1) ()
                                                (: piece (string b + chug s) (go (piece . acc) (have + #piece))))))
               p (c 'pend)
               got (go (0 < #p ? [p] ()) #p)
               (string? got ? (pin c 'pend (snip got n #got), snip got 0 n)))
 (pw-wr c s) (: q (c 's) (say q s, flush q))
 (pw-dial ip port hash id ms)
  (within ms (_ \ (connect ['tcp ip port] @ s
    (? !(hot? s) "no connection"
       (: c (pins {} 's s 'pend "" 'ip ip 'port port)
          _ (pw-wr c (string 19 + pw-proto + wrbe 0 8 + hash + id))
          h (pw-rd c 68)
          (? !(string? h) (close s, "the peer hung up")
             (snip h 0 20 != string 19 + pw-proto) (close s, "not the bittorrent protocol")
             (snip h 28 48 != hash) (close s, "the peer has another torrent")
             (pin c 'peer (snip h 48 68), c)))))))
 (pw-next c ms) (within ms (_ \ (pw-rd c 4 @ h
                   (string? h ? (rdbe h 0 4 @ n
                      (? (n = 0) 'alive
                         (262144 < n - 9) ()                   ; a block is 16 KiB, a piece message no more
                         (pw-rd c n @ b (string? b ? [(b 0) (snip b 1 n)] ()))))))))
 (pw-send c id p) (pw-wr c (wrbe (1 + #p) 4 + string id + p))
 (pw-request c i begin len) (pw-send c 6 (wrbe i 4 + wrbe begin 4 + wrbe len 4))
 (pw-close c) (c 's @ s (hot? s ? (close s) 0))
 ; does a bitfield say piece i
 (pw-has? bf i) (i // 8 < #bf && 0 < (bf (i // 8) & (128 >> i % 8)))
)) ; module peerwire
