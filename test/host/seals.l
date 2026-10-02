; --- test/host/seals.l: the hive's keys and cards (src/apps/seals.l) ------------------------
; a root, a box under it and a cell under that, then each way a chain can lie. run
; standalone from the repo root:
;   cat test/00-init.l test/host/seals.l | out/love

(borrow 'seals)
(borrow 'posix)

(: sl-t-hex (cite 'tls 'hex)
   sl-t-root (seal-key 0) sl-t-box (seal-key 0) sl-t-cell (seal-key 0) sl-t-other (seal-key 0)
   sl-t-rh (sl-t-hex (sl-t-root 1))
   (sl-t-fields nm kind k is ex)
    [["lineage" sl-t-rh] ["name" nm] ["kind" kind] ["pub" (sl-t-hex (k 1))]
     ["issued" (show is)] ["expires" (show ex)]]
   sl-t-boxc (seal-card sl-t-root (sl-t-fields "tau" "box" sl-t-box 100 900))
   sl-t-cellc (seal-card sl-t-box (sl-t-fields "g-05@tau" "cell" sl-t-cell 200 300))
   sl-t-chain (sl-t-cellc + "\n" + sl-t-boxc)
   (sl-t-ok s) (: r (seal-check s sl-t-rh 250 ()) (? (string? r) () r))
   (sl-t-why s) (: r (seal-check s sl-t-rh 250 ()) (string? r ? r ""))
   ; s with its first `old` swapped for `new`
   (sl-t-sub s old new)
    (: (at i) (? (#s < i + #old) -1 (snip s i (i + #old) = old) i (at (i + 1)))
       i (at 0)
       (? (i < 0) s (snip s 0 i + new + snip s (i + #old) #s))))

; --- keys: fresh, distinct, and the text spells them back --------------------------------
(test (32 = #<sl-t-root) (32 = #(sl-t-root 1))
      (<sl-t-root != <sl-t-box)
      (sl-t-root = seal-keyof (seal-keytext sl-t-root))
      ; a pub that is not the seed's is no key
      (() = seal-keyof (sl-t-sub (seal-keytext sl-t-root) (sl-t-hex (sl-t-root 1)) (sl-t-hex (sl-t-box 1))))
      (() = seal-keyof "seed 00\npub 00\n"))

; --- a key on disk: 0600, never over one already there -----------------------------------
(: sl-t-path ("out/.seal-" + show (getpid 0))
   _ (unlink sl-t-path)
   _ (test (1 = seal-keywrite sl-t-path sl-t-box)
           (sl-t-box = seal-keyread sl-t-path)
           (string? (seal-keywrite sl-t-path sl-t-cell))
           (sl-t-box = seal-keyread sl-t-path)
           (string? (seal-keyread (sl-t-path + ".none"))))
   _ (unlink sl-t-path)
   ())

; --- a good chain answers its leaf -------------------------------------------------------
(test (: t (sl-t-ok sl-t-chain) (&& t (t "name" = "g-05@tau") (t "kind" = "cell")))
      (: t (sl-t-ok sl-t-boxc) (&& t (t "name" = "tau")))
      (2 = #(seal-chain sl-t-chain)))

; --- and every lie is refused, with a reason ---------------------------------------------
(test (ends? (sl-t-why (sl-t-sub sl-t-chain "g-05@tau" "g-06@tau")) "bad sig")
      (ends? (sl-t-why sl-t-cellc) "not signed by the root")
      (ends? (seal-check sl-t-chain sl-t-rh 350 ()) "out of date")
      (ends? (seal-check sl-t-chain sl-t-rh 50 ()) "out of date")
      (ends? (seal-check sl-t-chain (sl-t-hex (sl-t-other 1)) 250 ()) "another lineage")
      (ends? (seal-check sl-t-chain sl-t-rh 250 [(sl-t-hex (sl-t-box 1))]) "revoked")
      (ends? (seal-check sl-t-chain sl-t-rh 250 [(sl-t-hex (sl-t-cell 1))]) "revoked")
      (string? (seal-check "" sl-t-rh 250 ()))
      (string? (seal-check sl-t-chain "nope" 250 ())))
; a card signed by a key the next card does not carry
(test (: c (seal-card sl-t-other (sl-t-fields "g-05@tau" "cell" sl-t-cell 200 300))
         (ends? (sl-t-why (c + "\n" + sl-t-boxc)) "not signed by the next")))
; a box cannot vouch for another box's sessions, nor a cell sign at all
(test (: c (seal-card sl-t-box (sl-t-fields "g-05@six" "cell" sl-t-cell 200 300))
         (ends? (sl-t-why (c + "\n" + sl-t-boxc)) "names another box"))
      (: c (seal-card sl-t-cell (sl-t-fields "x@g-05@tau" "cell" sl-t-other 200 300))
         (ends? (sl-t-why (c + "\n" + sl-t-chain)) "not signed by the next")))
; a field named twice, a line without a value, a missing field
(test (ends? (sl-t-why (sl-t-sub sl-t-boxc "kind box\n" "kind box\nkind cell\n")) "twice")
      (ends? (sl-t-why (sl-t-sub sl-t-boxc "kind box\n" "kind\n")) "`key value`")
      (: c (seal-card sl-t-root (filter (f \ <f != "expires") (sl-t-fields "tau" "box" sl-t-box 100 900)))
         (ends? (sl-t-why c) "lacks a field")))

(puts "seals: ok\n")
