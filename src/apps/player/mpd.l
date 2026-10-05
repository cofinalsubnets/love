; src/apps/player/mpd.l -- mpd's protocol as a skin over the player's core (notes/plan/av.md,
; layer 4): mpc, ncmpcpp and the rest of mpd's clients drive a core through it. the library is a
; scan of a music directory, and uris on the wire are relative to it, as mpd's are. held to mpd
; 0.24 itself, through mpc, by test/host/mpd.l. `(borrow 'mpd)`, then:
;
;   (mpd-lib dir)            -> the library: every song under dir that a codec here reads
;   (mpd-skin c lib)         -> a skin: core c (here or attached) seen through lib
;   (mpd-session k)          -> one client's state on skin k
;   (mpd-do ss line)         -> the reply text to one line of the protocol, () while a command
;                               list gathers; 'close when the client said close
;   (mpd-serve k port)       -> serves skin k on 127.0.0.1:port
;   (mpd-args line)          -> the words of a line, quotes and backslashes as mpd reads them
;
; a session's idle is fed by the core's events, which come from more than one task: each task
; has its own queue in the session's mailbox, written by it alone (tasks switch at any call).
(module (mpd mpd-lib mpd-skin mpd-session mpd-do mpd-serve mpd-args mpd-scan)
(borrow 'posix)
(borrow 'core)
(:
   udatez (cite 'kore 'udatez) stat (cite 'posix 'stat)
   known ["add" "addid" "clear" "clearerror" "close" "commands" "consume" "count" "currentsong" "decoders" "delete"
          "deleteid" "find" "findadd" "getvol" "idle" "list" "listall" "listallinfo" "listplaylist" "listplaylistinfo"
          "listplaylists" "load" "lsinfo" "move" "moveid" "next" "noidle" "notcommands" "outputs" "pause" "ping" "play"
          "playid" "playlistid" "playlistinfo" "plchanges" "plchangesposid" "previous" "random" "repeat" "rescan" "rm"
          "save" "search" "searchadd" "seek" "seekcur" "seekid" "setvol" "shuffle" "single" "stats" "status" "stop"
          "tagtypes" "update" "urlhandlers" "volume"]
   ; --- the words of a line --------------------------------------------------------
   (mpd-args l)
    (: (sp? c) (c = 32 || c = 9)
       (word i acc) (? (i >= #l || sp? (l i)) [(string (rev acc)) i] (word (i + 1) (l i . acc)))
       (quoted i acc) (? (i >= #l) [(string (rev acc)) i]
                         (l i = 34) [(string (rev acc)) (i + 1)]
                         (l i = 92 && i + 1 < #l) (quoted (i + 2) (l (i + 1) . acc))
                         (quoted (i + 1) (l i . acc)))
       (go i out) (? (i >= #l) (rev out)
                     (sp? (l i)) (go (i + 1) out)
                     (l i = 34) (quoted (i + 1) () @ [w j] (go j (w . out)))
                     (word i () @ [w j] (go j (w . out))))
       (go 0 ()))
   (num s) (sound s @ (n . _) (charm? n || gem? n ? n ()) _ ())
   (f3 x) (: m (int (x * 1000 + 0.5)) r (m % 1000)
             (show (m // 1000) + "." + (r < 10 ? "00" (r < 100 ? "0" "")) + show r))
   (rnd x) (int (x + 0.5))
   (iso ms) (udatez "%Y-%m-%dT%H:%M:%SZ" ms [0 "UTC"])
   (cat l) (foldl (\ a x (a + x)) "" l)
   (kv l k d) (foldl (\ a p (two? p && <p = k ? (p 1) a)) d l)

   ; --- the library ------------------------------------------------------------------
   ; the tags mpd knows, as it spells them, by the vorbis-comment name that carries them
   tag-names [["TITLE" "Title"] ["ARTIST" "Artist"] ["ALBUM" "Album"] ["ALBUMARTIST" "AlbumArtist"]
              ["TRACKNUMBER" "Track"] ["DATE" "Date"] ["GENRE" "Genre"] ["COMPOSER" "Composer"]
              ["PERFORMER" "Performer"] ["DISCNUMBER" "Disc"] ["NAME" "Name"]]
   all-tags (map (p \ p 1) tag-names)
   (tag-of nm) (: u (upper nm) (foldl (\ a p (<p = u ? (p 1) a)) () tag-names))
   ; m's "NAME=value" strings -> [[Tag value] ..], in the file's order
   (tags-of m)
    (filter (p \ p != ())
            (map (s \ (findsub (chars s) [61] @ k (? (k < 1) () (tag-of (snip s 0 k) @ () () t [t (snip s (k + 1) #s)]))))
                 (peep m 'tags ())))
   exts ["wav" "flac" "oga" "ogg" "mp3"]
   (ext f) (: k (findsub (rev (chars f)) [46]) (k < 0 ? "" (lower (snip f (#f - k) #f))))
   (dir? p) (stat p @ t (two? t && ((t 2) & 61440) = 16384))
   (mtime p) (stat p @ t (two? t ? (t 1) 0))
   (song dir rel)
    (: abs (dir + "/" + rel)
       ((cite 'av 'av-uri) abs @
         [q info] ((cite 'av 'av-open) q @
                    [nm m h] (: _ (close q) r (peep m 'rate 0)
                                fr (? (charm? (peep m 'total ())) (m 'total)
                                      (charm? (peep m 'len ()) && 0 <= m 'len) (m 'len // m 'align) 0)
                                {'file rel 'uri abs 'mtime (mtime abs) 'rate r 'ch (peep m 'ch 0)
                                 'bits (peep m 'bps (peep m 'bits 16)) 'dur (r ? (fr / (1.0 * r)) 0.0)
                                 'tags (tags-of m)})
                    why (: _ (close q) ()))
         why ()))
   ; songs and directories under dir/rel, depth first, sorted as mpd sorts them
   (walk dir rel)
    (: here (rel = "" ? dir (dir + "/" + rel))
       ns (readdir here @ l (two? l ? (sort (filter (n \ n 0 != 46) l)) ()))
       (foldl (\ acc n (: r (rel = "" ? n (rel + "/" + n))
                          (? (dir? (here + "/" + n)) (: sub (walk dir r) [(<acc + <sub) (acc 1 + [r] + sub 1)])
                             (elem (ext n) exts) (song dir r @ () acc s [(<acc + [s]) (acc 1)])
                             acc)))
              [() ()] ns))
   (mpd-lib dir)
    (walk dir "" @ [ss ds]
      {'dir dir 'songs ss 'dirs ds 'scanned (clock 0)
       'by (foldl (\ t s (pin t (s 'uri) s)) {} ss)})
   (mpd-scan k) (: l (mpd-lib (L k 'dir)) (pin k 'lib l))

   ; --- the skin and its sessions ------------------------------------------------------
   ; a mailbox several tasks put into and one takes from
   (mb-put mb x) (: me (myself 0 @ p (charm? p ? p 0)) q (peep mb me ())
                    q2 (? (tablet? q) q (: t {'w 0 'r 0} (pin mb me t, t)))
                    n (q2 'w)
                    (pin q2 n x, pin q2 'w (n + 1)))
   (mb-take mb) (foldl (\ a me (: q (mb me) r (q 'r) w (q 'w) ks (map (i \ i + r) ^(w - r))
                                  xs (map (i \ q i) ks)
                                  (each ks (i \ pin q i ()), pin q 'r w, a + xs)))
                       () (keys mb))
   (L k f) ((k 'lib) f)
   (mpd-skin c lib) {'c c 'lib lib 'ss () 'up (clock 0) 'nses 1}
   ; the core's events, as mpd's idle subsystems
   (subs-of m)
    (m @ ('queue . _) ['playlist]
         ['set kvs] (: ks (map (p \ <p) kvs)
                       (filter (x \ x != ())
                               [(aany? ks ['state 'song] ? 'player ())
                                (aany? ks ['vol 'bal 'pre 'eq 'eqon] ? 'mixer ())
                                (aany? ks ['repeat 'random 'single 'consume] ? 'options ())]))
         _ ())
   (aany? ks l) (foldl (\ a k (a || elem k l)) 0 ks)
   (mpd-session k)
    (: ss {'k k 'mb {} 'mask all-tags 'gath 0 'list () 'okl 0 'id (k 'nses)}
       _ (pin k 'nses (k 'nses + 1))
       _ (pin ss 'w (core-watch (k 'c) (m \ each (subs-of m) (x \ mb-put (ss 'mb) x))))
       _ (pin k 'ss (ss . k 'ss))
       ss)
   (mpd-end ss) (: k (ss 'k) _ (core-unwatch (k 'c) (ss 'w)) (pin k 'ss (filter (x \ (x 'id) != ss 'id) (k 'ss))))
   ; every session hears a subsystem the skin itself moves (the library, stored playlists)
   (tell-all k x) (each (k 'ss) (ss \ mb-put (ss 'mb) x))

   ; --- what goes out ------------------------------------------------------------------
   (rel k uri) (: d (L k 'dir + "/") (#uri > #d && snip uri 0 #d = d ? (snip uri #d #uri) uri))
   (abs k u) (? (starts? u "http://" || starts? u "https://" || starts? u "/") u (L k 'dir + "/" + u))
   (song-text ss s pos id)
    (: k (ss 'k)
       (cat [("file: " + rel k (s 'uri) + "\n")
             (? (s 'mtime) (: t (iso (s 'mtime)) ("Last-Modified: " + t + "\nAdded: " + t + "\n")) "")
             (? (0 < s 'rate) ("Format: " + show (s 'rate) + ":" + show (s 'bits) + ":" + show (s 'ch) + "\n") "")
             (cat (map (p \ elem <p (ss 'mask) ? (<p + ": " + p 1 + "\n") "") (peep s 'tags ())))
             (? (0 < s 'dur) ("Time: " + show (rnd (s 'dur)) + "\nduration: " + f3 (s 'dur) + "\n") "")
             (pos = () ? "" ("Pos: " + show pos + "\nId: " + show id + "\n"))]))
   ; a queue item as a song: the library's record when it has one, else what the core knows
   (item-song k it)
    (: u (kv it 'uri "")
       ((peep (L k 'by) u ()) @
         () {'uri u 'mtime 0 'rate 0 'dur (kv it 'dur 0.0)
             'tags (filter (p \ 0 < #(p 1)) [["Title" (kv it 'title "")] ["Artist" (kv it 'artist "")] ["Album" (kv it 'album "")]])}
         s s))
   (snap k) (core-snap (k 'c) @ ['snap st [_ its]] [st its] _ [() ()])
   (status-text k)
    (snap k @ [st its]
      (: n #its i (kv st 'song -1) state (kv st 'state 'stop)
         on (k \ (kv st k 0) = 1 ? "1" "0")
         nx (? (i < 0) -1 (i + 1 < n) (i + 1) (kv st 'repeat 0 = 1 && 0 < n) 0 -1)
         idof (j \ kv (its j) 'id 0)
         (cat [("volume: " + show (kv st 'vol 100) + "\n")
               ("repeat: " + on 'repeat + "\nrandom: " + on 'random + "\nsingle: " + on 'single
                + "\nconsume: " + on 'consume + "\npartition: default\n")
               ("playlist: " + show (kv st 'qver 0 + 1) + "\nplaylistlength: " + show n + "\nmixrampdb: 0\n")
               ("state: " + show state + "\nlastloadedplaylist: " + peep k 'last "" + "\n")
               (? (state = 'stop || i < 0) ""
                  (: e (kv st 'pos 0.0) d (kv st 'dur 0.0)
                     (cat ["song: " (show i) "\nsongid: " (show (idof i)) "\ntime: " (show (rnd e)) ":" (show (rnd d))
                           "\nelapsed: " (f3 e) "\nbitrate: " (show (kv st 'kbps 0)) "\nduration: " (f3 d) "\n"
                           (? (0 < kv st 'rate 0)
                              ("audio: " + show (kv st 'rate 0) + ":" + show (kv st 'bits 16) + ":" + show (kv st 'ch 2) + "\n") "")])))
               (? (nx < 0) "" ("nextsong: " + show nx + "\nnextsongid: " + show (idof nx) + "\n"))]))
      _ "")
   (queue-text ss its from to)
    (: k (ss 'k)
       (cat (map (j \ song-text ss (item-song k (its j)) j (kv (its j) 'id 0)) (map (j \ j + from) ^(max 0 (to - from))))))

   ; --- the commands -----------------------------------------------------------------
   ; an answer is the text before OK, or [code why] for an ACK
   (ack code why) [code why]
   (bad why) (ack 2 why)
   (nosuch why) (ack 50 why)
   (core-ok r f) (r @ ('ok . _) (f r) ['err why] (bad why) _ (bad "the core did not answer"))
   (send k m) (core-send (k 'c) m)
   (pos-id k p) (snap k @ [_ its] (? (charm? p && 0 <= p && p < #its) (kv (its p) 'id ()) ()) _ ())
   (id-pos k id) (snap k @ [_ its] (findsub (map (it \ kv it 'id ()) its) [id]) _ -1)
   ; "N" or "A:B" -> [A B] over a queue of n
   (range s n) (findsub (chars s) [58] @ k (? (k < 0) (num s @ () () a [a (a + 1)])
                                              (: a (num (snip s 0 k)) b (k + 1 < #s ? num (snip s (k + 1) #s) n)
                                                 (charm? a && charm? b ? [a b] ()))))
   (flag s) (s = "1" || s = "oneshot" ? 1 0)
   ; songs under a directory (every song for "") or the one song named
   (under k u) (filter (s \ u = "" || s 'file = u || starts? (s 'file) (u + "/")) (L k 'songs))
   (tag-val s t) (t @ "file" (s 'file)
                     "base" (s 'file @ f (findsub (rev (chars f)) [47] @ j (j < 0 ? f (snip f (#f - j) #f))))
                     _ (kv (s 'tags) t ""))
   ; find/search's TAG VALUE pairs: exact, or (search) a substring either case; any is any tag
   (matches s pairs exact)
    (: (hit v w) (exact ? (v = w) (0 <= findsub (chars (lower v)) (chars (lower w))))
       (foldl (\ a p (: t <p w (p 1)
                       (a && (t = "any" ? (foldl (\ b q (b || hit (q 1) w)) (hit (s 'file) w) (s 'tags))
                                (hit (tag-val s t) w)))))
              1 pairs))
   (pairs as) (? (two? as && two? >as) ([(canon <as) <>as] . pairs >>as) ())
   (canon t) (: l (lower t) (? (elem l ["any" "file" "base"]) l (tag-of l @ () t x x)))
   (findsongs k as exact) (: ps (pairs as) (filter (s \ matches s ps exact) (L k 'songs)))
   (lists-dir _) (: e (getenv "PLAYER_LISTS") h (getenv "HOME")
                   (? (string? e && 0 < #e) e (string? h) (h + "/.love/var/player/lists") "/tmp/player-lists"))
   (list-file nm) (lists-dir 0 + "/" + nm + ".m3u")
   (list-uris nm) (open (list-file nm) "r" @ q
                    (? !(hot? q) ()
                       (: t (slurp q) _ (close q)
                          (go i acc) (fsub t "\n" i @ e (: l (snip t i (e < 0 ? #t e))
                                                           acc2 (0 < #l && l 0 != 35 ? (l . acc) acc)
                                                           (e < 0 ? (rev acc2) (go (e + 1) acc2))))
                          (go 0 ()))))

   (do1 ss cmd as)
    (: k (ss 'k) (a1 _) (two? as ? <as ()) (a2 _) (two? as && two? >as ? <>as ())
       (cmd @
         "ping" ""
         "clearerror" ""
         "status" (status-text k)
         "currentsong" (snap k @ [st its] (: i (kv st 'song -1)
                                             (? (i < 0 || i >= #its || kv st 'state 'stop = 'stop) ""
                                                (song-text ss (item-song k (its i)) i (kv (its i) 'id 0))))
                                 _ "")
         "playlistinfo" (snap k @ [_ its] (? (a1 () = ()) (queue-text ss its 0 #its)
                                             (range (a1 ()) #its @ [a b] (? (a < #its) (queue-text ss its a (min b #its)) (bad "Bad song index"))
                                                                   _ (bad "Bad song index")))
                                  _ "")
         "playlistid" (snap k @ [_ its] (? (a1 () = ()) (queue-text ss its 0 #its)
                                           (id-pos k (num (a1 ())) @ j (j < 0 ? (nosuch "No such song") (queue-text ss its j (j + 1)))))
                                _ "")
         "plchanges" (snap k @ [_ its] (queue-text ss its 0 #its) _ "")
         "plchangesposid" (snap k @ [_ its] (cat (map (j \ "cpos: " + show j + "\nId: " + show (kv (its j) 'id 0) + "\n") ^#its)) _ "")
         "play" (: p (a1 () = () ? -1 (num (a1 ())))
                   (? (p = () || (p >= 0 && pos-id k p = ())) (bad "Bad song index")
                      (core-ok (send k (p < 0 ? ['play] ['play p])) (_ \ ""))))
         "playid" (: id (a1 () = () ? () (num (a1 ()))) j (id = () ? 0 (id-pos k id))
                     (? (j < 0) (nosuch "No such song") (core-ok (send k (id = () ? ['play] ['play j])) (_ \ ""))))
         "pause" (core-ok (send k (a1 () = () ? ['toggle] ['pause (flag (a1 ()))])) (_ \ ""))
         "stop" (core-ok (send k ['stop]) (_ \ ""))
         "next" (core-ok (send k ['next]) (_ \ ""))
         "previous" (core-ok (send k ['prev]) (_ \ ""))
         "seek" (: p (num (a1 ())) t (num (a2 ()))
                   (? (p = () || t = () || pos-id k p = ()) (bad "Bad song index")
                      (snap k @ [st _] (: _ (? (kv st 'song -1 != p || kv st 'state 'stop = 'stop) (send k ['play p]) 0)
                                          (core-ok (send k ['seek t]) (_ \ "")))
                                _ "")))
         "seekid" (: j (id-pos k (num (a1 ()))) t (num (a2 ()))
                     (? (j < 0 || t = ()) (nosuch "No such song")
                        (: _ (send k ['play j]) (core-ok (send k ['seek t]) (_ \ "")))))
         "seekcur" (: s (a1 () || "") t (num s)
                      (? (t = ()) (bad "Number expected")
                         (core-ok (send k (elem (s 0) [43 45] ? ['seekby t] ['seek t])) (_ \ ""))))
         "setvol" (num (a1 ()) @ v (? (charm? v && 0 <= v && v <= 100) (core-ok (send k ['vol v]) (_ \ "")) (bad "Invalid volume value")))
         "volume" (num (a1 ()) @ d (? (charm? d) (snap k @ [st _] (core-ok (send k ['vol (max 0 (min 100 (kv st 'vol 100 + d)))]) (_ \ "")) _ "")
                                       (bad "Invalid volume value")))
         "getvol" (snap k @ [st _] ("volume: " + show (kv st 'vol 100) + "\n") _ "")
         (m && elem m ["repeat" "random" "single" "consume"])
          (core-ok (send k [(sound m @ (s . _) s _ ()) (flag (a1 () || "0"))]) (_ \ ""))
         "add" (: u (a1 () || "")
                  (? (starts? u "http://" || starts? u "https://")
                     (core-ok (send k ['add u]) (_ \ ""))
                     (under k u @ () (nosuch "No such directory")
                                 l (: _ (each l (s \ send k ['add (s 'uri)])) ""))))
         "addid" (: u (a1 () || "") at (a2 () = () ? () (num (a2 ())))
                    (core-ok (send k (at = () ? ['add (abs k u)] ['add (abs k u) at]))
                             (r \ "Id: " + show (r 1) + "\n")))
         "delete" (snap k @ [_ its] (range (a1 () || "") #its @
                                      [a b] (? (a < 0 || b > #its || a >= b) (bad "Bad song index")
                                               (: ids (map (j \ kv (its (j + a)) 'id 0) ^(b - a)) _ (each ids (id \ send k ['del id])) ""))
                                      _ (bad "Bad song index"))
                           _ "")
         "deleteid" (core-ok (send k ['del (num (a1 ()))]) (_ \ ""))
         "move" (: p (num (a1 ())) to (num (a2 ())) id (pos-id k p)
                   (? (id = () || to = ()) (bad "Bad song index") (core-ok (send k ['move id to]) (_ \ ""))))
         "moveid" (core-ok (send k ['move (num (a1 ())) (num (a2 ()))]) (_ \ ""))
         "clear" (core-ok (send k ['clear]) (_ \ ""))
         "shuffle" (core-ok (send k ['shuffle]) (_ \ ""))
         ; the library
         "lsinfo" (: u (a1 () || "") l (k 'lib)
                     (? (u != "" && !(elem u (l 'dirs)))
                        (under k u @ [s] (song-text ss s () ()) _ (nosuch "No such directory"))
                        (: deep (n \ #(filter (c \ c = 47) (chars n)))
                           kids (filter (d \ (u = "" ? (deep d = 0) (starts? d (u + "/") && deep d = deep u + 1))) (l 'dirs))
                           files (filter (s \ (u = "" ? (deep (s 'file) = 0) (starts? (s 'file) (u + "/") && deep (s 'file) = deep u + 1))) (l 'songs))
                           ; directories and songs together, by name, as mpd lists them
                           ents (sort (map (d \ [d (\ _ ("directory: " + d + "\nLast-Modified: " + iso (mtime (l 'dir + "/" + d)) + "\n"))]) kids
                                       + map (s \ [(s 'file) (\ _ (song-text ss s () ()))]) files))
                           (cat (map (e \ (e 1) 0) ents)
                            + (u = "" ? (cat (map (n \ "playlist: " + n + "\nLast-Modified: " + iso (mtime (list-file n)) + "\n") (list-names ()))) "")))))
         "listall" (: u (a1 () || "") l (k 'lib)
                      (cat (map (d \ "directory: " + d + "\n") (filter (d \ u = "" || starts? d (u + "/")) (l 'dirs)))
                       + cat (map (s \ "file: " + s 'file + "\n") (under k u))))
         "listallinfo" (: u (a1 () || "") (cat (map (s \ song-text ss s () ()) (under k u))))
         "find" (? (pairs as = ()) (bad "too few arguments for \"find\"") (cat (map (s \ song-text ss s () ()) (findsongs k as 1))))
         "search" (? (pairs as = ()) (bad "too few arguments for \"search\"") (cat (map (s \ song-text ss s () ()) (findsongs k as 0))))
         "findadd" (: _ (each (findsongs k as 1) (s \ send k ['add (s 'uri)])) "")
         "searchadd" (: _ (each (findsongs k as 0) (s \ send k ['add (s 'uri)])) "")
         "count" (: ss2 (findsongs k as 1)
                    ("songs: " + show #ss2 + "\nplaytime: " + show (rnd (foldl (\ a s (a + s 'dur)) 0.0 ss2)) + "\n"))
         "list" (: t (canon (a1 () || "")) ss2 (findsongs k >as 1)
                   vs (sort (uniq (map (s \ tag-val s t) ss2)))
                   (? (t = () || t = "any") (bad "Unknown tag type")
                      (cat (map (v \ t + ": " + v + "\n") vs))))
         "update" (: _ (mpd-scan k) _ (tell-all k 'update) _ (tell-all k 'database) "updating_db: 1\n")
         "rescan" (do1 ss "update" as)
         "stats" (: l (k 'lib) ss2 (l 'songs)
                    (cat ["artists: " (show #(uniq (sort (filter (v \ 0 < #v) (map (s \ tag-val s "Artist") ss2)))))
                          "\nalbums: " (show #(uniq (sort (filter (v \ 0 < #v) (map (s \ tag-val s "Album") ss2)))))
                          "\nsongs: " (show #ss2) "\nuptime: " (show ((clock 0 - k 'up) // 1000))
                          "\ndb_playtime: " (show (rnd (foldl (\ a s (a + s 'dur)) 0.0 ss2)))
                          "\ndb_update: " (show (l 'scanned // 1000)) "\nplaytime: 0\n"]))
         ; stored playlists
         "listplaylists" (cat (map (n \ "playlist: " + n + "\nLast-Modified: " + iso (mtime (list-file n)) + "\n") (list-names ())))
         "listplaylist" (list-uris (a1 () || "") @ () (nosuch "No such playlist") us (cat (map (u \ "file: " + rel k u + "\n") us)))
         "listplaylistinfo" (list-uris (a1 () || "") @ () (nosuch "No such playlist")
                              us (cat (map (u \ song-text ss (peep (L k 'by) u {'uri u 'mtime 0 'rate 0 'dur 0.0 'tags ()}) () ()) us)))
         "load" (core-ok (send k ['load (a1 () || "")]) (_ \ (pin k 'last (a1 ()), "")))
         "save" (? (elem (a1 ()) (list-names ())) (ack 56 "Playlist already exists")
                   (core-ok (send k ['save (a1 () || "")]) (_ \ (tell-all k 'stored_playlist, ""))))
         "rm" (? !(elem (a1 ()) (list-names ())) (nosuch "No such playlist")
                 (core-ok (send k ['rm (a1 ())]) (_ \ (tell-all k 'stored_playlist, ""))))
         ; about the server
         "outputs" "outputid: 0\noutputname: horn\nplugin: horn\noutputenabled: 1\n"
         (m && elem m ["enableoutput" "disableoutput" "toggleoutput"]) ""
         "tagtypes" (: w (lower (a1 () || ""))
                       (? (w = "") (cat (map (t \ "tagtype: " + t + "\n") (ss 'mask)))
                          (w = "clear") (: _ (pin ss 'mask ()) "")
                          (w = "all" || w = "reset") (: _ (pin ss 'mask all-tags) "")
                          (w = "enable") (: _ (pin ss 'mask (filter (t \ elem t (ss 'mask) || elem (lower t) (map lower >as)) all-tags)) "")
                          (w = "disable") (: _ (pin ss 'mask (filter (t \ !(elem (lower t) (map lower >as))) (ss 'mask))) "")
                          (bad "Unknown sub command")))
         "urlhandlers" "handler: http://\nhandler: https://\n"
         "decoders" "plugin: wav\nsuffix: wav\nplugin: flac\nsuffix: flac\nplugin: ogg\nsuffix: ogg\nsuffix: oga\nplugin: mp3\nsuffix: mp3\n"
         "replay_gain_status" "replay_gain_mode: off\n"
         (m && elem m ["replay_gain_mode" "crossfade" "mixrampdb" "mixrampdelay" "binarylimit"]) ""
         "commands" (cat (map (c \ "command: " + c + "\n") (sort known)))
         "notcommands" ""
         "password" (ack 3 "incorrect password")
         _ (ack 5 ("unknown command \"" + cmd + "\""))))
   (list-names _) (: fs (readdir (lists-dir 0))
                     (sort (map (f \ snip f 0 (#f - 4)) (filter (f \ 4 < #f && ".m3u" = snip f (#f - 4) #f) (two? fs ? fs ())))))

   ; one line in -> the text out. a command list gathers until its end, then runs in order and
   ; stops at the first ACK, which names the command's place in the list
   (mpd-do ss line)
    (: ws (mpd-args line) cmd (two? ws ? <ws "") as (two? ws ? >ws ())
       (? (ss 'gath)
          (? (cmd = "command_list_end")
             (: l (rev (ss 'list)) okl (ss 'okl) _ (pins ss 'gath 0 'list () 'okl 0)
                (go i l out) (? (atom? l) (out + "OK\n")
                                (: w (mpd-args <l) r (do1 ss (<w || "") >w)
                                   (two? r ? (out + "ACK [" + show <r + "@" + show i + "] {" + (<w || "") + "} " + r 1 + "\n")
                                      (go (i + 1) >l (out + r + (okl ? "list_OK\n" ""))))))
                (go 0 l ""))
             (: _ (pin ss 'list (line . ss 'list)) ()))
          (cmd = "command_list_begin" || cmd = "command_list_ok_begin")
           (: _ (pins ss 'gath 1 'list () 'okl (cmd = "command_list_ok_begin")) ())
          (cmd = "close") 'close
          (: r (do1 ss cmd as)
             (two? r ? ("ACK [" + show <r + "@0] {" + (cmd = "" || !(elem cmd known) ? "" cmd) + "} " + r 1 + "\n") (r + "OK\n")))))

   ; --- the server ----------------------------------------------------------------------
   (line-of p) (: (go acc) (see p @ -1 (two? acc ? (string (rev acc)) ()) 10 (string (rev acc)) ch (go (ch . acc)))
                  (go ()))
   (idle-text xs want)
    (: got (uniq (sort (filter (x \ want = () || elem x want) xs)))
       (cat (map (x \ "changed: " + show x + "\n") got)))
   ; one client: its lines come in on a task of their own; between them the core's events
   ; gather, and an idle answers with those it asked for, now or when they come
   (conn k s)
    (: ss (mpd-session k)
       inbox {} ib {'up 1}
       rd (twirl (_ \ (: (go _) (line-of s @ () (pin ib 'up 0) l (: _ (mb-put inbox l) (go 0)))
                         (go 0))) 0)
       (out t) (: _ (say s t) (flush s))
       (got pend want) (uniq (sort (filter (x \ want = () || elem x want) pend)))
       (answer pend want) (: g (got pend want)
                             _ (out (cat (map (x \ "changed: " + show x + "\n") g) + "OK\n"))
                             (filter (x \ !(elem x g)) pend))
       (step want idling pend)
        (: ls (mb-take inbox) pend2 (uniq (sort (pend + mb-take (ss 'mb))))
           (? (two? ls) (feed ls want idling pend2)
              (idling && two? (got pend2 want)) (step () 0 (answer pend2 want))
              (ib 'up = 0) (mb-take inbox @ () 0 l (feed l want idling pend2))
              (: _ (rest 5) (step want idling pend2))))
       (feed ls want idling pend)
        (? (atom? ls) (step want idling pend)
           (: l <ls w (mpd-args l) cmd (two? w ? <w "")
              (? idling (? (cmd = "noidle") (feed >ls () 0 (answer pend want)) (feed >ls want idling pend))
                 (cmd = "idle") (: w2 (map (x \ sound x @ (y . _) y _ ()) >w)
                                   (? (two? (got pend w2)) (feed >ls () 0 (answer pend w2)) (feed >ls w2 1 pend)))
                 (mpd-do ss l @ 'close 0
                                () (feed >ls want 0 pend)
                                t (: _ (out t) (feed >ls want 0 pend))))))
       _ (out "OK MPD 0.24.0\n")
       _ (step () 0 ())
       _ (rd @ t (landed? t ? 0 (freeze t)))
       (mpd-end ss, close s, 0))
   (mpd-serve k port)
    (listen ['tcp "127.0.0.1" port] @ l
      (? !(hot? l) ("mpd: cannot listen on port " + show port)
         (: (go _) (accept l @ s (hot? s ? (twirl (_ \ conn k s) 0, go 0) 0))
            (go 0)))))
) ; module mpd
