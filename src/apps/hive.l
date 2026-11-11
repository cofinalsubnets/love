; src/apps/hive.l -- the hive's cells as files: the sessions on this machine, bee's and
; claude code's, each settled in HIVE/NAME/ with a `card` of `key value` lines (doc/bee.md,
; THE HIVE). bee writes cards and mail; this is the reading every client shares.
;
;   (hive-root _)      BEE_HIVE, else the nest's run/hive
;   (hive-host _)      BEE_HOST, else the kernel's hostname: the host a card is written on
;   (hive-lease _)     BEE_LEASE seconds, 60: how long a remote card's beat keeps it live
;   (hive-cell nm)     a session's cell
;   (hive-card nm)     its card as a tablet, "name" included, and "beat" off the cell's beat
;                      file when there is one; () when there is no card
;   (hive-pid c)       a card's pid, 0 for none
;   (hive-alive? p)    a pid that answers signal 0
;   (hive-remote? c)   a card written on another host: its pid means nothing here
;   (hive-live? c)     a remote card beaten within the lease, else a local one whose pid answers
;   (hive-user? c)     a user's card, the hud's: never swept, its pid 0 while away
;   (hive-taken? c)    a name no one else may settle as: a user's, or a live session's
;   (hive-draining? c) a session whose host is draining: a remote card saying drain, a local
;                      one while HIVE/.drain is there. it takes mail but holds nothing in a queue
;   (hive-sweep nm)    a gone session's cell removed, messages and all
;   (hive-cards _)     every cell with a card, [name card] each, by name
;   (hive-settled _)   the live ones and the users', the rest swept: a local one at once, a
;                      remote one once its beat is ten leases old and no mail waits in it
(module (hive hive-root hive-host hive-lease hive-cell hive-card hive-pid hive-alive? hive-remote?
         hive-live? hive-user? hive-taken? hive-draining? hive-sweep hive-cards hive-settled)
(borrow 'posix)
(:
 (hive-root _) (getenv "BEE_HIVE" @ r (string? r && 0 < #r ? r (cite 'path 'nest 0 + "/run/hive")))
 (slurp-at p) (: f (open p "r") (hot? f ? (slurp f @ s (close f, s))))
 (hive-host _)
  (getenv "BEE_HOST" @ e
   (string? e && 0 < #e ? e
    (slurp-at "/proc/sys/kernel/hostname" @ s
     (: w (string? s ? (lines s) ()) (two? w && 0 < #<w ? <w "localhost")))))
 (hive-lease _) (getenv "BEE_LEASE" @ e (: n (string? e ? (unum e)) (charm? n && 0 < n ? n 60)))
 (hive-cell nm) "\(hive-root 0)/\(nm)"
 (hive-card nm)
  (: s (slurp-at "\(hive-cell nm)/card")
     (? (string? s)
        (: c (foldl (\ t l (l @ ((k && 0 < #k) + " \(v)") (pin t k v) t))
                    {"name" nm} (lines s))
           b (slurp-at "\(hive-cell nm)/beat")
           w (string? b ? (lines b) ())
           (? (two? w) (pin c "beat" <w) c))))
 (hive-pid c) (unum (peep c "pid" "0") @ n (charm? n ? n 0))
 (hive-alive? p) (charm? p && 0 < p && !(nom? (still p 0)))
 (hive-remote? c) (tablet? c && (peep c "host" "" @ h (0 < #h && h != hive-host 0)))
 (beat-age c) (unum (peep c "beat" "") @ b (charm? b ? (clock 0 // 1000 - b) ()))
 (hive-live? c)
  (tablet? c && (? (hive-remote? c) (beat-age c @ a (charm? a && a <= hive-lease 0))
                   (hive-alive? (hive-pid c))))
 (hive-user? c) (tablet? c && peep c "kind" "" = "user")
 (hive-taken? c) (tablet? c && (hive-user? c || hive-live? c))
 (hive-draining? c)
  (tablet? c && (? (hive-remote? c) (peep c "drain" "" = "1") (string? (slurp-at "\(hive-root 0)/.drain"))))
 ; a cell with no card yet is being made, and stays
 (hive-sweep nm)
  (: d (hive-cell nm)
     _ (map (\ sub (: q "\(d)/\(sub)" fs (readdir q)
                      _ (? (two? fs) (map (f \ unlink "\(q)/\(f)") fs) 0)
                      (rmdir q)))
            ["inbox" "read"])
     _ (map (f \ unlink "\(d)/\(f)") ["key" "cert" ".cert" "seen" "beat" ".beat"])
     _ (unlink "\(d)/card")
     (rmdir d))
 (hive-cards _)
  (: ns (readdir (hive-root 0))
     (? (two? ns) (filter two? (map (\ nm (: c (hive-card nm) (tablet? c ? [nm c]))) (sort ns)))))
 ; a remote card is its own host's to sweep; here it waits ten leases, which a host away for
 ; maintenance outlasts only when it is truly gone
 (stale? c) (beat-age c @ a (!(charm? a) || 10 * hive-lease 0 < a))
 (mail? nm) (: fs (readdir "\(hive-cell nm)/inbox") (two? fs && two? (filter (f \ f 0 != 46) fs)))
 (hive-settled _)
  (filter (p \ hive-user? (p 1) || hive-live? (p 1)
                || (? (hive-remote? (p 1)) (: _ (? (stale? (p 1) && !(mail? <p)) (hive-sweep <p) 0) 0) (: _ (hive-sweep <p) 0)))
          (hive-cards 0)))
) ; module hive
