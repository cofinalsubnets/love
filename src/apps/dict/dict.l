; src/apps/dict/dict.l -- dictd's databases, read as dictd reads them, and RFC 2229's protocol.
; an index is lines of headword, offset and length (dictd's base64), sorted by dictd's key and
; bisected on disk; the text is plain, or a dictzip: a gzip whose extra field "RA" lists its
; chunks, each a deflate run ended by a full flush, so each inflates alone
;   (dict-db name index data)   -> a database: its flags, short name and chunks read
;   (dict-find db word strat)   -> [[headword offset length] ..], strat 'exact or 'prefix
;   (dict-text db off len)      -> a definition's bytes
;   (dict-session dbs host id)  -> [banner reply]: (reply line) -> [text quit?]
(module 'dict
(borrow '(bytes posix text gz))
(:
   ; --- the index -------------------------------------------------------------
   b64 "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   b64v (foldl (\ t i (pin t (b64 i) i)) {} ^64)
   (dict-num s) (foldl (\ n i (n * 64 + peep b64v (s i) 0)) 0 ^#s)
   ; dictd's key: lower case, and but for a database that keeps every character, letters,
   ; digits and spaces alone. a byte no character wears stays
   (dict-key db s)
    (: o (jug 0) all (db 'all) u8 (db 'utf8)
       (keep? c) (all || c = 32 || cpis "alnum" c)
       (go k) (#s <= k ? (slurp o)
               (: c (s k) m (c < 128 || !u8 ? 1 (cpn s k))
                  (? (m < 1 || c >= 128 && !u8) (put o c, go (k + 1))
                     (: u (c < 128 ? c (cpat s k))
                        (keep? u ? (say o (utf8 (cplower u))) 0, go (k + m))))))
       (go 0))
   find fsub
   (rd p off n) (uread-at p off n @ r (two? r ? <>r ""))
   ; the line opening at p -> [text next], () past the end
   (line-at db p)
    (: ix (db 'index) n (db 'size)
       (go w) (rd ix p w @ b (: k (find b "\n" 0)
                                (? (0 <= k) [(snip b 0 k) (p + k + 1)]
                                   (n <= p + #b) [b n]
                                   (go (w * 4)))))
       (p < n ? (go 512) ()))
   ; the first line opening at or past p
   (start-at db p)
    (: ix (db 'index) n (db 'size)
       (go q) (rd ix q 512 @ b (: k (find b "\n" 0)
                                  (? (0 <= k) (q + k + 1) (n <= q + #b) n (go (q + #b)))))
       (p <= 0 ? 0 (go (p - 1))))
   (fields l) (split "\t" l @ [h o n] [h (dict-num o) (dict-num n)] _ ())
   ; the first line whose key is q's or past it
   (lbound db q)
    (: n (db 'size)
       (go lo hi) (? (hi <= lo) (start-at db lo)
                     (: mid ((lo + hi) // 2) s (start-at db mid)
                        (? (n <= s) (go lo mid)
                           (line-at db s @ [l _] (dict-key db (<(split "\t" l)) < q ? (go (mid + 1) hi) (go lo mid))))))
       (go 0 n))
   (dict-find db w strat)
    (: q (dict-key db w)
       (hit? k) (strat = 'exact ? (k = q) (starts? k q))
       (go p acc) (line-at db p @
                    [l nx] (: f (fields l) k (dict-key db <f)
                              (hit? k ? (go nx (f . acc)) (rev acc)))
                    _ (rev acc))
       (go (lbound db q) ()))

   ; --- the text ----------------------------------------------------------------
   ; a dictzip's chunks -> [chunk-length [their offsets, the end last]], () for a plain text
   (dz-head p)
    (: h (rd p 0 12)
       (? (#h < 12 || h 0 != 31 || h 1 != 139 || !(h 3 & 4)) ()
          (: xl (rdle h 10 2) x (rd p 12 xl) flg (h 3)
             (ra i) (? (#x < i + 4) ()
                       (x i = 82 && x (i + 1) = 65) (i + 4)
                       (ra (i + 4 + rdle x (i + 2) 2)))
             a (ra 0)
             (? (a = ()) ()
                (: cl (rdle x (a + 2) 2) cn (rdle x (a + 4) 2)
                   tl (rd p (12 + xl) 4096)
                   (nul i) (find tl (string [0]) i @ k (k < 0 ? i (k + 1)))
                   i1 (flg & 8 ? (nul 0) 0) i2 (flg & 16 ? (nul i1) i1) i3 (flg & 2 ? (i2 + 2) i2)
                   d0 (12 + xl + i3)
                   st (rev (foldl (\ acc k ((<acc + rdle x (a + 6 + 2 * k) 2) . acc)) [d0] ^cn))
                   [cl (star-tray [#st] st)])))))
   ; a chunk ends at a full flush; an empty final block makes it a whole deflate stream
   (dz-chunk raw cl) (gz-inflate (raw + string [3 0]) cl @ r (two? r ? <>r ""))
   (dict-text db off len)
    (db 'zip @ () (rd (db 'data) off len)
               [cl st] (: a (off // cl) b ((off + len - 1) // cl)
                          s0 (st a) raw (rd (db 'data) s0 (st (b + 1) - s0))
                          txt (cats (map (k \ dz-chunk (snip raw (st k - s0) (st (k + 1) - s0)) cl)
                                         (map (+ a) ^(b - a + 1))))
                          (snip txt (off - a * cl) (off - a * cl + len))))

   ; --- a database --------------------------------------------------------------
   (holds? db w) (two? (dict-find db w 'exact))
   ; a 00-database entry's text, a first line that is its headword off
   (meta db w) (dict-find db w 'exact @
                 ([_ o n] . _) (dict-text db o n @ t (: k (find t "\n" 0)
                                                      (k < 0 || dict-key db (strip (snip t 0 k)) != dict-key db w ? t
                                                         (snip t (k + 1) #t))))
                 _ "")
   (dict-db name ix data)
    (: db {'name name 'index ix 'data data 'all 1 'utf8 1
           'size (stat ix @ s (two? s ? <s 0)) 'zip (dz-head data)}
       all (holds? db "00-database-allchars")
       _ (pins db 'all all 'utf8 0)
       _ (pin db 'utf8 (holds? db (all ? "00-database-utf8" "00databaseutf8")))
       (pins db 'short (strip (meta db (all ? "00-database-short" "00databaseshort")))
                'info (all ? "00-database-info" "00databaseinfo")))

   ; --- the protocol ------------------------------------------------------------
   ; a command's words: spaces part them, "" and '' quote, a backslash takes the next byte
   (dict-args s)
    (: n #s
       (go k q cur acc) (? (n <= k) (rev (cur = () ? acc (string (rev cur) . acc)))
                           (: c (s k)
                              (? (c = 92 && k + 1 < n) (go (k + 2) q (s (k + 1) . (cur || [])) acc)
                                 (q && c = q) (go (k + 1) 0 (cur || []) acc)
                                 q (go (k + 1) q (c . cur) acc)
                                 (c = 34 || c = 39) (go (k + 1) c (cur || []) acc)
                                 (c = 32 || c = 9) (go (k + 1) 0 () (cur = () ? acc (string (rev cur) . acc)))
                                 (go (k + 1) 0 (c . cur) acc))))
       (go 0 0 () ()))
   (crlf l) (l + "\r\n")
   ; a text as the protocol carries it: crlf lines, a dot doubled where one opens a line
   (body t) (: ls (lines t)
               (cats (map (l \ crlf (starts? l "." ? ("." + l) l)) ls)))
   (q s) ("\"" + s + "\"")
   strats [["exact" "Match headwords exactly"] ["prefix" "Match prefixes"]]
   help (unlines ["DEFINE database word         -- look up word in database"
                  "MATCH database strategy word -- match word in database using strategy"
                  "SHOW DB                      -- list all accessible databases"
                  "SHOW DATABASES               -- list all accessible databases"
                  "SHOW STRAT                   -- list available matching strategies"
                  "SHOW STRATEGIES              -- list available matching strategies"
                  "SHOW INFO database           -- provide information about the database"
                  "SHOW SERVER                  -- provide site-specific information"
                  "OPTION MIME                  -- use MIME headers"
                  "CLIENT info                  -- identify client to server"
                  "STATUS                       -- display timing information"
                  "HELP                         -- display this help information"
                  "QUIT                         -- terminate connection"])
   (dict-session dbs host id)
    (: st {'mime 0 'd 0 'm 0}
       (stats _) "[d/m/c = \(st 'd)/\(st 'm)/0; 0.000r 0.000u 0.000s]"
       (byname n) (filter (db \ db 'name = n) dbs)
       ; the databases a name picks: * every one, ! the first with a hit, else by name
       (pick n f) (? (n = "*") (map (db \ [db (f db)]) dbs)
                     (n = "!") (: (go l) (? (atom? l) () (f <l @ h (two? h ? [[<l h]] (go >l)))) (go dbs))
                     (byname n @ [db] [[db (f db)]] _ 'none))
       (bad _) "550 invalid database, use SHOW DB for list"
       ; a text's first line, and under OPTION MIME its empty header
       (head l) (crlf l + (st 'mime ? "\r\n" ""))
       (define n w)
        (pick n (db \ dict-find db w 'exact) @
          'none (crlf (bad 0))
          got (: hs (cats (map (x \ map (h \ [<x h]) (x 1)) got))
                 (? (!(two? hs)) (crlf "552 no match \(stats 0)")
                    (: _ (pin st 'd (st 'd + #hs))
                       (crlf "150 \(#hs) definitions retrieved"
                        + cats (map (\ [db [hw o n]]
                                       (head "151 \(q hw) \(db 'name) \(q (db 'short))"
                                        + body (dict-text db o n) + crlf "."))
                                    hs)
                        + crlf "250 ok \(stats 0)")))))
       (match n s w)
        (? (!(elem s ["exact" "prefix" "."])) (crlf "551 invalid strategy, use SHOW STRAT for a list")
           (pick n (db \ uniq (map cap (dict-find db w (s = "exact" ? 'exact 'prefix)))) @
             'none (crlf (bad 0))
             got (: hs (cats (map (x \ map (h \ [<x h]) (x 1)) got))
                    (? (!(two? hs)) (crlf "552 no match \(stats 0)")
                       (: _ (pin st 'm (st 'm + #hs))
                          (head "152 \(#hs) matches found"
                           + cats (map (\ [db hw] (crlf "\(db 'name) \(q hw)")) hs)
                           + crlf "." + crlf "250 ok \(stats 0)"))))))
       (listing code what rows) (head "\(code) \(#rows) \(what)" + cats (map crlf rows) + crlf "." + crlf "250 ok")
       (show a)
        (a @ ["db"] (two? dbs ? (listing 110 "databases present" (map (db \ "\(db 'name) \(q (db 'short))") dbs))
                       (crlf "554 no databases present"))
             ["databases"] (show ["db"])
             ["strat"] (listing 111 "strategies present" (map (\ [n d] "\(n) \(q d)") strats))
             ["strategies"] (show ["strat"])
             ["info" n] (byname n @ [db] (head "112 information for \(n)" + body ("============ \(n) ============\n" + meta db (db 'info) + "\n") + crlf "." + crlf "250 ok")
                                    _ (crlf (bad 0)))
             ["server"] (head "114 server information" + body "love dict on \(host)" + crlf "." + crlf "250 ok")
             _ (crlf "501 syntax error, illegal parameters"))
       (reply l)
        (: a (dict-args (l @ (t + "\r") t l))
           (lower (<a || "") @
             "define" (#a = 3 ? [(define (a 1) (a 2)) 0] [(crlf "501 syntax error, illegal parameters") 0])
             "match"  (#a = 4 ? [(match (a 1) (a 2) (a 3)) 0] [(crlf "501 syntax error, illegal parameters") 0])
             "show"   [(show (map lower >a)) 0]
             "client" [(crlf "250 ok") 0]
             "status" [(crlf "210 status \(stats 0)") 0]
             "help"   [(head "113 help text follows" + body help + crlf "." + crlf "250 ok") 0]
             "option" (map lower >a @ ["mime"] (: _ (pin st 'mime 1) [(crlf "250 ok - using MIME headers") 0])
                                      _ [(crlf "501 syntax error, illegal parameters") 0])
             "auth"   [(crlf "502 command not implemented") 0]
             "quit"   [(crlf "221 bye \(stats 0)") 1]
             ""       [(crlf "500 unknown command") 0]
             _        [(crlf "500 unknown command") 0]))
       [(crlf "220 \(host) love dict <mime> <\(id)@\(host)>") reply]))
) ; module dict
