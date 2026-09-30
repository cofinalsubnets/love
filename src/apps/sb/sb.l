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
   (look p) (open p "r" @ q                                            ; (1 text) | ()
                 (hot? q ? (mind (_ \ (slurp q @ s [1 (s + "")])) () (_ \ close q))))
   (lay p s) (open p "w" @ q (hot? q ? (mind (_ \ (say q s, 1)) () (_ \ close q)) 0))
   (form p) (open p "r" @ q                                 ; the file's one form | ()
                  (hot? q ? (mind (_ \ (: r (sound (slurp q))
                                   d (two? r ? <r)
                                   (two? d ? d)))
                           () (_ \ close q))))

   ; --- the store ---
   (mk _) (mkdir ".sb" 493, mkdir ".sb/blob" 493, mkdir ".sb/patch" 493, ())
   (snap _) (form ".sb/snap")                            ; ((path chash pid) ..) sorted
   (tips _) (form ".sb/tips")                            ; (id ..)
   ; the patch-set ID: the name of a head DAG state. the tips are a set -- sort
   ; before hashing, or the same head reads two ways.
   (psid tp) (sha256 (show (sort tp)))
   (blob h) ((sb-hex? h ? (look (".sb/blob/" + h))) @ t (two? t ? <>t))
   (keep s) (sha256 s @ h (lay (".sb/blob/" + h) s, h))
   (patch id) ((sb-hex? id ? (form (".sb/patch/" + id))) @ f (sb-sound? f ? f))
   (fld f k) (:- (go >f) (go m) (? (atom? m) () (two? <m && <<m = k) ><m (go >m)))

   ; --- what a patch may say: its ids and paths become paths here, so a peer's word
   ;     is checked before any of it is used ---
   ; a store name is a sha256 in lowercase hex and nothing else
   (sb-hex? s)
    (: (go i) (64 <= i ? 1 (s i @ c (48 <= c <= 57 || 97 <= c <= 102 ? (go (i + 1)) 0)))
       (string? s && #s = 64 && go 0))
   ; a hunk's path is relative and stays under the root: no leading /, no empty, . or .. segment
   (sb-rel? p) (string? p && sb-rel1? p)
   (sb-rel1? p)
    (: n #p
       (seg a b) (: s (snip p a b) !(#s = 0 || s = "." || s = ".."))
       (go a i) (? (n <= i) (seg a i)
                   (p i = 47) (seg a i && go (i + 1) (i + 1))
                   (go a (i + 1)))
       (0 < n && go 0 0))
   (sb-all? f l) (atom? l ? (l = ()) (f <l && sb-all? f >l))
   (sb-oid? x) (x = () || sb-hex? x)                             ; a hunk side: absent or a blob
   (sb-hunk? h) (two? h && #h = 3 && string? <h && sb-rel? <h && sb-oid? <>h && sb-oid? <>>h)
   (sb-sound? f) (sb-all? sb-hunk? (fld f 'hunks) && sb-all? sb-hex? (fld f 'deps))
   (sb-bad? id) (!(sb-hex? id) || (form (".sb/patch/" + id) @ f (two? f && !(sb-sound? f))))
   (sb-refuse id) (say err ("sb: patch " + (string? id ? (sh id) (show id)) + " refused -- an id that is not a hash,"
                            + " or a path that leaves the tree\n"))

   ; --- ignores: one rule a line in .sbignore, over the built-ins. a rule holding
   igsdir '(".sb" ".git" "out")
   ig-glob? (cite 'glob 'anyglob)
   ig-match (cite 'glob 'match)
   (ig-live? l) (0 < #l && l 0 != 35)
   (igs _) (look ".sbignore" @ t
                 (two? t ? (filter ig-live? (lines <>t)) ()))
   (ign1? p g) (#g @ n (ig-glob? g ? (ig-match g p)
                        (p = g || n + 1 < #p && snip p 0 (n + 1) = g + "/")))
   (ign? p igs) (? (atom? igs) 0 (ign1? p <igs) 1 (ign? p >igs))

   ; --- the walk: every regular file under the root, paths relative ---
   (walk dir igs acc)
    (: es (readdir (!dir ? "." dir))
       (go m acc)
        (atom? m ? acc
           ((!dir ? <m (dir + "/" + <m)) @ p
              (ign? p igs ? (go >m acc)
                 (: st (stat p)
                    md (two? st ? (61440 & <>>st) 0)
                  (md @ 16384 (ign? p igsdir ? (go >m acc) (go >m (walk p igs acc)))
                        32768 (go >m (p . acc))
                              (go >m acc))))))
       (go es acc))

   ; --- the scan: working tree vs snap -> the hunks, path-sorted. pure (no
   ;     blob writes); a hunk is (path old new), old/new content hashes | () ---
   (h1 p e)                                                   ; one path vs its snap entry|()
    (look p @ t
       (atom? t ? (two? e ? [p <>e ()])                 ; unreadable: dead if known
        (sha256 <>t @ h
           (? (atom? e) [p () h]                               ; born
              (<>e = h) ()                                   ; unchanged
              [p <>e h]))))                                  ; changed
   (scan ps sn acc)                                           ; ps sorted paths, sn the snap
    (? (atom? ps)
        (atom? sn ? (rev acc) (scan ps >sn ([<<sn <><sn ()] . acc)))         ; the tail of snap: dead
       (atom? sn)
        (h1 <ps () @ h (scan >ps sn (two? h ? (h . acc) acc)))
       (: p <ps e <sn
          (? (p = <e) (h1 p e @ h (scan >ps >sn (two? h ? (h . acc) acc)))
             (p < <e) (h1 p () @ h (scan >ps sn (two? h ? (h . acc) acc)))
             (scan ps >sn ([<e <>e ()] . acc)))))        ; snap-only: dead

   ; --- record ---
   (sb-record note)
    (: _ (mk ())
       sn (snap ())
       st {}                                             ; path -> (chash pid)
       _ (: (go m) (two? m ? (pin st <<m ><m, go >m)) (go sn))
       hunks (scan (sort (walk () (igs ()) ())) sn ())
       (? !(two? hunks) (puts "sb: nothing to record\n", ())
          (: ; the blobs: keep every hunk's new content
             _ (: (go m) (two? m ?  (<m @ h (!<>>h ? () (keep <>(look <h)), go >m)))
                  (go hunks))
             ; the deps: the patches whose writes this one's contexts read
             deps (:- (go hunks ()) (go m acc)
                   (atom? m ? (sort acc)
                    (<><m @ old
                     (!old ? (go >m acc)
                      (: e (st <<m)
                         pid (two? e ? <>e)
                       (!pid || elem pid acc ? (go >m acc)
                        (go >m (pid . acc))))))))
             ptext (show ['patch ['note note] ['time (clock 0)]
                          ('deps . deps) ('hunks . hunks)])
             pid (sha256 ptext)
             _ (lay (".sb/patch/" + pid) ptext)
             _ (lay ".sb/snap" (show (snap+ sn hunks pid ())))
             tp (filter (t \ nelem t deps) (tips ()))
             (lay ".sb/tips" (show (sort (pid . tp))),
              puts ("sb: recorded " + snip pid 0 12 + " (" + show #hunks + " paths)\n"),
              pid))))

   ; --- snap under a patch's hunks (both path-sorted) ---
   (snap+ sn hs pid acc)
    (? (atom? hs) (rev acc + sn)
       (atom? sn) (: h <hs nw <>>h
                        (snap+ () >hs pid (!nw ? acc ([<h nw pid] . acc))))
       (: h <hs e <sn
          (? (<h = <e) (<>>h @ nw
                            (snap+ >sn >hs pid (!nw ? acc ([<h nw pid] . acc))))
             (<h < <e) (<>>h @ nw
                            (snap+ sn >hs pid (!nw ? acc ([<h nw pid] . acc))))
             (snap+ >sn hs pid (<sn . acc)))))

   ; --- log: the patches newest first; * marks a tip ---
   (ins e l) (? (atom? l) [e]                                 ; insert desc by time (seat 0)
              (<<l <= <e) (e . l)
              (<l . ins e >l))
   (sb-log _)
    (: tp (tips ())
       (go m acc)
        (atom? m ? acc
         (: id <m f (patch id)
          (atom? f ? (go >m acc)
           (go >m (ins [<(fld f 'time) id <(fld f 'note) #(fld f 'hunks)] acc)))))
       es (go (readdir ".sb/patch") ())
       (pr m)
        (two? m ?
         (: e <m id <>e
            _ (puts (elem id tp ? "* " "  "))
            _ (puts (snip id 0 12 + "  " + show <>>>e + " paths"))
            nt <>>e
            (!nt ? () (puts ("  " + nt)),
             puts "\n",
             pr >m)))
       (pr es,
        (: (pf m) (two? m ?
                     (: e <m t <>e
                        ; the psid: the name of this release's head DAG state.
                        ; a banked ref stores its tips sorted, so the sort is a no-op here
                        (puts ("  " + <e + "  " + sh (psid t) + "  "
                               + show #t + " tip" + (1 = tally t ? "" "s") + "\n"),
                         pf >m)))
           (refs () @ rs (two? rs ? (puts "banked:\n", pf rs)))),
        #es))

   ; --- diff: working tree vs the recorded state, unified; answers how many differ ---
   (sb-diff _)
    (: sn (snap ())
       hunks (scan (sort (walk () (igs ()) ())) sn ())
       (pr m n)
        (atom? m ? n
           (: h <m p <h
              ot (!<>h ? "" (blob <>h))
              nt (!<>>h ? "" (look p @ t (two? t ? <>t "")))
              d (udiff (!<>h ? "(none)" (p + " (recorded)"))
                       (!<>>h ? "(gone)" p)
                       ot nt)
              (!d ? () (puts d),
               pr >m (n + 1))))
       (pr hunks 0))

   ; --- sync: union a peer nest's store. blobs + patches are immutable and
   (dirty _) #(scan (sort (walk () (igs ()) ())) (snap ()) ())
   ; one direction of the store exchange: copy the sha256-named files `to` lacks,
   ; verifying every address on the way. a nest root is "." or a peer path.
   ; answers (ncopied nfailed) -- a failed write is a peer we cannot push to.
   (copy sub cite to)
    (: fd (cite + "/.sb/" + sub + "/") td (to + "/.sb/" + sub + "/")
       (go m n bad)
        (? !(two? m) [n bad]
           (<m @ h
              (? !(sb-hex? h) (go >m n bad)                 ; only the sha256-named files
                 (two? (look (td + h))) (go >m n bad)         ; already there
                 (look (fd + h) @ t
                    (? (atom? t) (go >m n bad)
                       (sha256 <>t != h)
                        (say err ("sb: bad address " + h + "\n"), go >m n (bad + 1))
                       (sub = "patch" && !(sb-sound? (readform <>t)))
                        (sb-refuse h, go >m n (bad + 1))
                       (lay (td + h) <>t) (go >m (n + 1) bad)
                       (go >m n (bad + 1)))))))
       (go (readdir fd) 0 0))
   ; bring this nest to the state a given patch set implies
   (tell cfs)
    (: (go m n) (atom? m ? n
          (: e <m p <e k <>e
             (say (k @ 0 out err)
                  ("sb: " + (k @ 0 "merged " "CONFLICT in ") + p + " -- " + <>>e + "\n"),
              go >m (k @ 0 n (n + 1)))))
       (go cfs 0))
   (settle ids0)
    (: ids (filter (i \ (sb-bad? i ? (sb-refuse i, 0) 1)) ids0)
       oldsnap (snap ())
       _ (lay ".sb/tips" (show (derive-tips ids)))
       dr (derive-snap ids)
       newsnap <dr
       ; the derive replays the whole set every time
       ix (: (go m t) (two? m ? (pin t <<m <><m, go >m t) t))
       op (ix oldsnap {}) np (ix newsnap {})
       cfs (filter (e \ 0 < <>e || op <e != np <e) <>dr)
       _ (lay ".sb/snap" (show newsnap))
       nf (mater oldsnap newsnap)
       [#ids nf cfs])
   (derive-tips ids)                                          ; the ids nobody depends on
    ({} @ dep
       ((: (go m) (two? m ?
              (patch <m @ f
                 ((: (gd d) (two? d ? (pin dep <d 1, gd >d)) (gd (fld f 'deps))),
                  go >m)))
           (go ids)),
        sort (filter (i \ !(peep dep i 0)) ids)))
   (topo ids)                                                 ; deps before dependents, ties by sorted id
    (: have {} idl (sort ids)
       (ready _)
        (: (go m a) (atom? m ? (rev a)
             (<m @ id
                (peep have id 0 ? (go >m a)
                   (: f (patch id)
                      ok (: (gd d) (atom? d ? 1 (peep have <d 0 ? (gd >d) 0)) (gd (fld f 'deps)))
                      (go >m (ok ? (id . a) a))))))
           (go idl ()))
       (pass acc)
        (ready () @ b
           (atom? b ? acc
              ((: (mk m) (two? m ? (pin have <m 1, mk >m)) (mk b)),
               pass (acc + b))))
       (pass ()))
   ; --- a diverged write: two patches wrote one path from a shared base
   (bin? s) (: n #s (go i) (? (n <= i) 0 (s i = 0) 1 (go (i + 1))) (go 0))
   (sh h) (h ? (snip h 0 12) "()")
   (bl h) (? !h '(1 "") (sb-hex? h) (look (".sb/blob/" + h)))      ; (1 text) | () -- presence, not net
   (mend old curh nw curpid pid)
    (: bw (bl old) ow (bl curh) tw (bl nw)
       (? !nw [curh 1 ("kept the edit -- " + sh pid + " deletes what " + sh curpid + " wrote")]
          !curh [nw 1 ("kept the edit -- " + sh pid + " writes what was deleted here")]
          !(two? ow && two? tw)
             [curh 1 ("a blob is missing, cannot merge -- kept " + sh curh)]
          (: bt (two? bw ? <>bw "") ot <>ow tt <>tw
             (bin? bt || bin? ot || bin? tt ?
                [curh 1 ("binary, cannot merge -- kept " + sh curh + ", incoming " + sh nw)]
                (: r (diff3 bt ot tt ("recorded (" + sh curpid + ")")
                                      ("incoming (" + sh pid + ")"))
                   mh (keep <r) n <>r
                   (n @ 0 [mh 0 "both sides kept"]
                    [mh n (show n + " region" + (1 = n ? "" "s") + " left in markers")]))))))
   (derive-snap ids)                                          ; fold the DAG -> (snap conflicts)
    (: order (topo ids) snap {} cf {}
       ((:- (go order) (go m) (atom? m ? ()
              (: pid <m f (patch pid)
                 ((:- (h1 (fld f 'hunks)) (h1 hs) (atom? hs ? ()
                        (: h <hs p <h old <>h nw <>>h
                           cur (snap p) curh (two? cur ? <cur)
                           curpid (two? cur ? <>cur)
                           (curh = old || nw = curh ?          ; the expected base, or convergent
                              (pull cf p 0,                   ; a later patch can settle an earlier clash
                               !nw ? (pull snap p 0) (pin snap p [nw pid]))
                              (mend old curh nw curpid pid @ m
                                 (pin snap p [<m pid],
                                  pin cf p [<>m <>>m],
                                  ())),
                            h1 >hs)))),
                  go >m)))),
        (: (em ps a) (atom? ps ? (rev a)
             (: p <ps e (peep snap p ()) (em >ps [p <e <>e . a])))
           (cm ps a) (atom? ps ? (rev a)
             (: p <ps e (peep cf p ()) (cm >ps [p <e <>e . a])))
           [(em (sort (keys snap)) ()) (cm (sort (keys cf)) ())])))
   (mkparents p)                                              ; mkdir every "/"-prefix of a nested path
    (:- (go 0) (go i) (i < #p ? (p i @ 47 (mkdir (snip p 0 i) 493), go (i + 1))))
   (mater oldsnap newsnap)                                    ; make the tree match newsnap; #files touched
    (: np {}
       _ (: (go m) (two? m ? (pin np <<m <><m, go >m)) (go newsnap))
       w (: (go m n) (atom? m ? n
              (: e <m p <e ch <>e
                 ok (sb-rel? p && sb-hex? ch)
                 bl (ok ? (look (".sb/blob/" + ch)))   ; presence, not net: an empty blob is real
                 cur (ok ? (look p)) curh (two? cur ? (sha256 <>cur))
                 (? !ok (say err ("sb: will not write " + show p + " from " + show ch + "\n"), go >m n)
                    (atom? bl) (say err ("sb: missing blob " + ch + "\n"), go >m n)
                    (curh = ch) (go >m n)
                    (mkparents p, lay p <>bl, go >m (n + 1)))))
            (go newsnap 0))
       d (: (go m n) (? !(two? m) n
              (<<m @ p (? (peep np p 0) (go >m n)
                          !(sb-rel? p) (say err ("sb: will not unlink " + show p + "\n"), go >m n)
                          (unlink p, go >m (n + 1)))))
            (go oldsnap 0))
       (w + d))
   ; --- the http remote: pull only
   (pull-http base)
    (: n {}
       seen {}
       (bump k) (pin n k (1 + peep n k 0))
       (getblob h)                                     ; ensure a blob is local
        (? !h 1
           !(sb-hex? h) 0
           (two? (look (".sb/blob/" + h))) 1
           (http-fetch base ("/blob/" + h) @ b
              (? (atom? b) (say err ("sb: cannot fetch blob " + sh h + "\n"), 0)
                 (sha256 <>b = h) (lay (".sb/blob/" + h) <>b, bump 'b, 1)
                 (say err ("sb: bad address on blob " + sh h + "\n"), 0))))
       (getpatch id)                                   ; ensure a patch is local; answer its form
        (: local (sb-hex? id ? (look (".sb/patch/" + id)))
           f (two? local ? (readform <>local))
           (? !(sb-hex? id) (sb-refuse id, ())
              (two? local) (sb-sound? f ? f (sb-refuse id, ()))
              (: b (http-fetch base ("/patch/" + id))
                 f2 (two? b ? (readform <>b))
                 (? (atom? b) (say err ("sb: cannot fetch patch " + sh id + "\n"), ())
                    (sha256 <>b != id) (say err ("sb: bad address on patch " + sh id + "\n"), ())
                    !(sb-sound? f2) (sb-refuse id, ())
                    (lay (".sb/patch/" + id) <>b, bump 'p, f2)))))
       (walk ids ok)                                   ; the transitive closure, by reading as we go
        (atom? ids ? ok
           (<ids @ id
              (seen id ? (walk >ids ok)
                 (: _ (pin seen id 1)
                    f (getpatch id)
                    (atom? f ? (walk >ids 0)
                       (: hs (fld f 'hunks)
                          ; fetch first, then combine: && short-circuits, so folding the
                          ; calls into the accumulator would stop fetching at the first miss
                          bo (: (hb m a) (? !(two? m) a
                                   (: h <m x (getblob <>h) y (getblob <>>h)
                                      (hb >m (a && x && y))))
                                (hb hs 1))
                          (walk (fld f 'deps + >ids) (ok && bo))))))))
       tt (http-fetch base "/tips")
       (atom? tt ? (say err ("sb: no store at " + base + " (no /tips)\n"), ())
          (readform <>tt @ tips
             (atom? tips ? (say err ("sb: " + base + " has no tips\n"), ())
                (: ok (walk tips 1)
                   rt (http-fetch base "/refs")             ; the refs ride along
                   theirs (two? rt ? (readform <>rt))
                   ru (refadd (refs ()) theirs 1)
                   (two? <ru ? (lay ".sb/refs" (show <ru)),
                    [ok (peep n 'p 0) (peep n 'b 0) <>ru]))))))

   (sync-url peer)
    (mk (),
     0 < dirty () ?
       (say err "sb: working tree has changes; record or revert first\n", 0)
       (: base (snip peer (#peer - 1) #peer = "/" ?
                  (snip peer 0 (#peer - 1)) peer)         ; one trailing slash, ours to add
          r (pull-http base)
          (atom? r ? 0
             (: st (settle (readdir ".sb/patch"))
                nleft (tell <>>st)
                nref <>>>r
                (puts ("sb: pulled -- " + show <st + " patches (" + show <>r
                       + " in), " + show <>>r + " blobs, " + show <>st + " files here"
                       + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                       + (nref @ 0 "" (", " + show nref + " ref clash")) + "\n"),
                 <r ? () (say err "sb: some objects did not arrive -- the pull is INCOMPLETE\n"),
                 say err "sb: pulled only -- an http remote takes no push\n",
                 <r && 0 = nleft && 0 = nref ? <st 0)))))

   ; sync is the exchange, and an exchange has two ends: pull what the peer has
   ; that we lack, push what we have that it lacks, then settle both nests. the
   ; derive is a pure function of the patch set, so two nests over one union land
   ; on the same snap -- after a sync the trees are identical, which is the whole
   ; "distribution == cloning" claim made good. the peer's half needs its tree
   ; clean and writable; when it is not we still pull (always safe) and say so,
   ; leaving the peer's store untouched rather than half-fed.
   (sb-sync peer)
    (url? peer ? (sync-url peer)
    (mk (),
     0 < dirty () ?
       (say err "sb: working tree has changes; record or revert first\n", 0)
       (: home (cwd 0)
          pd (chdir peer @ c (c ? -1 (: _ (mk ()) d (dirty ()) (chdir home, d))))
          (pd < 0 ? (say err ("sb: cannot reach " + peer + "\n"), 0)
             (: inb (copy "blob" peer ".") inp (copy "patch" peer ".")
                ; the push: only onto a clean peer, and only if every write lands
                out1 (pd @ 0 (copy "blob" "." peer) '(0 0))
                out2 (pd @ 0 (copy "patch" "." peer) '(0 0))
                pushed (0 = pd && 0 = <>out1 && 0 = <>out2)
                ; the refs travel too -- a release is only "the unit you
                ; propagate" if the NAME reaches the other nest with it
                theirs (form (peer + "/.sb/refs"))
                ru (refadd (refs ()) theirs 1)
                _ (two? <ru ? (lay ".sb/refs" (show <ru)))
                _ (!pushed ? ()
                     (refadd theirs (refs ()) () @ pu
                        (two? <pu ? (lay (peer + "/.sb/refs") (show <pu)))))
                st (settle (readdir ".sb/patch"))
                nleft (tell <>>st)
                nref <>ru
                pst (!pushed ? ()                              ; settle the far end too
                       (: c (chdir peer) r (settle (readdir ".sb/patch")) (chdir home, r)))
                (puts ("sb: synced -- " + show <st + " patches ("
                       + show <inp + " in, " + show <out2 + " out), "
                       + show (<inb + <out1) + " blobs, " + show <>st + " files here"
                       + (two? pst ? (", " + show <>pst + " files there") "")
                       + (nleft @ 0 "" (", " + show nleft + " conflicted"))
                       + (nref @ 0 "" (", " + show nref + " ref clash"
                                           + (nref @ 1 "" "es"))) + "\n"),
                 pushed ? ()
                   (say err ("sb: pulled only -- the peer "
                             + (0 < pd ? "has unrecorded changes" "would not take the write")
                             + "; run sync from its side to finish\n")),
                 nleft @ 0 ()
                 (say err "sb: settle the flagged paths, then record\n"),
                 nref @ 0 ()
                 (say err "sb: a banked name is immutable\n"),
                 pushed && 0 = nleft && 0 = nref ? <st 0))))))

   ; --- apply: realize a dep-consistent subset of the store into the working
   (idpfx pfx)                                                   ; one patch from a prefix | ()
    (: n #pfx
       hits (filter (i \ #i = 64 && snip i 0 n = pfx) (readdir ".sb/patch"))
       (? (1 = #hits) <hits
          (atom? hits) (say err ("sb: no ref or patch matches " + pfx + "\n"), ())
          (say err ("sb: " + show #hits + " patches match " + pfx + "\n"), ())))
   (idsof a)                                                     ; a ref -> its whole tip set;
    (refof a @ r (two? r ? r (idpfx a @ i (i ? [i]))))
   (closure ids)                                                 ; ids + every dep, transitively
    (:- (go ids, sort (keys seen)) seen {}
     (go m) (two? m ?  (<m @ id (peep seen id 0 ? (go >m)
                                (pin seen id 1, go (fld (patch id) 'deps), go >m)))))
   (sb-apply args)
    (mk (),
     0 < dirty () ?
       (say err "sb: working tree has changes; record or revert first\n", 0)
       (: all (readdir ".sb/patch")
          want (: (go m acc) (atom? m ? acc (idsof <m @ l (two? l ? (go >m (acc + l)))))
                  (go args ()))
          (two? args && atom? want ? 0                    ; a prefix failed to resolve; it said so
             (: ids (two? args ? (closure want) all)
                st (settle ids)
                nleft (tell <>>st)
                (puts ("sb: applied " + show <st + " of " + show #all
                       + " patches, " + show <>st + " files updated"
                       + (#ids = #all ? " (the whole store)" "")
                       + (0 = nleft ? "" (", " + show nleft + " conflicted")) + "\n"),
                 0 = nleft ? ()
                   (say err "sb: settle the flagged paths, then record -- the resolution is a patch\n"),
                 0 = nleft ? #ids 0)))))

   ; --- bank: freeze the current head under a NAME -- an immutable release, the
   (refs _) (form ".sb/refs")                                  ; ((name (id..) time)..) | ()
   (refof nm) (refof-in (refs ()) nm)
   ; --- the ref exchange. a ref is a single file, not a content-addressed one,
   (refadd base extra loud)                                     ; loud: only one side tells it
    (: (go m acc n)
        (atom? m ? [(sort acc) n]
           (: e <m mine (refof-in base <e)
              (? (atom? mine) (go >m (e . acc) n)               ; theirs alone: take it
                 (show mine = show <>e) (go >m acc n)          ; the same head: already ours
                 (loud ? (say err ("sb: REF CLASH on " + <e
                                   + " -- banked to different heads\n")),
                  go >m acc (n + 1)))))
       (go extra base 0))
   (refof-in rs nm) (: (go m) (? (atom? m) () (<<m = nm) <><m (go >m)) (go rs))

   (sb-bank args)
    (: _ (mk ())
       nm (two? args ? <args "")
       (? (0 >= #nm)
          (say err "sb: bank needs a name\n", 0)
          (0 < dirty ())
          (say err "sb: working tree has changes; record or revert first\n", 0)
          (sort (tips ()) @ tp
             (atom? tp ? (say err "sb: nothing recorded to bank\n", 0)
                (refof nm @ old
                   (? (two? old && show old != show tp)
                      (say err ("sb: " + nm + " is already banked at a different head"
                                + " -- a banked name is immutable\n"), 0)
                      (two? old) (puts ("sb: " + nm + " is already banked\n"), 1)
                      (lay ".sb/refs" (show (sort ([nm tp (clock 0)] . refs ()))),
                       puts ("sb: banked " + nm + " at " + show #tp + " tip"
                             + (1 = tally tp ? "" "s") + " -- " + sh <tp + "\n"),
                       1)))))))

   ; --- undo: add the inverse patch. removal is growth here, never deletion --
   (sb-undo args)
    (mk (),
     0 < dirty () ?
       (say err "sb: working tree has changes; record or revert first\n", 0)
       (idpfx (two? args ? <args "") @ id
          (!id ? 0                                           ; idpfx already said why
             (: hs (fld (patch id) 'hunks)
                ix (: (go m t) (two? m ? (pin t <<m <><m, go >m t) t))
                sn (ix (snap ()) {})
                nc (:- (go hs 0) (go m n)
                       (atom? m ? n
                          (: h <m p <h pold <>h pnew <>>h
                             cur (sn p)              ; the index maps path -> chash directly
                             (cur = pnew ?                   ; P still owns the path: a clean lift
                                (!pold ? (unlink p)
                                   (mkparents p, lay p (blob pold)),
                                 go >m n)
                                ; it moved on -- merge P's write out of what is there now
                                (: bw (bl pnew) ow (bl cur) tw (bl pold)
                                   (? !(two? bw && two? ow && two? tw)
                                      (say err $ "sb: CONFLICT on " + p + " -- a birth or death moved on; kept what is there\n",
                                       go >m (n + 1))
                                      (bin? <>bw || bin? <>ow || bin? <>tw)
                                      (say err $ "sb: CONFLICT on " + p + " -- binary, cannot merge; kept what is there\n",
                                       go >m (n + 1))
                                      (: r (diff3 <>bw <>ow <>tw "here now" ("undone " + sh id))
                                         _ (lay p <r)
                                         k <>r
                                         (0 = k ? (puts ("sb: merged " + p + " -- the later edits kept\n"))
                                            (say err ("sb: CONFLICT in " + p + " -- " + show k
                                                      + " region" + (1 = k ? "" "s") + " left in markers\n")),
                                          go >m (n + k)))))))))
                (0 = nc ? ()
                   (say err "sb: settle the flagged paths before recording the undo\n"),
                 0 < nc ? 0
                   (sb-record ((two? >args ? <>args "undo ") + sh id) @ r
                      (r ? 1 (puts "sb: nothing to undo -- that patch is already lifted\n", 0)))))))))

; --- ledgers: a named value that moves only by compare-and-swap. a banked name never moves;
;     a ledger is the one thing here that does, and even it only grows: .sb/ledger/NAME is
;     a line per entry, `hash time who`, the last one standing, each hash a blob in the store.
;     a ledger stays in its nest -- sync carries patches, blobs and refs, never a ledger --
;     so sessions that share one name the same nest (sb -C DIR). ---
(:
   (lg-path nm) (".sb/ledger/" + nm)
   (lg-lock? nm) (#nm @ n (4 < n && snip nm (n - 5) n = ".lock"))
   (lg-name? nm) (sb-rel? nm && !(lg-lock? nm))
   (lg-lines nm) (look (lg-path nm) @ t (two? t ? (filter (l \ 0 < #l) (lines <>t)) ()))
   (lg-now nm) (lg-lines nm @ l (? (two? l) <(words (l (#l - 1))) "none"))
   ; the lock is a directory beside the ledger, made atomically, holding its holder's pid.
   ; a dead holder's is taken; a live one is waited on, tries times 20 ms
   (lg-lock nm tries)
    (lg-path nm + ".lock" @ d
       (mkdir d 448 = () ? (lay (d + "/pid") (show (getpid 0)))
          (: t (look (d + "/pid")) p (two? t ? (lg-num <>t) 0)
             (? (0 < p && nom? (still p 0)) (unlink (d + "/pid"), rmdir d, lg-lock nm tries)
                (tries <= 0) 0
                (rest 20, lg-lock nm (tries - 1))))))
   (lg-num s) (: (go i a) (i < #s && 48 <= s i <= 57 ? (go (i + 1) (a * 10 + s i - 48)) a) (go 0 0))
   (lg-unlock nm) (lg-path nm + ".lock" @ d (unlink (d + "/pid"), rmdir d))
   (lg-who _) (: w (getenv "SB_WHO") u (getenv "USER") (? (string? w && 0 < #w) w (string? u) u "?"))
   ; NAME moves to FILE's text iff it stands at WAS ("none" for a new ledger) -> 1, else 0.
   ; the new hash is printed either way it lands, even when the text was already there
   (lg-swap nm was file)
    ((file = "-" ? [1 (slurp in + "")] (look file)) @ t
       (? !(two? t) (say err ("sb: cannot read " + file + "\n"), 0)
          (mk (), mkparents (lg-path nm),
           (? !(lg-lock nm 250) (say err ("sb: ledger " + nm + " is held by another writer\n"), 0)
              (: cur (lg-now nm)
                 r (cur != was ? (say err ("sb: ledger " + nm + " stands at " + cur + ", not " + was + "\n"), 0)
                      (keep <>t @ h
                         (h = cur ? 0
                            (lay (lg-path nm)
                                 (foldl (a \ l \ a + l + "\n") "" (lg-lines nm)
                                  + h + " " + show (clock 0 // 1000) + " " + lg-who () + "\n")),
                          (puts (h + "\n"), 1))))
                 (lg-unlock nm,
                  r))))))
   ; every ledger under dir, by name
   (lg-names dir pre)
    (readdir dir @ es
       (two? es ?
          (catmap (e \ (: p (dir + "/" + e) st (stat p)
                          (? (lg-lock? e) ()
                             (two? st && 61440 & <>>st = 16384) (lg-names p (pre + e + "/"))
                             [(pre + e)])))
                  (sort es))))
   ; the verb: no NAME lists them; NAME says what it holds; --id its hash (or none); --log
   ; every entry; --was OLD FILE moves it. 1 when it took, 0 when not, 2 when malformed
   (sb-ledger args)
    (: nm (two? args ? <args "") r (two? args ? >args)
       (? (#nm = 0) (map (n \ puts (n + " " + lg-now n + "\n")) (lg-names ".sb/ledger" ""), 1)
          !(lg-name? nm) (say err ("sb: a ledger's name is a relative path: " + nm + "\n"), 0)
          (atom? r) (: c (lg-now nm) b (c = "none" ? () (blob c))
                       (string? b ? (say out b, 1) (say err ("sb: no ledger " + nm + "\n"), 0)))
          (<r = "--id") (puts (lg-now nm + "\n"), 1)
          (<r = "--log") (map (l \ puts (l + "\n")) (lg-lines nm), 1)
          (<r = "--was" && #r = 3) (lg-swap nm <>r <>>r)
          2)))                                             ; malformed: the dispatcher says the usage

; --- the CLI face: usage + the verb dispatcher (cook-main's shape) ---
(:
   sb-usage "sb -- svalbard, the patch-set vcs (doc/misc/sb.md)
usage: sb VERB ..
  record [NOTE]   working changes -> a patch in the store (.sb/)
  sync PEER       EXCHANGE patch sets with a peer nest (a dir holding .sb/),
                  or PULL from an http:// remote -- any static file tree serving
                  a .sb/ is a complete one, and it takes no push.
                  pull what it has, push what it lacks, settle BOTH trees to
                  the union. two patches on one path three-way merge; a true
                  overlap lands in markers and exits 1 -- resolve, then record
  apply [ID..]    realize a dep-consistent SUBSET into the working tree (an ID
                  may be a prefix; its deps come along). checkout and cherry-pick
                  are one act here. no ID realizes the whole store -- the way back
  bank NAME       freeze the current head -- its whole TIP SET -- as an immutable
                  release. deps are per PATH, so a multi-tip head is ordinary
                  parallel work, not a fork to repair. `apply NAME` realizes it
  undo ID [NOTE]  add the INVERSE of a patch -- revert as growth, never deletion.
                  a path that moved on since three-way merges instead of being
                  clobbered: P's write is lifted OUT, later edits stay
  log             the patches, newest first (* marks a tip)
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
                   (chdir <>as = ()) (sb-main >>as)
                   (say err ("sb: cannot enter " + <>as + "\n"), 1))
           "record" (sb-record (two? >as ? <>as ""), 0)
           "ledger" (sb-ledger >as @ r (r = 2 ? (usage ()) !r))
           "sync" (atom? >as ? (usage ()) !(sb-sync <>as))
           "apply" !(sb-apply >as)
           "bank" (atom? >as ? (usage ()) !(sb-bank >as))
           "undo" (atom? >as ? (usage ()) !(sb-undo >as))
           "log" (sb-log (), 0)
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
