; src/apps/sb/sb.l -- svalbard: the patch-set vcs (doc/misc/sb.md the interface,
; the seat form at the tail is the only thing that fires as a program.
(module 'sb
(borrow 'kore)
(borrow 'posix)
(:
   ; --- files ---
   ; an empty file slurps to (), so `+ ""` folds it back onto the string identity and a
   ; 0-byte file hashes honestly. the port is minded, not closed at the tail: a torn read
   ; raises, and the close has to leave that way too or the fd sits until a major compact.
   (look p) (: q (open p "r")                                            ; (1 text) | ()
                 (? (hot? q) (mind (_ \ (: s (slurp q) [1 (s + "")])) () (_ \ close q)) ()))
   (lay p s) (: q (open p "w") (? (hot? q) (mind (_ \ (say q s, 1)) () (_ \ close q)) 0))
   (form p) (: q (open p "r")                                 ; the file's one form | ()
                  (? (hot? q) (mind (_ \ (: r (sound (slurp q))
                                     d (two? r ? <r)
                                     (two? d ? d)))
                             () (_ \ close q))))

   ; --- the store ---
   ; a new nest's head is empty; a nest from before heads has none, and realizes its whole store
   (mk _) (: new !(two? (stat ".sb"))
             _ (mkdir ".sb" 493, mkdir ".sb/blob" 493, mkdir ".sb/patch" 493)
             (? new (lay ".sb/head" "()") ()))
   (snap _) (form ".sb/snap")                            ; ((path side pid) ..) sorted, the head's tree
   (tips _) (form ".sb/tips")                            ; (id ..), the store's: every patch it holds
   ; the head: the tips of the set this nest's tree realizes, which the store may hold more than
   (head-in d) (? (two? (stat (d + "/.sb/head"))) (form (d + "/.sb/head")) (form (d + "/.sb/tips")))
   (head _) (head-in ".")
   ; the head moved to a set, kept as .sb/sets/PSID too, so every set a head stood at stays a name
   (head-to tp) (: t (ids-text (sort tp)) _ (mkdir ".sb/sets" 493) _ (lay (".sb/sets/" + sha256 t) t) (lay ".sb/head" t))
   ; the nest's lock, a directory made atomically and holding its holder's pid, as a ledger's.
   ; it is this process's own when it holds it already, so a verb may call another
   (nest-hold d tries)
    (: l (d + "/.sb/lock")
       (? ((mkdir l 448) = ()) (: _ (lay (l + "/pid") (show (getpid 0))) 'took)
          (: t (look (l + "/pid")) p (? (two? t) (: s <>t (go i a) (? (i < #s && 48 <= s i <= 57) (go (i + 1) (a * 10 + s i - 48)) a) (go 0 0)) 0)
             (? (p = getpid 0) 'again
                (0 < p && nom? (still p 0)) (: _ (unlink (l + "/pid")) _ (rmdir l) (nest-hold d tries))
                (tries <= 0) ()
                (: _ (rest 20) (nest-hold d (tries - 1)))))))
   (nest-free d) (: _ (unlink (d + "/.sb/lock/pid")) (rmdir (d + "/.sb/lock")))
   (held d f)
    (: _ (? (d = ".") (mk ()) 0)                                   ; the lock lives in the nest
       h (nest-hold d 500)
       (? !h (: _ (say err ("sb: the nest at " + d + " is held by another writer\n")) 0)
          (: r (f 0) _ (? (h = 'took) (nest-free d) 0) r)))
   ; the patch-set ID: the name of a head DAG state. the tips are a set -- sort
   ; before hashing, or the same head reads two ways.
   (psid tp) (sha256 (ids-text (sort tp)))
   (ids-text l) (? (atom? l) "()" (cats (["(\"" <l "\""] + catmap (i \ [" \"" i "\""]) >l + [")"])))  ; = show, faster
   (blob h) (: k (sd-h h) t (? (sb-hex? k) (look (".sb/blob/" + k))) (two? t ? <>t))
   ; a side is a path's state: () absent, its blob's hash for a plain file, the hash and an
   ; x for an executable one. so a chmod is a change, and a context names the mode too
   (sd-h s) (? (sd-x? s) (snip s 0 64) s)                      ; the side's blob
   (sd-x? s) (string? s && #s = 65)
   (sd h x) (? (h && x) (h + "x") h)
   (sd-exe? p) (: st (stat p) (two? st && 0 < (64 & <>>st)))  ; the owner's x bit
   ; an x side gives x wherever there is r; a plain one takes every x away
   (sd-chmod p x)
    (: st (stat p) m (? (two? st) (4095 & <>>st) 0)
       m2 (? x (m | ((m & 292) // 4)) (m - (m & 73)))
       (? (two? st && m != m2) (chmod p m2)))
   (keep s) (: h (sha256 s) _ (lay (".sb/blob/" + h) s) h)
   (patch id) (: f (? (sb-hex? id) (form (".sb/patch/" + id))) (sb-sound? f ? f))
   (fld f k) (:- (go >f) (go m) (? (atom? m) () (two? <m && <<m = k) ><m (go >m)))

   ; --- what a patch may say: its ids and paths become paths here, so a peer's word
   ;     is checked before any of it is used ---
   ; a store name is a sha256 in lowercase hex and nothing else
   (sb-hex? s)
    (: (go i) (? (64 <= i) 1 (: c (s i) (? ((48 <= c <= 57) || (97 <= c <= 102)) (go (i + 1)) 0)))
       (string? s && #s = 64 && go 0))
   ; a hunk's path is relative and stays under the root: no leading /, no empty, . or .. segment,
   ; no control byte, and no segment naming a store (.git, .sb) at any depth
   (sb-rel? p) (string? p && sb-rel1? p)
   (sb-rel1? p)
    (: n #p
       (seg a b) (: s (snip p a b) !(#s = 0 || s = "." || s = ".." || sb-meta? s))
       (go a i) (? (n <= i) (seg a i)
                   (p i = 47) (seg a i && go (i + 1) (i + 1))
                   (go a (i + 1)))
       (0 < n && !(sb-ctl? p) && go 0 0))
   (sb-ctl? s) (: (go i) (? (#s <= i) 0 (s i < 32 || s i = 127) 1 (go (i + 1))) (go 0))
   ; a store's name in any case, trailing dots and spaces dropped, or git's 8.3 spelling
   (sb-meta? s)
    (: (go n) (? (0 < n && (s (n - 1) = 46 || s (n - 1) = 32)) (go (n - 1)) n)
       t (lower (snip s 0 (go #s)))
       (t = ".git" || t = ".sb" || t = "git~1"))
   ; some prefix of p, or p itself, is a symlink: a write there would leave the tree
   (sb-link? p)
    (: n #p
       (ln? q) (: st (lstat q) (two? st && (61440 & <>>st) = 40960))
       (go i) (? (n <= i) (ln? p) (p i = 47) (ln? (snip p 0 i) || go (i + 1)) (go (i + 1)))
       (go 0))
   (sb-all? f l) (? (atom? l) (l = ()) (f <l && sb-all? f >l))
   (sb-oid? x) (x = () || sb-hex? x                              ; a hunk side: absent, a blob,
                || (sd-x? x && x 64 = 120 && sb-hex? (sd-h x)))   ; or a blob and an x
   (sb-hunk? h) (two? h && #h = 3 && string? <h && sb-rel? <h && sb-oid? <>h && sb-oid? <>>h)
   (sb-sound? f) (sb-all? sb-hunk? (fld f 'hunks) && sb-all? sb-hex? (fld f 'deps))
   (sb-bad? id) (!(sb-hex? id) || (: f (form (".sb/patch/" + id)) (two? f && !(sb-sound? f))))
   (sb-refuse id) (say err ("sb: patch " + (? (string? id) (sh id) (show id)) + " refused -- an id that is not a hash,"
                            + " or a path sb may not write\n"))

   ; --- ignores: one rule a line in .sbignore, over the built-ins. a rule holding
   igsdir '(".sb" ".git" "out")
   ig-glob? (cite 'glob 'anyglob)
   ig-match (cite 'glob 'match)
   (ig-live? l) (0 < #l && l 0 != 35)
   (igs _) (: t (look ".sbignore")
                 (two? t ? (filter ig-live? (lines <>t)) ()))
   (ign1? p g) (: n #g (ig-glob? g ? (ig-match g p)
                        (p = g || n + 1 < #p && snip p 0 (n + 1) = (g + "/"))))
   (ign? p igs) (? (atom? igs) 0 (ign1? p <igs) 1 (ign? p >igs))

   ; --- the walk: every regular file under the root, paths relative ---
   (walk dir igs acc)
    (: es (readdir (? !dir "." dir))
       (go m acc)
        (? (atom? m) acc
           (: p (? !dir <m (dir + "/" + <m))
              (? (ign? p igs || !(sb-rel? p)) (go >m acc)       ; a name no patch may carry
                 (: st (lstat p)                                 ; a link is not followed, nor kept
                    md (two? st ? (61440 & <>>st) 0)
                  (md @ 16384 (? (ign? p igsdir) (go >m acc) (go >m (walk p igs acc)))
                        32768 (go >m (p . acc))
                              (go >m acc))))))
       (go es acc))

   ; --- the scan: working tree vs snap -> the hunks, path-sorted. pure (no
   ;     blob writes); a hunk is (path old new), old and new its sides ---
   (h1 p e)                                                   ; one path vs its snap entry|()
    (: t (look p)
       (atom? t ? (two? e ? [p <>e ()])                 ; unreadable: dead if known
        (: h (sd (sha256 <>t) (sd-exe? p))
           (? (atom? e) [p () h]                               ; born
              (<>e = h) ()                                   ; unchanged
              [p <>e h]))))                                  ; changed
   (scan ps sn acc)                                           ; ps sorted paths, sn the snap
    (? (atom? ps)
        (atom? sn ? (rev acc) (scan ps >sn ([<<sn <><sn ()] . acc)))         ; the tail of snap: dead
       (atom? sn)
        (: h (h1 <ps ()) (scan >ps sn (two? h ? (h . acc) acc)))
       (: p <ps e <sn
          (? (p = <e) (: h (h1 p e) (scan >ps >sn (two? h ? (h . acc) acc)))
             (p < <e) (: h (h1 p ()) (scan >ps sn (two? h ? (h . acc) acc)))
             (scan ps >sn ([<e <>e ()] . acc)))))        ; snap-only: dead

   ; --- record ---
   (sb-record note)
    (: _ (mk ())
       sn (snap ())
       st {}                                             ; path -> (chash pid)
       _ (: (go m) (? (two? m) (pin st <<m ><m, go >m) ()) (go sn))
       hunks (scan (sort (walk () (igs ()) ())) sn ())
       (? !(two? hunks) (puts "sb: nothing to record\n", ())
          (: ; the blobs: keep every hunk's new content
             _ (: (go m) (two? m ?  (: h <m _ (? !<>>h () (keep <>(look <h))) (go >m)))
                  (go hunks))
             ; the deps: the patches whose writes this one's contexts read
             deps (:- (go hunks ()) (go m acc)
                   (? (atom? m) (sort acc)
                    (: old <><m
                     (? !old (go >m acc)
                      (: e (st <<m)
                         pid (two? e ? <>e)
                       (!pid || elem pid acc ? (go >m acc)
                        (go >m (pid . acc))))))))
             ptext (show ['patch ['note note] ['time (clock 0)]
                          ('deps . deps) ('hunks . hunks)])
             pid (sha256 ptext)
             _ (lay (".sb/patch/" + pid) ptext)
             _ (lay ".sb/snap" (show (snap+ sn hunks pid ())))
             tp (filter (t \ !(elem t deps)) (tips ()))
             _ (lay ".sb/tips" (ids-text (sort (pid . tp))))
             _ (head-to (pid . filter (t \ !(elem t deps)) (head ())))
             _ (puts ("sb: recorded " + snip pid 0 12 + " (" + show #hunks + " paths)\n"))
             pid)))

   ; --- snap under a patch's hunks (both path-sorted) ---
   (snap+ sn hs pid acc)
    (? (atom? hs) (rev acc + sn)
       (atom? sn) (: h <hs nw <>>h
                        (snap+ () >hs pid (? !nw acc ([<h nw pid] . acc))))
       (: h <hs e <sn
          (? (<h = <e) (: nw <>>h
                            (snap+ >sn >hs pid (? !nw acc ([<h nw pid] . acc))))
             (<h < <e) (: nw <>>h
                            (snap+ sn >hs pid (? !nw acc ([<h nw pid] . acc))))
             (snap+ >sn hs pid (<sn . acc)))))

   ; --- log: the patches newest first; * marks a tip of the head ---
   (ins e l) (? (atom? l) [e]                                 ; insert desc by time (seat 0)
              (<<l <= <e) (e . l)
              (<l . ins e >l))
   ; the lines of (time id note nhunks) entries, * for a tip of tp
   (log-pr es tp)
    (two? es ?
     (: e <es id <>e
        _ (puts (? (elem id tp) "* " "  "))
        _ (puts (snip id 0 12 + "  " + show <>>>e + " paths"))
        nt <>>e
        _ (? !nt () (puts ("  " + nt)))
        _ (puts "\n")
        (log-pr >es tp)))
   (sb-log _)
    (: tp (head ())
       (go m acc)
        (atom? m ? acc
         (: id <m f (patch id)
          (atom? f ? (go >m acc)
           (go >m (ins [<(fld f 'time) id <(fld f 'note) #(fld f 'hunks)] acc)))))
       es (go (readdir ".sb/patch") ())
       _ (log-pr es tp)
       _ (: (pf m) (? (two? m)
                      (: e <m t <>e
                         ; the psid: the name of this release's head DAG state.
                         ; a banked ref stores its tips sorted, so the sort is a no-op here
                         _ (puts ("  " + <e + "  " + sh (psid t) + "  "
                                  + show #t + " tip" + (? (1 = tally t) "" "s") + "\n"))
                         (pf >m)) ())
            (: rs (refs ()) (? (two? rs) (puts "banked:\n", pf rs) ())))
       #es)

   ; --- diff: working tree vs the recorded state, unified; answers how many differ ---
   (sb-diff _)
    (: sn (snap ())
       hunks (scan (sort (walk () (igs ()) ())) sn ())
       (pr m n)
        (? (atom? m) n
           (: h <m p <h
              ot (? !<>h "" (blob <>h))
              nt (? !<>>h "" (: t (look p) (two? t ? <>t "")))
              d (udiff (? !<>h "(none)" (p + " (recorded)"))
                       (? !<>>h "(gone)" p)
                       ot nt)
              _ (? !d () (puts d))
              (pr >m (n + 1))))
       (pr hunks 0))

   ; --- sync: union a peer nest's store. blobs + patches are immutable and
   (dirty _) #(scan (sort (walk () (igs ()) ())) (snap ()) ())
   ; one direction of the store exchange: the patches `to` lacks, walked back from the
   ; source's tips through their deps. a store holds every patch's deps, so the walk stops
   ; at a patch `to` already holds, and lays each patch after its deps and blobs, which keeps
   ; that so: the cost goes with what differs, never with the store. pat and blb get a store
   ; object by name, (1 text) | (); every one is checked against its name on the way.
   ; -> {'laid 'bad 'read 'blobs 'ok}: read the patches fetched, ok when every tip arrived whole
   (gap pat blb tips to)
    (: tp (to + "/.sb/patch/") tb (to + "/.sb/blob/")
       seen {} n {'laid 0 'bad 0 'read 0 'blobs 0 'ids ()}
       (bump k) (pin n k (1 + n k))
       (each f l) (foldl (\ a x (: r (f x) (a && r))) 1 l)   ; every one runs: && would stop at a miss
       (blob1 h)
        (? (!h || two? (stat (tb + h))) 1
           (: t (blb h)
              (? (atom? t) (say err ("sb: cannot fetch blob " + sh h + "\n"), 0)
                 (sha256 <>t != h) (say err ("sb: bad address " + h + "\n"), bump 'bad, 0)
                 (lay (tb + h) <>t) (bump 'blobs, 1)
                 0)))
       (one id)
        (: r0 (peep seen id ())
           (? (r0 != ()) r0
              (: r (? !(sb-hex? id) (sb-refuse id, bump 'bad, 0)
                      (two? (stat (tp + id))) 1
                      (: t (pat id) _ (bump 'read)
                         f (? (two? t && sha256 <>t = id) (readform <>t))
                         (? (atom? t) (say err ("sb: cannot fetch patch " + sh id + "\n"), 0)
                            (sha256 <>t != id) (say err ("sb: bad address " + id + "\n"), bump 'bad, 0)
                            !(sb-sound? f) (sb-refuse id, bump 'bad, 0)
                            (: dk (each one (fld f 'deps))
                               bk (each blob1 (catmap (h \ [(sd-h <>h) (sd-h <>>h)]) (fld f 'hunks)))
                               (? (dk && bk && lay (tp + id) <>t) (bump 'laid, pin n 'ids (id . n 'ids), 1) 0)))))
                 _ (pin seen id r)
                 r)))
       _ (pin n 'ok (each one (? (sb-all? sb-hex? tips) tips ())))
       ; to's store tips: what was laid joins them, and whatever a laid patch depends on leaves
       _ (? (0 < n 'laid)
            (: deps (catmap (i \ fld (form (tp + i)) 'deps) (n 'ids))
               old (form (to + "/.sb/tips"))
               (lay (to + "/.sb/tips") (show (sort (filter (t \ !(elem t deps)) ((two? old ? old ()) + n 'ids)))))))
       n)
   ; a nest's patches and blobs by name, (1 text) | ()
   (dir-pat d) (\ id (look (d + "/.sb/patch/" + id)))
   (dir-blb d) (\ h (look (d + "/.sb/blob/" + h)))
   ; bring this nest to the state a given patch set implies
   (tell cfs)
    (: (go m n) (? (atom? m) n
          (: e <m p <e k <>e
             _ (say (k @ 0 out err)
                    ("sb: " + (k @ 0 "merged " "CONFLICT in ") + p + " -- " + <>>e + "\n"))
             (go >m (k @ 0 n (n + 1)))))
       (go cfs 0))
   ; the tree moved to realize the set want closes over, which becomes the head: (n nf cfs)
   (settle want)
    (: was (psid (head ())) d (dv-derive want)
       oldsnap (snap ())
       sn (d 'snap) cf (d 'cf)
       newsnap (map (p \ (: e (sn p) [p <e <>e])) (sort (keys sn)))
       ix (: (go m t) (two? m ? (pin t <<m <><m, go >m t) t))
       op (ix oldsnap {})
       cfs (filter (e \ 0 < <>e || op <e != <(sn <e))
                   (map (p \ (: e (cf p) [p <e <>e])) (sort (keys cf))))
       _ (head-to (d 'tips))
       _ (lay ".sb/snap" (show newsnap))
       _ (dv-write d)
       _ (dv-prune (d 'tips) was)
       nf (mater oldsnap newsnap)
       [(dv-count d) nf cfs])
   (derive-snap ids)                                          ; the full fold -> (snap conflicts)
    (: d (dv-derive1 ids (dv-new 0))
       sn (d 'snap) cf (d 'cf)
       [(map (p \ (: e (sn p) [p <e <>e])) (sort (keys sn)))
        (map (p \ (: e (cf p) [p <e <>e])) (sort (keys cf)))])

   ; --- the derive. a set's tree is the fold of its patches ordered by (depth, id), depth the
   ;     longest dep chain beneath a patch, and each path folds on its own. the key is the
   ;     patch's own, so a set derived once is a base the rest folds onto: a path the rest
   ;     writes after the base's last writer of it takes the rest's hunks, and a path it writes
   ;     under one folds again from its writers. .sb/derive/PSID keeps a derived set: its tips,
   ;     members and depths, snap, conflicts, and each path's last writer and writers, a line
   ;     apiece; settle keeps the head's, the one before it and the newest four banks' ---
   (dv-new _) {'tips () 'n 0 'raw "" 'probes 0 'mem {} 'add {} 'snap {} 'cf {} 'last {} 'hist {} 'new {} 'refold 0}
   (dv-num s) (foldl (\ a i (a * 10 + s i - 48)) 0 ^#s)
   (dv-path tp) (".sb/derive/" + psid tp)
   (dv-key< a b) (<a < <b || (<a = <b && a 1 < b 1))
   (dv-count d) (d 'n + #(keys (d 'add)))
   (dv-hist d p) (peep (d 'new) p () + filter (w \ 0 < #w) (cite 'kore 'usplit 32 (peep (d 'hist) p "")))
   (dv-cut l) (: (go i acc) (: k (fsub l "\t" i) (? (k < 0) (rev ((snip l i #l) . acc)) (go (k + 1) ((snip l i k) . acc))))
                 (go 0 ()))
   ; a member's depth, -1 for none: the raw block is searched until searching costs more than
   ; reading it whole
   (dv-dep d id)
    (: m (d 'mem) v (peep m id -1)
       (? (0 <= v) v
          (d 'probes < 64)
           (: _ (pin d 'probes (d 'probes + 1)) r (d 'raw) k (fsub r (id + " ") 0)
              (? (k < 0) -1 (: e (fsub r "\n" k) (dv-num (snip r (k + 65) e)))))
          (d 'probes = 64)
           (: _ (pin d 'probes 65)
              _ (map (l \ (? (65 < #l) (pin m (snip l 0 64) (dv-num (snip l 65 #l))))) (lines (d 'raw)))
              (peep m id -1))
          -1))
   (dv-read p)
    (: t (look p) x (? (two? t) <>t "") k (fsub x "\nM\n" 0)
       (? (k < 0) ()
          (: d (dv-new 0) sn (d 'snap) cf (d 'cf) la (d 'last) hi (d 'hist)
             _ (pin d 'raw (snip x (k + 3) #x))
             _ (map (l \ (? (#l < 3) ()
                           (: v (dv-cut l)
                              (l 0 @ 119 (pin hi (v 1) (v 2))                              ; w
                                     116 (pin d 'tips ((v 1) . d 'tips))                   ; t
                                     115 (pin sn (v 1) [(v 2) (v 3)])                      ; s
                                     99 (pin cf (v 1) [(dv-num (v 2)) (v 3)])              ; c
                                     108 (pin la (v 1) [(dv-num (v 2)) (v 3)])             ; l
                                     110 (pin d 'n (dv-num (v 1)))                         ; n
                                     ()))))
                    (lines (snip x 0 (k + 1))))
             d)))
   (dv-write d)
    (: (kv f t) (catmap (k \ f k (t k)) (keys t))
       hi (d 'hist) nu (d 'new)
       s (cats (["n\t" (show (dv-count d)) "\n"]
                + catmap (i \ ["t\t" i "\n"]) (d 'tips)
                + kv (\ k v ["s\t" k "\t" <v "\t" <>v "\n"]) (d 'snap)
                + kv (\ k v ["c\t" k "\t" (show <v) "\t" <>v "\n"]) (d 'cf)
                + kv (\ k v ["l\t" k "\t" (show <v) "\t" <>v "\n"]) (d 'last)
                + catmap (p \ (: ws (peep nu p ()) o (peep hi p "")
                                ["w\t" p "\t" (cats (catmap (i \ [i " "]) ws)) o "\n"]))
                         (keys (d 'last))
                + ["M\n" (d 'raw)]
                + kv (\ k v [k " " (show v) "\n"]) (d 'add)))
       p (dv-path (d 'tips))
       _ (mkdir ".sb/derive" 493)
       (lay (p + ".new") s && !(nom? (rename (p + ".new") p))))
   (dv-prune tp was)                                          ; keep the head's, the last one's, four banks'
    (: rs (sort (map (r \ [<>>r <>r]) (refs ())))            ; (time tips), oldest first
       ks ((psid tp) . was . map (r \ psid <>r) (drop (max 0 (#rs - 4)) rs))
       (map (f \ (? (#f = 64 && !(elem f ks)) (unlink (".sb/derive/" + f)) ()))
            (readdir ".sb/derive")))
   ; the bases to try: the head's, then any other kept, at most two
   (dv-bases _)
    (: hp (psid (head ()))
       fs (filter (f \ #f = 64) (readdir ".sb/derive"))
       (take 2 ((elem hp fs ? [hp] ()) + filter (f \ f != hp) fs)))
   (dv-derive want)
    (: (go bs) (? (atom? bs) (dv-derive1 want (dv-new 0))
                  (: b (dv-read (".sb/derive/" + <bs))
                     d (? (tablet? b) (dv-derive1 want b))
                     (tablet? d ? d (go >bs))))
       (go (dv-bases ())))
   ; want's set folded onto base: () when base is not within it
   (dv-derive1 want base)
    (: fs {} got {} hit {}
       ; the walk: from want down the deps, stopping at the base and at what it has read
       _ (:- (go want) (go st) (? (atom? st) ()
             (: id <st
                (? (0 <= dv-dep base id) (pin hit id 1, go >st)
                   (peep got id 0) (go >st)
                   !(sb-hex? id) (sb-refuse id, go >st)
                   (: f (form (".sb/patch/" + id))
                      (? (two? f && !(sb-sound? f)) (sb-refuse id, go >st)
                         (pin got id 1, pin fs id f, go (fld f 'deps + >st))))))))
       (? !(sb-all? (t \ peep hit t 0) (base 'tips)) ()
          (: xs (keys got)
             ; depths, deps before dependents; a patch over one never read never readies
             n {} kids {} dp {}
             _ (map (x \ (: ds (fld (fs x) 'deps)
                           _ (pin n x (? (sb-all? (y \ peep got y 0 || 0 <= dv-dep base y) ds)
                                         #(filter (y \ peep got y 0) ds) -1))
                           _ (pin dp x (foldl (\ a y (max a (dv-dep base y + 1))) 0 ds))
                           (map (y \ (? (peep got y 0) (pin kids y (x . peep kids y ())) ())) ds)))
                    xs)
             order (:- (go (filter (x \ n x = 0) xs) ()) (go q acc)
                       (? (atom? q) (sort acc)
                          (: x <q
                             nq (foldl (\ a k (: _ (pin dp k (max (dp k) (dp x + 1)))
                                                 _ (pin n k (n k - 1))
                                                 (n k = 0 ? (k . a) a)))
                                       >q (peep kids x ()))
                             (go nq ([(dp x) x] . acc)))))
             _ (dv-fold base order fs)
             depd {}
             _ (map (k \ map (y \ pin depd y 1) (fld (fs (k 1)) 'deps)) order)
             _ (pin base 'tips (filter (t \ !(peep depd t 0)) (base 'tips + map (k \ k 1) order)))
             base)))
   ; one hunk folded onto a path: the expected base or a convergent write lands, a diverged one merges
   (dv-step sn cf p old nw pid)
    (: cur (peep sn p ()) curh (two? cur ? <cur) curpid (two? cur ? <>cur)
       (? (curh = old || nw = curh)
          (pull cf p 0, (!nw ? (pull sn p 0) (pin sn p [nw pid])))  ; a later patch can settle an earlier clash
          (: mm (mend old curh nw curpid pid)
             (pin sn p [<mm pid], pin cf p [<>mm <>>mm]))))
   ; order folded onto d, whose paths the order writes under their last writer fold again whole
   (dv-fold d order fs)
    (: sn (d 'snap) cf (d 'cf) la (d 'last) nu (d 'new) q {}
       _ (:- (go order) (go m) (? (two? m)
             (: k <m
                _ (:- (h1 (fld (fs (k 1)) 'hunks)) (h1 hs) (? (two? hs)
                      (: lw (peep la <<hs ()) _ (? (two? lw && dv-key< k lw) (pin q <<hs 1)) (h1 >hs))))
                (go >m))))
       _ (:- (go order) (go m) (? (two? m)
             (: k <m pid (k 1)
                _ (pin (d 'mem) pid <k) _ (pin (d 'add) pid <k)
                _ (:- (h1 (fld (fs pid) 'hunks)) (h1 hs) (? (two? hs)
                      (: h <hs p <h
                         _ (pin nu p (pid . peep nu p ()))
                         _ (? (peep q p 0) () (dv-step sn cf p <>h <>>h pid))
                         _ (pin la p k)
                         (h1 >hs))))
                (go >m))))
       _ (pin d 'refold #(keys q))
       (map (p \ (: ks (sort (map (i \ [(dv-dep d i) i]) (dv-hist d p)))
                    _ (pull sn p 0) _ (pull cf p 0)
                    _ (pin la p (ks (#ks - 1)))
                    (:- (go ks) (go m) (? (two? m)
                          (: i (<m 1) f (peep fs i ()) g (? (two? f) f (form (".sb/patch/" + i)))
                             h <(filter (e \ <e = p) (fld g 'hunks))
                             _ (dv-step sn cf p <>h <>>h i)
                             (go >m))))))
            (keys q)))
   (bin? s) (: n #s (go i) (? (n <= i) 0 (s i = 0) 1 (go (i + 1))) (go 0))
   (sh h) (? h (snip h 0 12) "()")
   (bl h) (: k (sd-h h) (? !k '(1 "") (sb-hex? k) (look (".sb/blob/" + k))))  ; (1 text) | () -- presence, not net
   (mend old curh nw curpid pid)
    (: bw (bl old) ow (bl curh) tw (bl nw)
       bh (sd-h old) oh (sd-h curh) th (sd-h nw)
       ; the mode merges by itself: the incoming side's when it moved it, else ours
       x (? (sd-x? nw = sd-x? old) (sd-x? curh) (sd-x? nw))
       (? !nw [curh 1 ("kept the edit -- " + sh pid + " deletes what " + sh curpid + " wrote")]
          !curh [nw 1 ("kept the edit -- " + sh pid + " writes what was deleted here")]
          (oh = th || th = bh) [(sd oh x) 0 "both sides kept"]     ; the texts agree, or theirs is the base's
          (oh = bh) [(sd th x) 0 "both sides kept"]                ; ours is the base's
          !(two? ow && two? tw)
             [curh 1 ("a blob is missing, cannot merge -- kept " + sh curh)]
          (: bt (? (two? bw) <>bw "") ot <>ow tt <>tw
             (? (bin? bt || bin? ot || bin? tt)
                [curh 1 ("binary, cannot merge -- kept " + sh curh + ", incoming " + sh nw)]
                (: r (diff3 bt ot tt ("recorded (" + sh curpid + ")")
                                      ("incoming (" + sh pid + ")"))
                   mh (keep <r) n <>r
                   (n @ 0 [(sd mh x) 0 "both sides kept"]
                    [(sd mh x) n (show n + " region" + (? (1 = n) "" "s") + " left in markers")]))))))
   (mkparents p)                                              ; mkdir every "/"-prefix of a nested path
    (:- (go 0) (go i) (i < #p ? (p i @ 47 (mkdir (snip p 0 i) 493), go (i + 1))))
   (mater oldsnap newsnap)                                    ; make the tree match newsnap; #files touched
    (: np {}
       _ (: (go m) (two? m ? (pin np <<m <><m, go >m)) (go newsnap))
       w (: (go m n) (? (atom? m) n
              (: e <m p <e ch <>e
                 ok (sb-rel? p && sb-oid? ch && string? ch && !(sb-link? p))
                 bh (sd-h ch) x (sd-x? ch)
                 bl (? ok (look (".sb/blob/" + bh)))   ; presence, not net: an empty blob is real
                 cur (? ok (look p)) curh (? (two? cur) (sha256 <>cur) ())
                 (? !ok (say err ("sb: will not write " + show p + " from " + show ch + "\n"), go >m n)
                    (atom? bl) (say err ("sb: missing blob " + bh + "\n"), go >m n)
                    (curh = bh) (? (x = sd-exe? p) (go >m n) (sd-chmod p x, go >m (n + 1)))
                    (mkparents p, lay p <>bl, sd-chmod p x, go >m (n + 1)))))
            (go newsnap 0))
       d (: (go m n) (? !(two? m) n
              (: p <<m (? (peep np p 0) (go >m n)
                          (!(sb-rel? p) || sb-link? p) (say err ("sb: will not unlink " + show p + "\n"), go >m n)
                          (unlink p, go >m (n + 1)))))
            (go oldsnap 0))
       (w + d))
   ; --- the http remote: pull only
   (pull-http base)
    (: tt (http-fetch base "/tips")
       (? (atom? tt) (say err ("sb: no store at " + base + " (no /tips)\n"), ())
          (: tips (readform <>tt)
             (? (atom? tips) (say err ("sb: " + base + " has no tips\n"), ())
                (: g (gap (\ id (http-fetch base ("/patch/" + id))) (\ h (http-fetch base ("/blob/" + h))) tips ".")
                   rt (http-fetch base "/refs")             ; the refs ride along
                   theirs (two? rt ? (readform <>rt))
                   ru (refadd (refs ()) theirs 1)
                   _ (two? <ru ? (lay ".sb/refs" (show <ru)))
                   hh (http-fetch base "/head")
                   rh (two? hh ? (readform <>hh) tips)
                   [(g 'ok) (g 'laid) (g 'blobs) <>ru (sb-all? sb-hex? rh ? rh tips)])))))

   (sync-url peer keep)
    (mk (),
     (? (!keep && 0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: base (peer @ (s + "/") s peer)        ; one trailing slash, ours to add
           r (pull-http base)
           (? (atom? r) 0
              keep (: _ (puts ("sb: deposited -- " + show (r 1) + " patches in, " + show (r 2) + " blobs\n")) (? <r 1 0))
              (: st (settle (head () + r 4))
                 nleft (tell <>>st)
                 nref <>>>r
                 _ (puts ("sb: pulled -- " + show <st + " patches (" + show <>r
                          + " in), " + show <>>r + " blobs, " + show <>st + " files here"
                          + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                          + (nref @ 0 "" (", " + show nref + " ref clash")) + "\n"))
                 _ (? <r () (say err "sb: some objects did not arrive -- the pull is INCOMPLETE\n"))
                 _ (say err "sb: pulled only -- an http remote takes no push\n")
                 (? (<r && (0 = nleft) && (0 = nref)) <st 0))))))

   ; sync is the exchange, and an exchange has two ends: pull what the peer has
   ; that we lack, push what we have that it lacks, then settle both nests on the
   ; union of their heads. the derive is a pure function of the patch set, so two
   ; nests over one union land on the same snap -- after a sync the trees are
   ; identical, which is the whole "distribution == cloning" claim made good. the
   ; peer's half needs its tree clean and writable; when it is not we still pull
   ; (always safe) and say so, leaving the peer's store untouched rather than
   ; half-fed. --keep only deposits: both stores fill and neither head moves, so a
   ; hub can hold work it has not taken
   (sb-sync peer) (sync-with peer 0)
   (sb-deposit peer) (sync-with peer 1)
   (sync-with peer keep)
    (? (url? peer) (sync-url peer keep)
    (mk (),
     (? (!keep && 0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: home (cwd 0)
           pd (chdir peer @ c (c ? -1 (: _ (mk ()) d (? keep 0 (dirty ())) (chdir home, d))))
           (? (pd < 0) (say err ("sb: cannot reach " + peer + "\n"), 0)
              (held peer (_ \ sync2 peer keep pd home)))))))
   (sync2 peer keep pd home)
              (: gi (gap (dir-pat peer) (dir-blb peer) (form (peer + "/.sb/tips")) ".")
                 ; the push: only onto a clean peer, and only if every write lands
                 go (pd @ 0 (gap (dir-pat ".") (dir-blb ".") (tips ()) peer) {'laid 0 'bad 0 'blobs 0})
                 pushed (0 = pd && 0 = go 'bad)
                 ; the refs travel too -- a release is only "the unit you
                 ; propagate" if the NAME reaches the other nest with it
                 theirs (form (peer + "/.sb/refs"))
                 ru (refadd (refs ()) theirs 1)
                 _ (two? <ru ? (lay ".sb/refs" (show <ru)))
                 _ (? !pushed ()
                      (: pu (refadd theirs (refs ()) ())
                         (? (two? <pu) (lay (peer + "/.sb/refs") (show <pu)) ())))
                 (? keep
                    (: _ (puts ("sb: deposited -- " + show (gi 'laid) + " patches in, " + show (go 'laid) + " out, "
                                + show (gi 'blobs + go 'blobs) + " blobs\n"))
                       (pushed ? 1 0))
                    (sync3 peer pd home gi go pushed ru)))
   ; both heads move to their union, and both trees to its derive
   (sync3 peer pd home gi go pushed ru)
              (: u (head () + head-in peer)
                 st (settle u)
                 nleft (tell <>>st)
                 nref <>ru
                 pst (? !pushed ()                             ; settle the far end too
                        (: c (chdir peer) r (settle u) _ (chdir home) r))
                 _ (puts ("sb: synced -- " + show <st + " patches ("
                          + show (gi 'laid) + " in, " + show (go 'laid) + " out), "
                          + show (gi 'blobs + go 'blobs) + " blobs, " + show <>st + " files here"
                          + (? (two? pst) (", " + show <>pst + " files there") "")
                          + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                          + (nref @ 0 "" (", " + show nref + " ref clash"
                                              + (nref @ 1 "" "es"))) + "\n"))
                 _ (? pushed ()
                      (say err ("sb: pulled only -- the peer "
                                + (? (0 < pd) "has unrecorded changes" "would not take the write")
                                + "; run sync from its side to finish\n")))
                 _ (nleft @ 0 ()
                    (say err "sb: settle the flagged paths, then record\n"))
                 _ (nref @ 0 ()
                    (say err "sb: a banked name is immutable\n"))
                 (? (pushed && 0 = nleft && 0 = nref) <st 0))

   ; --- apply: realize a dep-consistent subset of the store into the working
   (idpfx pfx)                                                   ; one patch from a prefix | ()
    (: n #pfx
       hits (filter (i \ #i = 64 && snip i 0 n = pfx) (readdir ".sb/patch"))
       (? (1 = #hits) <hits
          (atom? hits) (say err ("sb: no ref or patch matches " + pfx + "\n"), ())
          (say err ("sb: " + show #hits + " patches match " + pfx + "\n"), ())))
   (idsof a)                                                     ; a ref -> its whole tip set;
    (refof a @ r (? (two? r) r
                    (a = "head") (head ())
                    (sb-hex? a && !(two? (stat (".sb/patch/" + a)))) (psid-ids a)
                    (idpfx a @ i (i ? [i]))))
   ; a set by its psid: a ref's, the head's, a kept derive's, or one a head stood at
   (psid-ids s)
    (: r (filter (e \ psid <>e = s) (refs ()))
       (? (two? r) <><r
          (s = psid (head ())) (head ())
          (: d (dv-read (".sb/derive/" + s))
             (? (tablet? d) (d 'tips)
                (two? (stat (".sb/sets/" + s))) (form (".sb/sets/" + s))
                (say err ("sb: no set " + s + " here\n"), ())))))
   ; --- psid: the name of a set -- the head's, or a named one's; paths: the paths two sets'
   ;     trees differ on; within: whether one set lies inside another ---
   (sb-psid args)
    (: ts (? (two? args) (idsof <args) (head ()))
       (? (two? args && atom? ts) 0 (: _ (puts (psid ts + "\n")) 1)))
   ; a named set -> [ids], () when the name resolves to none (it said so); the empty set is a set
   (setof a) (: l (idsof a) (? (two? l || a = "head" || a = psid ()) [l]))
   (sb-paths a b)                                             ; -> exit status
    (: x (setof a) y (setof b)
       (? (atom? x || atom? y) 1
          (: sa ((dv-derive <x) 'snap) sb ((dv-derive <y) 'snap) u {}
             _ (map (p \ pin u p 1) (keys sa + keys sb))
             ps (sort (filter (p \ <(sa p) != <(sb p)) (keys u)))
             _ (map (p \ puts (p + "\n")) ps)
             0)))
   ; a set's stamp: its newest tip's time in seconds, which orders two builds of a tree
   (sb-stamp args)
    (: x (setof (two? args ? <args "head"))
       (? (two? x) (: _ (puts (show (foldl (\ a i (: f (patch i) (? (two? f) (max a (<(fld f 'time) // 1000)) a))) 0 <x) + "\n")) 1)))
   (sb-within a b) (: x (setof a) y (setof b) (? (two? x && two? y) (: d (dv-derive <y) (sb-all? (t \ 0 <= dv-dep d t) <x))))
   (sb-apply args)
    (mk (),
     (? (0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: all (readdir ".sb/patch")
           want (: (go m acc) (atom? m ? acc (: l (idsof <m) (two? l ? (go >m (acc + l)))))
                   (go args ()))
           (? (two? args && atom? want) 0                 ; a prefix failed to resolve; it said so
              (: st (settle (two? args ? want all))
                 nleft (tell <>>st)
                 _ (puts ("sb: applied " + show <st + " of " + show #all
                          + " patches, " + show <>st + " files updated"
                          + (? (<st = #all) " (the whole store)" "")
                          + (? (0 = nleft) "" (", " + show nleft + " conflicted")) + "\n"))
                 _ (? (0 = nleft) ()
                      (say err "sb: settle the flagged paths, then record -- the resolution is a patch\n"))
                 (? (0 = nleft) <st 0))))))

   ; --- take: grow the head by a set -- a ref, or patches by prefix, their deps with them --
   ;     and lay the tree it realizes. what a hub does to land work it holds ---
   (sb-take args)
    (mk (),
     (? (0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: want (: (go m acc) (atom? m ? acc (: l (idsof <m) (two? l ? (go >m (acc + l)))))
                   (go args ()))
           (? (atom? want) 0                               ; a name failed to resolve; it said so
              (: st (settle (head () + want))
                 nleft (tell <>>st)
                 _ (puts ("sb: took " + show #want + " tip" + (? (1 = #want) "" "s") + ", the head now "
                          + sh (psid (head ())) + ", " + show <>st + " files updated"
                          + (? (0 = nleft) "" (", " + show nleft + " conflicted")) + "\n"))
                 (? (0 = nleft) 1 0))))))
   ; --- ls: the head's paths, a line each ---
   (sb-ls long) (: sn (snap ()) _ (map (e \ puts ((? long (<>e + "\t") "") + <e + "\n")) sn) #sn)   ; -l: side, tab, path

   ; --- bank: freeze the current head under a NAME -- an immutable release, the
   (refs _) (form ".sb/refs")                                  ; ((name (id..) time)..) | ()
   (refof nm) (refof-in (refs ()) nm)
   ; --- the ref exchange. a ref is a single file, not a content-addressed one,
   (refadd base extra loud)                                     ; loud: only one side tells it
    (: (go m acc n)
        (? (atom? m) [(sort acc) n]
           (: e <m mine (refof-in base <e)
              (? (atom? mine) (go >m (e . acc) n)               ; theirs alone: take it
                 (show mine = show <>e) (go >m acc n)          ; the same head: already ours
                 ((? loud (say err ("sb: REF CLASH on " + <e
                                    + " -- banked to different heads\n")) ()),
                  go >m acc (n + 1)))))
       (go (? (sb-all? sb-ref? extra) extra ()) base 0))              ; a malformed file is taken whole or not at all
   ; a ref off the wire: a printable name over a set of patch ids
   (sb-ref? e) (two? e && string? <e && 0 < #<e && !(sb-ctl? <e) && two? <>e && sb-all? sb-hex? <>e)
   (refof-in rs nm) (: (go m) (? (atom? m) () (<<m = nm) <><m (go >m)) (go rs))

   (sb-bank args)
    (: _ (mk ())
       nm (? (two? args) <args "")
       (? (0 >= #nm)
          (say err "sb: bank needs a name\n", 0)
          (0 < dirty ())
          (say err "sb: working tree has changes; record or revert first\n", 0)
          (: tp (sort (head ()))
             (? (atom? tp) (say err "sb: nothing recorded to bank\n", 0)
                (: old (refof nm)
                   (? (two? old && show old != show tp)
                      (say err ("sb: " + nm + " is already banked at a different head"
                                + " -- a banked name is immutable\n"), 0)
                      (two? old) (puts ("sb: " + nm + " is already banked\n"), 1)
                      (lay ".sb/refs" (show (sort ([nm tp (clock 0)] . refs ()))),
                       puts ("sb: banked " + nm + " at " + show #tp + " tip"
                             + (? (1 = tally tp) "" "s") + " -- " + sh <tp + "\n"),
                       1)))))))

   ; --- undo: add the inverse patch. removal is growth here, never deletion --
   (sb-undo args)
    (mk (),
     (? (0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: id (idpfx (two? args ? <args ""))
           (? !id 0                                          ; idpfx already said why
              (: hs (fld (patch id) 'hunks)
                 ix (: (go m t) (two? m ? (pin t <<m <><m, go >m t) t))
                 sn (ix (snap ()) {})
                 nc (:- (go hs 0) (go m n)
                        (atom? m ? n
                           (: h <m p <h pold <>h pnew <>>h
                              cur (sn p)             ; the index maps path -> side directly
                              (? (sb-link? p)
                                 (say err $ "sb: CONFLICT on " + p + " -- it lies through a link; kept what is there\n",
                                  go >m (n + 1))
                                 (cur = pnew)                ; P still owns the path: a clean lift
                                 ((? !pold (unlink p)
                                     (mkparents p, lay p (blob pold), sd-chmod p (sd-x? pold))),
                                  go >m n)
                                 ; it moved on -- merge P's write out of what is there now
                                 (: bw (bl pnew) ow (bl cur) tw (bl pold)
                                    bh (sd-h pnew) oh (sd-h cur) th (sd-h pold)
                                    x (? (sd-x? pnew = sd-x? cur) (sd-x? pold) (sd-x? cur))
                                    (? (pold && cur && th = bh)     ; P moved only the mode
                                       (sd-chmod p x, go >m n)
                                       (pold && cur && oh = bh)     ; only the mode moved on since
                                       (lay p (blob pold), sd-chmod p x, go >m n)
                                       !(two? bw && two? ow && two? tw)
                                       (say err $ "sb: CONFLICT on " + p + " -- a birth or death moved on; kept what is there\n",
                                        go >m (n + 1))
                                       (bin? <>bw || bin? <>ow || bin? <>tw)
                                       (say err $ "sb: CONFLICT on " + p + " -- binary, cannot merge; kept what is there\n",
                                        go >m (n + 1))
                                       (: r (diff3 <>bw <>ow <>tw "here now" ("undone " + sh id))
                                          _ (lay p <r, sd-chmod p x)
                                          k <>r
                                          _ (? (0 = k) (puts ("sb: merged " + p + " -- the later edits kept\n"))
                                               (say err ("sb: CONFLICT in " + p + " -- " + show k
                                                         + " region" + (? (1 = k) "" "s") + " left in markers\n")))
                                          (go >m (n + k)))))))))
                 _ (? (0 = nc) ()
                      (say err "sb: settle the flagged paths before recording the undo\n"))
                 (? (0 < nc) 0
                    (: r (sb-record ((? (two? >args) <>args "undo ") + sh id))
                       (? r 1 (puts "sb: nothing to undo -- that patch is already lifted\n", 0))))))))))

; --- ledgers: a named value that moves only by compare-and-swap. a banked name never moves;
;     a ledger is the one thing here that does, and even it only grows: .sb/ledger/NAME is
;     a line per entry, `hash time who`, the last one standing, each hash a blob in the store.
;     a ledger stays in its nest -- sync carries patches, blobs and refs, never a ledger --
;     so sessions that share one name the same nest (sb -C DIR). ---
(:
   (lg-path nm) (".sb/ledger/" + nm)
   (lg-lock? nm) (: n #nm (4 < n && snip nm (n - 5) n = ".lock"))
   (lg-name? nm) (sb-rel? nm && !(lg-lock? nm))
   (lg-lines nm) (: t (look (lg-path nm)) (two? t ? (filter (\ l (0 < #l)) (lines <>t)) ()))
   (lg-now nm) (: l (lg-lines nm) (? (two? l) <(words (l (#l - 1))) "none"))
   ; the lock is a directory beside the ledger, made atomically, holding its holder's pid.
   ; a dead holder's is taken; a live one is waited on, tries times 20 ms
   (lg-lock nm tries)
    (: d (lg-path nm + ".lock")
       (? ((mkdir d 448) = ()) (lay (d + "/pid") (show (getpid 0)))
          (: t (look (d + "/pid")) p (? (two? t) (lg-num <>t) 0)
             (? (0 < p && nom? (still p 0)) (: _ (unlink (d + "/pid")) _ (rmdir d) (lg-lock nm tries))
                (tries <= 0) 0
                (: _ (rest 20) (lg-lock nm (tries - 1)))))))
   (lg-num s) (: (go i a) (? (i < #s && 48 <= s i <= 57) (go (i + 1) (a * 10 + s i - 48)) a) (go 0 0))
   (lg-unlock nm) (: d (lg-path nm + ".lock") _ (unlink (d + "/pid")) (rmdir d))
   (lg-who _) (: w (getenv "SB_WHO") u (getenv "USER") (? (string? w && 0 < #w) w (string? u) u "?"))
   ; NAME moves to FILE's text iff it stands at WAS ("none" for a new ledger) -> 1, else 0.
   ; the new hash is printed either way it lands, even when the text was already there
   (lg-swap nm was file)
    (: t (? (file = "-") [1 (slurp in + "")] (look file))
       (? !(two? t) (say err ("sb: cannot read " + file + "\n"), 0)
          (: _ (mk ()) _ (mkparents (lg-path nm))
             (? !(lg-lock nm 250) (say err ("sb: ledger " + nm + " is held by another writer\n"), 0)
                (: cur (lg-now nm)
                   r (? (cur != was) (say err ("sb: ledger " + nm + " stands at " + cur + ", not " + was + "\n"), 0)
                        (: h (keep <>t)
                           _ (? (h = cur) 0
                                (lay (lg-path nm)
                                     (foldl (\ a l (a + l + "\n")) "" (lg-lines nm)
                                      + h + " " + show (clock 0 // 1000) + " " + lg-who () + "\n")))
                           (puts (h + "\n"), 1)))
                   _ (lg-unlock nm)
                   r)))))
   ; every ledger under dir, by name
   (lg-names dir pre)
    (: es (readdir dir)
       (? !(two? es) ()
          (catmap (\ e (: p (dir + "/" + e) st (stat p)
                          (? (lg-lock? e) ()
                             (two? st && (61440 & <>>st) = 16384) (lg-names p (pre + e + "/"))
                             [(pre + e)])))
                  (sort es))))
   ; the verb: no NAME lists them; NAME says what it holds; --id its hash (or none); --log
   ; every entry; --was OLD FILE moves it. 1 when it took, 0 when not, 2 when malformed
   (sb-ledger args)
    (: nm (? (two? args) <args "") r (? (two? args) >args ())
       (? (#nm = 0) (: _ (map (\ n (puts (n + " " + lg-now n + "\n"))) (lg-names ".sb/ledger" "")) 1)
          !(lg-name? nm) (say err ("sb: a ledger's name is a relative path: " + nm + "\n"), 0)
          (atom? r) (: c (lg-now nm) b (? (c = "none") () (blob c))
                       (? (string? b) (: _ (say out b) 1) (say err ("sb: no ledger " + nm + "\n"), 0)))
          (<r = "--id") (: _ (puts (lg-now nm + "\n")) 1)
          (<r = "--log") (: _ (map (\ l (puts (l + "\n"))) (lg-lines nm)) 1)
          (<r = "--was" && #r = 3) (lg-swap nm <>r <>>r)
          2)))                                             ; malformed: the dispatcher says the usage

; --- ssh: sync with a nest on another box. the far side is `sb serve DIR` on stdio, each
;     word framed as a decimal length, a newline and the bytes. the near side drives: it
;     learns what the far store lacks by asking, a level of its tip walk a round, and the
;     far side walks its own tips down to what the near store holds, so the cost goes with
;     what differs. the far nest is held for the whole talk ---
(:
   (ssh? p) (6 < #p && snip p 0 6 = "ssh://")
   (ssh-env k d) (: v (getenv k) (? (string? v && 0 < #v) v d))
   (ssh-words s) (filter (w \ 0 < #w) (cite 'kore 'usplit 32 s))
   ; a far path the far shell reads as one word
   (ssh-pc? c) (? (97 <= c <= 122) 1 (65 <= c <= 90) 1 (48 <= c <= 57) 1 (elem c [47 46 95 45 126 43 44 61 64 58]) 1 0)
   (ssh-path? s) (: (go i) (? (#s <= i) 1 (ssh-pc? (s i)) (go (i + 1)) 0) (0 < #s && go 0))
   ; ssh://[USER@]HOST[:PORT]/PATH -> the argv of the far `sb serve PATH` | (); /~/ is the far home.
   ; SB_SSH is the ssh words (ssh -T), SB_LOVE the far binary (love)
   (ssh-argv p)
    (: r (snip p 6 #p) k (fsub r "/" 0)
       (? (box-peer? p) (box-argv p)
          (k <= 0) ()
          (: hp (snip r 0 k) pt (snip r k #r)
             path (? (3 <= #pt && snip pt 0 3 = "/~/") (snip pt 1 #pt) pt)
             c (fsub hp ":" 0)
             (? !(ssh-path? path) ()
                ((ssh-words (ssh-env "SB_SSH" "ssh -T"))
                 + (? (c < 0) [hp] ["-p" (snip hp (c + 1) #hp) (snip hp 0 c)])
                 + [(ssh-env "SB_LOVE" "love") "sb" "serve" path])))))
   ; NAME@BOX: the nest NAME that BOX's door serves (love bee --door), BOX reached as bee's
   ; ~/.love/etc/bee/boxes says, a line `BOX HOST [LOVE]`
   (box-peer? p) (: k (fsub p "@" 0) (0 < k && k < #p - 1 && fsub p "/" 0 < 0 && fsub p ":" 0 < 0))
   (box-argv p)
    (: k (fsub p "@" 0) nm (snip p 0 k) bx (snip p (k + 1) #p)
       t (look (ssh-env "HOME" "/" + "/.love/etc/bee/boxes"))
       w (: (go m) (? (atom? m) [bx] (: v (ssh-words <m) (? (two? v && <v = bx) v (go >m))))
            (go (? (two? t) (lines <>t) ())))
       (? !(ssh-path? nm) ()
          ((ssh-words (ssh-env "SB_SSH" "ssh -T"))
           + [(? (1 < #w) (w 1) bx) (? (2 < #w) (w 2) (ssh-env "SB_LOVE" "love")) "sb" "serve" ("@" + nm)])))
   ; --- the frames
   (fr-put w s) (say w (show #s + "\n" + s))
   (fr-get q)                                                 ; the next frame's text | () at the end
    (: (hd n k) (: c (see q) (? (c < 0) () (c = 10) (k ? n ()) (48 <= c <= 57 && k < 12) (hd (n * 10 + c - 48) (k + 1)) ()))
       n (hd 0 0)
       (? (charm? n) (fr-n q n) ()))
   (fr-n q n)
    (: (go k acc) (? (k <= 0) (cats (rev acc))
          (: c (see q)
             (? (c < 0) ()
                (: _ (unsee q c) s (chug q) m #s
                   (? (m <= k) (go (k - m) (s . acc))
                      (: _ (unchug q (m - k)) (go 0 ((snip s 0 k) . acc))))))))
       (? (n = 0) "" (go n ())))
   (ssh-line v l) (cats ([v] + catmap (i \ [" " i]) l))
   (ssh-form r) (? (string? r) (readform r))
   (ssh-sides f) (? (two? f && sb-sound? f) (catmap (h \ [(sd-h <>h) (sd-h <>>h)]) (fld f 'hunks)) ())
   (ssh-deps t) (: f (readform t) (? (two? f) (fld f 'deps) ()))
   ; the hashes some patch texts name, each once
   (ssh-hashes ts) (: u {} _ (map (t \ map (h \ (? (sb-hex? h) (pin u h 1) ())) (ssh-sides (readform t))) ts)
                     (sort (keys u)))
   ; --- the near side
   (ssh-open av)                                              ; {'p 'w 'q} | ()
    (: pi (pipe 0) po (pipe 0)
       p (spawnio av <pi >po -1 [>pi <po] -1 0)
       _ (close <pi) _ (close >po)
       (? (charm? p && 0 < p) {'p p 'w (fdopen >pi) 'q (fdopen <po)}
          (: _ (close >pi) _ (close <po) ())))
   (ssh-ask c s) (: _ (fr-put (c 'w) s) _ (flush (c 'w)) (fr-get (c 'q)))
   (ssh-shut c) (: _ (close (c 'w)) _ (close (c 'q)) (wait (c 'p)))
   ; ids asked in rounds of 1024 -> a 0 or 1 apiece, or 0 when the far side stops answering
   (ssh-bits c v ids)
    (: (go l acc) (? (atom? l) acc
          (: b (take 1024 l) r (ssh-ask c (ssh-line v b))
             (? (string? r && #r = #b) (go (drop 1024 l) (acc + map (i \ (? (r i = 49) 1 0)) ^#b)) 0)))
       (go ids ()))
   ; our patches the far store lacks, and the ones it holds where the walk met it -> (lacks
   ; holds) | 0. a level of the walk a round: work far ahead costs rounds, never a list of all
   (ssh-lacks c)
    (: seen {}
       (deps i) (: f (form (".sb/patch/" + i)) (? (two? f) (fld f 'deps) ()))
       (go f lk hd)
        (? (atom? f) [lk hd]
           (: bs (ssh-bits c "has" f)
              (? (charm? bs) 0
                 (: (pass f bs nf lk hd)
                     (? (atom? f) (go nf lk hd)
                        (<bs = 1) (pass >f >bs nf lk (<f . hd))
                        (: nx (filter (d \ !(peep seen d 0)) (deps <f))
                           _ (map (d \ pin seen d 1) nx)
                           (pass >f >bs (nx + nf) (<f . lk) hd)))
                    (pass f bs () lk hd)))))
       t0 (tips ())
       _ (map (i \ pin seen i 1) t0)
       (go t0 () ()))
   ; blobs by hash, rounds of 256 -> {hash (1 text)} | 0
   (ssh-blobs c hs)
    (: bc {} q (c 'q)
       (go l) (? (atom? l) bc
          (: b (take 256 l) r (ssh-ask c (ssh-line "blobs" b))
             (? !(string? r && #r = #b) 0
                (: (rd i m) (? (two? m) (: _ (? (r i = 49) (: t (fr-get q) (? (string? t) (pin bc <m [1 t]) ())) ())
                                           (rd (i + 1) >m)))
                   _ (rd 0 b)
                   (go (drop 256 l))))))
       (go hs))
   ; the far side's patches beyond hd, and the blobs we lack of theirs, laid by gap over its
   ; tips -> gap's count | 0
   (ssh-pull c hd ft)
    (: n (: r (ssh-ask c (ssh-line "want" hd)) (? (string? r) (dv-num r)))
       (? !(charm? n) 0
          (: pc {} q (c 'q)
             _ (: (go k) (? (0 < k) (: t (fr-get q) _ (? (string? t) (pin pc (sha256 t) [1 t]) ()) (go (k - 1))))
                  (go n))
             hs (filter (h \ !(two? (stat (".sb/blob/" + h)))) (ssh-hashes (map (k \ <>(pc k)) (keys pc))))
             bc (ssh-blobs c hs)
             (? (tablet? bc) (gap (\ id (peep pc id ())) (\ h (peep bc h ())) ft ".") 0))))
   ; our patches lk, with the blobs the far store lacks of theirs -> [laid bad blobs ok] | ()
   (ssh-push c lk)
    (: ts (filter string? (map (i \ (: t (look (".sb/patch/" + i)) (? (two? t) <>t ()))) lk))
       hs (filter (h \ two? (stat (".sb/blob/" + h))) (ssh-hashes ts))
       bs (ssh-bits c "hasb" hs)
       (? (charm? bs) ()
          (: send (: (go l b acc) (? (atom? l) acc (go >l >b (? (<b = 1) acc (<l . acc))))
                     (go hs bs ()))
             w (c 'w)
             (each l) (? (two? l) (: _ (fr-put w <l) (each >l)) ())
             _ (fr-put w ("put " + show #ts + " " + show #send))
             _ (each ts)
             _ (each (map (h \ <>(look (".sb/blob/" + h))) send))
             _ (flush w)
             (ssh-form (fr-get (c 'q))))))
   (sync-ssh peer keep)
    (mk (),
     (? (keep != 1 && 0 < dirty ())
        (say err "sb: working tree has changes; record or revert first\n", 0)
        (: av (ssh-argv peer)
           (? (atom? av) (say err ("sb: cannot read " + peer + " -- ssh://[USER@]HOST[:PORT]/PATH, or NAME@BOX\n"), 0)
              (: c (ssh-open av)
                 (? !(tablet? c) (say err ("sb: cannot run " + <av + "\n"), 0)
                    (: r (ssh-sync c peer keep) _ (ssh-shut c) r)))))))
   ; sync-with's exchange over the wire: pull, push onto a clean far nest (or deposit), the
   ; refs both ways, then both heads to their union. keep: 0 the exchange, 1 a deposit, 2 a take
   (ssh-sync c peer keep)
    (: hi (ssh-form (ssh-ask c (? (keep = 0) "hello dirty" "hello")))
       (? !(two? hi && sb-all? sb-hex? <hi && sb-all? sb-hex? <>hi)
          (say err ("sb: no nest answers at " + peer + "\n"), 0)
          (: ft <hi fh <>hi theirs <>>hi pd (? (keep = 0) (hi 3) 0)
             ng (ssh-lacks c)
             (? (charm? ng) (say err ("sb: " + peer + " stopped answering\n"), 0)
                (: gi (ssh-pull c <>ng ft)
                   got (? (tablet? gi) (gi 'ok) 0)
                   po (? (got && keep != 2 && (keep = 1 || pd = 0)) (ssh-push c <ng) ())
                   pushed (? (two? po) (0 = po 1 && po 3) 0)
                   ru (refadd (refs ()) theirs 1)
                   _ (two? <ru ? (lay ".sb/refs" (show <ru)))
                   _ (? pushed (ssh-ask c ("refs " + show (refs ()))) ())
                   nin (? (tablet? gi) (gi 'laid) 0) nout (? pushed (po 0) 0)
                   nb ((? (tablet? gi) (gi 'blobs) 0) + (? (two? po) (po 2) 0))
                   (? !got (say err ("sb: some objects did not arrive from " + peer + " -- the sync is INCOMPLETE\n"), 0)
                      (keep = 2) (take-tell gi fh <>ru)
                      (keep = 1) (: _ (puts ("sb: deposited -- " + show nin + " patches in, " + show nout + " out, "
                                       + show nb + " blobs\n"))
                              (? pushed 1 0))
                      (ssh-settle c pushed pd fh nin nout nb <>ru)))))))
   (ssh-settle c pushed pd fh nin nout nb nref)
    (: u (head () + fh)
       st (settle u)
       nleft (tell <>>st)
       pst (? pushed (ssh-form (ssh-ask c (ssh-line "take" u))) ())
       took (two? pst && 0 <= pst 2)
       _ (puts ("sb: synced -- " + show <st + " patches (" + show nin + " in, " + show nout + " out), "
                + show nb + " blobs, " + show <>st + " files here"
                + (? took (", " + show <>pst + " files there") "")
                + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                + (nref @ 0 "" (", " + show nref + " ref clash" + (nref @ 1 "" "es"))) + "\n"))
       _ (? took ()
            (say err ("sb: pulled only -- the peer "
                      + (? (0 < pd) "has unrecorded changes" "would not take the write")
                      + "; run sync from its side to finish\n")))
       _ (nleft @ 0 () (say err "sb: settle the flagged paths, then record\n"))
       _ (nref @ 0 () (say err "sb: a banked name is immutable\n"))
       (? (took && 0 = nleft && 0 = nref && 0 = pst 2) <st 0))
   ; a take: the peer's head joins ours, nothing goes back
   (take-tell gi fh nref)
    (? !(tablet? gi && gi 'ok) (say err "sb: some objects did not arrive -- the take is INCOMPLETE\n", 0)
       (: st (settle (head () + fh)) nleft (tell <>>st)
          _ (puts ("sb: took the peer's head -- " + show <st + " patches (" + show (gi 'laid) + " in), "
                   + show (gi 'blobs) + " blobs, " + show <>st + " files here"
                   + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                   + (nref @ 0 "" (", " + show nref + " ref clash" + (nref @ 1 "" "es"))) + "\n"))
          _ (nleft @ 0 () (say err "sb: settle the flagged paths, then record\n"))
          (? (0 = nleft && 0 = nref) <st 0)))
   ; the same from a peer nest on this box: no push, the peer only read
   (sync-take peer)
    (mk (),
     (? (0 < dirty ()) (say err "sb: working tree has changes; record or revert first\n", 0)
        !(two? (stat (peer + "/.sb"))) (say err ("sb: cannot reach " + peer + "\n"), 0)
        (held peer (_ \ (: gi (gap (dir-pat peer) (dir-blb peer) (form (peer + "/.sb/tips")) ".")
                            ru (refadd (refs ()) (form (peer + "/.sb/refs")) 1)
                            _ (two? <ru ? (lay ".sb/refs" (show <ru)))
                            (take-tell gi (head-in peer) <>ru))))))
   ; --- the far side: one answer per word asked, nothing else on stdout
   (sv-has d l) (cats (map (i \ (? (sb-hex? i && two? (stat (d + i))) "1" "0")) l))
   (sv-each l) (? (two? l) (: _ (fr-put out <l) (sv-each >l)) ())
   ; a set's closure as a test: the walk down from it, stopping at a kept derive that lies
   ; within it -> [test] | ()
   (reach1 want base)
    (: got {} hit {}
       _ (: (go st) (? (atom? st) ()
             (: id <st
                (? (0 <= dv-dep base id) (: _ (pin hit id 1) (go >st))
                   (peep got id 0) (go >st)
                   !(sb-hex? id) (go >st)
                   (: f (form (".sb/patch/" + id)) _ (pin got id 1)
                      (go (? (two? f) (fld f 'deps + >st) >st))))))
            (go want))
       (? (sb-all? (t \ peep hit t 0) (base 'tips)) [(\ id (peep got id 0 || 0 <= dv-dep base id))] ()))
   (reach want)
    (: (try bs) (? (atom? bs) <(reach1 want (dv-new 0))
                   (: b (dv-read (".sb/derive/" + <bs)) r (? (tablet? b) (reach1 want b) ())
                      (? (two? r) <r (try >bs))))
       (try (dv-bases ())))
   ; the patches our tips reach that a store holding hs's closure lacks, as texts
   (sv-want hs)
    (: in? (reach hs) seen {}
       (go st acc) (? (atom? st) acc
          (: id <st
             (? (peep seen id 0) (go >st acc)
                (: _ (pin seen id 1)
                   (? (in? id) (go >st acc)
                      (: t (look (".sb/patch/" + id))
                         (? (two? t) (go (ssh-deps <>t + >st) (<>t . acc)) (go >st acc))))))))
       (go (tips ()) ()))
   ; put NP NB: that many patch frames, then blob frames, laid by gap -> [laid bad blobs ok]
   (sv-put ns)
    (: np (? (two? ns) (dv-num <ns) 0) nb (? (two? >ns) (dv-num <>ns) 0)
       pc {} bc {}
       (rd k t) (? (0 < k) (: s (fr-get in) _ (? (string? s) (pin t (sha256 s) [1 s]) ()) (rd (k - 1) t)) t)
       _ (rd np pc) _ (rd nb bc)
       g (gap (\ id (peep pc id ())) (\ h (peep bc h ())) (sort (keys pc)) ".")
       [(g 'laid) (g 'bad) (g 'blobs) (g 'ok)])
   (sv-refs a) (: pu (refadd (refs ()) (readform a) ()) _ (? (two? <pu) (lay ".sb/refs" (show <pu)) ()) (show <>pu))
   ; take TIPS: the head to that set, on a clean tree -> [patches files conflicts], -1 conflicts
   ; when the tree is dirty, -2 when a tip is not here
   (sv-take ids)
    (? (0 < dirty ()) [0 0 -1]
       !(two? ids && sb-all? (i \ sb-hex? i && two? (stat (".sb/patch/" + i))) ids) [0 0 -2]
       (: st (settle ids) [<st <>st #(filter (e \ 0 < <>e) <>>st)]))
   (sv-do v a ids)
    (v @ "hello" (fr-put out (show [(tips ()) (head ()) (refs ()) (? (elem "dirty" ids) (dirty ()) 0)]))
         "has" (fr-put out (sv-has ".sb/patch/" ids))
         "hasb" (fr-put out (sv-has ".sb/blob/" ids))
         "want" (: ps (sv-want (filter (i \ sb-hex? i && two? (stat (".sb/patch/" + i))) ids))
                   _ (fr-put out (show #ps))
                   (sv-each ps))
         "blobs" (: bs (map (h \ (? (sb-hex? h) (look (".sb/blob/" + h)) ())) ids)
                    _ (fr-put out (cats (map (b \ (? (two? b) "1" "0")) bs)))
                    (sv-each (map (b \ <>b) (filter two? bs))))
         "put" (fr-put out (show (sv-put ids)))
         "refs" (fr-put out (sv-refs a))
         "take" (fr-put out (show (sv-take ids)))
         (fr-put out (show ["unknown" v])))
   (sv-loop _)
    (: r (fr-get in)
       (? !(string? r) 1
          (: k (fsub r " " 0) v (? (k < 0) r (snip r 0 k)) a (? (k < 0) "" (snip r (k + 1) #r))
             _ (sv-do v a (ssh-words a))
             _ (flush out)
             (sv-loop ()))))
   ; serve [DIR]: a nest's side of an ssh sync, on stdin and stdout, until the near side hangs up
   (sb-serve as)
    (: d (? (two? as) <as ".")
       h (ssh-env "HOME" "/")
       dir (? (2 <= #d && snip d 0 2 = "~/") (h + snip d 1 #d) d)
       (? ((chdir dir) != ()) (: _ (say err ("sb: cannot enter " + d + "\n")) 1)
          !(two? (stat ".sb")) (: _ (say err ("sb: no nest at " + d + "\n")) 1)
          (? (held "." (_ \ sv-loop ())) 0 1))))

; --- history: a patch shown, the patches that wrote a path, the patch behind each line, the
;     tree against the head, and bisect over banks. a path's writers come from the head's
;     derive in the fold's (depth, id) order, the order its states were made in ---
(:
   (hs-derive _) (dv-derive (head ()))
   (hs-text s) (: t (bl s) (? (two? t) <>t))                  ; a side's text, "" absent | ()
   (hs-entry i) (: f (patch i) [<(fld f 'time) i <(fld f 'note) #(fld f 'hunks)])   ; log-pr's
   ; a hunk as text: its unified diff, a mode line, or a word for a side that cannot diff
   (hs-hunk h)
    (: p <h o <>h n <>>h ot (hs-text o) nt (hs-text n)
       md (? (o && n && sd-x? o != sd-x? n) ["mode " p (? (sd-x? n) " +x" " -x") "\n"] ())
       (? (o && n && sd-h o = sd-h n) md
          !(string? ot && string? nt) (md + ["missing blob " p "\n"])
          (bin? ot || bin? nt) (md + ["binary " p "\n"])
          (: d (udiff (? !o "(none)" p) (? !n "(gone)" p) ot nt) (md + (? (string? d) [d] ())))))
   ; a patch as text: its id, time in seconds, note, deps, then each hunk | ()
   (hs-show id)
    (: f (patch id) nt <(fld f 'note)
       (? (two? f)
          (cats (["patch " id "\n" "time " (show (<(fld f 'time) // 1000)) "\n"]
                 + (? (string? nt && 0 < #nt) ["note " nt "\n"] ())
                 + catmap (d \ ["dep " d "\n"]) (fld f 'deps)
                 + catmap hs-hunk (fld f 'hunks)))))
   ; PATH, or every path under PATH/, that a patch of the derive writes
   (hs-under d p)
    (: q (? (1 < #p && p (#p - 1) = 47) (snip p 0 (#p - 1)) p) n #q
       (filter (k \ k = q || (n < #k && snip k 0 (n + 1) = (q + "/"))) (sort (keys (d 'last)))))
   ; their writers, the fold's last first
   (hs-log d p)
    (: u {} _ (map (k \ map (i \ pin u i 1) (dv-hist d k)) (hs-under d p))
       (map (e \ e 1) (rev (sort (map (i \ [(dv-dep d i) i]) (keys u))))))
   ; a path's states as the fold made them, each writer through dv-step -> ((text pid) ..)
   ; oldest first, a deletion's text ()
   (hs-states d p)
    (: sn {} cf {}
       (go m acc) (? (atom? m) (rev acc)
          (: i (<m 1) h <(filter (e \ <e = p) (fld (patch i) 'hunks))
             (? (atom? h) (go >m acc)
                (: _ (dv-step sn cf p <>h <>>h i) e (peep sn p ())
                   (go >m ([(? (two? e) (hs-text <e)) i] . acc))))))
       (go (sort (map (i \ [(dv-dep d i) i]) (dv-hist d p))) ()))
   ; each line of the path's last state with the patch that wrote it -> ((pid line) ..): a line a
   ; state keeps keeps its writer, a line it adds is its own
   (hs-blame d p)
    (: (step s pv i acc) (? (atom? s) (rev acc)
          (<<s @ 'keep (step >s >pv i (<pv . acc))
                 'del (step >s >pv i acc)
                 (step >s pv i ([i <><s] . acc))))
       (go m pv) (? (atom? m) pv
          (: t <<m (go >m (step (myers (map (e \ <>e) pv) (? (string? t) (lines t) ())) pv <><m ()))))
       (go (hs-states d p) ()))
   ; the head and the tree against it, a line apiece: the head, the banks at it, what the store
   ; holds beyond it, its conflicted paths, then A D M or X (the mode alone) per changed path
   (hs-status _)
    (: tp (head ()) d (hs-derive ()) n (dv-count d) ps (psid tp)
       all #(filter (i \ #i = 64) (readdir ".sb/patch"))
       cf (d 'cf) cs (filter (p \ 0 < <(cf p)) (sort (keys cf)))
       (tag h) (? !<>h "A" !<>>h "D" (sd-h <>h = sd-h <>>h) "X" "M")
       ([("head " + sh ps + ", " + show #tp + " tip" + (? (1 = #tp) "" "s")
          + ", " + show n + " patch" + (? (1 = n) "" "es"))]
        + map (r \ "bank " + <r) (filter (r \ psid <>r = ps) (refs ()))
        + (? (n < all) [("store " + show (all - n) + " more, not in the head")] ())
        + map (p \ "C " + p + " -- " + <>(cf p)) cs
        + map (h \ tag h + " " + <h) (scan (sort (walk () (igs ()) ())) (snap ()) ())))
   ; the ids a set adds over another: the walk down from its tips, stopping where in? holds
   (hs-above tp in?)
    (: seen {}
       (go st acc) (? (atom? st) (sort acc)
          (: id <st
             (? (peep seen id 0 || in? id) (go >st acc)
                (: _ (pin seen id 1) (go (fld (patch id) 'deps + >st) (id . acc))))))
       (go tp ()))
   ; the banks above GOOD and within BAD, oldest first, then BAD: each one halving lays it and
   ; runs cmd in the tree, exit 0 good, 125 skip, else bad. the head is laid back after
   ; -> [[name tips] [name tips]], the first bad set and the last good one | ()
   (hs-bisect ga ba cmd)
    (: x (setof ga) y (setof ba)
       (? (atom? x || atom? y) ()
          (: g <x b <y bin (reach b) gp (psid g) bp (psid b) tp0 (head ())
             (between r) (: rp (psid <>r) (rp != gp && rp != bp && sb-all? bin <>r && sb-all? (reach <>r) g))
             l (map (e \ [(e 1) (e 2)]) (sort (map (r \ [<>>r <r <>r]) (filter between (refs ())))))
             l2 (l + [[ba b]])
             (run c) (: _ (settle <>c) s <(hark cmd)
                        _ (puts ("sb: bisect " + <c + " " + sh (psid <>c) + " -- " + (s @ 0 "good" 125 "skip" "bad") + "\n"))
                        s)
             (go l lo hi) (? (hi - lo <= 1) [(l hi) (? (lo < 0) [ga g] (l lo))]
                             (: m ((lo + hi) // 2)
                                (run (l m) @ 0 (go l m hi)
                                             125 (go (take m l + drop (m + 1) l) lo (hi - 1))
                                             (go l lo m))))
             r (go l2 -1 (#l2 - 1))
             _ (settle tp0)
             r)))

   (sb-show a) (: id (idpfx a) t (? id (hs-show id)) (? (string? t) (: _ (say out t) 1) 0))
   (sb-log-path p)
    (: ids (hs-log (hs-derive ()) p)
       (? (atom? ids) (say err ("sb: no patch in the head writes " + p + "\n"), 0)
          (: _ (log-pr (map hs-entry ids) (head ())) 1)))
   (sb-blame p)
    (: d (hs-derive ()) e ((d 'snap) p) t (? (two? e) (hs-text <e))
       (? (atom? e) (say err ("sb: " + p + " is not in the head\n"), 0)
          (!(string? t) || bin? t) (say err ("sb: " + p + " is binary, or its blob is missing\n"), 0)
          (: bs (hs-blame d p) w #(show #bs)
             _ (foldl (\ n b (: s (show n)
                                _ (puts (snip <b 0 12 + "  " + snip "            " 0 (w - #s) + s + "  " + <>b + "\n"))
                                (n + 1)))
                      1 bs)
             1)))
   (sb-status _)
    (? !(two? (stat ".sb")) (say err "sb: no nest here\n", 0)
       (: _ (map (l \ puts (l + "\n")) (hs-status ())) 1))
   ; GOOD BAD [--] CMD ..: 2 when malformed
   (sb-bisect as)
    (: cmd (? (<>>as = "--") >>>as >>as)
       (? (atom? cmd) 2
          (0 < dirty ()) (say err "sb: working tree has changes; record or revert first\n", 0)
          (: r (hs-bisect <as <>as cmd)
             (? (atom? r) 0
                (: bd <r gd <>r ad (hs-above <>bd (reach <>gd))
                   _ (puts ("sb: first bad " + <bd + " " + sh (psid <>bd) + ", over " + <gd + " -- "
                            + show #ad + " patch" + (? (1 = #ad) "" "es") + "\n"))
                   _ (log-pr (foldl (\ a e (ins e a)) () (map hs-entry ad)) ())
                   1))))))

; --- the CLI face: usage + the verb dispatcher (cook-main's shape) ---
(:
   sb-usage "sb -- svalbard, the patch-set vcs (doc/misc/sb.md)
usage: sb VERB ..
  record [NOTE]   working changes -> a patch in the store (.sb/)
  sync [--keep] PEER  EXCHANGE patch sets with a peer nest (a dir holding .sb/),
                  or PULL from an http:// remote -- any static file tree serving
                  a .sb/ is a complete one, and it takes no push.
                  pull what it has, push what it lacks, settle BOTH trees to
                  the union of their HEADS. two patches on one path three-way
                  merge; a true overlap lands in markers and exits 1 -- resolve,
                  then record. --keep only deposits: both stores fill, no head
                  moves, so a hub holds work it has not taken.
                  ssh://[USER@]HOST[:PORT]/PATH is a nest on another box, its
                  side `sb serve PATH` (SB_SSH the ssh words, SB_LOVE the far love).
                  NAME@BOX is the nest NAME that BOX's door serves (love bee --door),
                  BOX reached as ~/.love/etc/bee/boxes says
  sync --take PEER  pull only, and grow the head by the peer's head: a new nest
                  made from a hub, or one brought up to it
  serve [DIR]     the far side of an ssh sync, on stdin and stdout
  take ID..       grow the HEAD by a set (a ref, or patches by prefix, with
                  their deps) and lay the tree: what a hub does to land work
  ls [-l]         the head's paths; -l puts each one's side (blob hash, x when
                  executable) and a tab before it
  psid [SET]      the name of a set's state: the head's, or SET's (a ref, a
                  patch, a psid, or head)
  paths A B       the paths sets A and B lay differently, a line each
  within A B      exit 0 when set A lies inside set B
  stamp [SET]     the newest of a set's patch times, in seconds: the head's, or SET's
  apply [ID..]    make the HEAD a dep-consistent SUBSET, laid in the tree (an ID
                  may be a prefix; its deps come along). checkout and cherry-pick
                  are one act here. no ID realizes the whole store -- the way back
  bank NAME       freeze the current head -- its whole TIP SET -- as an immutable
                  release. deps are per PATH, so a multi-tip head is ordinary
                  parallel work, not a fork to repair. `apply NAME` realizes it
  undo ID [NOTE]  add the INVERSE of a patch -- revert as growth, never deletion.
                  a path that moved on since three-way merges instead of being
                  clobbered: P's write is lifted OUT, later edits stay
  log             the patches, newest first (* marks a tip of the head)
  log PATH        the head's patches that write PATH, or a path under it, the
                  fold's last first
  show ID         a patch: its time, note and deps, then each hunk as a diff
  blame PATH      each line of PATH in the head, after the patch that wrote it
  status          the head, the banks at it, what the store holds beyond it,
                  conflicted paths, and the tree's changes: A D M, X the mode
  bisect GOOD BAD [--] CMD ..  lay the banks above GOOD and within BAD, halving,
                  and run CMD in each: exit 0 good, 125 skip, else bad. says the
                  first bad set and the patches it adds, then lays the head back
  diff            working tree vs the recorded state (unified; exit 1 on change)
  ledger [NAME]   a named value that moves only by compare-and-swap, its every
                  entry kept. no NAME lists them; NAME prints what it holds
  ledger NAME --id | --log      its hash (none when new) | every entry
  ledger NAME --was OLD FILE    move it to FILE's text (- is stdin) iff it
                  stands at OLD (none for a new one); exit 1 when it has moved on.
                  ledgers stay in their nest: sync never carries one
  -C DIR VERB ..  the verb in the nest at DIR
"
   ; the same page two ways: asked for, it is the answer; reached by a miss, a complaint
   (usage _) (say err sb-usage, uleave 2)
   ; a verb answers its status: 0, or 1 when it did not take
   (sb-main as) (atom? as ? (usage ())
    (<as @ "-C" (? (atom? >as) (usage ())
                   ((chdir <>as) = ()) (sb-main >>as)
                   (say err ("sb: cannot enter " + <>as + "\n"), 1))
           "record" (: _ (held "." (_ \ sb-record (two? >as ? <>as ""))) 0)
           "ledger" (: r (sb-ledger >as) (? (r = 2) (usage ()) !r))
           "sync" (: pr (filter (w \ !(elem w ["--keep" "--take"])) >as)
                     md (? (elem "--take" >as) 2 (elem "--keep" >as) 1 0)
                     (atom? pr ? (usage ())
                      !(held "." (_ \ (? (ssh? <pr || box-peer? <pr) (sync-ssh <pr md)
                                         (md < 2) (sync-with <pr md)
                                         (url? <pr) (sync-url <pr 0)
                                         (sync-take <pr))))))
           "serve" (sb-serve >as)
           "apply" !(held "." (_ \ sb-apply >as))
           "take" (atom? >as ? (usage ()) !(held "." (_ \ sb-take >as)))
           "bank" (atom? >as ? (usage ()) !(held "." (_ \ sb-bank >as)))
           "undo" (atom? >as ? (usage ()) !(held "." (_ \ sb-undo >as)))
           "log" (atom? >as ? (sb-log (), 0) !(sb-log-path <>as))
           "show" (#>as = 1 ? !(sb-show <>as) (usage ()))
           "blame" (#>as = 1 ? !(sb-blame <>as) (usage ()))
           "status" !(sb-status ())
           "bisect" (#>as < 3 ? (usage ()) (: r (held "." (_ \ sb-bisect >as)) (? (r = 2) (usage ()) !r)))
           "ls" (sb-ls (elem "-l" >as), 0)
           "psid" !(sb-psid >as)
           "stamp" !(sb-stamp >as)
           "paths" (#>as = 2 ? (sb-paths <>as <>>as) (usage ()))
           "within" (#>as = 2 ? !(sb-within <>as <>>as) (usage ()))
           "diff" (0 < sb-diff ())
           (usage ()))))

; the seat (cook.l's shape): fire sb-main, and quit with its answer, iff this file -- or the installed
; `sb` binary -- sits in the program seat of the real command line (the
; positional program or a -l preload), taking the args after the seat. cmdline
; is the full C argv, never rebound, so the read is the same in both load orders
; and the cat stays quiet under any other name -- which is why the gate can cat
; this file and have nothing fire. sb-main reads bare: the module's layer holds
; this file's binds and is still the head when this form compiles. body-having:
; the seat leaks nothing.
(: door (udoor 'sb (urun sb-main) sb-usage 1 1)
   s ((cite 'verbs 'enlist) 'sb door (),
      cite 'verbs 'fire ["sb" "sb.l"])
   (two? s && quit (door >s)))

) ; module 'sb
