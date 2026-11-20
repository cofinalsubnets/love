; src/apps/dict: a small database laid here, plain and as a dictzip of 16-byte chunks, read as
; dictd reads one, and a session's replies as dictd words them
(borrow "src/apps/gz.l")                         ; by path, as love0 bakes none
(borrow "src/apps/dict/dict.l")
(borrow '(bytes gz))

(: d ("out/.dict-law." + show (getpid 0))        ; per process: shards run at once
   _ (mkdir d 493)
   b64 "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (enc n) (n < 64 ? (string [(b64 n)]) (enc (n // 64) + string [(b64 (n % 64))]))
   ; in dictd's key order; Abaddon's index line keeps its case, as moby's does
   es [["00databaseinfo" "00-database-info\nmade by a law\n"]
       ["00databaseshort" "00-database-short\n     A Law's Dictionary\n"]
       ["a cappella" "a cappella\nwithout instruments\n"]
       ["Abaddon" "Abaddon\nthe pit\n"]
       ["abandon" "abandon\nto leave\n.a dot opens this line\n"]
       ["abandon" "abandon\nto give up\n"]
       ["bath" "BATH, n.\n"]]
   text (cats (map (e \ e 1) es))
   ix (cats (rev (<(foldl (\ [acc o] [h t] [(h + "\t" + enc o + "\t" + enc #t + "\n" . acc) (o + #t)]) [() 0] es))))
   ; a dictzip: each chunk a stored block, not the last, as a full flush leaves one
   cl 16
   cks (map (k \ snip text (k * cl) (k * cl + cl)) ^((#text + cl - 1) // cl))
   zs (map (c \ string [0] + wrle #c 2 + wrle (65535 - #c) 2 + c) cks)
   ex ("RA" + wrle (6 + 2 * #zs) 2 + wrle 1 2 + wrle cl 2 + wrle #zs 2 + cats (map (z \ wrle #z 2) zs))
   dz (string [31 139 8 12 0 0 0 0 0 3] + wrle #ex 2 + ex + "law.dict" + string [0] + cats zs
       + wrle (gz-crc32 text) 4 + wrle #text 4)
   _ (uwrite (d + "/law.index") ix) _ (uwrite (d + "/law.dict") text) _ (uwrite (d + "/law.dict.dz") dz)
   pl (dict-db "law" (d + "/law.index") (d + "/law.dict"))
   zd (dict-db "lawz" (d + "/law.index") (d + "/law.dict.dz"))
   (defs db w s) (map (\ [h o n] [h (dict-text db o n)]) (dict-find db w s))
   (ms w s) (dict-match pl w s)
   ; a session: each line's reply, the stats taken off
   (talk ls) (dict-session [pl zd] "box" "7" @ [b r]
               [b (map (l \ (r l @ [t q] [(t @ (a + " [d/m/c" + _ + "]\r\n") (a + "\r\n") t) q])) ls)])
   s (talk ["DEFINE law abaddon" "define law \"A Cappella\"" "DEFINE law nothing" "DEFINE none x"
            "MATCH law prefix ab" "MATCH * exact bath" "MATCH law nope x" "SHOW DB" "SHOW INFO law"
            "OPTION MIME" "DEFINE lawz bath" "MATCH ! . bat" "DEFINE" "FOO" "QUIT"])
   rs (s 1) (re k) (<(rs k))
   _ (test
      ; the key: case folded, but for letters, digits and spaces nothing kept
      (dict-key pl "A-Cap'pella!" = "acappella") (dict-key pl "Über Fuß" = "Über fuß")
      (dict-key {'all 0 'utf8 1} "Über-Fuß" = "überfuß") (dict-key {'all 1 'utf8 1} "Über-Fuß" = "über-fuß")
      (dict-num "A" = 0) (dict-num "B/" = 127) (dict-num (enc 123456) = 123456)
      ; the database's flags and short name, its headword line off
      (pl 'all = 0) (pl 'utf8 = 0) (pl 'short = "A Law's Dictionary") (zd 'short = "A Law's Dictionary")
      ; exact and prefix by bisection on the index, the text the same plain and zipped
      (map cap (dict-find pl "ABANDON" 'exact) = ["abandon" "abandon"])
      (map cap (dict-find pl "ab" 'prefix) = ["Abaddon" "abandon" "abandon"])
      (map cap (dict-find pl "a" 'prefix) = ["a cappella" "Abaddon" "abandon" "abandon"])
      (dict-find pl "abandonment" 'exact = ()) (dict-find pl "c" 'prefix = ())
      (defs pl "a cappella" 'exact = [["a cappella" "a cappella\nwithout instruments\n"]])
      (defs zd "abandon" 'prefix = defs pl "abandon" 'prefix)
      (defs zd "bath" 'exact = [["bath" "BATH, n.\n"]])
      (map (\ [h t] t) (defs zd "0" 'prefix) = [<>(es 0) <>(es 1)])
      ; the scanning strategies, each headword once
      (ms "and" "substring" = ["abandon"]) (ms "ON" "suffix" = ["Abaddon" "abandon"])
      (ms "^A.*N$" "re" = ["Abaddon" "abandon"]) (ms "ba\\(d\\|t\\)" "regexp" = ["Abaddon" "bath"]) (ms "^$" "re" = ())
      (ms "abadon" "soundex" = ["Abaddon"]) (ms "abandn" "lev" = ["abandon"]) (ms "cappella" "word" = ["a cappella"])
      (ms "a" "first" = ["a cappella"]) (ms "cappella" "last" = ["a cappella"]) (ms "a" "last" = ())
      ; the keys' search refuses a hit in an offset's digits, and a word with a space in it
      (all (c \ ms c "substring" = uniq (filter (h \ 0 <= fsub (dict-key pl h) c 0) (map cap es)))
           (map (i \ string [i]) (cats [(map (+ 97) ^26) (map (+ 48) ^10)])))
      (ms "a cappella" "word" = ()) (ms "a cappella" "first" = ()) (ms " abadon" "soundex" = ["Abaddon"])
      ; nprefix skips and counts the index's lines, not its headwords
      (ms "1#2#ab" "nprefix" = ["abandon"]) (ms "ab" "nprefix" = ms "ab" "prefix") (ms "x#ab" "nprefix" = ())
      (dict-soundex "Robert" = "R163") (dict-soundex "Pfister" = "P236") (dict-soundex "  bath" = "B300")
      (dict-soundex "Ashcraft" = "A226") (dict-soundex "" = "")
      (dict-lev1 "ab" ["x" "y"] 0 = ["ba" "abx" "aby" "b" "xab" "xb" "yab" "yb" "a" "axb" "ax" "ayb" "ay"])
      (dict-lev1 "aa" ["a"] 1 = ["aaa" "a" "aa"])
      ; the protocol
      (has? <s "220 box love dict <mime> <7@box>\r\n")
      (re 0 = "150 1 definitions retrieved\r\n151 \"Abaddon\" law \"A Law's Dictionary\"\r\nAbaddon\r\nthe pit\r\n.\r\n250 ok\r\n")
      (has? (re 1) "151 \"a cappella\" law ")
      (re 2 = "552 no match\r\n") (re 3 = "550 invalid database, use SHOW DB for list\r\n")
      (re 4 = "152 2 matches found\r\nlaw \"Abaddon\"\r\nlaw \"abandon\"\r\n.\r\n250 ok\r\n")
      (re 5 = "152 2 matches found\r\nlaw \"bath\"\r\nlawz \"bath\"\r\n.\r\n250 ok\r\n")
      (re 6 = "551 invalid strategy, use SHOW STRAT for a list\r\n")
      (re 7 = "110 2 databases present\r\nlaw \"A Law's Dictionary\"\r\nlawz \"A Law's Dictionary\"\r\n.\r\n250 ok\r\n")
      (re 8 = "112 information for law\r\n============ law ============\r\nmade by a law\r\n\r\n.\r\n250 ok\r\n")
      (re 9 = "250 ok - using MIME headers\r\n")
      (re 10 = "150 1 definitions retrieved\r\n151 \"bath\" lawz \"A Law's Dictionary\"\r\n\r\nBATH, n.\r\n.\r\n250 ok\r\n")
      (re 11 = "152 1 matches found\r\n\r\nlaw \"bath\"\r\n.\r\n250 ok\r\n")
      (re 12 = "501 syntax error, illegal parameters\r\n") (re 13 = "500 unknown command\r\n")
      (rs 14 = ["221 bye\r\n" 1]) (all (r \ r 1 = 0) (take 14 rs))
      ; a dot opening a line is doubled; quotes part a command's words, a backslash and its byte kept
      (has? (<(talk ["DEFINE law \"abandon\""] 1 0)) "\r\n..a dot opens this line\r\n")
      (dict-args "DEFINE 'a b' \"c \\\"d\\\"\" e\\ f" = ["DEFINE" "a b" "c \\\"d\\\"" "e\\ f"]))
   (hark ["rm" "-rf" d]))
