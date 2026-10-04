; src/apps/qlog.l -- a queue as a signed log (notes/plan/hive-decentral.md, rung 1). each write is
; an entry: the queue (NAME@BOX, BOX its hub's), its term, seq and prev (the hash of the entry
; before it), when, by whom and through which tool, the hash of the queue's text after it, the
; writer's chain and its sig over all of that. a queue's state is the text of the last entry of
; its longest valid chain; sb keeps the entries as a ledger and the texts as blobs.
;
;   (qlog-make q seq prev by call th seal)   an entry's text, signed by seal [key chain]
;   (qlog-read s)                            an entry's fields as a tablet | () unless canonical
;   (qlog-hash s)                            an entry's name: sha256 of its whole text
;   (qlog-who e)                             the writer as the queue spells it: bare when local
;   (qlog-step prev s before after root revoked)  "" when entry s may follow entry prev (() for
;                                            the first), turning text before into after; else why
;   (qlog-may? before after who)             "" when who may turn text before into after
;   (qlog-trust 0)                           [root revoked]: the lineage this box trusts and the
;                                            keys it no longer does, where bee keeps them
;
; term is 0 until terms (rung 3). an entry is laid out one way only, and a text that is not that
; way is not an entry, so its sig covers exactly what it says.
(module (qlog qlog-make qlog-read qlog-hash qlog-who qlog-step qlog-may? qlog-trust)
(borrow 'posix)

(: ql-hex (cite 'tls 'hex)
   ql-unhex (cite 'tls 'unhex)
   ql-sign (cite 'ssh 'ed-sign)
   ql-verify (cite 'ssh 'ed-verify)
   ql-b64e (cite 'ssh 'b64e)
   ql-b64d (cite 'ssh 'b64d)
   ql-check (cite 'seals 'seal-check)
   ql-keys ["queue" "term" "seq" "prev" "at" "by" "call" "text" "cert"]

   (ql-num? s) (string? s && 0 < #s && #s < 19 && all (c \ 47 < c < 58) (map s ^#s))
   (ql-num s) (foldl (\ a c (a * 10 + c - 48)) 0 (map s ^#s))
   ; a field's value is one plain word: no quote, backslash, space or control byte
   (ql-word? s) (string? s && 0 < #s && all (c \ 32 < c && c < 127 && c != 34 && c != 92) (map s ^#s))
   (ql-body f) (cats (["(entry"] + catmap (k \ [" (" k " \"" (f k) "\")"]) ql-keys + [")"]))
   (ql-signed b) (snip b 0 (#b - 1))                          ; the body less its closing paren
   (qlog-hash s) (sha256 s)

   (qlog-make q seq prev by call th seal)
    (: f {"queue" q "term" "0" "seq" (show seq) "prev" prev "at" (show (clock 0 // 1000)) "by" by
          "call" call "text" th "cert" (ql-b64e (seal 1) 1)}
       b (ql-body f)
       sg (ql-hex (ql-sign <<seal (<seal 1) (ql-signed b)))
       (ql-signed b + " (sig \"" + sg + "\"))"))

   ; the fields, when s is an entry laid out the one way: every key once, in order, then the sig
   (qlog-read s)
    (: k (? (string? s) (fsub s " (sig \"" 0) -1)
       (? (k < 0) ()
          (: r (: b (sound s) (? (two? b) <b))
             ps (? (two? r && <r = 'entry) >r ())
             f (foldl (\ t p (? (two? p && string? <>p && atom? >>p) (pin t (show <p) <>p) t)) {} ps)
             (? (&& (#ps = 10) (all (k \ ql-word? (peep f k ())) (ql-keys + ["sig"]))
                    (ql-num? (f "term")) (ql-num? (f "seq")) (ql-num? (f "at"))
                    (s = ql-signed (ql-body f) + " (sig \"" + f "sig" + "\"))"))
                f))))

   ; the writer as the queue's rows spell it: NAME for a session on the queue's own box, else NAME@BOX
   (qlog-who e)
    (: q (e "queue") by (e "by") k (fsub q "@" 0) bx (? (0 < k) (snip q k #q) "@")
       n #by m #bx
       (? (m < n && snip by (n - m) n = bx) (snip by 0 (n - m)) by))

   ; its place in the chain, its term, its writer's chain and sig, then what it changed
   (qlog-step prev s before after root revoked)
    (: e (qlog-read s) head (? (string? prev) (qlog-read prev))
       (? !(tablet? e) "not an entry"
          (string? prev && !(tablet? head)) "the entry before is not one"
          (ql-step1 e head (? (string? prev) (qlog-hash prev) "none") before after root revoked)))
   (ql-step1 e head hp before after root revoked)
    (: sq (ql-num (e "seq")) t (ql-b64d (e "cert"))
       c (? (string? t) (ql-check t root (ql-num (e "at")) revoked) "no chain")
       (? (tablet? head && head "queue" != e "queue") "an entry of another queue"
          (? (tablet? head) (sq != ql-num (head "seq") + 1) (sq != 0)) "out of place: its seq does not follow"
          (e "prev" != hp) "out of place: its prev is not the entry before"
          (tablet? head && ql-num (e "term") < ql-num (head "term")) "an older term"
          (sha256 after != e "text") "its text is not the one it names"
          !(tablet? c) ("its chain does not check: " + c)
          (c "kind" != "cell" || c "name" != e "by") "its card is not the writer's"
          !(ql-verify (ql-unhex (c "pub")) (ql-signed (ql-body e)) (ql-unhex (e "sig"))) "its sig does not check"
          (qlog-may? before after (qlog-who e))))

   ; the box card's lineage, else the one it enrolled under, else its own root; revoked is the
   ; list bee kept, which it takes only when the root signed it
   (qlog-trust _)
    (: h (getenv "HOME") d ((string? h ? h "/tmp") + "/.love/etc/bee")
       (rd p) (: q (open p "r") (? (hot? q) (: s (slurp q) _ (close q) (s + ""))))
       (field t k) (: ls (filter (l \ starts? l (k + " ")) (lines t)) (? (two? ls) (snip <ls (#k + 1) #<ls)))
       bc (rd (d + "/box.card")) lf (rd (d + "/lineage")) rk ((cite 'seals 'seal-keyread) (d + "/root.key"))
       root (? (string? bc && string? (field bc "lineage")) (field bc "lineage")
               (string? lf && 64 <= #lf) (snip lf 0 64)
               (two? rk) (ql-hex (rk 1)) "")
       rv (: t (rd (d + "/revoked")) (? (string? t) (map (l \ snip l 8 #l) (filter (l \ starts? l "revoked ") (lines t))) ()))
       [root rv])

   ; --- what a writer may change. a text is its lines: the rows by position, and the header by
   ;     kind -- leader, sync, pre, next, mirror, the base line and the # lines ---
   (ql-row? w) (5 < #w && ql-num? <w)
   (ql-kind l)
    (: w (words l)
       (? !(two? w) "" (ql-row? w) "row" (<w 0 = 35) "#" (elem <w ["leader" "sync" "pre" "next" "mirror"]) <w "base"))
   (ql-rows t) (foldl (\ a l (: w (words l) (? (ql-row? w) (pin a <w w) a))) {} (lines t))
   (ql-head t k) (filter (l \ ql-kind l = k) (lines t))
   (ql-leader t) (: l (ql-head t "leader") (? (two? l) (: w (words <l) (? (1 < #w) (w 1) "")) ""))

   (qlog-may? before after who)
    (? !(string? before) ""                                      ; the first: it names its leader
       (who = ql-leader before) ""
       (: ro (ql-rows before) rn (ql-rows after)
          ps (sort (keys (foldl (\ a p (pin a p 1)) (foldl (\ a p (pin a p 1)) {} (keys ro)) (keys rn))))
          mine (filter (p \ (: o (peep ro p ()) n (peep rn p ())
                              ((two? o && o 1 = who) || (two? n && n 1 = who)))) ps)
          gone (filter (p \ (: o (ro p) (two? o && o 1 = who && !(two? (peep rn p ()))))) ps)
          (ok p)
           (: o (peep ro p ()) n (peep rn p ())
              (? (show o = show n) 1
                 (elem p mine) (!(two? n) || !(starts? (n 5) "folded-into-") || (two? o && o 5 = n 5))
                 ; a row folded into one of who's that lands goes with it
                 (&& (two? o) !(two? n) (starts? (o 5) "folded-into-") (elem (snip (o 5) 12 #(o 5)) gone))
                 0))
          bad (filter (p \ !(ok p)) ps)
          (same k) (show (ql-head before k) = show (ql-head after k))
          la (ql-head after "leader")
          (? (two? bad) ("row " + <bad + " is not " + who + "'s to change")
             !(all same ["#" "sync" "pre" "mirror"]) "only the leader edits the header"
             !(same "base" || two? gone) "only the leader, or a landing, moves the base line"
             !(same "leader" || (two? la && words <la = ["leader" who "acting"])) "only the leader hands on the queue"
             "")))
)
) ; module qlog
