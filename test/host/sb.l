; the svalbard gate (src/apps/sb/): a sandbox store driven end to end
; (record / log / diff, tips + snap + deps + the content addresses). runs under
; `make test_sb`: cat test/00-init.l this | out/love -- host nifs
; (sha256, readdir, chdir), so it stays off the corpus like the other hostnif
; tests. cwd is the repo root, and everything here happens inside out/.sbtest-PID,
; the pid's own so two runs over one out/ keep apart, removed at the end.
; the use below splices svalbard under the session layer: every internal reads
; bare, and the test's own helpers stay above in the session.
(borrow 'sb)
(borrow 'kore)          ; sb splices the text floor below itself, so the session must ask for it too

(: sb-home (cwd 0))
(: sb-dir ("out/.sbtest-" + show (getpid 0)))
(: _ (mkdir sb-dir 493)
   cd (chdir sb-dir)
   _ (!cd ? () (puts "sbtest: chdir failed\n", quit 1))
   ; the same-text equality for list-shaped store values
   (seq a b) (show a = show b)
   ; the tree: two files and two ignored dirs -- junk/ by the file below, out/ by the
   ; built-in, which is a directory rule (a file by that name would stay)
   _ (mkdir "sub" 493)
   _ (lay "a.txt" "one\ntwo\nthree\n")
   _ (lay "sub/b.txt" "hello\n")
   _ (mkdir "junk" 493)
   _ (lay "junk/x" "never\n")
   _ (mkdir "out" 493)
   _ (lay "out/x" "built\n")
   _ (mk ())
   _ (lay ".sbignore" "junk\npr\nnest2\nmrg\n")   ; junk/ + the nests we sync with
   p1 (sb-record "first")
   s1 (snap ())
   again (sb-record "again"))

(test
 (64 = #p1)                                            ; a real content address
 (seq (tips ()) [p1])                               ; the one tip
 (3 = #s1)                                             ; junk/ and out/ stayed out; .sbignore is a file like any other
 (".sbignore" = <<s1)                                  ; path-sorted
 (blob <>(s1 1) = "one\ntwo\nthree\n")               ; the blob rides its hash
 !again                                                ; a clean tree records nothing
 (p1 = sha256 <>(look (".sb/patch/" + p1))))      ; the id is the file's hash

; mutate: one changed, one born, one dead
(: _ (lay "a.txt" "one\ntwo point five\nthree\n")
   _ (lay "c.txt" "born\n")
   _ (unlink "sub/b.txt")
   nd (sb-diff ())
   p2 (sb-record "second")
   f2 (patch p2))

(test
 (3 = nd)                                              ; diff saw all three
 (seq (fld f2 'deps) [p1])                          ; the context reads p1's writes
 (3 = #(fld f2 'hunks))
 (seq (tips ()) [p2])                               ; p1 is no longer maximal
 !(elem "sub/b.txt" (: (go m acc) (two? m ? (go >m (<<m . acc)) acc)
                          (go (snap ()) ())))       ; the death left the snap
 (0 = sb-diff ()))                                   ; recorded = working again

; a patch of only births depends on nothing: a second tip (the DAG, locally)
(: _ (lay "d.txt" "free\n")
   p3 (sb-record "third")
   f3 (patch p3))

(test
 !(fld f3 'deps)                                    ; no context anywhere
 (2 = #(tips ()))                                   ; two maximal patches
 (elem p2 (tips ())) (elem p3 (tips ()))
 (3 = sb-log ()))                                    ; three patches told

; --- sync: a peer nest (built inside ./pr, ignored) shares d.txt's births and
;     adds its own, plus edits a.txt on a common base. union it in: the store
;     gains the peer's patch, tips + snap re-derive over the whole set, and the
;     working tree materializes to the merged state. content-addressing dedups
;     the shared blobs, so only the genuinely-new patch/blob copy over ---
(: _ (mkdir "pr" 493)
   _ (chdir "pr")
   _ (lay "d.txt" "free\n")                            ; same births as p3 -> dedups
   _ (lay "peer.txt" "from the other machine\n")       ; the peer's own file
   _ (mk ())
   pp (sb-record "peer work")
   _ (chdir "..")
   nbefore #(readdir ".sb/patch")
   pdirty (dirty ())                                   ; the main tree is clean pre-sync
   got (sb-sync "pr")
   nafter #(readdir ".sb/patch"))

(test
 (0 = pdirty)                                             ; clean, so sync will materialize
 (nbefore < nafter)                                       ; the peer's patch arrived
 (two? (patch pp))                                     ; ...as a real, addressable patch object
 (elem pp (tips ()))                                ; and it opens a fresh tip
 (3 = #(tips ()))                                      ; p2 + p3 + pp, all maximal
 (4 = got)                                                ; p1 p2 p3 + the peer's pp
 ((<>(look "peer.txt")) = "from the other machine\n")  ; materialized into the working tree
 ((<>(look "a.txt")) = "one\ntwo point five\nthree\n") ; local edits untouched
 (0 = sb-diff ())                                       ; working tree == the recomputed snap
 !(sb-record "noop"))                                   ; ...so nothing is left to record

; --- an empty file is content, not absence. it slurps to () -- the zero point --
;     so a scan that reads the net hashes it to () and it never reaches the snap:
;     the tree is dirty forever, every record buds a junk tip, and sync
;     (which both refuse a dirty tree) never run again. it must record, land in
;     the snap under the honest empty digest, and materialize 0-byte through a
;     sync (where blob presence is likewise the wrapper, never the net) ---
(: _ (lay "e.txt" "")
   pe (sb-record "an empty file")
   esnap (: (go m) (? !(two? m) () ("e.txt" = <<m) <m (go >m)) (go (snap ())))
   clean (dirty ())
   _ (mkdir "nest2" 493)
   _ (chdir "nest2")
   _ (mk ())
   got2 (sb-sync "..")
   et (look "e.txt")
   _ (chdir ".."))

(test
 (64 = #pe)                                               ; the empty file made a real patch
 (two? esnap)                                             ; ...and reached the snap
 (<>esnap = sha256 "")                                  ; ...under the honest empty digest
 (0 = clean)                                              ; ...so the tree came back clean
 !(sb-record "noop")                                    ; ...and stays clean -- no junk tip
 (0 < got2)                                               ; the fresh nest took the whole store
 (two? et)                                                ; ...materializing e.txt: present...
 (0 = #<>et))                                             ; ...and 0 bytes

; --- divergence on one path is a merge, not a coin flip. the incoming hunk
;     names the base it expected, so all three sides sit in the store: disjoint
;     edits to one file both survive (the case that used to drop a side by hash
;     order), a true overlap lands in markers and sync answers 0, and the
;     resolution is an ordinary record -- after which the clash is settled for
;     good. two nests under an ignored parent so the outer walk never sees them ---
(: _ (mkdir "mrg" 493) _ (mkdir "mrg/a" 493)
   _ (chdir "mrg/a")
   _ (lay "f" "one\ntwo\nthree\nfour\nfive\n")
   _ (mk ())
   _ (sb-record "the base")
   _ (mkdir "../b" 493) _ (chdir "../b") _ (mk ())
   _ (sb-sync "../a")
   ; a moves the head, b moves the tail -- one file, disjoint regions
   _ (chdir "../a") _ (lay "f" "ONE\ntwo\nthree\nfour\nfive\n") _ (sb-record "a: the head")
   _ (chdir "../b") _ (lay "f" "one\ntwo\nthree\nfour\nFIVE\n") _ (sb-record "b: the tail")
   gotm (sb-sync "../a")
   mtext (<>(look "f"))
   cfm (<>(derive-snap (readdir ".sb/patch")))
   ; now both move the same line -- a real overlap
   _ (chdir "../a") _ (lay "f" "ONE\nA-TWO\nthree\nfour\nFIVE\n") _ (sb-record "a: two")
   _ (chdir "../b") _ (lay "f" "ONE\nB-TWO\nthree\nfour\nFIVE\n") _ (sb-record "b: two")
   gotc (sb-sync "../a")
   ctext (<>(look "f"))
   cfc (<>(derive-snap (readdir ".sb/patch")))
   ; the resolution is just a record
   _ (lay "f" "ONE\nRESOLVED\nthree\nfour\nFIVE\n")
   _ (sb-record "resolve the overlap")
   cfr (<>(derive-snap (readdir ".sb/patch")))
   ndirty (dirty ())
   _ (chdir "../.."))

(test
 (mtext = "ONE\ntwo\nthree\nfour\nFIVE\n")               ; both disjoint edits survived
 (0 < gotm)                                              ; ...and it was not a conflict
 (1 = #cfm) (0 = <><cfm)                               ; one merge, zero regions unresolved
 (0 = gotc)                                              ; the overlap did conflict: sync answers 0
 (1 = <><cfc)                                          ; ...one region
 (elem "=======" (lines ctext))                       ; ...and the markers are in the file
 (elem "A-TWO" (lines ctext))                         ; ...carrying both sides, neither lost
 (elem "B-TWO" (lines ctext))
 !cfr                                                    ; the record settled it -- nothing left
 (0 = ndirty))                                           ; ...and the tree matches the snap

; --- the two sides that cannot line-merge: a delete meeting an edit keeps the
;     content (a deletion would be the one lossy answer), and flags it ---
(: _ (chdir "mrg/a")
   _ (lay "g" "keep\nme\n") _ (sb-record "g is born")
   _ (chdir "../b") _ (sb-sync "../a")
   _ (chdir "../a") _ (unlink "g") _ (sb-record "a: g dies")
   _ (chdir "../b") _ (lay "g" "keep\nme too\n") _ (sb-record "b: g edited")
   gotd (sb-sync "../a")
   gtext (look "g")
   cfd (<>(derive-snap (readdir ".sb/patch")))
   _ (chdir "../.."))

(test
 (0 = gotd)                                              ; a delete against an edit is a conflict
 (two? gtext)                                            ; the file is still there...
 (<>gtext = "keep\nme too\n")                          ; ...with the edit intact, not the deletion
 (1 = #(filter (\ e ("g" = <e)) cfd)))                   ; ...and g is named in the report

; --- sync is an exchange, not a fetch: one command settles both nests. the
;     derive is a pure function of the patch set, so two nests over one union
;     land on the same snap -- after a sync the trees are identical and the far
;     end needed no attendance. a peer that is dirty takes no push at all (its
;     store is left whole, never half-fed) and sync says so ---
(: _ (mkdir "mrg/c" 493) _ (chdir "mrg/c") _ (mk ())
   _ (lay "shared" "base\n") _ (sb-record "c: the base")
   _ (mkdir "../d" 493) _ (chdir "../d") _ (mk ())
   _ (sb-sync "../c")
   _ (lay "d-only" "from d\n") _ (sb-record "d: its own file")
   _ (chdir "../c") _ (lay "c-only" "from c\n") _ (sb-record "c: its own file")
   gotx (sb-sync "../d")                               ; one sync, run from c
   csnap (snap ()) cdirty (dirty ())
   dhere (look "d-only")                              ; d's file walked in
   _ (chdir "../d")
   dsnap (snap ()) ddirty (dirty ())
   chere (look "c-only")                              ; ...and c's walked out, unattended
   _ (lay "scratch" "unrecorded\n")                   ; now dirty the peer
   _ (chdir "../c")
   nb4 #(readdir ".sb/patch")
   _ (lay "late" "late work\n") _ (sb-record "c: late")
   goty (sb-sync "../d")
   dstore #(readdir "../d/.sb/patch")
   _ (chdir "../.."))

(test
 (0 < gotx)                                              ; the exchange went through
 (two? dhere) (two? chere)                               ; each nest took the other's file
 (show csnap = show dsnap)                               ; ...and both derived the same snap
 (0 = cdirty) (0 = ddirty)                               ; ...both trees clean, the far end untouched by hand
 (0 = goty)                                              ; a dirty peer refuses the push
 (dstore = nb4))                                         ; ...and its store is left whole, not half-fed

; --- apply: realize a dep-consistent subset of the store. git's checkout and
;     its cherry-pick are one act here -- the tree is a pure function of a patch
;     set, so both are only "name a set", with no replay-onto-a-foreign-state to
;     conflict. a named patch drags its DEP closure along: topo silently drops a
;     patch whose context-writer is absent, so leaving one behind would quietly
;     realize less than you asked for ---
(: _ (mkdir "mrg/e" 493) _ (chdir "mrg/e") _ (mk ())
   _ (lay "a" "v1\n") pa (sb-record "a born")
   _ (lay "a" "v2\n") pb (sb-record "a edited")
   ; "b" on purpose: a built-in ignore names it, and those are directory-only, so a
   ; file by that name is an ordinary file. this line is what says so.
   _ (lay "b" "x\n")  pc (sb-record "b born -- independent")
   n1 (sb-apply [pa])                                  ; checkout: the tree as OF pa
   a1 (<>(look "a")) b1 (look "b")
   n2 (sb-apply [pa pc])                               ; cherry-pick: pc taken, pb skipped
   a2 (<>(look "a")) b2 (look "b")
   n3 (sb-apply [pb])                                  ; the closure drags pa in behind pb
   n4 (sb-apply ())                                    ; no id: the way back
   a4 (<>(look "a"))
   bad (sb-apply '("deadbeef"))                        ; a prefix that resolves to nothing
   nstore #(readdir ".sb/patch")                ; read here -- the assert runs after the chdir back
   clean (dirty ())
   _ (chdir "../.."))

(test
 (1 = n1) (a1 = "v1\n") !(two? b1)                       ; as of pa: a rolled back, b not yet born
 (2 = n2) (a2 = "v1\n") (two? b2)                        ; pa + pc: pb's edit skipped, pc's birth kept
 (3 = nstore)                                            ; ...and the store never shrank -- apply is a view
 (2 = n3)                                                ; naming pb alone realized two: its dep came
 (3 = n4) (a4 = "v2\n")                                  ; the way back is the whole store
 !bad                                                    ; an unresolvable prefix answers 0
 (0 = clean))                                            ; every apply leaves the tree clean

; --- undo: the inverse patch. removal is growth -- the patch stays, its
;     dependents stay valid, the store only gets bigger, and that is what keeps
;     releases inclusion-ordered. a path that moved on since is three-way merged
;     rather than clobbered: base = what the patch wrote, ours = what is there
;     now, theirs = what it replaced -- so the later edits survive and only that
;     patch's write is lifted out. a true overlap records nothing ---
(: _ (mkdir "mrg/u" 493) _ (chdir "mrg/u") _ (mk ())
   _ (lay "f" "one\ntwo\nthree\n") _ (sb-record "base")
   _ (lay "f" "one\nBAD\nthree\n") pbad (sb-record "the bad edit, line 2")
   _ (lay "f" "one\nBAD\nTHREE!\n") _ (sb-record "later work, line 3")
   n0 #(readdir ".sb/patch")
   u1 (sb-undo [pbad])
   ftext (<>(look "f"))
   n1 #(readdir ".sb/patch")
   clean (dirty ())
   _ (lay "g" "born\n") pg (sb-record "g born")       ; a birth undone is a death
   u2 (sb-undo [pg])
   gone (look "g")
   _ (lay "h" "a\nb\n") _ (sb-record "h base")        ; the overlap: same line, later patch
   _ (lay "h" "a\nB2\n") pq (sb-record "h -> B2")
   _ (lay "h" "a\nB3\n") _ (sb-record "h -> B3")
   n2 #(readdir ".sb/patch")
   u3 (sb-undo [pq])
   n3 #(readdir ".sb/patch")
   _ (lay "h" "a\nB3\n")                                ; settle the markers by hand
   _ (chdir "../.."))

(test
 (1 = u1)                                               ; the undo landed as a patch
 (ftext = "one\ntwo\nTHREE!\n")                        ; the bad edit lifted, the later work kept
 (n1 = (n0 + 1))                                        ; ...by growing the store, never shrinking it
 (0 = clean)                                            ; ...and the tree matches the snap after
 (1 = u2) !(two? gone)                                  ; a birth undone leaves no file
 !u3                                                    ; a true overlap answers 0...
 (n3 = n2))                                             ; ...and records nothing -- resolve first

; --- bank: freeze the head under a NAME, immutable. hatch.md asks for a
;     single-tip head and that does not survive per-path deps: an independent
;     birth is never depended upon, so it stays maximal and two tips is what
;     ordinary parallel work looks like, not a fork to repair. a ref freezes the
;     tip set instead -- the head DAG state whatever its shape, and the same
;     thing psid hashes, so a release and its goods line up ---
(: _ (mkdir "mrg/k" 493) _ (chdir "mrg/k") _ (mk ())
   _ (lay "a" "1\n") _ (sb-record "a born")
   _ (lay "b" "2\n") _ (sb-record "b born -- independent, so BOTH stay tips")
   ntip #(tips ())
   b1 (sb-bank '("v1"))
   b2 (sb-bank '("v1"))                                ; the same head again: idempotent
   r1 (refof "v1")
   _ (lay "c" "3\n") _ (sb-record "work after the release")
   b3 (sb-bank '("v1"))                                ; a different head: immutable, refuses
   b4 (sb-bank '("v2"))
   n1 (sb-apply '("v1"))                               ; realize the release by NAME
   cgone (look "c")
   n2 (sb-apply '("v2"))
   cback (look "c")
   bad (sb-bank '(""))
   _ (lay "a" "dirty\n") bdirty (sb-bank '("v3"))      ; a dirty tree refuses too
   _ (lay "a" "1\n")
   _ (chdir "../.."))

(test
 (2 = ntip)                                              ; two independent births, two tips -- normal
 (1 = b1) (1 = b2)                                       ; banked; re-banking the same head is a no-op
 (2 = #r1)                                               ; the ref froze the tip set, not one id
 !b3 (1 = b4)                                            ; a banked name is immutable
 (2 = n1) !(two? cgone)                                  ; apply by NAME realized exactly the release
 (3 = n2) (two? cback)                                   ; ...and the later ref brings c back
 !bad !bdirty)                                           ; an empty name and a dirty tree both refuse

; --- refs travel. a release is only "the unit you propagate" if the NAME
;     reaches the other nest with the patches. a ref is a single file, not a
;     content-addressed one, so sync unions it by name instead of gap-filling.
;     the same name at the same head is idempotent; at different heads it is a
;     human error, since a banked name is immutable and neither nest may repoint
;     the other's -- so each side keeps its own and the clash is told once ---
(: _ (mkdir "mrg/r" 493) _ (mkdir "mrg/r/l" 493) _ (chdir "mrg/r/l") _ (mk ())
   _ (lay "f" "base\n") _ (sb-record "base") _ (sb-bank '("v1"))
   _ (mkdir "../d" 493) _ (chdir "../d") _ (mk ())
   got (sb-sync "../l")
   travelled (refof "v1")                                ; ...it arrived, unbanked here
   n1 (sb-apply '("v1"))                               ; ...and realizes by NAME
   ; now bank the same name on each side at different heads
   _ (lay "g" "d\n") _ (sb-record "d work") _ (sb-bank '("rel"))
   drel (refof "rel")
   _ (chdir "../l") _ (lay "h" "l\n") _ (sb-record "l work") _ (sb-bank '("rel"))
   lrel (refof "rel")
   clash (sb-sync "../d")
   lkept (refof "rel")                                   ; l kept its rel...
   _ (chdir "../d") dkept (refof "rel")                  ; ...and d kept its
   _ (chdir "../../.."))

(test
 (0 < got) (two? travelled)                              ; the ref crossed with the patches
 (1 = n1)                                                ; ...and named a release the nest never banked
 !(show drel = show lrel)                                ; the two `rel`s really are different heads
 !clash                                                  ; a clash makes sync answer 0
 (show lkept = show lrel)                                ; each side kept its own -- no silent loss
 (show dkept = show drel))

; --- a hostile peer: its patch hashes honestly but names a path out of the tree and
;     a blob id that is a path. the patch is refused whole -- not copied, not laid,
;     and refused again when planted in the store by hand ---
(: _ (mkdir "mrg/h" 493) _ (mkdir "mrg/h/a" 493) _ (lay "mrg/h/secret" "the key\n")
   _ (chdir "mrg/h/a") _ (mk ())
   bh (keep "pwned\n")
   ptext ("(patch (note \"evil\") (time 0) (deps) (hunks (\"stolen\" () \"../../../secret\")"
          + " (\"../escaped\" () \"" + bh + "\")))")
   pid (sha256 ptext)
   _ (lay (".sb/patch/" + pid) ptext)
   _ (lay ".sb/tips" ("(\"" + pid + "\")"))
   _ (mkdir "../b" 493) _ (chdir "../b") _ (mk ())
   _ (sb-sync "../a")
   hcopied (look (".sb/patch/" + pid))
   hstolen (look "stolen")
   hesc (look "../escaped")
   _ (lay (".sb/patch/" + pid) ptext)                   ; planted by hand
   hform (patch pid)
   _ (sb-apply ())
   hstolen2 (look "stolen")
   hesc2 (look "../escaped")
   _ (chdir "../../.."))

(test
 !(two? hcopied)                                         ; the peer's patch was not taken
 !(two? hstolen) !(two? hesc)                            ; ...and nothing was read or written by it
 !hform                                                  ; planted, it reads as no patch
 !(two? hstolen2) !(two? hesc2)                          ; ...and apply lays none of it
 (sb-hex? pid) !(sb-hex? "../../x") !(sb-hex? (snip pid 0 63)) !(sb-hex? ("A" + snip pid 1 64))
 (sb-rel? "a/b.txt") !(sb-rel? "/etc/passwd") !(sb-rel? "a/../b")
 !(sb-rel? "a//b") !(sb-rel? "./a") !(sb-rel? "") !(sb-rel? 'a))

; --- a store's own files and a link are out of reach: no hunk names .git or .sb at any
;     depth or in any case, no control byte, and no write lands through a symlink ---
(: _ (mkdir "mrg/l" 493) _ (mkdir "mrg/lo" 493) _ (lay "mrg/lo/y" "outside\n")
   _ (chdir "mrg/l") _ (mk ())
   _ (symlink "../lo" "lk")
   lrec (sb-record "a link is not walked")               ; lk/y is not ours to record
   bh (keep "pwned\n")
   ptext (show ['patch ['note "through"] ['time 0] ['deps] ['hunks ["lk/x" () bh]]])
   pid (sha256 ptext)
   _ (lay (".sb/patch/" + pid) ptext)
   _ (lay ".sb/tips" (show [pid]))
   lsound (two? (patch pid))                             ; the path is fine on its face...
   lapp (sb-apply ())
   lout (look "../lo/x")                                 ; ...but the write would leave the tree
   _ (chdir "../.."))

(test
 !lrec lsound !(two? lout)
 !(sb-rel? ".git/config") !(sb-rel? "a/.git/hooks/x") !(sb-rel? ".GIT/config")
 !(sb-rel? ".git./config") !(sb-rel? ".git /config") !(sb-rel? "git~1/config")
 !(sb-rel? ".sb/refs") !(sb-rel? "sub/.Sb/tips") !(sb-rel? (string [97 10 98])) !(sb-rel? (string [97 0 98]))
 (sb-rel? ".sbignore") (sb-rel? ".gitignore") (sb-rel? "a.git/x") (sb-rel? "x/.github/y")
 (sb-link? "mrg/l/lk/x") !(sb-link? "mrg/l/nope") !(sb-link? "mrg/lo/y"))

; --- a ledger: the one value here that moves, and only by compare-and-swap. it moves
; from what it stands at, every entry stays, a live holder's lock is waited on and a dead
; one's taken, and sync carries patches, blobs and refs but never a ledger ---
(: _ (mkdir "mrg/g" 493) _ (mkdir "mrg/g/a" 493) _ (mkdir "mrg/g/b" 493)
   _ (chdir "mrg/g/a") _ (mk ())
   _ (lay "v1" "row 1\n") _ (lay "v2" "row 1\nrow 2\n")
   made (lg-swap "queue/main" "none" "v1")
   h1 (lg-now "queue/main")
   stale (lg-swap "queue/main" "none" "v2")                 ; it no longer stands at none
   moved (lg-swap "queue/main" h1 "v2")
   h2 (lg-now "queue/main")
   holds (blob h2)                                          ; read here: the test runs from the root
   held (: _ (mkdir ".sb/ledger/queue/main.lock" 448)
           _ (lay ".sb/ledger/queue/main.lock/pid" (show (getpid 0)))    ; a live holder: us
           r (lg-lock "queue/main" 2)
           _ (lg-unlock "queue/main")
           r)
   taken (: _ (mkdir ".sb/ledger/queue/main.lock" 448)
            _ (lay ".sb/ledger/queue/main.lock/pid" "999999")           ; a gone one
            r (lg-lock "queue/main" 2)
            _ (lg-unlock "queue/main")
            r)
   log (lg-lines "queue/main")
   names (lg-names ".sb/ledger" "")
   _ (lay "f.txt" "a patch to carry\n") _ (sb-record "the carried one")
   _ (chdir "../b") _ (mk ())
   _ (sb-sync "../a")
   carried (look "f.txt")
   theirs (lg-now "queue/main")
   _ (chdir "../../.."))

(test
 made !stale moved (held = 0) taken
 (sb-hex? h1) (sb-hex? h2) (h1 != h2)
 (holds = "row 1\nrow 2\n")                              ; what it holds is a blob in the store
 (2 = #log) (h1 = <(words <log)) (h2 = <(words (log 1)))  ; both entries, oldest first
 (seq names ["queue/main"])                              ; the lock is not a ledger
 !(lg-name? "../x") !(lg-name? "q.lock") (lg-name? "queue/main")
 (two? carried) ("none" = theirs))                       ; the patch travelled, the ledger did not

; --- the x bit: a side is a blob, or a blob and an x, so a chmod is a change that records,
;     travels and lands, and a mode merges three ways on its own -- one nest's chmod and the
;     other's edit both survive, a binary's too. undo of a chmod gives the mode back ---
(: _ (mkdir "mrg/x" 493) _ (mkdir "mrg/x/a" 493) _ (mkdir "mrg/x/b" 493)
   _ (chdir "mrg/x/a") _ (mk ())
   _ (lay "run.sh" "#!/bin/sh\necho hi\n") _ (chmod "run.sh" 493)
   _ (lay "plain" "not run\n")
   _ (lay "bin" (string [0 1 2 3]))
   xp1 (sb-record "a script")
   xh1 (fld (patch xp1) 'hunks)
   xside (: (go m) (? (atom? m) () (<<m = "run.sh") <>><m (go >m)) (go xh1))
   pside (: (go m) (? (atom? m) () (<<m = "plain") <>><m (go >m)) (go xh1))
   _ (chmod "run.sh" 420)
   xdirty (dirty ())
   xp2 (sb-record "not a script")
   xh2 (fld (patch xp2) 'hunks)
   _ (chmod "run.sh" 493) _ (sb-record "a script again")
   _ (chdir "../b")
   xgot (sb-sync "../a")
   bexe (sd-exe? "run.sh") bplain (sd-exe? "plain")
   ; the two sides move apart: b edits run.sh and bin, a takes run.sh's x and gives bin one
   _ (lay "run.sh" "#!/bin/sh\necho there\n") _ (lay "bin" (string [0 1 2 4]))
   _ (sb-record "b: the text")
   _ (chdir "../a") _ (chmod "run.sh" 420) _ (chmod "bin" 493)
   xp3 (sb-record "a: the modes")
   _ (chdir "../b")
   xmerge (sb-sync "../a")
   bt (look "run.sh") bx (sd-exe? "run.sh") bbin (look "bin") bbx (sd-exe? "bin")
   _ (chdir "../a")
   at (look "run.sh") ax (sd-exe? "run.sh") abx (sd-exe? "bin")
   xundo (sb-undo [xp3])
   ut (look "run.sh") ux (sd-exe? "run.sh") ubx (sd-exe? "bin")
   _ (chdir "../../.."))

(test
 (65 = #xside) (120 = xside 64) (64 = #pside)                ; the script's side carries its x
 (1 = xdirty) (1 = #xh2)                                     ; a chmod alone is a change
 (sd-h <><xh2 = sd-h <>><xh2) (sd-x? <><xh2) !(sd-x? <>><xh2) ; ...one blob, two modes
 (0 < xgot) bexe !bplain                                     ; the mode landed with the text
 (0 < xmerge)                                                ; no conflict: the sides are disjoint
 (<>bt = "#!/bin/sh\necho there\n") !bx                     ; b's text, a's mode
 (<>bbin = string [0 1 2 4]) bbx                             ; a binary merges when one side kept the text
 (<>at = <>bt) (ax = bx) (abx = bbx)                         ; both nests on one tree
 xundo (<>ut = <>bt) ux !ubx                                 ; the undo lifts only the modes
 (sb-oid? xside) !(sb-oid? (snip xside 0 64 + "y")) !(sb-oid? (xside + "x")))

; --- sync walks from the tips: a store holds every patch's deps, so the walk stops at a patch
;     the other side holds. against thirty patches, one new one is the one patch read. a patch
;     whose blob will not come is not laid, so what is laid keeps its closure ---
(: _ (mkdir "mrg/t" 493) _ (mkdir "mrg/t/a" 493) _ (mkdir "mrg/t/b" 493)
   _ (chdir "mrg/t/a") _ (mk ())
   _ (: (go i) (? (i < 30) (: _ (lay ("f" + show (i % 3)) ("rev " + show i + "\n")) _ (sb-record ("r" + show i)) (go (i + 1))) 0) (go 0))
   _ (chdir "../b") _ (mk ())
   tfull (sb-sync "../a")
   _ (chdir "../a") _ (lay "f0" "one more\n") tnew (sb-record "one more") _ (chdir "../b")
   tg (gap (dir-pat "../a") (dir-blb "../a") (form "../a/.sb/tips") ".")
   tsame (gap (dir-pat "../a") (dir-blb "../a") (form "../a/.sb/tips") ".")
   _ (chdir "../a") _ (lay "f1" "no blob\n") tlost (sb-record "its blob goes") _ (chdir "../b")
   tbh (sha256 "no blob\n")
   _ (rename ("../a/.sb/blob/" + tbh) "../held")
   th (gap (dir-pat "../a") (dir-blb "../a") (form "../a/.sb/tips") ".")
   tlaid (two? (stat (".sb/patch/" + tlost)))
   _ (rename "../held" ("../a/.sb/blob/" + tbh))
   tdone (sb-sync "../a")
   tf0 (look "f0") tf1 (look "f1")
   _ (chdir "../../.."))

(test
 (30 = tfull)
 (1 = tg 'read) (1 = tg 'laid) (1 = tg 'blobs) (tg 'ok)     ; one patch, its one blob
 (0 = tsame 'read) (0 = tsame 'laid) (tsame 'ok)          ; held already: nothing read
 !(th 'ok) (0 = th 'laid) !tlaid                          ; no blob, no patch
 (32 = tdone) (<>tf0 = "one more\n") (<>tf1 = "no blob\n"))  ; and it all arrives once the blob is back

; --- the head: a nest's tree realizes its head, a tip set, and its store may hold more. a worker's
;     patch deposited in a hub sits in the hub's store and not its tree until the hub takes it;
;     apply sets the head and it stays set; sync settles both nests on the union of their heads.
;     the nest's lock is its own process's again, a live other's to wait on, a dead one's to take.
;     a nest from before heads realizes its whole store ---
(: _ (mkdir "mrg/n" 493) _ (mkdir "mrg/n/hub" 493) _ (mkdir "mrg/n/w" 493)
   _ (chdir "mrg/n/hub") _ (mk ())
   _ (lay "base" "the hub's\n") nb (sb-record "base")
   _ (chdir "../w") nw0 (sb-sync "../hub")
   _ (lay "work" "the worker's\n") nwk (sb-record "work")
   nd (sb-deposit "../hub")
   _ (chdir "../hub")
   held1 (look "work")                                   ; deposited: not in the hub's tree
   inst (two? (patch nwk))                               ; ...but in its store
   tips1 (tips ()) head1 (head ())
   nt (sb-take [nwk])
   took (look "work") head2 (head ())
   nls (sb-ls ())
   na (sb-apply [nb])                                    ; back to the base alone
   gone (look "work") head3 (head ())
   _ (lay "more" "the hub's again\n") nm (sb-record "more")
   head4 (head ())
   ns (sb-sync "../w")                                   ; the union of the two heads
   back (look "work") wmore (look "../w/more")
   own (nest-hold "." 2)                                 ; a free lock, taken
   again (nest-hold "." 2)                               ; ...and this process's own again
   _ (nest-free ".")
   live (spawn ["sleep" "30"])                           ; a live other holder
   _ (mkdir ".sb/lock" 448) _ (lay ".sb/lock/pid" (show live))
   other (nest-hold "." 2)
   _ (still live 9) _ (wait live)
   _ (lay ".sb/lock/pid" "999999")                       ; a gone one
   dead (nest-hold "." 2)
   _ (nest-free ".")
   _ (unlink ".sb/head") old (head ())                   ; a nest from before heads
   _ (chdir "../../.."))

(test
 (0 < nw0) (1 = nd)
 !(two? held1) inst (elem nwk tips1) !(elem nwk head1)
 (1 = nt) (<>took = "the worker's\n") (elem nwk head2) (2 = nls)
 (0 < na) !(two? gone) (show head3 = show [nb])
 (show head4 = show (sort [nb nm]))
 (0 < ns) (<>back = "the worker's\n") (<>wmore = "the hub's again\n")
 (own = 'took) (again = 'again) (other = ()) (dead = 'took)
 (show old = show (sort [nb nm nwk])))


; --- derive from a base: a set derived once is a base the rest folds onto, and the fold equals
;     the whole replay on any set, from whichever base. a store of synthetic patches, three lines
;     of work on twenty paths that take up each other's state now and then, so writes cross ---
(: (dg-r i) ((i * 7919 + 13) * 104729 % 1000003)
   (dg-tab t) (map (k \ [k (t k)]) (sort (keys t)))
   (dg-all d ids) [(sort (d 'tips)) (dg-tab (d 'snap)) (dg-tab (d 'cf)) (dg-tab (d 'last))
                   (dv-count d) (map (i \ dv-dep d i) ids)
                   (map (p \ [p (sort (dv-hist d p))]) (sort (keys (d 'last))))]
   (dg-same a b) (: ids (sort (keys (a 'mem) + keys (b 'mem))) (seq (dg-all a ids) (dg-all b ids)))
   ; patch i on a line's state: path p rewritten over what it held, or deleted
   (dg-patch i st p del)
    (: e (peep st p ()) old (two? e ? <e)
       nw (? (del && two? e) ()
             (keep ("line " + show i + " of " + p + "\n" + (two? e ? <>(look (".sb/blob/" + old)) ""))))
       pt (show ['patch ['note (show i)] ['time i] ('deps . (two? e ? [<>e] ())) ('hunks . [[p old nw]])])
       pid (sha256 pt)
       _ (lay (".sb/patch/" + pid) pt)
       _ (? (string? nw) (pin st p [nw pid]) (pull st p 0))
       pid)
   (dg-store n np)
    (: ls [{} {} {}]
       (go i acc)
        (? (n <= i) (rev acc)
           (: r (dg-r i) st (ls (r % 3))
              _ (? (i % 5 = 4) (: c (ls ((r // 3) % 3)) (map (k \ pin st k (c k)) (keys c))) ())
              (go (i + 1) ((dg-patch i st ("p" + show ((r // 9) % np)) (r % 11 = 0)) . acc))))
       (go 0 ()))
   (dg-pick ps i k) (map (j \ ps (dg-r (i * 31 + j) % #ps)) ^k))

(: _ (mkdir "mrg/v" 493) _ (chdir "mrg/v") _ (mk ())
   dps (dg-store 300 20)
   ; twelve trials: a base, then more on it, folded and replayed whole
   dtr (map (t \ (: w1 (dg-pick dps t (t * 3)) w2 (dg-pick dps (t + 100) (t * t))
                    inc (dv-derive1 (w1 + w2) (dv-derive1 w1 (dv-new 0)))
                    full (dv-derive1 (w1 + w2) (dv-new 0))
                    [(dg-same inc full) (inc 'refold)]))
            ^12)
   dsame (sb-all? (r \ <r) dtr)
   dre #(filter (r \ 0 < r 1) dtr)
   ; the cache round trip
   dall (dv-derive1 (readdir ".sb/patch") (dv-new 0))
   _ (dv-write dall)
   dback (dv-read (dv-path (dall 'tips)))
   dtrip (dg-same dall dback)
   ; through the verbs: apply a set, take more, and the tree is the replay's
   dw1 (dg-pick dps 7 3) dw2 (dg-pick dps 77 3)
   _ (sb-apply dw1)
   dkept (two? (stat (dv-path (head ()))))
   _ (sb-take dw2)
   dsnap (seq (snap ()) <(derive-snap (dw1 + dw2)))
   dclean (0 = dirty ())
   dbases #(filter (f \ #f = 64) (readdir ".sb/derive"))
   _ (chdir "../.."))

(test
 dsame (0 < dre) (dre < 12)                ; equal every time, some paths folded again or none
 dtrip dkept dsnap dclean (1 = dbases))


; --- the bank's worth: over twenty thousand patches, a take onto the cached head folds only what
;     it adds, so it costs a small part of the whole replay (a ratio: the box may be busy) ---
(: _ (mkdir "mrg/b" 493) _ (chdir "mrg/b") _ (mk ())
   _ (dg-store 20000 2000)
   b0 (clock 0) _ (sb-apply []) b1 (clock 0)                ; no base: the whole replay
   bpt (show ['patch ['note "w"] ['time 1] ['deps] ['hunks ["w0" () (keep "w\n")]]])
   bpid (sha256 bpt) _ (lay (".sb/patch/" + bpid) bpt)
   b2 (clock 0) _ (sb-take [bpid]) b3 (clock 0)
   btook (elem bpid (head ()))
   bsnap (seq (snap ()) <(derive-snap (readdir ".sb/patch")))
   _ (chdir "../.."))

(test
 btook bsnap
 ((b3 - b2) * 4 < b1 - b0))

(chdir sb-home)
(hark ["rm" "-rf" sb-dir])
(puts "sb: ok", putc 10, 0)
