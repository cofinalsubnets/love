; src/apps/player/core.l -- the player's core: a queue, the decoder door, the bus, the horn,
; and the messages every view speaks (notes/plan/av.md, the core's protocol). one core per
; (user, sink); in process a view watches it and sends to it, and a socket only carries the
; same messages. `(borrow 'pcore)` (lux's core.l is the module core), then:
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
;   (core-serve c path)   -> serves c on a unix socket until a client says kill
;   (core-attach path)    -> a served core, attached: the words above take it as they take a
;                            core here | ()
;   (player-main as)      -> the verb: `love player [-n SINK] [FILE..]` -- on a terminal the
;                            player in cells (src/apps/player/tui.l) on the sink's served core,
;                            started detached when none is (--here: a core in this process);
;                            --headless queues and plays and leaves; --serve is the server,
;                            with --mpd PORT mpd's protocol too (mpd.l) over --music DIR,
;                            --kill stops it; --pipe or off a terminal the protocol on stdio
;
; a track runs on a task of its own that feeds the horn a chunk at a time, never more than
; lead ahead of the speaker, so a pause, a seek or an eq change is heard within lead. what
; went out is kept in a ring for the feeds, read where the speaker is, not where the bus is.
(module (pcore core-new core-send core-watch core-tell core-unwatch core-snap core-close
              core-serve core-attach core-keys core-item player-main)
(borrow 'bus)
(borrow 'posix)
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
     'q () 'nid 1 'w () 'nw 1 'hn () 'hrate 0 'brate 0 'fl () 'dec () 'fq () 'fi {} 'ftn 0 'fm () 'fln 0 'bus (bus-new ()) 'tick ()
     'tf 0 'base 0 'skip 0 'ring (cask (4 * ringn)) 'rw 0 'held "" 'seed (clock 0)}

   ; --- the messages out ------------------------------------------------------
   (alist t ks) (map (k \ [k (t k)]) ks)
   (core-item it) (alist it item-keys)
   (queue-msg c) ['queue (S c 'qver) (map core-item (c 'q))]
   (core-snap c) (c 'remote ? (rsend c ['status]) (lsnap c))
   (lsnap c) ['snap (alist (c 's) core-keys) [(S c 'qver) (map core-item (c 'q))]]
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
   ; at is a frame, or ['sec S] when the rate is not known until the stream is open
   (track c i at0)
    (: it (Q c i) p (it 'uri)
       (opens p @
         [nm m h q info]
          (: cd (<(filter (d \ <d = nm) ((cite 'av 'av-codecs) ())))
             f ((cd 3) m) rate (f 'rate) ch (min 2 (f 'ch))
             at (two? at0 ? (int ((at0 1) * rate)) at0)
             _ (pins c 'fq q 'fi info 'ftn 0 'fm m 'fln 0 'tf 0 'base at 'skip at 'brate rate)
             _ (rebus c)
             _ (horn-at c rate)
             _ (sets c [['song i] ['dur (it 'dur)] ['rate rate] ['ch ch] ['bits (peep it 'bits 16)]
                        ['kbps (it 'dur > 0 ? (int (peep it 'size 0 * 8 / (it 'dur * 1000))) (peep it 'br 0))]
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
           _ (? (k % 10 = 0) (follow-check c) 0)
           (go (k + 1)))
       (go 0))
   ; the playing track's title moved -- a stream's StreamTitle, or a codec's tags at a new chain
   ; link ('link, a count the pump bumps): the item takes it, and the queue goes out again
   (retitle c)
    (: fi (c 'fi) n (stream? fi ? (peep fi 'titles 0) 0) t (stream? fi ? (peep fi 'title "") "")
       m (c 'fm) k (tablet? m ? (peep m 'link 0) 0)
       it (0 <= S c 'song ? (Q c (S c 'song)) ())
       (? !(tablet? it) 0
          (n != c 'ftn && string? t && 0 < #t) (: _ (pin c 'ftn n) _ (pin it 'title t) (requeue c))
          (k != c 'fln) (: _ (pin c 'fln k)
                           _ (pins it 'title (tag m "TITLE" || it 'title) 'artist (tag m "ARTIST" || it 'artist)
                                      'album (tag m "ALBUM" || it 'album))
                           (requeue c))
          0))
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
   (nay why) ['err why]
   (num? x) (charm? x || gem? x)
   (pct x lo hi) (max lo (min hi x))
   ; --- playlists: one directory a user, so every sink of theirs sees the same ones -------
   (lists-dir _) (: e (getenv "PLAYER_LISTS") h (getenv "HOME")
                   (? (string? e && 0 < #e) e (string? h) (h + "/.love/var/player/lists") "/tmp/player-lists"))
   (list-name? nm) (string? nm && 0 < #nm && nm 0 != 46 && findsub (chars nm) [47] < 0)
   (list-path nm) (lists-dir 0 + "/" + nm + ".m3u")
   (list-save c nm)
    (? !(list-name? nm) (nay "a list's name: no / and no leading .")
       (: _ (umkdirs (lists-dir 0) 448)
          body (foldl (\ a it (a + "#EXTINF:" + show (int (it 'dur)) + "," + it 'title + "\n" + it 'uri + "\n"))
                      "#EXTM3U\n" (c 'q))
          (open (list-path nm) "w" @ q (? (hot? q) (: _ (say q body) _ (close q) ['ok #(c 'q)])
                                          (nay ("cannot write " + list-path nm))))))
   (list-load c nm)
    (? !(list-name? nm) (nay "a list's name: no / and no leading .")
       (open (list-path nm) "r" @ q
         (? !(hot? q) (nay ("no list " + nm))
            (: t (slurp q) _ (close q)
               us (filter (l \ 0 < #l && l 0 != 35) (map (l \ l @ x (#x && x (#x - 1) = 13 ? (snip x 0 (#x - 1)) x)) (lines-of t)))
               ids (map (u \ ltell c 0 ['add u] @ ['ok i] i _ ()) us)
               ['ok #(filter (i \ i != ()) ids)]))))
   (lines-of t) (: (go i acc) (fsub t "\n" i @ e (? (e < 0) (rev (snip t i #t . acc)) (go (e + 1) (snip t i e . acc))))
                  (go 0 ()))
   (list-names _) (: fs (readdir (lists-dir 0))
                     (sort (map (f \ snip f 0 (#f - 4)) (filter (f \ 4 < #f && ".m3u" = snip f (#f - 4) #f) (two? fs ? fs ())))))

   ; --- follow: this sink plays what another served sink plays, where it plays it -------
   ; the leader's queue and transport are mirrored; mixer, feeds and the follow stay this
   ; sink's own, and while following, transport and queue commands go to the leader
   forwarded ['play 'pause 'toggle 'stop 'next 'prev 'seek 'seekby 'add 'del 'move 'clear 'shuffle 'sort
              'repeat 'random 'single 'consume 'load]
   (kv-of l k d) (foldl (\ a kv (two? kv && <kv = k ? (kv 1) a)) d l)
   (adopt-queue c its)
    (: q (map (al \ foldl (\ t kv (pin t <kv (kv 1))) {'size 0 'bits 16 'br 0} al) its)
       (? (map (it \ it 'uri) q = map (it \ it 'uri) (c 'q))
          (: _ (each ^#q (i \ pin (Q c i) 'title ((q i) 'title))) (requeue c))
          (: _ (pin c 'q q) (requeue c))))
   (adopt-state c kvs)
    (: st (kv-of kvs 'state ()) i (kv-of kvs 'song ()) p (kv-of kvs 'pos ())
       mine (S c 'state)
       _ (? (st = 'stop && mine != 'stop) (stop c) 0)
       _ (? ((st = 'play || st = 'pause) && charm? i && 0 <= i && i < #(c 'q) && (mine = 'stop || i != S c 'song))
            (go-to c i ['sec (num? p ? p 0.0)]) 0)
       _ (? (st = 'pause && S c 'state = 'play) (pause c 1) (st = 'play && S c 'state = 'pause) (pause c 0) 0)
       ; drifted past half a second: catch up, a little ahead for the restart
       _ (? (num? p && S c 'state = 'play && (i = () || i = S c 'song) && 0.5 < abs (pos c - p))
            (seek c (p + 0.1)) 0)
       0)
   (mirror c m)
    (m @ ['snap st [_ its]] (: _ (adopt-queue c its) (adopt-state c st))
         ['queue _ its] (adopt-queue c its)
         ['set kvs] (adopt-state c kvs)
         _ 0)
   (follow c nm)
    (? (nm = () || nm = 0) (: _ (unfollow c) ok)
       !(string? nm) (nay "follow SINK|()")
       (nm = S c 'sink) (nay "a sink cannot follow itself")
       (core-attach (player-sock nm) @
         () (nay ("no core is served as " + nm))
         rc (: _ (unfollow c) _ (pin c 'fl rc)
               _ (? (c 'tick = ()) (pin c 'tick (twirl (_ \ ticker c) 0)) 0)
               _ (sets c [['follow nm]])
               _ (core-watch rc (m \ mirror c m))
               ok)))
   (unfollow c) (c 'fl @ () 0 rc (: _ (pin c 'fl ()) _ (core-close rc) (sets c [['follow ()]])))
   (follow-check c)
    (c 'fl @ () 0 rc (? (rc 'up) 0 (: _ (notice c ("the sink followed has gone: " + show (S c 'follow))) (unfollow c))))

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
    (? (i < 0 || i >= #(c 'q)) (nay "no such song")
       (: _ (pin c 'held "") _ (start c i (two? at ? at (max 0 at))) _ (sets c [['song i] ['state 'play]]) ok))
   (stop c) (: _ (halt c) _ (pin c 'held "") _ (stopped c) ok)
   (seek c secs)
    (? !(playing? c) (nay "not playing")
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

   (ltell c id msg)
    (? !(two? msg) (nay "a message is [verb arg ..]")
       (: v <msg a >msg (a1 _) (two? a ? <a ()) (a2 _) (two? a && two? >a ? <>a ())
          (v @
            'ping ok
            'status (core-snap c)
            'bye (: _ (core-unwatch c id) ok)
            'kill (: _ (pin c 'dead 1) ok)
            'play (: i (a1 ()) (go-to c (num? i ? i (max 0 (S c 'song))) 0))
            'pause (pause c (num? (a1 ()) ? (a1 () != 0) 1))
            'toggle (? (paused? c) (pause c 0) (playing? c) (pause c 1) (go-to c (max 0 (S c 'song)) 0))
            'stop (stop c)
            'next (: i (S c 'song + 1) (i < #(c 'q) ? (go-to c i 0) (stop c)))
            'prev (go-to c (max 0 (S c 'song - 1)) 0)
            'seek (num? (a1 ()) ? (seek c (a1 ())) (nay "seek SECS"))
            'seekby (num? (a1 ()) ? (seek c (max 0 (pos c + a1 ()))) (nay "seekby SECS"))
            'vol (num? (a1 ()) ? (mix c 'vol (pct (a1 ()) 0 100)) (nay "vol 0..100"))
            'bal (num? (a1 ()) ? (mix c 'bal (pct (a1 ()) -100 100)) (nay "bal -100..100"))
            'pre (num? (a1 ()) ? (mix c 'pre (pct (a1 ()) -20 20)) (nay "pre DB"))
            'eq (? (two? (a1 ()) && #(a1 ()) = 10 && foldl (\ y g (y && num? g)) 1 (a1 ()))
                   (mix c 'eq (map (g \ pct g -20 20) (a1 ()))) (nay "eq [DB x10]"))
            'band (? (num? (a1 ()) && 0 <= a1 () && a1 () < 10 && num? (a2 ()))
                     (mix c 'eq (map (k \ k = a1 () ? (pct (a2 ()) -20 20) ((S c 'eq) k)) ^10))
                     (nay "band 0..9 DB"))
            'eqon (mix c 'eqon (a1 () = 0 ? 0 1))
            (m && elem m ['repeat 'random 'single 'consume]) (: _ (sets c [[m (a1 () = 0 ? 0 1)]]) ok)
            'add (? !(string? (a1 ())) (nay "add URI [AT]")
                    (probe c (a1 ()) @
                      it (? !(tablet? it) (nay it)
                            (: n #(c 'q) at (num? (a2 ()) ? (pct (a2 ()) 0 n) n)
                               cur (playing? c && 0 <= S c 'song ? ((Q c (S c 'song)) 'id) ())
                               _ (pin c 'q (insert (c 'q) at it))
                               _ (? (cur != ()) (reindex c cur) 0)
                               _ (requeue c)
                               ['ok (it 'id)]))))
            'del (: k (find c (a1 ()))
                    (? (k < 0) (nay "no such id")
                       (k = S c 'song && playing? c) (: _ (stop c) _ (pin c 'q (dropat (c 'q) k)) _ (requeue c) ok)
                       (moved c (dropat (c 'q) k))))
            'move (: k (find c (a1 ()))
                     (? (k < 0 || !(num? (a2 ()))) (nay "move ID AT")
                        (: l (dropat (c 'q) k) (moved c (insert l (pct (a2 ()) 0 #l) (Q c k))))))
            'clear (: _ (stop c) _ (pin c 'q ()) _ (requeue c) ok)
            'shuffle (moved c (shuffled c (c 'q)))
            'sort (? (elem (a1 ()) ['title 'artist 'album 'dur 'uri]) (moved c (sorted c (a1 ())))
                     (nay "sort title|artist|album|dur|uri"))
            'follow (follow c (a1 ()))
            'save (list-save c (a1 ()))
            'load (list-load c (a1 ()))
            'lists ['ok (list-names ())]
            'rm (? !(list-name? (a1 ())) (nay "rm NAME") (: _ (unlink (list-path (a1 ()))) ok))
            'feed (? (id = 0) (nay "feed: a watcher's")
                     (!(elem (a1 ()) ['spec 'scope]) || !(num? (a2 ()))) (nay "feed spec|scope FPS N")
                     (: w (<(filter (w \ <w = id) (c 'w))) fps (pct (a2 ()) 0 60)
                        n (two? >>a && num? <>>a ? (pct <>>a 1 512) 32)
                        _ (pin (w 2) (a1 ()) (fps = 0 ? () [fps n 0]))
                        ok))
            _ (nay ("no verb " + show v)))))

   (lwatch c f)
    (: id (c 'nw) _ (pins c 'nw (id + 1) 'w (c 'w + [[id f {}]]))
       _ (? (c 'tick = ()) (pin c 'tick (twirl (_ \ ticker c) 0)) 0)
       _ (f (core-snap c))
       _ (sets c [['clients #(c 'w)]])
       id)
   (lunwatch c id)
    (? !(elem id (map (w \ <w) (c 'w))) 0
       (: _ (pin c 'w (filter (w \ <w != id) (c 'w)))
          (sets c [['clients #(c 'w)]])))
   (lclose c) (: _ (unfollow c) _ (halt c) _ (horn-off c)
                 _ (c 'tick @ () 0 t (freeze t)) (pins c 'tick () 'w ()))

   ; --- the five words, on a core here or one attached over its socket ----------
   (core-send c msg) (core-tell c 0 msg)
   (core-tell c id msg)
    (? (c 'remote) (rsend c msg)
       (c 'fl != () && two? msg && elem <msg forwarded) (core-send (c 'fl) msg)
       (ltell c id msg))
   (core-watch c f) (c 'remote ? (rwatch c f) (lwatch c f))
   (core-unwatch c id) (c 'remote ? (pin c 'fs (filter (w \ <w != id) (c 'fs))) (lunwatch c id))
   (core-close c) (c 'remote ? (rclose c) (lclose c))

   ; --- served: a core on PLAYER_RUN/SINK.sock (~/.love/run/player) ------------
   ; on the wire the first line is the attach's [snap]; after it [ok] [err] [snap] answer
   ; commands in the order they came, and every other message is an event. a command may
   ; lead with a number, its tag: its answer leads with the same number. tasks switch at any
   ; call, so what two tasks share here is written by one of them only
   (player-dir _) (: e (getenv "PLAYER_RUN") h (getenv "HOME")
                    (? (string? e && 0 < #e) e (string? h) (h + "/.love/run/player") "/tmp/player"))
   (player-sock nm) (player-dir 0 + "/" + nm + ".sock")
   (lines-in s f) (line-of s @ () 0
                    x (: m (sound x @ (m . _) m _ ()) (f m @ 0 0 _ (lines-in s f))))
   ; one client: its lines in, the core's out through an outbox its own task drains, so a
   ; slow client never holds the core. each task that speaks has its own queue in the outbox,
   ; its slots and 'w written by it alone, 'r by the drain alone
   (conn c s)
    (: qs {} ob {'on 1}
       (put1 m) (: me (myself 0 @ p (charm? p ? p 0)) q (peep qs me ())
                   q2 (? (tablet? q) q (: t {'w 0 'r 0} (pin qs me t, t)))
                   n (q2 'w)
                   (pin q2 n (show m + "\n"), pin q2 'w (n + 1)))
       (take q) (: r (q 'r) w (q 'w) ks (map (k \ k + r) ^(w - r))
                   ls (map (k \ q k) ks)
                   (each ks (k \ pin q k ()), pin q 'r w, ls))
       (drain _) (: l (foldl (\ a me (a + take (qs me))) () (keys qs))
                    _ (? (two? l) (: _ (each l (x \ say s x)) (flush s)) 0)
                    (ob 'on || two? l ? (rest 5, drain 0) 0))
       wr (twirl drain 0)
       id (core-watch c put1)
       _ (lines-in s (m \ (: tag (two? m && charm? <m ? <m ())
                             b (tag = () ? m >m)
                             r (two? b ? (core-tell c id b) ['err "a message is [verb arg ..]"])
                             _ (put1 (tag = () ? r (tag . r)))
                             (elem b [['bye] ['kill]] ? 0 1))))
       _ (core-unwatch c id) _ (pin ob 'on 0)
       (gone _) (landed? wr ? 0 (rest 5, gone 0))
       (gone 0, close s, 0))
   ; serve c at path until a client says kill
   (core-serve c path)
    (: _ (umkdirs (player-dir 0) 448) _ (unlink path)
       l (listen ['unix path])
       (? !(hot? l) ("cannot listen on " + path)
          (: acc (twirl (_ \ (: (go _) (accept l @ s (hot? s ? (twirl (_ \ conn c s) 0, go 0) 0)) (go 0))) 0)
             (wait _) (c 'dead ? 0 (rest 50, wait 0))
             _ (wait 0)
             _ (freeze acc) _ (close l) _ (unlink path) _ (rest 50)
             (lclose c, 0))))
   ; a served core, attached -> a handle the five words take | () when none answers at path.
   ; every command goes tagged, so tasks may send at once
   (core-attach path)
    (: s (connect ['unix path])
       (? !(hot? s) ()
          (: rc {'remote 1 's s 'fs () 'nf 1 'rt {} 'tk {} 'snap () 'up 1}
             _ (pin rc 'rd (twirl (_ \ (: _ (lines-in s (m \ (: _ (? (rc 'snap = () && two? m && <m = 'snap) (pin rc 'snap m)
                                                                    (two? m && charm? <m) (pin (rc 'rt) <m >m)
                                                                    (each (rc 'fs) (w \ (w 1) m)))
                                                                 1)))
                                          (pin rc 'up 0))) 0))
             (wait n) (? (rc 'snap != () || n = 0) 0 (rest 5, wait (n - 1)))
             _ (wait 400)
             (rc 'snap = () ? (rclose rc, ()) rc))))
   ; a tag no other task can draw: the sender's task id and its own count
   (rsend rc msg)
    (? !(rc 'up) ['err "the core has gone"]
       (: me (myself 0 @ p (charm? p ? p 0)) k (peep (rc 'tk) me 0) _ (pin (rc 'tk) me (k + 1))
          t (me * 1048576 + k % 1048576)
          _ (say (rc 's) (show (t . msg) + "\n")) _ (flush (rc 's))
          (go _) (? (peep (rc 'rt) t () != ()) (: r ((rc 'rt) t) _ (pin (rc 'rt) t ()) r)
                    !(rc 'up) ['err "the core has gone"]
                    (rest 2, go 0))
          (go 0)))
   (rwatch rc f) (: k (rc 'nf) _ (pins rc 'nf (k + 1) 'fs (rc 'fs + [[k f]])) _ (f (rsend rc ['status])) k)
   (rclose rc) (: _ (? (rc 'up) (: _ (say (rc 's) "(bye)\n") (flush (rc 's))) 0)
                  _ (rc 'rd @ () 0 t (landed? t ? 0 (freeze t)))
                  _ (close (rc 's))
                  (pins rc 'up 0 'fs ()))
   ; a core for sink nm: the one served, else one started detached as mitty does, then attached
   (player-num s) (sound s @ (n . _) (charm? n ? n -1) _ -1)
   (player-spawn nm)
    (: me (selfpath 0) nul (openfd "/dev/null" 0)
       fds (: ns (readdir "/proc/self/fd") (two? ns ? (filter (n \ 2 < n) (map player-num ns)) ()))
       p (? (string? me) (spawnio [me "setsid" me "player" "--serve" "-n" nm] nul nul nul fds 0 0) -1)
       _ (? (0 <= nul) (close nul) 0)
       (charm? p && 0 < p))
   (player-reach nm n) (core-attach (player-sock nm) @ () (? (n = 0) () (rest 50, player-reach nm (n - 1))) rc rc)
   (player-core nm) (core-attach (player-sock nm) @ () (? (player-spawn nm) (player-reach nm 100) ()) rc rc)

   ; --- the verb: the protocol on stdin and stdout ---------------------------
   (line-of p) (: (go acc) (see p @ -1 (two? acc ? (string (rev acc)) ()) 10 (string (rev acc)) ch (go (ch . acc)))
                  (go ()))
   ; love player [-n SINK] [--here|--pipe|--serve|--headless|--kill] [FILE..]
   (player-main as)
    (: (opt f) (findsub as [f] @ k (k < 0 || k + 1 >= #as ? () (as (k + 1))))
       nm (opt "-n" || "main")
       (valued i) (i > 0 && elem (as (i - 1)) ["-n" "--mpd" "--music"])
       fs (filter (a \ a != ()) (map (i \ (? (starts? (as i) "-" || valued i) () (as i))) ^#as))
       (flag f) (elem f as)
       (music _) (: e (getenv "MPD_MUSIC") h (getenv "HOME")
                   (opt "--music" || (string? e && 0 < #e ? e (string? h ? (h + "/Music") "."))))
       (? (flag "--serve")
           (: c (core-new nm)
              ; the mpd skin on the same core, by cite: mpd.l bakes after this file
              _ (opt "--mpd" @ () 0
                  p (twirl (_ \ (cite 'mpd 'mpd-serve) ((cite 'mpd 'mpd-skin) c ((cite 'mpd 'mpd-lib) (music ()))) (sound p @ (n . _) n _ 6600)) 0))
              (core-serve c (player-sock nm)))
          (flag "--kill") (core-attach (player-sock nm) @
                            () (: _ (say err ("player: no core is served as " + nm + "\n")) _ (flush err) 1)
                            rc (: _ (core-send rc ['kill]) _ (core-close rc) 0))
          (flag "--headless") (player-core nm @
                                () (: _ (say err ("player: cannot start a core as " + nm + "\n")) _ (flush err) 1)
                                rc (: _ (player-feed rc fs) _ (core-close rc) 0))
          (flag "--pipe" || !(two? (tty 1))) (player-pipe fs)
          (flag "--here") (player-tui fs (core-new nm))
          (player-core nm @ () (player-tui fs (core-new nm)) rc (player-tui fs rc))))
   ; the files queued, and played from the first of them when nothing plays
   (player-feed c fs)
    (: ids (map (p \ (core-send c ['add p]) @ ['ok i] i _ ()) fs)
       got (filter (i \ i != ()) ids)
       st (core-snap c @ [_ s _] s _ ())
       stopped (foldl (\ a kv (<kv = 'state ? (kv 1 = 'stop) a)) 1 st)
       (? (two? got && stopped)
          (core-send c ['status] @ [_ _ [_ its]] (: n (findsub (map (it \ (<(filter (kv \ <kv = 'id) it)) 1) its) [<got])
                                                    (core-send c ['play n]))
                                  _ 0)
          0))
   ; the protocol on stdin and stdout, over a core in process
   (player-pipe fs)
    (: c (core-new "main")
       (line m) (say out (show m + "\n"), flush out)
       id (core-watch c line)
       _ (each fs (p \ (core-send c ['add p]) @ ['ok _] 0 r (line r)))
       _ (? (0 < #(c 'q)) (core-send c ['play 0]) 0)
       (go _) (line-of in @ () 0
                            s (: m (sound s @ (m . _) m _ ())
                                 r (two? m ? (core-tell c id m) ['err "a message is [verb arg ..]"])
                                 (line r, m = ['bye] ? 0 (go 0))))
       (go 0, core-close c, 0))
   ; the cells on this terminal over core c; tui.l bakes after this file, so by cite. an
   ; attached core plays on when the cells close, as a tmux session does
   (player-tui fs c)
    (: _ (player-feed c fs)
       _ ((cite 'ptui 'ptui-run) ((cite 'ptui 'ptui-new) c))
       (core-close c, 0))
   _ (pins (cite 'verbs 'tab) 'player (udoor 'player player-main "usage: love player [-n SINK] [--here|--pipe|--serve [--mpd PORT] [--music DIR]|--headless|--kill] [FILE..]" 1 1)))
) ; module core
