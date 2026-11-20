; src/apps/dict/dictd.l -- a dict server (RFC 2229) over dictd's own databases and config:
;   love -l src/apps/dict/dict.l src/apps/dict/dictd.l [-p PORT] [-c CONF]
; CONF is a dictd.conf (/etc/dict/dictd.conf by default): its database blocks, each a data and
; an index file, the rest read past. PORT is 2628 by default. a task to each connection
(borrow '(posix dict))
(: (after l) (atom? l ? () (<l @ (_ + "dictd.l") >l (after >l)))
   as (after cmdline)
   (gone s) (say err ("dictd: " + s + "\n"), quit 1)
   (opt k d) (: (go l) (? (atom? l || atom? >l) d (<l = k) <>l (go >>l)) (go as))
   port (read (opt "-p" "2628"))
   conf (opt "-c" "/etc/dict/dictd.conf")
   ; a conf's words: a # to its line's end off, braces words of their own, "" quoting
   (toks s) (dict-args (join " " (map (l \ (: k (find l "#" 0) t (k < 0 ? l (snip l 0 k))
                                            (join " { " (split "{" (join " } " (split "}" t))))))
                                      (lines s))))
   ; each database block -> [name index data]
   (dbs-of ts)
    (: (body l kv) (l @ ("}" . r) [kv r]
                        (k . v . r) (body r (pin kv k v))
                        _ [kv ()])
       (go l acc) (l @ ("database" . n . "{" . r)
                        (body r {} @ [kv r2] (go r2 (kv "index" && kv "data" ? ([n (kv "index") (kv "data")] . acc) acc)))
                        (_ . r) (go r acc)
                        _ (rev acc))
       (go ts ()))
   find fsub
   host (uname () @ u (two? u ? (u 1) "localhost"))
   dbs (uread conf @ [1 s] (map (\ [n i d] (dict-db n i d)) (dbs-of (toks s)))
                     _ (gone ("cannot read " + conf)))
   ; one connection: the banner, then a reply to each line until QUIT or its end
   (talk c reply buf)
    (: k (find buf "\n" 0)
       (? (0 <= k) (reply (snip buf 0 k) @ [t qt] (say c t, flush c, qt ? 0 (talk c reply (snip buf (k + 1) #buf))))
          (: _ (await c) (see c @ -1 0 ch (unsee c ch, talk c reply (buf + chug c))))))
   (serve c n) (dict-session dbs host "\(getpid 0).\(n)" @ [b reply] (say c b, flush c, talk c reply ""))
   l (listen port)
   _ (hot? l ? 0 (gone ("cannot listen on port " + show port + " (" + show l + ")")))
   _ (say err ("dictd: " + show #dbs + " databases on port " + show port + "\n"))
   (loop n) (: _ (await l) c (accept l)
               (hot? c ? (twirl (_ \ (trap (c \ serve c n) c (\ a b 0), close c)) ()) 0,
                loop (n + 1)))
   (loop 1))
