; src/apps/torrent/torrent.l -- love torrent, the client (transmission-cli's shape), and the
; door av reads a torrent through.
;
;   love torrent [-w DIR] [-p PORT] [-P IP:PORT] [-seq] [-x] FILE
;                                 seeds when every piece is had, as transmission-cli does;
;                                 -x leaves then instead
;   love torrent-show FILE        transmission-show's report
;
;   (torrent-open src f dir) -> [port bytes t] | why not: src a .torrent's path or its
;                               metainfo; file f of it as an ordered read port, the swarm
;                               running behind it into dir
;   (torrent-seek t f byte)  -> [port bytes]: a fresh port from byte on; the playhead moves
;
; a port from torrent-open seeds nothing; the verb offers every piece it has.
(module (torrent torrent-open torrent-seek torrent-main torrent-show-main torrent-peers)
(borrow 'posix)
(borrow 'metainfo)
(borrow 'tracker)
(borrow 'swarm)
(:
 (tt-meta src) (? (tablet? src) src
                  (uread src @ [1 s] (tmeta s) ("cannot read " + src)))
 ; every tier asked in turn, its peers gathered; a tracker that fails is passed over
 (tt-ask m t id port ev) (pins {} 'hash (m 'hash) 'id id 'port port 'up (t 'up) 'down (t 'down)
                               'left (max 0 (m 'total - t 'had * m 'plen)) 'event ev)
 (tt-announce m ask)
  (: rs (filter tablet? (map (u \ announce u ask) (cats (m 'tiers))))
     [(cats (map (r \ r 'peers) rs)) (foldl (a \ r \ min a (r 'interval)) 1800 rs)])
 (torrent-peers m id port) (<(tt-announce m (tt-ask m {'up 0 'down 0 'had 0} id port "started")))
 ; the trackers again at the interval they ask, "completed" said once, the new peers dialled
 (tt-track t m id port wait)
  (: done (t 'had = m 'count)
     _ (rest (1000 * max 60 wait))
     (tt-announce m (tt-ask m t id port (!done && t 'had = m 'count ? "completed" "")) @ [ps w]
        (swarm-add! t ps, tt-track t m id port w)))
 (tt-start m dir opts)
  (: id (peer-id 0) port (peep opts 'port 51413)
     t (swarm-new m dir)
     first (peep opts 'peers () @ () (tt-announce m (tt-ask m t id port "started")) l [l 1800])
     _ (pin t 'tracker (twirl (_ \ tt-track t m id port (first 1)) ()))
     task (twirl (_ \ swarm-run t (first 0) (pins opts 'id id) @ r (freeze (t 'tracker), r)) ())
     (pin t 'task task, t))
 (torrent-open src f dir)
  (tt-meta src @ m
     (? (string? m) m
        !(0 <= f < #(m 'files)) "no such file in the torrent"
        (: t (tt-start m dir {'window 8})
           (swarm-port t f 0 @ [q n] [q n t]))))
 (torrent-seek t f byte) (swarm-port t f byte)

 ; --- the verbs ----------------------------------------------------------------------
 tt-usage "usage: love torrent [-w DIR] [-p PORT] [-P IP:PORT] [-seq] [-x] FILE"
 (tt-rate b ms) (ms < 1 ? "0 B/s" (tsize-rate (b * 1000 // ms)))
 (tsize-rate bps) (bps < 1000 ? (show bps + " B/s") (tsize bps 1000 ["B/s" "kB/s" "MB/s" "GB/s"]))
 (tt-pct t) (: k (floor (1000.0 * t 'had / t 'm 'count + 0.0)) (show (k // 10) + "." + show (k % 10)))
 ; transmission's ratio: uploaded over downloaded, or over the size when nothing came down
 (tt-ratio t) (: d (t 'down) k (floor (100.0 * t 'up / (0 < d ? d (t 'm 'total)) + 0.5))
                (show (k // 100) + "." + (k % 100 < 10 ? "0" "") + show (k % 100)))
 (torrent-main as)
  (: (opt as o) (? (atom? as) o
                   (<as = "-w" && two? >as) (opt >>as (pin o 'dir <>as))
                   (<as = "-p" && two? >as) (opt >>as (pin o 'port (read <>as)))
                   (<as = "-P" && two? >as) (: w <>as k (fsub w ":" 0)
                                               (opt >>as (pin o 'peers ([(snip w 0 k) (read (snip w (k + 1) #w))] . peep o 'peers ()))))
                   (<as = "-seq") (opt >as (pin o 'window 1000000))
                   (<as = "-x") (opt >as (pin o 'seed 0))
                   (<<as = 45) (pin o 'bad <as)
                   (opt >as (pin o 'file <as)))
     o (opt as {'dir "." 'window 8 'seed 1 'port 51413})
     (? (peep o 'bad ()) (say err ("torrent: unknown option " + o 'bad + "\n" + tt-usage + "\n"), flush err, 2)
        !(peep o 'file ()) (say err (tt-usage + "\n"), flush err, 2)
        (tt-meta (o 'file) @ m
           (? (string? m) (say err ("torrent: " + m + "\n"), flush err, 1)
              (: t0 (clock 0) last (pins {} 'b 0 'u 0 'c t0 'done 0)
                 l (listen (o 'port))
                 _ (hot? l ? 0 (say err ("torrent: cannot listen on port " + show (o 'port) + ", dialling only\n"), flush err))
                 (done! t) (? !(last 'done) (pin last 'done 1,
                                             puts ("\nDone: " + m 'name + ", " + show (m 'count) + " pieces checked, in "
                                                   + show ((clock 0 - t0) // 1000) + " s\n")))
                 (tick t) (: now (clock 0) ms (now - last 'c)
                             dr (tt-rate (t 'down - last 'b) ms) ur (tt-rate (t 'up - last 'u) ms)
                             (pins last 'b (t 'down) 'u (t 'up) 'c now,
                              t 'had = m 'count ? (done! t),
                              say out (t 'had = m 'count
                                 ? ("\rSeeding, uploading to " + show (t 'open) + " of " + show (t 'live) + " peer(s), "
                                    + ur + " [" + tt-ratio t + "]   ")
                                 ("\rProgress: " + tt-pct t + "%, dl from " + show (t 'live) + " of "
                                  + show (t 'peers) + " peers (" + dr + "), ul to " + show (t 'open) + " (" + ur
                                  + ") [" + tt-ratio t + "]   ")),
                              flush out))
                 t (tt-start m (o 'dir) (pins o 'tick tick 'max 30 'listen l))
                 r (catch (t 'task))
                 (r = 1 ? (done! t, 0)
                    (say err ("\ntorrent: " + show r + "\n"), flush err, 1)))))))
 (torrent-show-main as)
  (? !(two? as) (say err "usage: love torrent-show FILE\n", 2)
     (tt-meta <as @ m (string? m ? (say err ("torrent-show: " + m + "\n"), 1) (puts (tshow m <as), 0))))
 _ (pins (cite 'verbs 'tab)
         'torrent (udoor 'torrent torrent-main tt-usage 1 1)
         'torrent-show (udoor 'torrent-show torrent-show-main "usage: love torrent-show FILE" 1 1)))
) ; module torrent
