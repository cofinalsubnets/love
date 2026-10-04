; src/apps/torrent/peerwire.l -- the peer wire protocol (BEP 3): a handshake, then messages,
; each a four-byte length and an id.
;
;   (pw-dial ip port hash id ms) -> a connection | why not: tcp, the handshake both ways,
;                                   the peer's infohash checked
;   (pw-greet s hash id ms)      -> a connection | why not: a socket that dialled us, its
;                                   handshake for hash checked, then ours sent back
;   (pw-next c ms)  -> [id payload] | 'alive (a keepalive) | 'gone at the end | () on ms of
;                      quiet, nothing lost: the next call takes the message whole
;   (pw-send c id payload)
;   (pw-request c i begin len)   a block of piece i
;   (within ms f)   -> (f ()) | () if it has not answered in ms
;   (pw-rd c n) (pw-wr c s)      exactly n bytes off the wire | (), and bytes onto it
; ids: 0 choke 1 unchoke 2 interested 3 not interested 4 have 5 bitfield 6 request 7 piece
; 8 cancel. a connection is a tablet: the socket 's, bytes read ahead 'pend, the peer's id.
(module (peerwire pw-dial pw-greet pw-next pw-send pw-request pw-close within pw-has? pw-proto pw-rd pw-wr)
(borrow 'bytes)
(:
 (close q) (cite 'posix 'close q)
 pw-proto "BitTorrent protocol"
 ; f on a task of its own, a watchdog on the clock: the first to finish wins
 (within ms f) (: r (twirl (_ \ [(f ())]) ())
                  w (twirl (_ \ (rest ms, freeze r)) ())
                  v (catch r)
                  (freeze w, two? v ? <v))
 ; c's read-ahead at least n bytes long -> 1 | () at the end. every byte taken is kept in
 ; 'pend at once, so a read a watchdog stops loses nothing
 (pw-fill c n) (? (n <= #(c 'pend)) 1
                  (: s (c 's) b (see s)
                     (b = -1 ? () (pin c 'pend (c 'pend + string b + chug s), pw-fill c n))))
 ; exactly n bytes off the socket -> them | () at the end
 (pw-rd c n) (pw-fill c n ? (: p (c 'pend) (pin c 'pend (snip p n #p), snip p 0 n)))
 (pw-wr c s) (: q (c 's) (say q s, flush q))
 (pw-hello hash id) (string 19 + pw-proto + wrbe 0 8 + hash + id)
 ; the peer's handshake read and checked -> c | why not, the socket closed
 (pw-heard c hash) (: s (c 's) h (pw-rd c 68)
                     (? !(string? h) (close s, "the peer hung up")
                        (snip h 0 20 != string 19 + pw-proto) (close s, "not the bittorrent protocol")
                        (snip h 28 48 != hash) (close s, "the peer has another torrent")
                        (pin c 'peer (snip h 48 68), c)))
 (pw-dial ip port hash id ms)
  (within ms (_ \ (connect ['tcp ip port] @ s
    (? !(hot? s) "no connection"
       (: c (pins {} 's s 'pend "" 'ip ip 'port port)
          (pw-wr c (pw-hello hash id), pw-heard c hash))))))
 ; a peer that dialled us: its handshake first, then ours back
 (pw-greet s hash id ms)
  (: c (pins {} 's s 'pend "")
     r (within ms (_ \ pw-heard c hash))
     (? (tablet? r) (pw-wr c (pw-hello hash id), r)
        (string? r) r
        (close s, "the peer said nothing")))
 ; a message is taken whole or not at all: a watchdog may stop the read anywhere
 (pw-next c ms) (within ms (_ \ (? !(pw-fill c 4) 'gone
                   (rdbe (c 'pend) 0 4 @ n
                      (? (n = 0) (pw-rd c 4, 'alive)
                         (262144 < n - 9) 'gone             ; a block is 16 KiB, a piece message no more
                         !(pw-fill c (4 + n)) 'gone
                         (pw-rd c (4 + n) @ b [(b 4) (snip b 5 #b)]))))))
 (pw-send c id p) (pw-wr c (wrbe (1 + #p) 4 + string id + p))
 (pw-request c i begin len) (pw-send c 6 (wrbe i 4 + wrbe begin 4 + wrbe len 4))
 (pw-close c) (c 's @ s (hot? s ? (close s) 0))
 ; does a bitfield say piece i
 (pw-has? bf i) (i // 8 < #bf && 0 < (bf (i // 8) & (128 >> i % 8)))
)) ; module peerwire
