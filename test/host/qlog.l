; --- test/host/qlog.l: a queue as a signed log (src/apps/qlog.l, sb's signed ledgers) -------
; one lineage -- a root, the hub box, two cells -- then a chain of entries, each way one can
; lie, and sb's two sides of it: a ledger that moves only by an entry that follows, and nests
; that pull a queue only along a chain that checks. run from the repo root:
;   cat test/00-init.l test/host/qlog.l | out/love

(borrow 'qlog)
(borrow 'seals)
(borrow 'sb)

(borrow 'posix)

(: ql-home (cwd 0)
   ql-dir (ql-home + "/out/.qlogtest-" + show (getpid 0))
   ql-h0 (getenv "HOME")
   _ (hark ["rm" "-rf" ql-dir])
   _ (mkparents (ql-dir + "/.love/etc/bee/x"))
   _ (setenv "HOME" ql-dir)
   ql-hex (cite 'tls 'hex)
   ql-root (seal-key 0) ql-boxk (seal-key 0) ql-antk (seal-key 0) ql-bobk (seal-key 0)
   ql-rh (ql-hex (ql-root 1))
   ql-now (clock 0 // 1000)
   (ql-fields nm kind k) [["lineage" ql-rh] ["name" nm] ["kind" kind] ["pub" (ql-hex (k 1))]
                          ["issued" (show (ql-now - 60))] ["expires" (show (ql-now + 86400))]]
   ql-boxc (seal-card ql-root (ql-fields "hub" "box" ql-boxk))
   (ql-seal nm k) [k (seal-card ql-boxk (ql-fields nm "cell" k) + "\n" + ql-boxc)]
   ql-ant (ql-seal "ant@hub" ql-antk) ql-bob (ql-seal "bob@hub" ql-bobk)
   _ (lay (ql-dir + "/.love/etc/bee/lineage") (ql-rh + "\n"))
   ql-q "queue/q@hub"
   ql-t0 "leader ant\nmain -\nnext 3\n1 ant b1 - - waiting\n2 bob b2 - - waiting\n"
   ql-t1 "leader ant\nmain -\nnext 3\n1 ant b1 - - waiting\n2 bob b2 - aaa gating\n"
   ql-tx "leader ant\nmain -\nnext 3\n1 ant b1 - - green\n2 bob b2 - aaa gating\n"    ; bob moves ant's row
   ql-tl "leader ant\nmain bbb\nnext 3\n1 ant b1 - - waiting\n"                       ; bob's row lands
   (ql-mk seq prev by call t seal) (qlog-make ql-q seq prev by call (sha256 t) seal)
   ql-e0 (ql-mk 0 "none" "ant@hub" "queue_row" ql-t0 ql-ant)
   ql-e1 (ql-mk 1 (qlog-hash ql-e0) "bob@hub" "queue_row" ql-t1 ql-bob)
   ql-tr (qlog-trust 0)
   (ql-step prev e before after) (qlog-step prev e before after <ql-tr (ql-tr 1))
   (ql-sub s old new) (: i (fsub s old 0) (? (i < 0) s (snip s 0 i + new + snip s (i + #old) #s))))

; --- the entry: laid one way, read back, its writer as the queue spells it ---------------
(: f (qlog-read ql-e1)
   _ (test (tablet? f) (f "seq" = "1") (f "by" = "bob@hub") (f "text" = sha256 ql-t1)
           (qlog-who f = "bob")
           (ql-tr 0 = ql-rh)
           (() = qlog-read (ql-e1 + " "))                       ; not laid the one way: not an entry
           (() = qlog-read (ql-sub ql-e1 "(term \"0\") " ""))
           (() = qlog-read "leader ant\n"))
   0)

; --- the chain: each entry follows the one before, by a writer whose card and sig check, making
;     a change it may make. each way to lie is refused by its own law ---------------------------
(: e2 (ql-mk 2 (qlog-hash ql-e1) "bob@hub" "queue_row" ql-tx ql-bob)            ; bob moves ant's row
   e2l (ql-mk 2 (qlog-hash ql-e1) "bob@hub" "queue_landed" ql-tl ql-bob)       ; bob's own landing
   e2s (ql-mk 3 (qlog-hash ql-e1) "bob@hub" "queue_row" ql-t1 ql-bob)          ; a seq skipped
   e2p (ql-mk 2 (qlog-hash ql-e0) "bob@hub" "queue_row" ql-t1 ql-bob)          ; a prev not the last
   e2o (qlog-make "queue/other@hub" 2 (qlog-hash ql-e1) "bob@hub" "queue_row" (sha256 ql-t1) ql-bob)
   e2w (ql-mk 2 (qlog-hash ql-e1) "ant@hub" "queue_row" ql-t1 ql-bob)          ; bob's key, ant's name
   e2g (ql-sub e2l "\"queue_landed\"" "\"queue_lands\"")                       ; changed after signing
   e2a (ql-mk 2 (qlog-hash ql-e1) "ant@hub" "queue_row" ql-tx ql-ant)          ; the leader: anything
   _ (test ("" = ql-step () ql-e0 () ql-t0)
           ("" = ql-step ql-e0 ql-e1 ql-t0 ql-t1)
           ("" = ql-step ql-e1 e2l ql-t1 ql-tl)
           ("" = ql-step ql-e1 e2a ql-t1 ql-tx)
           (0 <= fsub (ql-step ql-e1 e2 ql-t1 ql-tx) "row 1 is not bob's" 0)
           (0 <= fsub (ql-step ql-e1 e2s ql-t1 ql-t1) "seq does not follow" 0)
           (0 <= fsub (ql-step ql-e1 e2p ql-t1 ql-t1) "prev is not the entry before" 0)
           (0 <= fsub (ql-step ql-e1 ql-e1 ql-t1 ql-t1) "seq does not follow" 0)      ; replayed
           (0 <= fsub (ql-step ql-e1 e2o ql-t1 ql-t1) "another queue" 0)
           (0 <= fsub (ql-step ql-e1 e2w ql-t1 ql-t1) "not the writer's" 0)
           (0 <= fsub (ql-step ql-e1 e2g ql-t1 ql-tl) "sig does not check" 0)
           (0 <= fsub (ql-step ql-e1 e2l ql-t1 ql-tx) "not the one it names" 0)
           (0 <= fsub (ql-step () ql-e1 () ql-t1) "seq does not follow" 0))           ; truncated head
   0)

; --- sb: a nest's queue moves only by an entry that follows; a plain write, or an entry that
;     does not chain, is refused once it is signed --------------------------------------------
(: n1 (ql-dir + "/n1")
   _ (mkdir n1 493) _ (chdir n1) _ (mk ())
   (put was s) (: f (ql-dir + "/put") _ (lay f s) (lg-swap "queue/q" was f))
   p0 (put "none" (ql-e0 + "\n" + ql-t0))
   h0 (lg-now "queue/q")
   pp (put h0 "a plain text\n")
   pb (put h0 (ql-mk 1 (qlog-hash ql-e0) "bob@hub" "queue_row" ql-tx ql-bob + "\n" + ql-tx))
   p1 (put h0 (ql-e1 + "\n" + ql-t1))
   h1 (lg-now "queue/q")
   _ (test p0 (h0 = qlog-hash ql-e0) !pp !pb p1 (h1 = qlog-hash ql-e1)
           (ql-t1 = blob ((qlog-read (blob h1)) "text")))
   _ (chdir ql-home)
   0)

; --- the pull: a second nest takes the chain and folds it to the same text; a peer behind it, a
;     fork and a log out of order move nothing, and the fork is kept --------------------------
(: n1 (ql-dir + "/n1") n2 (ql-dir + "/n2") n3 (ql-dir + "/n3") n4 (ql-dir + "/n4")
   (nest d) (: _ (mkdir d 493) _ (chdir d) (mk ()))
   (copy d ls) (: _ (mkparents (d + "/.sb/ledger/queue/x")) (lay (d + "/.sb/ledger/queue/q") (cats (map (l \ l + "\n") ls))))
   (blobs d es) (map (e \ lay (d + "/.sb/blob/" + sha256 e) e) es)
   _ (nest n2) t1 (lg-pull-dir n1)
   s2 [(lg-now "queue/q") (blob ((qlog-read (blob (lg-now "queue/q"))) "text"))]
   s1 (: _ (chdir n1) [(lg-now "queue/q") (blob ((qlog-read (blob (lg-now "queue/q"))) "text"))])
   ; n3 holds only the first entry: n2 is ahead of it
   l1 (: _ (chdir n1) (lg-lines "queue/q"))
   _ (nest n3) _ (copy n3 [<l1]) _ (blobs n3 [ql-e0 ql-t0])
   _ (chdir n2) t3 (lg-pull-dir n3) a3 (lg-now "queue/q")
   ; n4: the first entry, then another second -- a fork
   ef (ql-mk 1 (qlog-hash ql-e0) "ant@hub" "queue_row" ql-tx ql-ant)
   _ (nest n4) _ (copy n4 [<l1 (sha256 ef + " 1 ant")]) _ (blobs n4 [ql-e0 ql-t0 ef ql-tx])
   _ (chdir n2) t4 (lg-pull-dir n4) a4 (lg-now "queue/q") fk (look ".sb/ledger/queue/q.forks")
   ; n5 lists the entries out of order, and a fresh nest takes none of it
   n5 (ql-dir + "/n5") n6 (ql-dir + "/n6")
   _ (nest n5) _ (copy n5 [(l1 1) <l1]) _ (blobs n5 [ql-e0 ql-t0 ql-e1 ql-t1])
   _ (nest n6) t6 (lg-pull-dir n5) a6 (lg-now "queue/q")
   _ (chdir ql-home)
   _ (test (show t1 = show [2]) (show s2 = show s1) (s2 1 = ql-t1)
           (show t3 = show [0]) (a3 = s1 0)
           (show t4 = show [-1]) (a4 = s1 0) (two? fk) (0 <= fsub <>fk (sha256 ef) 0)
           (a6 = "none"))
   0)

(: _ (setenv "HOME" (string? ql-h0 ? ql-h0 ""))
   _ (hark ["rm" "-rf" ql-dir])
   (test_fin ()))
(puts "qlog: ok", putc 10, 0)
