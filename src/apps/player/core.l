; src/apps/player/core.l -- the player's core: a queue, the decoder door, the bus, the horn,
; and the messages every view speaks (notes/plan/av.md, the core's protocol). one core per
; (user, sink); in process a view watches it and sends to it, and a socket only carries the
; same messages. `(borrow 'core)`, then:
;
;   (core-new sink)       -> a core, stopped, its queue empty
;   (core-send c msg)     -> the reply to msg, [verb arg ..]: [ok] [ok VALUE] [err "why"]
;   (core-watch c f)      -> a client id; f is handed [snap ..] at once, then every event
;   (core-tell c id msg)  -> core-send as that client: its feeds are its own
;   (core-unwatch c id)
;   (core-snap c)         -> [snap STATE QUEUE]
;   (core-close c)        -> stops it and lets the horn go
;   a uri is a path or an http(s) stream (icy.l, through av-uri); a stream's title follows
;   what the station says it plays
;   (player-main as)      -> the verb: `love player [--pipe] [FILE..]`, the protocol on stdin
;                            and stdout, the files queued and played
;
; a track runs on a task of its own that feeds the horn a chunk at a time, never more than
; lead ahead of the speaker, so a pause, a seek or an eq change is heard within lead. what
; went out is kept in a ring for the feeds, read where the speaker is, not where the bus is.
(module (core core-new core-send core-watch core-tell core-unwatch core-snap core-close
              core-keys core-item player-main)
(borrow 'bus)
(:
   open (cite 'posix 'open) close (cite 'posix 'close) stat (cite 'posix 'stat)
   peepv (cite 'guts 'peepv) pinv (cite 'guts 'pinv)
   lead 0.2                              ; seconds queued ahead of the speaker
   chunk 1024                            ; frames a bus run
   ringn 32768                           ; frames the feeds can look back
   core-keys ['state 'song 'pos 'dur 'rate 'ch 'bits 'kbps 'vol 'bal 'pre 'eq 'eqon
              'repeat 'random 'single 'consume 'qver 'sink 'follow 'clients]
   item-keys ['id 'uri 'title 'artist 'album 'dur]
   (S c k) ((c 's) k)
   (Q c i) ((c 'q) i)

   (core-new sink)
    {'s {'state 'stop 'song -1 'pos 0.0 'dur 0.0 'rate 0 'ch 0 'bits 0 'kbps 0 'vol 100 'bal 0
         'pre 0 'eq (map (_ \ 0) ^10) 'eqon 1 'repeat 0 'random 0 'single 0 'consume 0 'qver 0
         'sink sink 'follow () 'clients 0}
     'q () 'nid 1 'w () 'nw 1 'hn () 'hrate 0 'brate 0 'dec () 'fq () 'fi {} 'ftn 0 'bus (bus-new ()) 'tick ()
     'tf 0 'base 0 'skip 0 'ring (cask (4 * ringn)) 'rw 0 'held "" 'seed (clock 0)}

   ; --- the messages out ------------------------------------------------------
   (alist t ks) (map (k \ [k (t k)]) ks)
   (core-item it) (alist it item-keys)
   (queue-msg c) ['queue (S c 'qver) (map core-item (c 'q))]
   (core-snap c) ['snap (alist (c 's) core-keys) [(S c 'qver) (map core-item (c 'q))]]
   (emit c msg) (each (c 'w) (w \ (w 1) msg))
   ; set fields and tell every client, in one event
   (sets c kvs) (: _ (each kvs (kv \ pin (c 's) <kv (kv 1))) (emit c ['set kvs]))
   (requeue c) (: _ (pin (c 's) 'qver (S c 'qver + 1)) (emit c (queue-msg c)))
   (notice c why) (emit c ['msg why])

   ; --- items -----------------------------------------------------------------
   (base p) (: k (findsub (rev (chars p)) [47]) (k < 0 ? p (snip p (#p - k) #p)))
   (tag m nm) (: u (upper nm + "=")
                 (foldl (\ a t (a || (#t > #u && upper (snip t 0 #u) = u ? (snip t #u #t) ()))) () (peep m 'tags ())))
   ; a uri through the door -> [codec m h port info] | why: a path or an http(s) stream, info
   ; the stream's live tablet ({} for a file). the caller lets both go with shut
   (stream? info) (tablet? info && string? (peep info 'url ()))
   (shut q info) (: _ (? (stream? info) ((cite 'icy 'icy-close) info) 0) (close q))
   (opens p)
    ((cite 'av 'av-uri) p @
      [q info] ((cite 'av 'av-open) q @ [nm m h] [nm m h q info]
                                        why (shut q info, why))
      why why)
   (frames m) (? (charm? (peep m 'total ())) (m 'total)
                 (charm? (peep m 'len ()) && 0 <= m 'len) (m 'len // m 'align)
                 0)
   ; a stream is asked only its name: what it carries may be a codec still to come
   (probe c uri)
    (? (starts? uri "http://" || starts? uri "https://")
       ((cite 'av 'av-uri) uri @
         [q info] (: _ (shut q info) t (peep info 'title "") nm (peep info 'name "")
                     it {'id (c 'nid) 'uri uri 'title (#t > 0 ? t (#nm > 0 ? nm uri)) 'artist ""
                         'album nm 'dur 0.0 'rate 0 'ch 0 'bits 0 'size 0 'br (peep info 'br 0)}
                     (pin c 'nid (c 'nid + 1), it))
         why why)
    (opens uri @
      [nm m h q info] (: _ (shut q info) r (m 'rate)
                    it {'id (c 'nid) 'uri uri 'title (tag m "TITLE" || base uri)
                        'artist (tag m "ARTIST" || "") 'album (tag m "ALBUM" || "")
                        'dur (r ? (frames m / (1.0 * r)) 0.0) 'rate r 'ch (m 'ch)
                        'bits (peep m 'bps (peep m 'bits 16)) 'size (stat uri @ (z . _) z 0)}
                    (pin c 'nid (c 'nid + 1), it))
      why why))
   (find c id) (findsub (map (it \ it 'id) (c 'q)) [id])

   ; --- the horn and the ring -------------------------------------------------
   (lag c) (c 'hn @ () 0 hn (horn-lag hn @ n (charm? n ? n 0)))
   (horn-off c) (c 'hn @ () 0 hn (close hn, pins c 'hn () 'hrate 0, 0))
   (horn-at c rate)
    (? (c 'hn != () && c 'hrate = rate) (c 'hn)
       (: _ (horn-off c)
          (horn rate 2 @ hn (nom? hn ? (notice c ("no horn: " + show hn), ())
                                (pins c 'hn hn 'hrate rate, hn)))))
   (ring-put c pcm)
    (: n (#pcm // 4) r (c 'ring) at (c 'rw % ringn)
       k (min n (ringn - at))
       _ (pour r (4 * at) pcm 0 (4 * k))
       _ (? (k < n) (pour r 0 pcm (4 * k) (4 * (n - k))) 0)
       (pin c 'rw (c 'rw + n)))
   ; n frames of what the speaker is playing now, ending there; zeros ahead of the first
   (ring-get c n)
    (: e (c 'rw - lag c) s (max 0 (max (e - n) (e - ringn))) out (cask (4 * n))
       (go f o) (? (f >= e) 0
                   (: at (f % ringn) k (min (e - f) (ringn - at))
                      (pour out o (c 'ring) (4 * at) (4 * k), go (f + k) (o + 4 * k))))
       (go s (4 * (n - (e - s))), string out))

   ; --- the track task --------------------------------------------------------
   (stereo pcm ch)
    (? (ch = 2) pcm
       (: n (#pcm // 2) c (cask (4 * n)) t (cask #pcm) _ (pour t 0 pcm 0 #pcm)
          v (peepv t 0 2 2 n)
          (pinv c 0 2 4 v, pinv c 2 2 4 v, string c)))
   (paused? c) (S c 'state = 'pause)
   (wait c rate)
    (? (paused? c || lead * rate < lag c) (rest 10, wait c rate) 0)
   ; s16 stereo frames to the horn, a chunk at a time, past any still to skip
   (feed c rate pcm)
    (: n (#pcm // 4) skip (min n (c 'skip))
       _ (pin c 'skip (c 'skip - skip))
       (go o) (? (o >= n) 0
                 (: k (min chunk (n - o)) _ (wait c rate)
                    out (bus-run (c 'bus) (snip pcm (4 * o) (4 * (o + k))) 2)
                    _ (c 'hn @ () 0 hn (say hn out, flush hn))
                    _ (ring-put c out)
                    _ (pin c 'tf (c 'tf + k))
                    (go (o + k))))
       (go skip))
   ; play queue index i from frame at, then whatever comes after it
   (track c i at)
    (: it (Q c i) p (it 'uri)
       (opens p @
         [nm m h q info]
          (: cd (<(filter (d \ <d = nm) ((cite 'av 'av-codecs) ())))
             f ((cd 3) m) rate (f 'rate) ch (min 2 (f 'ch))
             _ (pins c 'fq q 'fi info 'ftn 0 'tf 0 'base at 'skip at 'brate rate)
             _ (rebus c)
             _ (horn-at c rate)
             _ (sets c [['song i] ['dur (it 'dur)] ['rate rate] ['ch ch] ['bits (it 'bits)]
                        ['kbps (it 'dur > 0 ? (int (it 'size * 8 / (it 'dur * 1000))) (peep it 'br 0))]
                        ['pos (at / (1.0 * rate))]
                        ['state (paused? c ? 'pause 'play)]])
             r ((cd 4) q h m ((cite 'av 'av-pcm) f (pcm \ feed c rate (stereo pcm ch))))
             _ (shut q info) _ (pins c 'fq () 'fi {})
             (? (r = 0) (after c i) (: _ (notice c (p + ": " + show r)) (after c i))))
         why (: _ (notice c why) (after c i))))
   ; the track at i is done: the next by the modes, or let the horn play out and stop
   (after c i)
    (: n #(c 'q)
       _ (? (S c 'consume && i < n) (: _ (pin c 'q (dropat (c 'q) i)) (requeue c)) 0)
       n2 #(c 'q) i2 (S c 'consume ? (i - 1) i)
       nx (? (n2 = 0) -1
             (S c 'single) (S c 'repeat ? (max 0 i2) -1)
             (S c 'random) (pick c n2)
             (i2 + 1 < n2) (i2 + 1)
             (S c 'repeat) 0
             -1)
       (nx < 0 ? (: _ (drain c) (stopped c)) (track c nx 0)))
   (drain c) (? (0 < lag c) (rest 10, drain c) 0)
   (stopped c) (: _ (horn-off c) _ (pins c 'dec () 'tf 0 'base 0)
                  (sets c [['state 'stop] ['song -1] ['pos 0.0]]))
   (dropat l i) (? (atom? l) () (i = 0) >l (<l . dropat >l (i - 1)))
   (pick c n) (: x (c 'seed) y ((x * 1103515245 + 12345) % 2147483648)
                (pin c 'seed y, y % n))

   ; the track task: begun, and ended without a trace
   (halt c)
    (: _ (c 'dec @ () 0 t (landed? t ? 0 (freeze t)))
       _ (c 'fq @ () 0 q (shut q (c 'fi)))
       (pins c 'dec () 'fq () 'fi {}))
   (start c i at) (: _ (halt c) _ (horn-off c)
                     (pin c 'dec (twirl (_ \ track c i at) 0)))
   (pos c) (: r (c 'brate || 1) ((max (c 'base) (c 'base + c 'tf - lag c)) / (1.0 * r)))

   ; the ticker: pos four times a second, and each client's feeds when due
   (ticker c)
    (: (go k)
        (: _ (rest 10) t (clock 0)
           _ (? (S c 'state = 'play && k % 25 = 0) (sets c [['pos (pos c)]]) 0)
           _ (? (S c 'state = 'play) (each (c 'w) (w \ feeds c w t)) 0)
           _ (retitle c)
           (go (k + 1)))
       (go 0))
   ; a stream's StreamTitle moved: the playing item takes it, and the queue goes out again
   (retitle c)
    (: fi (c 'fi) n (stream? fi ? (peep fi 'titles 0) 0) t (stream? fi ? (peep fi 'title "") "")
       (? (n = c 'ftn || !(string? t) || #t = 0 || S c 'song < 0) 0
          (: _ (pin c 'ftn n) _ (pin (Q c (S c 'song)) 'title t) (requeue c))))
   (feeds c w t)
    (: fs (w 2)
       (each (keys fs) (kind \ (fs kind @
          [fps n due] (? (t < due) 0
                         (: _ (pin fs kind [fps n (max (due + 1000 // fps) (t - 1000 // fps))])
                            r (c 'brate || 44100) at (pos c)
                            ((w 1) (kind @ 'spec ['spec at (bus-spec (ring-get c 2048) 2 r n)]
                                          _ ['scope at (bus-scope (ring-get c (r // fps)) 2 n)]))))
          _ 0))))

   ; --- commands --------------------------------------------------------------
   ok ['ok]
   (err why) ['err why]
   (num? x) (charm? x || gem? x)
   (pct x lo hi) (max lo (min hi x))
   (rebus c)
    (pin (c 'bus) 'co (bus-co (c 'brate || 44100) (S c 'eq) (S c 'pre) (S c 'vol) (S c 'bal) (S c 'eqon)))
   (mix c k v) (: _ (sets c [[k v]]) _ (rebus c) ok)
   (playing? c) (S c 'state != 'stop)
   (pause c on)
    (? !(playing? c) ok
       (on = (paused? c)) ok
       ; what the horn held and the speaker never played comes back ahead of the rest
       on (: p (pos c) n (lag c)
             _ (pins c 'held (ring-get c n) 'rw (c 'rw - n) 'tf (c 'tf - n))
             _ (horn-off c)
             _ (sets c [['state 'pause] ['pos p]])
             ok)
       (: h (c 'held) _ (pin c 'held "")
          _ (horn-at c (c 'brate))
          _ (? (0 < #h && c 'hn != ()) (: _ (say (c 'hn) h) _ (flush (c 'hn)) _ (ring-put c h) (pin c 'tf (c 'tf + #h // 4))) 0)
          _ (sets c [['state 'play]])
          ok))
   (go-to c i at)
    (? (i < 0 || i >= #(c 'q)) (err "no such song")
       (: _ (pin c 'held "") _ (start c i (max 0 at)) _ (sets c [['song i] ['state 'play]]) ok))
   (stop c) (: _ (halt c) _ (pin c 'held "") _ (stopped c) ok)
   (seek c secs)
    (? !(playing? c) (err "not playing")
       (: i (S c 'song) r (c 'brate || 1) was (S c 'state)
          _ (go-to c i (int (secs * r)))
          _ (sets c (was = 'pause ? [['state 'pause] ['pos secs]] [['pos secs]]))
          ok))
   (sort-by key l)
    (? (atom? l) ()
       (: p <l k (key p)
          (sort-by key (filter (x \ key x < k) >l) + [p] + sort-by key (filter (x \ !(key x < k)) >l))))
   (sorted c key) (sort-by (it \ (key @ 'dur (it 'dur) k (lower (it k)))) (c 'q))
   (shuffled c l) (? (atom? l) () (: k (pick c #l) (l k . shuffled c (dropat l k))))
   (reindex c id) (: k (find c id) (? (0 <= k) (pin (c 's) 'song k) 0))
   ; the song playing keeps playing when the queue moves under it
   (moved c l)
    (: cur (playing? c && 0 <= S c 'song ? ((Q c (S c 'song)) 'id) ())
       _ (pin c 'q l) _ (? (cur != ()) (reindex c cur) 0)
       _ (requeue c)
       _ (? (cur != ()) (sets c [['song (S c 'song)]]) 0)
       ok)
   (insert l at x) (? (at <= 0 || atom? l) (x . l) (<l . insert >l (at - 1) x))

   (core-send c msg) (core-tell c 0 msg)
   (core-tell c id msg)
    (? !(two? msg) (err "a message is [verb arg ..]")
       (: v <msg a >msg (a1 _) (two? a ? <a ()) (a2 _) (two? a && two? >a ? <>a ())
          (v @
            'ping ok
            'status (core-snap c)
            'bye (: _ (core-unwatch c id) ok)
            'play (: i (a1 ()) (go-to c (num? i ? i (max 0 (S c 'song))) 0))
            'pause (pause c (num? (a1 ()) ? (a1 () != 0) 1))
            'toggle (? (paused? c) (pause c 0) (playing? c) (pause c 1) (go-to c (max 0 (S c 'song)) 0))
            'stop (stop c)
            'next (: i (S c 'song + 1) (i < #(c 'q) ? (go-to c i 0) (stop c)))
            'prev (go-to c (max 0 (S c 'song - 1)) 0)
            'seek (num? (a1 ()) ? (seek c (a1 ())) (err "seek SECS"))
            'seekby (num? (a1 ()) ? (seek c (max 0 (pos c + a1 ()))) (err "seekby SECS"))
            'vol (num? (a1 ()) ? (mix c 'vol (pct (a1 ()) 0 100)) (err "vol 0..100"))
            'bal (num? (a1 ()) ? (mix c 'bal (pct (a1 ()) -100 100)) (err "bal -100..100"))
            'pre (num? (a1 ()) ? (mix c 'pre (pct (a1 ()) -20 20)) (err "pre DB"))
            'eq (? (two? (a1 ()) && #(a1 ()) = 10 && foldl (\ y g (y && num? g)) 1 (a1 ()))
                   (mix c 'eq (map (g \ pct g -20 20) (a1 ()))) (err "eq [DB x10]"))
            'band (? (num? (a1 ()) && 0 <= a1 () && a1 () < 10 && num? (a2 ()))
                     (mix c 'eq (map (k \ k = a1 () ? (pct (a2 ()) -20 20) ((S c 'eq) k)) ^10))
                     (err "band 0..9 DB"))
            'eqon (mix c 'eqon (a1 () = 0 ? 0 1))
            (m && elem m ['repeat 'random 'single 'consume]) (: _ (sets c [[m (a1 () = 0 ? 0 1)]]) ok)
            'add (? !(string? (a1 ())) (err "add URI [AT]")
                    (probe c (a1 ()) @
                      it (? !(tablet? it) (err it)
                            (: n #(c 'q) at (num? (a2 ()) ? (pct (a2 ()) 0 n) n)
                               cur (playing? c && 0 <= S c 'song ? ((Q c (S c 'song)) 'id) ())
                               _ (pin c 'q (insert (c 'q) at it))
                               _ (? (cur != ()) (reindex c cur) 0)
                               _ (requeue c)
                               ['ok (it 'id)]))))
            'del (: k (find c (a1 ()))
                    (? (k < 0) (err "no such id")
                       (k = S c 'song && playing? c) (: _ (stop c) _ (pin c 'q (dropat (c 'q) k)) _ (requeue c) ok)
                       (moved c (dropat (c 'q) k))))
            'move (: k (find c (a1 ()))
                     (? (k < 0 || !(num? (a2 ()))) (err "move ID AT")
                        (: l (dropat (c 'q) k) (moved c (insert l (pct (a2 ()) 0 #l) (Q c k))))))
            'clear (: _ (stop c) _ (pin c 'q ()) _ (requeue c) ok)
            'shuffle (moved c (shuffled c (c 'q)))
            'sort (? (elem (a1 ()) ['title 'artist 'album 'dur 'uri]) (moved c (sorted c (a1 ())))
                     (err "sort title|artist|album|dur|uri"))
            'feed (? (id = 0) (err "feed: a watcher's")
                     (!(elem (a1 ()) ['spec 'scope]) || !(num? (a2 ()))) (err "feed spec|scope FPS N")
                     (: w (<(filter (w \ <w = id) (c 'w))) fps (pct (a2 ()) 0 60)
                        n (two? >>a && num? <>>a ? (pct <>>a 1 512) 32)
                        _ (pin (w 2) (a1 ()) (fps = 0 ? () [fps n 0]))
                        ok))
            _ (err ("no verb " + show v)))))

   (core-watch c f)
    (: id (c 'nw) _ (pins c 'nw (id + 1) 'w (c 'w + [[id f {}]]))
       _ (? (c 'tick = ()) (pin c 'tick (twirl (_ \ ticker c) 0)) 0)
       _ (f (core-snap c))
       _ (sets c [['clients #(c 'w)]])
       id)
   (core-unwatch c id)
    (: _ (pin c 'w (filter (w \ <w != id) (c 'w)))
       (sets c [['clients #(c 'w)]]))
   (core-close c) (: _ (halt c) _ (horn-off c)
                     _ (c 'tick @ () 0 t (freeze t)) (pins c 'tick () 'w ()))

   ; --- the verb: the protocol on stdin and stdout ---------------------------
   (line-of p) (: (go acc) (see p @ -1 (two? acc ? (string (rev acc)) ()) 10 (string (rev acc)) ch (go (ch . acc)))
                  (go ()))
   (player-main as)
    (: c (core-new "main")
       (line m) (say out (show m + "\n"), flush out)
       id (core-watch c line)
       fs (filter (a \ a != "--pipe") as)
       _ (each fs (p \ (core-send c ['add p]) @ ['ok _] 0 r (line r)))
       _ (? (0 < #(c 'q)) (core-send c ['play 0]) 0)
       (go _) (line-of in @ () 0
                            s (: m (sound s @ (m . _) m _ ())
                                 r (two? m ? (core-tell c id m) ['err "a message is [verb arg ..]"])
                                 (line r, m = ['bye] ? 0 (go 0))))
       (go 0, core-close c, 0))
   _ (pins (cite 'verbs 'tab) 'player (udoor 'player player-main "usage: love player [--pipe] [FILE..]" 1 1)))
) ; module core
