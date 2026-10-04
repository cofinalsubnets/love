; src/apps/torrent/torrent.l -- love torrent, the client (transmission-cli's shape), and the
; door av reads a torrent through.
;
;   love torrent [-w DIR] [-p PORT] [-P IP:PORT] [-seq] FILE
;   love torrent-show FILE        transmission-show's report
;
;   (torrent-open src f dir) -> [port bytes t] | why not: src a .torrent's path or its
;                               metainfo; file f of it as an ordered read port, the swarm
;                               running behind it into dir
;   (torrent-seek t f byte)  -> [port bytes]: a fresh port from byte on; the playhead moves
;
; leeching only for now: nothing is uploaded, and the client leaves when every piece is had.
(module (torrent torrent-open torrent-seek torrent-main torrent-show-main torrent-peers)
(borrow 'posix)
(borrow 'metainfo)
(borrow 'tracker)
(borrow 'swarm)
(:
 (tt-meta src) (? (tablet? src) src
                  (uread src @ [1 s] (tmeta s) ("cannot read " + src)))
 ; every tier asked in turn, its peers gathered; a tracker that fails is passed over
 (torrent-peers m id port)
  (: ask (pins {} 'hash (m 'hash) 'id id 'port port 'up 0 'down 0 'left (m 'total) 'event "started")
     urls (cats (m 'tiers))
     got (map (u \ announce u ask @ r (tablet? r ? (r 'peers) ())) urls)
     (: seen {} (filter (p \ (show p) @ k (peep seen k 0 ? 0 (pin seen k 1, 1))) (cats got))))
 (tt-start m dir opts)
  (: id (peer-id 0) port (peep opts 'port 51413)
     t (swarm-new m dir)
     ps (peep opts 'peers () @ () (torrent-peers m id port) l l)
     task (twirl (_ \ swarm-run t ps (pins opts 'id id)) ())
     (pin t 'task task, t))
 (torrent-open src f dir)
  (tt-meta src @ m
     (? (string? m) m
        !(0 <= f < #(m 'files)) "no such file in the torrent"
        (: t (tt-start m dir {'window 8})
           (swarm-port t f 0 @ [q n] [q n t]))))
 (torrent-seek t f byte) (swarm-port t f byte)

 ; --- the verbs ----------------------------------------------------------------------
 tt-usage "usage: love torrent [-w DIR] [-p PORT] [-P IP:PORT] [-seq] FILE"
 (tt-rate b ms) (ms < 1 ? "0 kB/s" (tsize-rate (b * 1000 // ms)))
 (tsize-rate bps) (bps < 1000 ? (show bps + " B/s") (tsize bps 1000 ["B/s" "kB/s" "MB/s" "GB/s"]))
 (tt-pct t) (: k (floor (1000.0 * t 'had / t 'm 'count + 0.0)) (show (k // 10) + "." + show (k % 10)))
 (torrent-main as)
  (: (opt as o) (? (atom? as) o
                   (<as = "-w" && two? >as) (opt >>as (pin o 'dir <>as))
                   (<as = "-p" && two? >as) (opt >>as (pin o 'port (read <>as)))
                   (<as = "-P" && two? >as) (: w <>as k (fsub w ":" 0)
                                               (opt >>as (pin o 'peers ([(snip w 0 k) (read (snip w (k + 1) #w))] . peep o 'peers ()))))
                   (<as = "-seq") (opt >as (pin o 'window 1000000))
                   (<<as = 45) (pin o 'bad <as)
                   (opt >as (pin o 'file <as)))
     o (opt as {'dir "." 'window 8})
     (? (peep o 'bad ()) (say err ("torrent: unknown option " + o 'bad + "\n" + tt-usage + "\n"), flush err, 2)
        !(peep o 'file ()) (say err (tt-usage + "\n"), flush err, 2)
        (tt-meta (o 'file) @ m
           (? (string? m) (say err ("torrent: " + m + "\n"), flush err, 1)
              (: t0 (clock 0) last {'b 0 'c t0}
                 (tick t) (: now (clock 0) b (t 'down)
                             r (tt-rate (b - last 'b) (now - last 'c))
                             (pins last 'b b 'c now,
                              say out ("\rProgress: " + tt-pct t + "%, dl from " + show (t 'live) + " of "
                                       + show (t 'peers) + " peers (" + r + "), ul to 0 (0 kB/s) [0.00]   "),
                              flush out))
                 t (tt-start m (o 'dir) (pins o 'tick tick 'max 30))
                 r (catch (t 'task))
                 (r = 1 ? (puts ("\nDone: " + m 'name + ", " + show (m 'count) + " pieces checked, in "
                                 + show ((clock 0 - t0) // 1000) + " s\n"), 0)
                    (say err ("\ntorrent: " + show r + "\n"), flush err, 1)))))))
 (torrent-show-main as)
  (? !(two? as) (say err "usage: love torrent-show FILE\n", 2)
     (tt-meta <as @ m (string? m ? (say err ("torrent-show: " + m + "\n"), 1) (puts (tshow m <as), 0))))
 _ (pins (cite 'verbs 'tab)
         'torrent (udoor 'torrent torrent-main tt-usage 1 1)
         'torrent-show (udoor 'torrent-show torrent-show-main "usage: love torrent-show FILE" 1 1)))
) ; module torrent
