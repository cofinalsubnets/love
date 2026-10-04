; src/apps/hive.l -- the hive's cells as files: the sessions on this machine, bee's and
; claude code's, each settled in HIVE/NAME/ with a `card` of `key value` lines (doc/bee.md,
; THE HIVE). bee writes cards and mail; this is the reading every client shares.
;
;   (hive-root _)      BEE_HIVE, else ~/.love/run/hive
;   (hive-cell nm)     a session's cell
;   (hive-card nm)     its card as a tablet, "name" included; () when there is none
;   (hive-pid c)       a card's pid, 0 for none
;   (hive-alive? p)    a pid that answers signal 0
;   (hive-user? c)     a user's card, the hud's: never swept, its pid 0 while away
;   (hive-taken? c)    a name no one else may settle as: a user's, or a live session's
;   (hive-sweep nm)    a gone session's cell removed, messages and all
;   (hive-cards _)     every cell with a card, [name card] each, by name
;   (hive-settled _)   the live ones and the users', the rest swept
(module (hive hive-root hive-cell hive-card hive-pid hive-alive? hive-user? hive-taken?
         hive-sweep hive-cards hive-settled)
(borrow 'posix)
(:
 (hive-root _) (: r (getenv "BEE_HIVE") h (getenv "HOME")
                  (? (string? r && 0 < #r) r (string? h) (h + "/.love/run/hive") "/tmp/bee-hive"))
 (hive-cell nm) (hive-root 0 + "/" + nm)
 (hive-card nm)
  (: f (open (hive-cell nm + "/card") "r")
     s (? (hot? f) (: s (slurp f) _ (close f) s))
     (? (string? s)
        (foldl (\ t l (l @ ((k && 0 < #k) + " " + v) (pin t k v) t))
               {"name" nm} (lines s))))
 (hive-pid c) (unum (peep c "pid" "0") @ n (charm? n ? n 0))
 (hive-alive? p) (charm? p && 0 < p && !(nom? (still p 0)))
 (hive-user? c) (tablet? c && peep c "kind" "" = "user")
 (hive-taken? c) (tablet? c && (hive-user? c || hive-alive? (hive-pid c)))
 ; a cell with no card yet is being made, and stays
 (hive-sweep nm)
  (: d (hive-cell nm)
     _ (map (\ sub (: q (d + "/" + sub) fs (readdir q)
                      _ (? (two? fs) (map (\ f (unlink (q + "/" + f))) fs) 0)
                      (rmdir q)))
            ["inbox" "read"])
     _ (map (\ f (unlink (d + "/" + f))) ["key" "cert" ".cert" "seen"])
     _ (unlink (d + "/card"))
     (rmdir d))
 (hive-cards _)
  (: ns (readdir (hive-root 0))
     (? (two? ns) (filter two? (map (\ nm (: c (hive-card nm) (tablet? c ? [nm c]))) (sort ns)))))
 (hive-settled _)
  (filter (p \ hive-user? (p 1) || hive-alive? (hive-pid (p 1)) || (hive-sweep <p, 0)) (hive-cards 0)))
) ; module hive
