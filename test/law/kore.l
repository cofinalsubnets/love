; test/law/kore.l -- the kore laws: diffs against an lcs oracle with a seeded fuzz, the tool
; floors to their GNU faces, the regex floor by hand, a seeded fuzz over bc's algebra

; --- the classic: Myers' own worked example, D = 5 ---
(: A '(a b c a b b a) B '(c b a b a c) s (myers A B)
   (test
      (dold s = A) (dnew s = B)
      (dcost s = 5)))                                       ; the paper's shortest path

; --- the edges: empties, equal, disjoint, a lone keep ---
(: s1 (myers () '(1 2)) s2 (myers '(1 2) ()) s3 (myers '(1 2 3) '(1 2 3)) s4 (myers '(1 2) '(3 4))
   (test
      !(myers () ())
      (dnew s1 = '(1 2)) !(dold s1) (dcost s1 = 2)
      (dold s2 = '(1 2)) !(dnew s2) (dcost s2 = 2)
      (dold s3 = '(1 2 3)) (dnew s3 = '(1 2 3)) (dcost s3 = 0)
      (dcost s4 = 4)
      (myers '(1) '(1) = '((keep 1)))
      (dcost (myers '(a) '(b)) = 2)
      (dcost (myers '(x a b c) '(a b c y)) = 2)))

; --- the seeded fuzz: dcost = n + m - 2*lcs, and the projections spell the inputs back ---
(: (lcslen a b)
    (: ax (dindex a) bx (dindex b) n #a m #b
       t {}
       (get i j) (i < 1 || j < 1 ? 0 (peep t (i * 4096 + j) 0))
       (goj i j) (m < j ? ()
                    ((ax (i - 1) = bx (j - 1) ? (1 + get (i - 1) (j - 1))
                        (: u (get (i - 1) j) w (get i (j - 1)) (u < w ? w u))) @ v
                     (pin t (i * 4096 + j) v,
                      goj i (j + 1))))
       (goi i) (n < i ? (get n m) (goj i 1, goi (i + 1)))
       (goi 1))
   (rlist i st acc) (i < 1 ? [acc st]                       ; a random list over 1..4, and the state
                       (random st 4 @ r (rlist (i - 1) >r ((1 + <r) . acc))))
   (fz i st)
    (i < 1 ? 'ok
       (: r1 (random st 8) r2 (random >r1 8)
          la (rlist <r1 >r2 ())
          lb (rlist <r2 <>la ())
          a <la b <lb
          s (myers a b)
          ok (dold s = a && dnew s = b
                 && dcost s = #a + #b - 2 * lcslen a b)
          (ok ? (fz (i - 1) <>lb) ['broke a b])))
   r (fz 100 (wheel 7))
   (test (r = 'ok)))

; --- patience: projections hold, never below myers, unique-in-both lines land as keeps ---
(: (keeps s) (map caup (filter (o \ <o = 'keep) s))
   A '(a b c a b b a) B '(c b a b a c)
   s (patience A B)                                             ; no unique-both line here ...
   mv (patience '(h1 b1 b2 h2 c1 c2) '(h2 c1 c2 h1 b1 b2))      ; a moved block, all lines unique
   x (patience '(u1 u2) '(u2 u1))                               ; crossing anchors: lis keeps one
   st (patience '("a" "b" "c") '("b" "c" "d"))                  ; string lines census structurally
   tr (patience '((1 2) (3 4)) '((3 4) (5 6)))                  ; ... and whole trees do too
   eq (patience '(1 2 3) '(1 2 3))
   (test
      (dold s = A) (dnew s = B) (dcost s = 5)                   ; ... so patience = the myers floor
      (dold mv = '(h1 b1 b2 h2 c1 c2)) (dnew mv = '(h2 c1 c2 h1 b1 b2))
      (#(keeps mv) = 3) (dcost mv = 6)                          ; one block anchors whole, the other moves
      (dcost x = 2) (dold x = '(u1 u2)) (dnew x = '(u2 u1))
      (dold st = '("a" "b" "c")) (dnew st = '("b" "c" "d")) (dcost st = 2)
      (keeps tr = '((3 4))) (dcost tr = 2)
      (dcost eq = 0) (keeps eq = '(1 2 3))
      !(patience () ()) (dnew (patience () '(1 2)) = '(1 2))
      (dold (patience '(1 2) ()) = '(1 2))))

; --- the patience fuzz: a wider alphabet so anchors occur; dcost(patience) >= dcost(myers) ---
(: (rlist2 i st acc) (i < 1 ? [acc st]
                        (random st 12 @ r (rlist2 (i - 1) >r ((1 + <r) . acc))))
   (fzp i st)
    (i < 1 ? 'ok
       (: r1 (random st 11) r2 (random >r1 11)
          la (rlist2 <r1 >r2 ())
          lb (rlist2 <r2 <>la ())
          a <la b <lb
          sp (patience a b)
          ok (dold sp = a && dnew sp = b
                 && !(dcost sp < dcost (myers a b)))
          (ok ? (fzp (i - 1) <>lb) ['broke a b])))
   r (fzp 100 (wheel 11))
   (test (r = 'ok)))

; --- lines/unlines: exact round trip on terminated texts; an unterminated tail gains its newline ---
(: t "a\nb\n" u "a\n\nb\n"
   (test
      (lines t = '("a" "b")) (unlines '("a" "b") = t)
      (unlines (lines t) = t) (unlines (lines u) = u)
      !(lines "") !(unlines ())
      (#(lines "\n") = 1) (unlines (lines "\n") = "\n")
      (#(lines u) = 3)
      (lines "a\nb" = '("a" "b")) (unlines (lines "a\nb") = t)))       ; the one normalization

; --- unified hunks to the byte: context merges a narrow gap, splits a wide one, empty side -0,0 ---
(: at "a\nb\nc\nd\ne\nf\ng\nh\ni\n"
   d1 (udiff "old" "new" at "a\nb\nC\nd\ne\nf\ng\nH\ni\n")       ; two changes, gap 4 <= 2*3: one hunk
   x1 "--- old\n+++ new\n@@ -1,9 +1,9 @@\n a\n b\n-c\n+C\n d\n e\n f\n g\n-h\n+H\n i\n"
   s2 (uhunks (patience (lines at) (lines "a\nb\nC\nd\ne\nf\nG\nh\ni\n")) 1)   ; gap 3 > 2*1: two hunks
   x2 "@@ -2,3 +2,3 @@\n b\n-c\n+C\n d\n@@ -6,3 +6,3 @@\n f\n-g\n+G\n h\n"
   (test
      (d1 = x1) (s2 = x2)
      !(udiff "a" "b" at at)
      (udiff "a" "b" "" "x\n" = "--- a\n+++ b\n@@ -0,0 +1 @@\n+x\n")
      (udiff "a" "b" "x\n" "" = "--- a\n+++ b\n@@ -1 +0,0 @@\n-x\n")))

; --- the u-floor (u.l): the line tools' pure helpers to their GNU faces ---
(: (test
      (uatoi "42" = 42) (uatoi "-7" = -7) (uatoi "0" = 0)
      (upad 7 "2" = "      2") (upad 1 "34" = "34")                ; a wider count never shrinks
      (ujoin '("a" "b" "c") = "a b c") (ujoin () = "")
      (uhead 2 "a\nb\nc\n" = "a\nb\n") (uhead 9 "a\nb\n" = "a\nb\n")
      !(uhead 0 "a\n")
      (utail 2 "a\nb\nc\n" = "b\nc\n") (utail 9 "a\nb\n" = "a\nb\n")
      ; a clip reaching the last line ends as the source did; one cut before it ends terminated
      (nl-end? "a\n") !(nl-end? "a") !(nl-end? "")
      (chomp "a\n" = "a") (chomp "a" = "a") (chomp "" = "")
      (uhead 9 "a\nb" = "a\nb") (uhead 1 "a\nb" = "a\n")
      (utail 9 "a\nb" = "a\nb") (utail 1 "a\nb" = "b")
      (ucount "a b\nc\n" = '(2 3 6)) (ucount "" = '(0 0 0))        ; (lines words bytes)
      (ucount "  a  b  " = '(0 2 8))                               ; a word is a maximal ink run
      ; wc -m: valid characters only, and one torn across two gulps counts once
      (ucharc-go ucharc0 "日本\n" = '(3 ""))
      (ucharc-go ucharc0 "a\xffb\xc0\x80" = '(2 ""))               ; a bad byte, an overlong
      (ucharc-go ucharc0 "a\xe6\x97" = '(1 "\xe6\x97"))            ; the torn tail is held
      (ucharc-go (ucharc-go ucharc0 "a\xe6\x97") "\xa5b" = '(3 ""))
      (ubase "/a/b.txt" "" = "b.txt") (ubase "/a/b.txt" ".txt" = "b")
      (ubase "/a/b/" "" = "b") (ubase "///" "" = "/")
      (ubase "b" "b" = "b")                                        ; the suffix never eats the whole name
      (udir "/a/b" = "/a") (udir "a" = ".") (udir "/" = "/")
      (udir "a/" = ".") (udir "/a/b/" = "/a")
      (words " a  bb\tc\n" = '("a" "bb" "c"))
      (words "x" = '("x"))
      !(words "  \n") !(words "")))

; --- the field floor: usplit keeps the empty tail (cut's face), uset reads tr's sets ---
(: (test
      (usplit 58 "a:b:c" = '("a" "b" "c"))
      (usplit 58 "a:" = '("a" ""))
      (usplit 58 "" = '(""))
      (ujoinc 58 '("a" "" "c") = "a::c")
      (ujoinc 58 '("a" "b") = ("a" + (":" + "b")))
      (uspec "1,3-5,7-,-2" = '((1 1) (3 5) (7 536870911) (1 2)))
      (upick '((2 4)) 3) (upick '((2 4)) 2) (upick '((2 4)) 4)
      !(upick '((2 4)) 5) !(upick '((2 4)) 1) !(upick () 1)
      (uset "a-c" = '(97 98 99))
      (uset "abc" = '(97 98 99))
      (uset "x-" = '(120 45)) (uset "-x" = '(45 120))              ; an edge dash stays literal
      (uset "\\n\\t" = '(10 9))
      (uset "α-γ日" = '(945 946 947 26085))                         ; code points, ranges too
      (uset "\\日-" = '(26085 45))))

; --- the column floor (core.l): ucol first, then fold, expand and unexpand over it ---
(: (test
      (ucol 0 9 8 = 8) (ucol 1 9 8 = 8) (ucol 8 9 8 = 16)           ; a tab lands on the stop
      (ucol 3 9 4 = 4) (ucol 4 9 4 = 8)
      (ucol 5 8 8 = 4) (ucol 0 8 8 = 0)                             ; \b never walks past 0
      (ucol 7 13 8 = 0) (ucol 2 97 8 = 3)
      (ufold 4 0 0 "abcdefghij" = '("abcd" "efgh" "ij"))
      (ufold 4 0 0 "abcd" = '("abcd")) (ufold 4 0 0 "" = '(""))
      (ufold 6 1 0 "aaa bbb ccc" = '("aaa " "bbb " "ccc"))           ; -s backs up to the blank
      (ufold 8 0 0 "a\tbcdefgh" = '("a\t" "bcdefgh"))                ; the tab fills to the stop
      (ufold 4 0 1 "ab\tcd" = '("ab\tc" "d"))                        ; -b counts the bytes instead
      (ucol 2 26085 8 = 4) (ucol 2 769 8 = 2)                       ; wide two, combining none
      (ufold 4 0 0 "日本語日本語" = '("日本" "語日" "本語"))
      (ufold 3 0 0 "a日本" = '("a日" "本"))                          ; a wide one never splits
      (uexpand 8 0 "日\tx" = "日      x") (uexpand 8 0 "é\tx" = "é       x")
      (uunexpand 8 1 "日本語  x" = "日本語\tx")
      (uexpand 8 0 "a\tb" = "a       b") (uexpand 4 0 "a\tb" = "a   b")
      (uexpand 8 0 "\tx" = "        x")
      (uexpand 8 1 "\ta\tb" = "        a\tb")                        ; -i stops at the first ink
      (uunexpand 8 1 "        a       b" = "\ta\tb")
      (uunexpand 8 1 "abcdefg x" = "abcdefg x")                      ; one space saves nothing
      (uunexpand 8 1 "abcdef  x" = "abcdef\tx")                      ; two of them reach the stop
      (uunexpand 8 0 "   \tab   cd" = "\tab   cd")                   ; no -a: the lead alone
      (uunexpand 8 1 "a        " = "a\t ")))                         ; a trailing run is a run

; --- tac, the encodings and factor (core.l) ---
(: (test
      ; the newline rides its line: an unterminated last line comes back first, unterminated
      (utac "a\nb\nc\n" = '("c\n" "b\n" "a\n"))
      (utac "x\ny" = '("y" "x\n"))
      !(utac "")
      (ubenc ub64set 6 "hello world" = "aGVsbG8gd29ybGQ=")
      (ubenc ub64set 6 "a" = "YQ==") (ubenc ub64set 6 "ab" = "YWI=")
      (ubenc ub64set 6 "abc" = "YWJj") !(ubenc ub64set 6 "")
      (ubenc ub32set 5 "hello" = "NBSWY3DP") (ubenc ub32set 5 "a" = "ME======")
      (ubdec ub64set 6 "aGVsbG8gd29ybGQ=" = '(1 "hello world"))
      (ubdec ub64set 6 "YQ==" = '(1 "a")) (ubdec ub32set 5 "NBSWY3DP" = '(1 "hello"))
      (ubdec ub64set 6 "aGVs\nbG8=" = '(1 "hello"))                 ; a newline is ignored
      !(ubdec ub64set 6 "aG!s")                                      ; anything else is not
      (ubwrap 4 "abcdefg" = "abcd\nefg\n") (ubwrap 0 "ab" = "ab")       ; -w 0 closes nothing
      !(ubwrap 4 "") !(ubwrap 0 "")
      (ufactor 97 = '(97)) (ufactor 100 = '(2 2 5 5))
      (ufactor 1234567 = '(127 9721)) (ufactor 2 = '(2))
      !(ufactor 1) !(ufactor 0)))

; --- the fs floor (fs.l): uoct reads chmod's octal, rp-parts the components realpath walks ---
(: (test
      (uoct "755" = 493) (uoct "644" = 420) (uoct "0" = 0) (uoct "7" = 7)
      (rp-parts "/a//b/" = '("a" "b")) (rp-parts "a" = '("a")) !(rp-parts "///")))

; --- the record floor (core.l): paste's delimiters, split's suffixes and sizes, join, od ---
(: (test
      (udels ":|" = '(":" "|"))
      (udels "\\t" = '("\t")) (udels "\\0" = '(""))       ; POSIX's \0 is the empty one
      (udels "" = '(""))
      (usfx 0 2 0 = "aa") (usfx 1 2 0 = "ab") (usfx 26 2 0 = "ba")
      (usfx 675 2 0 = "zz") (usfx 0 3 0 = "aaa")
      (usfx 0 2 1 = "00") (usfx 9 2 1 = "09") (usfx 10 2 1 = "10")
      (usize "1000" = 1000) (usize "2K" = 2048) (usize "1M" = 1048576)
      (ujfs () "  a   1  " = '("a" "1"))                  ; blank runs, the edges dropped
      (ujfs () "" = ()) (ujfs 58 "a:b:" = '("a" "b" ""))
      (unth '("a" "b") 2 = "b") !(unth '("a" "b") 3) !(unth '("a") 0)
      (zpad 3 "7" = "007") (zpad 1 "77" = "77")
      (radix 255 16 = "ff") (radix 255 8 = "377")
      (uodesc 10 = "\\n") (uodesc 0 = "\\0") (uodesc 92 = "\\") (uodesc 65 = "A")
      (uodesc 1 = "001") (uodesc 255 = "377") (uodesc 127 = "177")
      (uodname 10 = "nl") (uodname 32 = "sp") (uodname 127 = "del")
      (uodname 255 = "del") (uodname 65 = "A")            ; -ta masks the high bit
      (uodtype "x1" = '(x 1 2)) (uodtype "o2" = '(o 2 6)) (uodtype "d4" = '(d 4 11))
      (uodtype "u1" = '(u 1 3)) (uodtype "c" = '(c 1 3)) !(uodtype "q")))

; --- the report floor (fs.l): stat's mode and timestamp, du's human face (rounded up, GNU's rule) ---
(: (test
      (ust-perm 33188 = "-rw-r--r--") (ust-perm 16877 = "drwxr-xr-x")
      (ust-perm 41471 = "lrwxrwxrwx") (ust-perm 36333 = "-rwsr-sr-x")
      (ust-perm 33261 = "-rwxr-xr-x") (ust-perm 17407 = "drwxrwxrwt")
      (ust-kind 33188 10 = "regular file") (ust-kind 33188 0 = "regular empty file")
      (ust-kind 16877 4 = "directory") (ust-kind 41471 2 = "symbolic link")
      (ustamp 0 = "1970-01-01 00:00:00.000000000 +0000")
      (ustamp 1700000000073610912 = "2023-11-14 22:13:20.073610912 +0000")
      (uhuman 0 = "0") (uhuman 1023 = "1023")
      (uhuman 1024 = "1.0K") (uhuman 4096 = "4.0K") (uhuman 12288 = "12K")
      (uhuman 102400 = "100K") (uhuman 1500160 = "1.5M") (uhuman 3000000000 = "2.8G")
      ; %N's quoting: single, double when the quote is the only trouble, $'..' for a control byte
      (ushq "plain" = "plain") (ushq "with space" = "'with space'")
      (ushq "a-b.c_d+e,f%g@h:i]j" = "a-b.c_d+e,f%g@h:i]j")      ; nothing the shell reads otherwise
      (ushq "#x" = "'#x'") (ushq "a#b" = "a#b") (ushq "-x" = "-x") (ushq "-" = "-")
      (ushq "{" = "'{'") (ushq "{a}" = "{a}")
      (ushq "sq'ote" = "\"sq'ote\"") (ushq "dq\"ote" = "'dq\"ote'")
      (ushq "both'and\"q" = "'both'\\''and\"q'")
      (ushq "sq'ote$x" = "'sq'\\''ote$x'")     ; a $ inside "" would expand, so it splices
      (ushq "back\\slash" = "'back\\slash'") (ushq "dollar$x" = "'dollar$x'")
      (ushq ("tab" + string 9 + "here") = "'tab'$'\\t''here'")
      (ushq ("a" + string 1 + "b") = "'a'$'\\001''b'")
      (ushq "" = "''")
      ; a device number is one packed word, and linux splits it unevenly
      (ust-major 54 = 0) (ust-minor 54 = 54)
      (ust-major 259 = 1) (ust-minor 259 = 3)             ; /dev/null: 1,3
      (ust-major 1050 = 4) (ust-minor 1050 = 26)          ; a tty: 4,26
      (ust-major 66306 = 259) (ust-minor 66306 = 2)       ; nvme: a major past 8 bits
      (ust-minor 1048576 = 256)                           ; ..and a minor past its own
      ; df: every figure rounds up; nothing used and nothing free has no percentage
      (udf-up 0 1024 = 0) (udf-up 1 1024 = 1) (udf-up 1024 1024 = 1)
      (udf-up 1025 1024 = 2) (udf-up 12123 1024 = 12) (udf-up 113829 1024 = 112)
      (udf-up 5 0 = 0)
      (udf-pct 12123 113829 = "10%") (udf-pct 22091993 2714191 = "90%")
      (udf-pct 0 1024 = "0%") (udf-pct 1 1 = "50%") (udf-pct 0 0 = "-")
      (udf-esc "/mnt/plain" = "/mnt/plain")
      (udf-esc "/mnt/a\\040b" = "/mnt/a b")
      (udf-esc "/mnt/a\\011b\\012c\\134d" = ("/mnt/a" + string 9 + "b" + string 10 + "c\\d"))
      (udf-esc "/mnt/a\\09b" = "/mnt/a\\09b")       ; not three octal digits: the text stands
      ; one row a device: a bind of a subtree (a deeper root) gives way to its parent mount,
      ; the mount nearer the root wins, a path dev beats a name, a refused stat keeps its row
      (udf-dedup [["/dev/a" "/usr/local/data" "btrfs" 53 "/data"] ["/dev/a" "/swap" "btrfs" 52 "/swap"]
                  ["/dev/a" "/srv/steam" "btrfs" 53 "/data/gwen/steam"]]
       = [["/dev/a" "/usr/local/data" "btrfs" 53 "/data"] ["/dev/a" "/swap" "btrfs" 52 "/swap"]])
      (udf-dedup [["/dev/b" "/mnt/deep/x" "ext4" 7 "/"] ["/dev/b" "/mnt" "ext4" 7 "/"]] = [["/dev/b" "/mnt" "ext4" 7 "/"]])
      (udf-dedup [["tmpfs" "/a" "tmpfs" 9 ()] ["/dev/c" "/b" "ext4" 9 ()]] = [["/dev/c" "/b" "ext4" 9 ()]])
      (udf-dedup [["/dev/d" "/m" "ext4" 4 "/"] ["/dev/e" "/m" "ext4" 4 "/"]] = [["/dev/e" "/m" "ext4" 4 "/"]])
      (udf-dedup [["x" "/p" "t" () ()] ["x" "/q" "t" () ()]] = [["x" "/p" "t" () ()] ["x" "/q" "t" () ()]])
      (udf-esc "trail\\04" = "trail\\04")
      ; time's two places, rounded to nearest
      (utsec 0 = "0.00") (utsec 5000 = "0.01") (utsec 4999 = "0.00")
      (utsec 1000000 = "1.00") (utsec 340000 = "0.34") (utsec 90200000 = "90.20")))

; --- the expr floor (expr.l): values are texts, numeric where wanted; division truncates ---
(: (e as) (<(ex-parse 0 as))
   (test
      (t-int "42" = '(1 42)) (t-int "-7" = '(1 -7)) !(t-int "12a") !(t-int "")
      !(t-int "-") (t-int "0" = '(1 0))
      (ex-true? "1") (ex-true? "a") !(ex-true? "0") !(ex-true? "")
      (ex-arith "/" "-7" "2" = "-3") (ex-arith "%" "-7" "2" = "-1")       ; C's truncation
      (ex-arith "/" "7" "-2" = "-3") (ex-arith "%" "7" "-2" = "1")
      (ex-cmp "<" "2" "10" = "1") (ex-cmp "<" "2" "10a" = "0")            ; text, not number
      (ex-cmp "=" "abc" "abc" = "1") (ex-cmp ">=" "3" "3" = "1")
      (ex-substr "abcdef" "2" "3" = "bcd") (ex-substr "abcdef" "0" "3" = "")
      (ex-substr "abcdef" "5" "99" = "ef")
      (ex-index "abcdef" "cd" = "3") (ex-index "abcdef" "z" = "0")
      (ex-match "abc" "a.c" = "3") (ex-match "abc" "a\\(.\\)c" = "b")
      (ex-match "abcd" "a.c" = "3")                                       ; anchored at the head
      (ex-match "abc" "x" = "0") (ex-match "abc" "a\\(x\\)c" = "")
      (e '("1" "+" "2") = "3") (e '("1" "+" "2" "*" "3") = "7")
      (e '("(" "1" "+" "2" ")" "*" "3") = "9")
      (e '("0" "|" "3") = "3") (e '("0" "&" "2") = "0") (e '("1" "&" "2") = "1")
      (e '("length" "abcde") = "5") (e '("+" "length") = "length")))

; --- the patch floor (patch.l): the hunk header, counts, `\ No newline`, -p, the pairs bridge ---
(: p1 "--- a/x\n+++ b/x\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n"
   secs (pt-parse (lines p1))
   sec <secs
   h (<(sec 2))
   (test
      (pt-hdr "@@ -1,8 +1,8 @@" = '(1 8 1 8))
      (pt-hdr "@@ -3 +4,2 @@ fn()" = '(3 1 4 2))                          ; a bare start is one line
      (pt-hdr "@@ -0,0 +1,2 @@" = '(0 0 1 2))
      !(pt-hdr "@@ nope")
      (pt-hname "--- a/sub/f.txt\t2026-08-17 09:46:51" = "a/sub/f.txt")
      (pt-hname "+++ b/x" = "b/x")
      (pt-strip "a/b/c.txt" 1 = "b/c.txt") (pt-strip "a/b/c.txt" 2 = "c.txt")
      (pt-strip "a/b/c.txt" () = "c.txt")                                 ; unsaid drops them all
      (pt-strip "c.txt" 3 = "c.txt")
      (#secs = 1) (<sec = "a/x") (<>sec = "b/x")
      (h = '(1 1 ((32 "one" 1) (45 "two" 1) (43 "TWO" 1) (32 "three" 1))))
      (pt-old h = '("one" "two" "three")) (pt-new h = '(("one" 1) ("TWO" 1) ("three" 1)))
      ; the `\` line marks the entry before it, and it arrives after the counts are spent
      ((<(pt-body (lines "-c\n\\ No newline at end of file\n+C\n\\ No newline at end of file\n")
                    1 1 ())) = '((45 "c" 0) (43 "C" 0)))
      (pt-render (pt-pairs "a\nb\n") = "a\nb\n")
      (pt-render (pt-pairs "a\nb") = "a\nb")                              ; the end is data
      (pt-seek (pt-pairs "x\na\nb\n") '("a" "b") 0 = '(1 1))              ; found one line down
      (pt-seek (pt-pairs "") () -1 = '(1 0))                              ; a create's -0,0
      !(pt-seek (pt-pairs "q\n") '("a") 0)))

; --- the scan floor (scan.l): the byte scan against its love walk, every length and start.
; register roles differ per arch (r1 is Sp on x64, Ip on a64), so this is its a64 gate ---
(: sc (cite 'scan 'scanner ())
   tw (cite 'scan 'walk)
   (mk o n k) (n <= 0 ? (slurp o) (put o (97 + (k % 5)), mk o (n - 1) (k * 7 + 3)))
   (agree s c i) (sc s c i = (tw s c i))
   (sweep n)                                     ; every length past the word step ...
    (n > 24 ? 1
       (: s (mk (jug 0) n 1)
          (over i) (i > n + 1 ? 1                ; ... every start, one past the end too
                      (foldl (a \ c \ agree s c i ? a 0) 1 '(97 98 99 100 101 122)
                       && over (i + 1)))
          (over 0 && sweep (n + 1))))
   big (mk (jug 0) 5000 9)
   (test
      (sweep 0)
      (sc "" 97 0 = -1) (sc "abc" 97 9 = -1)                   ; empty, and a start past the end
      (sc "abc" 98 0 = 1) (sc "abc" 98 2 = -1)                 ; found, and found no later
      (sc big 122 0 = (tw big 122 0))                          ; absent over 5000 bytes
      (sc (big + "z") 122 0 = 5000)))                          ; and present at the very last

; --- the byte loops (core.l): xlat and the kb64 kernel against their love walks; kb64's a64 gate ---
(: kx xlat kb (kb64 0)
   (mk o n k) (n <= 0 ? (slurp o) (put o (k % 256), mk o (n - 1) (k * 7 + 3)))
   ; a-z up, digits dropped, 32 and 128..255 squeezed, the rest through
   tbl (ktable (c \ (? (97 <= c <= 122) [(c - 32) 1]
                       (48 <= c <= 57) [c 0]
                       (c = 32 || 127 < c) [c 2]
                       [c 1])))
   (xagree s) (: d1 (cask (#s + 1)) d2 (cask (#s + 1))
                 k1 (kx s tbl d1) k2 (kxlat-walk s tbl d2)
                 (k1 = k2 && (snip d1 0 k1 = snip d2 0 k2)))
   (bagree s) (: m (4 + 4 * ((#s + 2) // 3))
                 d1 (cask m) d2 (cask m)
                 k1 (kb s ub64set d1) k2 (kb64-walk s ub64set d2)
                 (k1 = k2 && (snip d1 0 k1 = snip d2 0 k2)))
   (sweep n) (n > 40 ? 1 (mk (jug 0) n (n + 1) @ s (xagree s && bagree s && sweep (n + 1))))
   big (mk (jug 0) 5000 9)
   same (mk (jug 0) 300 0)                                    ; one byte: the squeeze's longest run
   (test
      (sweep 0)
      (xagree big) (bagree big) (xagree same) (bagree same)
      (kb64-walk "abc" ub64set (cask 4) = 4)
      (ubenc ub64set 6 "hello, world" = "aGVsbG8sIHdvcmxk")
      (ubenc ub64set 6 "hello" = "aGVsbG8=")))

; --- the regex door (post.l's re): the BRE faces, by hand ---
(: (ok p s) (rebre p @ r (two? r && rehas <>r s))
   (no p s) (rebre p @ r (two? r && !(rehas <>r s)))
   (bad p) !(two? (rebre p))
   (test
      (ok "" "anything") (ok "" "")                            ; the empty pattern matches every line
      (ok "a" "bab") (no "a" "xyz")
      (ok "b.c" "abzcd") (no "b.c" "bc")
      (ok "^ab" "abc") (no "^b" "abc")                         ; ^ anchors the head ...
      (ok "c$" "abc") (no "b$" "abc")                          ; ... $ the tail
      (ok "^abc$" "abc") (no "^abc$" "abcd") (ok "a^b" "a^b")  ; elsewhere they are ink
      ; GNU's BRE positions: ^ also just past \( or \|, $ just before \) or \|
      (ok "\\(^a\\)b" "ab") (no "\\(^a\\)b" "xab")             ; ^ past \(
      (ok "\\(\\(^a\\)\\)" "ab") (no "\\(\\(^a\\)\\)" "xa")    ; ... however deep
      (ok "x\\|^a" "ab") (ok "x\\|^a" "zx") (no "x\\|^a" "za") ; ^ past \|
      (ok "\\(a^b\\)" "a^b")                                   ; but not past a read atom
      (ok "\\(ab$\\)" "xab") (no "\\(ab$\\)" "abx")            ; $ before \)
      (ok "a$\\|y" "za") (ok "a$\\|y" "yz") (no "a$\\|y" "az") ; $ before \|
      (ok "\\(a$b\\)" "a$b")                                   ; but not with more to read
      (no "\\(a$\\)b" "ab")                                    ; syntactic: anchored, so unmatchable
      (ok "ab*c" "ac") (ok "ab*c" "abbbc") (no "ab*c" "adc")
      (ok "ab\\+c" "abc") (no "ab\\+c" "ac")                   ; the GNU \+ and \?
      (ok "ab\\?c" "ac") (ok "ab\\?c" "abc") (no "ab\\?c" "abbc")
      (ok "[abc]x" "acx") (no "[abc]" "xyz")
      (ok "[^abc]" "ab ") (ok "[a-c]" "b") (no "[a-c]" "d")
      (ok "[]a]" "]") (ok "[^]]" "a") (no "[^]]" "]")          ; a first ] is literal
      (ok "[a-]" "-") (ok "[-a]" "-")                          ; an edge - is literal
      (ok "*x" "*x") (ok "^*" "*a") (no "^*" "a*")             ; a repeat with no atom is ink
      (ok "\\+" "a+b") (no "\\+" "ab")
      (ok "a\\.b" "a.b") (no "a\\.b" "axb") (ok "a\\\\b" "a\\b")
      (ok "\\(ab\\)*c" "ababc") (ok "\\(ab\\)*c" "c") (no "x\\(ab\\)c" "xac")
      (ok "\\(a\\(b\\)*\\)*x" "abbax") (ok "\\(\\)*x" "ax")    ; nesting; an empty repeat rests
      (bad "\\(ab") (bad "ab\\)") (bad "[ab") (bad "a\\")      ; malformed answers ()
      (bad "a\\1") (bad "a\\{2") (bad "a\\{3,2\\}")            ; backref, unclosed, inverted
      ; --- alternation, intervals and the POSIX classes ---
      (ok "a\\|b" "b") (ok "a\\|b" "a") (no "a\\|b" "c")       ; BRE's GNU \|
      (ok "ab\\|cd" "zcdz") (no "ab\\|cd" "acbd")              ; the branches are whole
      (ok "\\(a\\|b\\)c" "bc") (no "\\(a\\|b\\)c" "cc")        ; grouped, and it still groups
      (ok "a\\|b\\|c" "c") (no "a\\|b\\|c" "d")                ; three-way, kept flat
      (ok "a\\|" "") (ok "\\|a" "z")                           ; an empty branch fits the empty text
      (ok "ab\\{2\\}c" "abbc") (no "ab\\{2\\}c" "abc")         ; {n}
      (ok "ab\\{2,\\}c" "abbbc") (no "ab\\{2,\\}c" "abc")      ; {n,}
      (ok "ab\\{1,2\\}c" "abc") (no "ab\\{1,2\\}c" "abbbc")    ; {n,m}
      (ok "\\{2\\}" "x{2}y") (ok "\\+q" "+q")                  ; nothing to repeat: BRE ink
      (ok "[[:digit:]]" "a1") (no "[[:digit:]]" "ab")
      (ok "[[:alpha:][:digit:]]" "1") (ok "[^[:digit:]]" "a")  ; two in one bracket, negated
      (ok "[[:space:]]" "a b") (ok "[[:upper:]]" "aB")
      (bad "[[:nope:]]")                                       ; an unknown class is malformed
      ; by character: `.` and a class take one whole, and never a byte no character wears
      (ok "^.$" "é") (no "^..$" "é") (no "." (string 255))
      (ok "^[^a]$" "日") (no "[^a]" (string 255)) (ok "[à-ÿ]" "é") (no "[à-é]" "ÿ")
      (ok "^é*$" "éé") (ok "^é\\{2\\}$" "éé") (no "^é\\{2\\}$" "é")  ; a repeat takes all of é
      (refind <>(rebre "本.") "日本語" 0 = '(1 3 9 ()))
      ; the POSIX classes past ascii, and -i by gnulib's fold
      (ok "^[[:alpha:]]*$" "naïve") (ok "[[:alpha:]]" "日") (no "[[:digit:]]" "٣")
      (ok "[[:punct:]]" "—") (no "[[:punct:]]" " ") (ok "[[:space:]]" " ") (ok "[^[:alpha:]]" "—")
      (: (iok p s) (rebre p @ r (two? r && rehas (refold <>r) s))
         (ino p s) (rebre p @ r (two? r && !(rehas (refold <>r) s)))
         (test (iok "é" "É") (iok "s" "ſ") (iok "ſ" "S") (ino "k" "\xe2\x84\xaa") (ino "i" "İ")
               (iok "σ" "ς") (iok "[à-é]" "É") (ino "[^é]" "É") (iok "[[:upper:]]" "a")
               (iok "[[:upper:]]" "日") (iok "ᲀ" "В") (ino "В" "ᲀ") (iok "[a-z]" "ſ")))
      ; GNU's \w \W \s \S, a class in both dialects; inside a bracket the backslash is ink
      (ok "^\\w*$" "héllo_1") (no "\\w" "—") (ok "\\W" "a b") (no "\\W" "ab")
      (ok "\\s" " ") (no "\\s" "\xc2\xa0") (ok "^\\S*$" "a_é")
      (ok "[\\w]" "\\") (no "[\\w]" "a")
      ; GNU's word edges: \b a boundary, \B none, \< a word's start, \> its end
      (ok "\\bba" "foo bar") (no "\\bba" "foobar") (ok "\\Bba" "foobar") (no "\\Bba" "foo bar")
      (ok "\\<b" "foo bar") (no "\\<o" "foo") (ok "o\\>" "foo bar") (no "f\\>" "foo")
      (no "\\b" "") (ok "\\B" "") (ok "\\B" "-") (no "\\B" "a")      ; an empty line has no edge
      (ok "\\<本" "日本 本") (ok "a\\Bï" "naïve") (no "\\B" "ö")      ; never inside a character
      (no "x\\b" ("x" + string 255)) (ok "\\Ba" ("x" + string 200 + "a"))   ; latin-1 reading
      (ok "\\b*a" "x*a") (no "\\b*a" "ab")                          ; BRE: a star after an edge is ink
      (ok "[\\b]" "b")
      (refind <>(rebre "b*") "abbc" 0 = '(1 0 0 ()))           ; leftmost, before longest
      (refind <>(rebre "bb") "abbc" 0 = '(1 1 3 ()))
      (refind <>(rebre "b*") "abbc" 1 = '(1 1 3 ()))           ; greedy at its own start
      !(refind <>(rebre "zz") "abbc" 0)
      ; the group spans: numbered in \( order, a repeated group its last iteration (GNU's \1)
      (refind <>(rebre "\\(b*\\)c") "abbc" 0 = '(1 1 4 ((1 1 3))))
      (refind <>(rebre "\\(a\\(b\\)\\)") "ab" 0 = '(1 0 2 ((1 0 2) (2 1 2))))
      (refind <>(rebre "\\(ab\\)*x") "ababx" 0 = '(1 0 5 ((1 2 4))))
      ; leftmost-longest: the longest match at the leftmost start, not the first path
      (refind <>(reere "a|ab") "abc" 0 = '(1 0 2 ()))
      (refind <>(reere "x*|b") "b" 0 = '(1 0 1 ()))
      (refind <>(reere "(a|ab)(c|bcd)") "abcd" 0 = '(1 0 4 ((1 0 1) (2 1 4))))
      (refind <>(reere "(a|ab){1,2}") "aab" 0 = '(1 0 3 ((1 1 3))))
      (refind <>(reere "()*x") "x" 0 = '(1 0 1 ((1 0 0))))         ; an empty iteration reports its group
      (<>>(rebre "\\(a\\)\\(b\\)") = 2)
      (<>>(rebre "ab") = 0)))

; --- the ERE door: the backslashes moved ---
(: (eok p s) (reere p @ r (two? r && rehas <>r s))
   (eno p s) (reere p @ r (two? r && !(rehas <>r s)))
   (ebad p) !(two? (reere p))
   (test
      (eok "a|b" "b") (eno "a|b" "c") (eok "(a|x)b" "xb")
      (eok "ab?c" "ac") (eok "a+" "aa") (eno "a+" "b")
      (eok "a{2}" "aa") (eno "a{2}" "ab") (eok "(a|b)+z" "abz")
      (eok "[[:digit:]]{2}" "a12") (eno "[[:digit:]]{2}" "a1b")
      (eok "*r" "r") (eok "+q" "q") (eok "{2}" "anything")     ; ERE drops a loose repeat
      (eok "a{" "a{") (eok "a)" "a)")                          ; ..and takes these as ink
      (ebad "a{3,2}") (ebad "(a") (ebad "a\\1")))

; --- the sed floor (sed.l): the substitution to its GNU face, what the parser takes and refuses ---
(: (sub p r s g?) (rebre p @ b <>(usub <>b r s g?))
   (sp s) (sparse s ())
   (test
      (sub "b" "X" "abc" () = "aXc") (sub "z" "X" "abc" () = "abc")
      <(usub <>(rebre "b") "X" "abc" ())
      !<(usub <>(rebre "z") "X" "abc" ())
      (sub "b" "X" "abab" 1 = "aXaX")
      (sub "b" "X" "abab" () = "aXab")
      (sub "x*" "-" "abc" 1 = "-a-b-c-")                         ; the empty-match step rule
      (sub "x*" "-" "xbz" 1 = "-b-z-")                           ; ... and the discard after a real match
      (sub "x*" "-" "xx" 1 = "-")
      (sub "x*" "-" "a…b" 1 = "-a-…-b-")                         ; the step is a character, never a byte of one
      (sub "\\(a\\|ab\\)b*" "<&>" "abb" () = "<abb>")              ; the longest match is the one replaced
      (sub "b" "[&]" "abc" () = "a[b]c")
      (sub "\\(b*\\)c" "[\\1]" "xbbc" () = "x[bb]")
      (sub "a\\(b\\)\\?c" "<\\1>" "ac" () = "<>")                ; an unmatched group is ""
      (sub "b" "\\&\\\\" "abc" () = "a&\\c")                     ; \& and \\ stay ink
      (sub "^a" "X" "aaa" 1 = "Xaa")                             ; the anchor can't re-fire
      (two? (sp "p")) (two? (sp "2,4d")) (two? (sp "/x/,$d"))
      (two? (sp "s/a/b/g; 3p")) (two? (sp "2 p")) (two? (sp "s|/|_|"))
      (#<>(sp "p;p;p") = 3)
      !(sp "s/a") !(sp ",")                                      ; unterminated s; a legless ,
      !(sp "2,3q") !(sp "x") !(sp "s/a/b/x")                     ; q takes one address; unknown verb/flag
      !(sp "s/a\\{/b/")                                          ; the regex dialect refuses through
      ; the dialect reaches an address and an s alike
      (two? (sp "s/\\(a\\|b\\)/x/")) (two? (sparse "s/(a|b)/x/" 1))
      (two? (sparse "/a|b/d" 1))))

; --- the /proc floor (proc.l): the faces read live clocks, so the family is held here ---
(: (test
      ; the comm runs from the first ( to the last ): a name may hold either, or spaces
      (ustatf "42 (bash) S 7 42 42 1024 99" = '(42 "bash" "S" "7" "42" "42" "1024" "99"))
      (ustatf "9 ((sd-pam)) S 1" = '(9 "(sd-pam)" "S" "1"))
      (ustatf "9 (a b) c) S 1" = '(9 "a b) c" "S" "1"))
      !(ustatf "9 no parens here")
      (uclk 0 = "00:00:00") (uclk 3661 = "01:01:01") (uclk 359999 = "99:59:59")
      (uclk 360000 = "100:00:00")                       ; the hours are never clipped
      (uhms 100 = "00:00:01") (uhms 131 = "00:00:01")       ; user_hz is 100, and it truncates
      ; the terminal number is Linux's own dev_t: major in bits 8..19, minor split
      (utty 0 = "?") (utty 34816 = "pts/0") (utty 34819 = "pts/3")
      (utty 1025 = "tty1") (utty 1088 = "ttyS0") (utty 2304 = "?")
      (uupsay 60 = "1 min") (uupsay 1980 = "33 min")
      (uupsay 9180 = " 2:33") (uupsay 86400 = "1 day,  0:00")
      (uupsay 2275261 = "26 days,  8:01")
      (usignum "-9" = 9) (usignum "-TERM" = 15) (usignum "-KILL" = 9)
      !(usignum "-nope") !(usignum "x") !(usignum "-")))

; --- post.l's readers: durations to milliseconds, ports, errnos ---
(: (test
      (udur "2" = 2000) (udur "0" = 0) (udur "1s" = 1000)
      (udur "1.5" = 1500) (udur ".5" = 500) (udur "1." = 1000)
      (udur "2m" = 120000) (udur "1h" = 3600000) (udur "1d" = 86400000)
      (udur "1.5m" = 90000)
      !(udur "") !(udur "x") !(udur "5x") !(udur "1.2.3") !(udur ".")
      (uport "80" = 80) (uport "1" = 1) (uport "65535" = 65535)
      !(uport "0") !(uport "65536") !(uport "8x") !(uport "") !(uport "-1")
      (uerrno 'econnrefused = "Connection refused") (uerrno 'enoent = "No such file or directory")
      (uerrno 'exdev = "exdev")))

; --- the find floor (find.l): the path join, the argument split, the expression grammar ---
(: (test
      (fi-join "a" "b" = "a/b") (fi-join "a/" "b" = "a/b") (fi-join "/" "b" = "/b")
      ; the paths run out at the first flag, bracket or bang
      (fi-paths '("a" "b" "-name" "x") () = ['("a" "b") '("-name" "x")])
      (fi-paths '("-type" "f") () = [() '("-type" "f")])
      (fi-paths '("a") () = ['("a") ()])
      (fi-paths '("a" "!" "-type" "d") () = ['("a") '("!" "-type" "d")])
      ; the depths come out of the word list wherever they sat
      (fi-depths '("-maxdepth" "2" "-print") 99 0 () = ['("-print") 2 0])
      (fi-depths '("-print" "-mindepth" "1") 99 0 () = ['("-print") 99 1])
      ; -a is implicit, and binds tighter than -o
      (fi-or '("-name" "a" "-o" "-name" "b" "-type" "f") = [['or ['name "a"] ['and ['name "b"] ['type "f"]]] ()])
      (fi-or '("!" "-type" "d") = [['not ['type "d"]] ()])
      (fi-or '("(" "-name" "a" "-o" "-name" "b" ")" "-print") = [['and ['or ['name "a"] ['name "b"]] ['print]] ()])
      (fi-or '("-exec" "echo" "{}" ";") = [['exec '("echo" "{}")] ()])
      !(fi-or '("-name"))                                ; a primary with no argument
      !(fi-or '("(" "-print"))                           ; a bracket that never closes
      !(fi-or '("-exec" "echo"))                         ; an -exec with no ;
      ; only -print and -exec act; anything else earns the added -print
      (fi-acts? ['print]) (fi-acts? ['and ['name "a"] ['print]])
      !(fi-acts? ['and ['name "a"] ['type "f"]]) !(fi-acts? ['prune])))

; --- the awk floor (awk.l): printf's number faces, strnum, the grammar's shapes ---
(: (test
      ; %f %e %g by hand -- `show` spells a double round-trip exact, awk owes %.6g
      (aw-fixed 3.14159 2 = "3.14") (aw-fixed -1.005 2 = "-1.00")
      (aw-fixed 2.5 0 = "2") (aw-fixed 3.5 0 = "4")   ; an exact tie goes to even, as C's
      (aw-fixed 2.675 2 = "2.67")                        ; the double is under the tie
      (aw-expo 1234.5 3 = "1.234e+03") (aw-expo 1234.6 3 = "1.235e+03") (aw-expo 0.000123 2 = "1.23e-04")
      (aw-gen (1 / 3) 6 = "0.333333") (aw-gen 100000 6 = "100000")
      (aw-gen 1000000 6 = "1e+06") (aw-gen 0.0001 6 = "0.0001")
      (aw-gen 0.00001 6 = "1e-05") (aw-gen 0 6 = "0")
      (aw-numstr 42 "%.6g" = "42") (aw-numstr 3.5 "%.6g" = "3.5")
      (aw-sprintf "%d|%5.2f|%-4s|%x" [42 3.14159 "ab" 255] "%.6g" = "42| 3.14|ab  |ff")
      (aw-sprintf "%05d|%+d|%c" [42 7 65] "%.6g" = "00042|+7|A")
      ; the strnum question is asked of the whole text, blanks aside
      (aw-looks-num? " 12.5 ") (aw-looks-num? "-3") (aw-looks-num? "1e3")
      !(aw-looks-num? "12a") !(aw-looks-num? "") !(aw-looks-num? "e3") !(aw-looks-num? "1e")
      (aw-s2n "  12.5xyz" = 12.5) (aw-s2n "1e3" = 1000) (aw-s2n "abc" = 0)
      ; substr clamps its start and does not dock the length for it -- gnu's reading
      (aw-substr {} "hello" 2 3 1 = "ell") (aw-substr {} "hello" 0 3 1 = "hel")
      (aw-substr {} "hello" 4 0 0 = "lo") (aw-substr {} "hello" 2 -1 1 = "")
      (aw-index {} "hello" "ll" = 3) (aw-index {} "hello" "z" = 0)
      ; by character
      (aw-substr {} "h\u{e9}l\u{8a9e}x" 2 3 1 = "\u{e9}l\u{8a9e}") (aw-index {} "\u{8a9e}\u{e9}x" "x" = 3)
      (aw-cpn {} "a\u{8a9e}\xff" = 3)
      (aw-repl "[&]" "b" = "[b]") (aw-repl "\\&" "b" = "&")
      (aw-slt "ab" "b") !(aw-slt "b" "ab") !(aw-slt "a" "a") (aw-slt "a" "ab")
      ; the lexer's one context: / after a value divides, / anywhere else opens a regex
      (aw-lex "a/b" = '((name "a") (op "/") (name "b") (eof "")))
      (aw-lex "/a/" = '((ere "a") (eof "")))
      (aw-lex "f(" = '((fname "f") (op "(") (eof "")))         ; a glued ( makes a call
      (aw-program (aw-lex "{print}") {} () = '((item () ((print () ())))))
      (aw-program (aw-lex "BEGIN{x=1}") {} () = '((begin ((expr (assign "=" (var "x") (num 1)))))))
      (aw-program (aw-lex "/a/,/b/{}") {} () = '((range (ere "a") (ere "b") ())))))

; --- the pager (less.l): keys drive the pure engine a byte at a time; no tty, port or file ---
(: (pg-bytes s) (: n #s (go i acc) (i < 0 ? acc (go (i - 1) (s i . acc))) (go (n - 1) ()))
   (pg-mk ls w h fl)
    (: t {}
       _ (foldl (a \ c \ pin t c 1) 0 (pg-bytes fl))
       st (pgnew t w h)
       (pgload st ls "t",
        st))
   (pg-run ls w h fl keys)
    (pg-mk ls w h fl @ st (foldl (a \ c \ pgstep st c) 0 (pg-bytes keys), st))
   (pg-top ls w h fl keys) (pg-run ls w h fl keys 'top)
   ten '("l1" "l2" "l3" "l4" "l5" "l6" "l7" "l8" "l9" "l10")
   caps '("a" "b" "c" "d" "e" "f" "ALPHA" "h" "i" "j")
   (test
      ; the wrap: width fragments, a tab to the next 8th column, a control as ^X, a utf-8 tail no column
      (pgwrap 4 "abcdefghij" = '("abcd" "efgh" "ij"))
      (pgwrap 4 "abcd" = '("abcd"))
      (pgwrap 4 "" = '(""))                     ; a blank line is a row like any other
      (pgwrap 8 "a\tb" = '("a       " "b"))
      (pgwrap 20 (string 1) = '("^A"))
      (pgwrap 2 "\xce\xbb\xce\xbb\xce\xbb" = '("\xce\xbb\xce\xbb" "\xce\xbb"))
      ; an sgr sequence costs no column; any other escape shows as ^[
      (pgwrap 4 "\x1b[1mabcd\x1b[0m" = '("\x1b[1mabcd\x1b[0m"))
      (pgwrap 4 "\x1b[1;4mab\x1b[0mcdef" = '("\x1b[1;4mab\x1b[0mcd" "ef"))
      (pgwrap 20 "\x1b[2Ja" = '("^[[2Ja"))
      ; a c1 control shows as <9B> raw or <U+009B> encoded, never reaches the terminal
      (pgwrap 20 "a\x9b2Jb" = '("a<9B>2Jb"))
      (pgwrap 20 "a\xc2\x9b2J" = '("a<U+009B>2J"))
      (pgwrap 4 "\x9b\x9b" = '("<9B>" "<9B>"))
      (pgwrap 20 "\xc2\xa0\xce\xbb" = '("\xc2\xa0\xce\xbb"))
      ; ..and a wrap inside an attribute closes it and reopens it on the next row
      (pgwrap 2 "\x1b[1mabcd\x1b[0m" = '("\x1b[1mab\x1b[0m" "\x1b[1mcd\x1b[0m"))
      (pgclip 3 "abcdef" = "abc") (pgclip 9 "abcdef" = "abcdef")
      ; the status clips the other way -- its tail is what carries the news
      (pgclipl 6 "t  1-2/3  66%" = "<  66%")
      (pgclipl 20 "t  1-2/3  66%" = "t  1-2/3  66%")
      ; a row carries the source line it came off and whether it heads it
      (pgrows 4 '("abcdef" "x") = '(("abcd" 0 1) ("ef" 0 ()) ("x" 1 1)))
      ; ten lines in a five-line window: four of text, so the last top is row 6
      (pg-top ten 20 5 "" " " = 4)              ; a screenful, and the end holds it
      (pg-top ten 20 5 "" "  " = 6)
      (pg-top ten 20 5 "" " b" = 0)
      (pg-top ten 20 5 "" "3j" = 3)             ; a count is lines, whatever the key
      (pg-top ten 20 5 "" "3j2k" = 1)
      (pg-top ten 20 5 "" "5 " = 5)
      (pg-top ten 20 5 "" "G" = 6) (pg-top ten 20 5 "" "Gg" = 0)
      (pg-top ten 20 5 "" "3g" = 2) (pg-top ten 20 5 "" "7g" = 6)
      (pg-top ten 20 5 "" "d" = 2) (pg-top ten 20 5 "" "du" = 0)
      (pg-top ten 20 5 "" "50p" = 5)
      ; the search starts past the top line, and n / N walk it either way
      (pg-top ten 20 5 "" "/l7\n" = 6)
      (pg-top ten 20 5 "" "G?l2\n" = 1)
      (pg-top ten 20 5 "" "/l[0-9]\n" = 1)
      (pg-top ten 20 5 "" "/l[0-9]\nn" = 2)
      (pg-top ten 20 5 "" "/l[0-9]\nnN" = 1)
      (pg-run ten 20 5 "" "/zz\n" 'msg = "pattern not found: zz")
      (pg-run ten 20 5 "" "n" 'msg = "no previous pattern")
      ; -i folds the pattern, and without it the case counts
      (pg-top caps 20 5 "i" "/alpha\n" = 6)
      (pg-top caps 20 5 "" "/alpha\n" = 0)
      ; -s squeezes a run of blank lines to one, and -e is the door out at the end
      (pg-mk '("a" "" "" "" "b") 20 5 "s" 'ls = '("a" "" "b"))
      (pg-mk '("a" "" "" "" "b") 20 5 "" 'ls = '("a" "" "" "" "b"))
      !(pg-run ten 20 5 "e" " " 'quit)
      (pg-run ten 20 5 "e" "G " 'quit)
      !(pg-run ten 20 5 "" "G  " 'quit)
      (pg-run ten 20 5 "" "q" 'quit)
      (pg-run ten 20 5 "" "ZZ" 'quit) !(pg-run ten 20 5 "" "Z" 'quit)
      ; h swaps the help page in, and q comes back out of it before it quits
      (pg-run ten 20 5 "" "h" 'file = "HELP")
      (pg-run ten 20 5 "" "hq" 'file = "t")
      (pg-run ten 20 5 "" "hqq" 'quit)
      ; a typed line takes a rubout, and ESC drops the whole thing
      (pg-run ten 20 5 "" "/l9\x7f" 'cmd = "l")
      (pg-run ten 20 5 "" "/l9\x1b" 'mode = 'n)
      ; the frame: body, status in standout, cursor on it; a row past the end is a tilde
      (pgframe (pg-mk '("ab" "cd" "ef") 20 3 "") = "\e[Hab\e[K\r\ncd\e[K\r\n\e[7mt  1-2/3  66%\e[0m\e[K\e[3;14H")
      (pgframe (pg-mk '("ab") 20 3 "") = "\e[Hab\e[K\r\n~\e[K\r\n\e[7m< 1-1/1  100%  (END)\e[0m\e[K\e[3;21H")
      (pgmark "\e" "[1]" "a [1]x [11] [1]" = "a \e[7m[1]\e[27mx [11] \e[7m[1]\e[27m")
      (pg-mk '("see [2]b") 20 3 "" @ st (pin st 'hi "[2]",
                                         0 <= fsub (pgframe st) "see \e[7m[2]\e[27mb" 0))
      (pgstat (pg-mk '("ab") 20 3 "") = "t  1-1/1  100%  (END)")
      (pgstat (pg-mk ten 20 5 "") = "t  1-4/10  40%")
      ; and what a search paints on the rows it found
      ((pgpaint (string 27) <(pgnds (pg-mk ten 20 5 "") "l.") "hello") = "he\e[7mll\e[27mo")))

; the : commands name the next file for the face to read, and refuse to walk off either end
(: t {}
   st (pgnew t 20 5)
   (pgload st '("x") "a.txt",
    pins st 'files '("a.txt" "b.txt") 'fi 0,
    pgstep st 58, pgstep st 110,
    (test (st 'fi = 1) (st 'doe = '("b.txt"))),
    pin st 'doe (),
    pgstep st 58, pgstep st 110,
    (test (st 'fi = 1) !(st 'doe) (st 'msg = "no next file")),
    pgstep st 58, pgstep st 112,
    (test (st 'fi = 0) (st 'doe = '("a.txt")))))

; ..and reads it through the face's 'load when there is one: man walks pages, not files.
; a complaint from the loader is the message, and the page stays
(: t (pin {} 'load (nm \ nm = "gone" ? "man: no manual entry for gone" [[("page " + nm)] (nm + "(1)")]))
   st (pgnew t 20 5)
   (pgload st '("page ls") "ls(1)",
    pins st 'files '("ls" "cat" "gone") 'fi 0,
    pgstep st 58, pgstep st 110, pgdoe st,
    (test (st 'file = "cat(1)") (st 'ls = '("page cat"))),
    pgstep st 58, pgstep st 110, pgdoe st,
    (test (st 'file = "cat(1)") (st 'msg = "man: no manual entry for gone")),
    pgstep st 58, pgstep st 112, pgstep st 58, pgstep st 112, pgdoe st,
    (test (st 'file = "ls(1)") (st 'ls = '("page ls")))))

; --- the bc floor (bc.l): the scale rules, the base writer, the numeral reader, the grammar ---
(: st (bc-state 0)
   (sho b n) (pin st 'obase b, bc-show st n)
   (nod s) <(bc-expr (bc-lex s))
   (stm s) <(bc-stmt (bc-lex s))
   (refuses? th) (trap (_ \ (th 0, 0)) () (a \ b \ 1))
   (test
      (bn-add [15 1] [15 1] = [30 1])                        ; + and - keep the wider
      (bn-add [1 0] [5 3] = [1005 3])
      (bn-sub [1 0] [5 3] = [995 3])
      (bn-mul 0 [2 0] [325 2] = [650 2])                     ; * min(sa+sb, max(sc,sa,sb))
      (bn-mul 0 [15 1] [15 1] = [22 1])                      ; ... and it truncates
      (bn-mul 5 [15 1] [15 1] = [225 2])
      (bn-div 5 [1 0] [3 0] = [33333 5])                     ; / keeps scale
      (bn-div 5 [-1 0] [3 0] = [-33333 5])                   ; ... toward zero, both ways
      (bn-mod 0 [17 0] [5 0] = [2 0])                        ; % wears the dividend's sign
      (bn-mod 0 [-17 0] [5 0] = [-2 0])
      (bn-mod 0 [17 0] [-5 0] = [2 0])
      (bn-mod 3 [10 0] [3 0] = [1 3])                        ; ... max(scale + sb, sa)
      (bn-pow 0 [25 1] [3 0] = [156 1])                      ; ^ min(sa*b, max(sc,sa))
      (bn-pow 0 [2 0] [10 0] = [1024 0])
      (bn-pow 4 [2 0] [-2 0] = [2500 4])                     ; a negative power keeps scale
      (bn-pow 0 [0 0] [0 0] = [1 0])                         ; 0^0 is 1, as bc says
      (bn-sqrt 5 [2 0] = [141421 5])                         ; sqrt max(scale, sa)
      (bn-sqrt 5 [225 2] = [150000 5])
      ; 0 and 1 answer themselves, scale and all -- GNU's two short circuits
      (bn-sqrt 5 [0 0] = [0 0]) (bn-sqrt 5 [1 0] = [1 0])
      ; the significant digits, where a whole zero still owns one
      (bn-len [0 0] = 1) (bn-len [0 3] = 3) (bn-len [5 1] = 1)
      (bn-len [5 2] = 2) (bn-len [123456 3] = 6) (bn-len [-123 0] = 3)
      (bn-len [100 0] = 3)
      ; the fraction's digits: the least k with base^k >= 10^s, in whole numbers
      (bc-fdigits 10 5 = 5) (bc-fdigits 2 2 = 7) (bc-fdigits 8 1 = 2)
      (bc-fdigits 16 20 = 17) (bc-fdigits 100 2 = 1) (bc-fdigits 100 20 = 10)
      ; the writer: no leading zero, and a base over 16 spells each digit out
      (sho 10 [5 1] = ".5") (sho 10 [-5 1] = "-.5") (sho 10 [1100 3] = "1.100")
      (sho 10 [0 5] = "0") (sho 10 [0 0] = "0")
      (sho 16 [255 0] = "FF") (sho 16 [-255 0] = "-FF") (sho 16 [2555 1] = "FF.8")
      (sho 2 [10 0] = "1010")
      (sho 100 [1234 0] = " 12 34") (sho 100 [-1234 0] = "- 12 34")
      (sho 100 [0 0] = "0") (sho 1000 [1234567 0] = " 001 234 567")
      (sho 20 [33 2] = ".06 12")                    ; a fraction's first group sits bare
      (sho 17 [17 0] = " 01 00")
      ; the reader: a lone figure is itself in any base; elsewhere a figure >= base clamps to base-1
      (bc-numeral "255" 10 = [255 0]) (bc-numeral "1.100" 10 = [1100 3])
      (bc-numeral ".5" 10 = [5 1]) (bc-numeral "FF" 16 = [255 0])
      (bc-numeral "9" 2 = [9 0]) (bc-numeral "12" 2 = [3 0])
      (bc-numeral "101" 2 = [5 0]) (bc-numeral ".8" 16 = [5 1])
      ; the lexer: a lone dot is `last`, a dot with a figure behind it opens a numeral
      (bc-lex "1+2" = '((num "1") (op "+") (num "2") (eof "")))
      (bc-lex "." = '((kw "last") (eof "")))
      (bc-lex ".5" = '((num ".5") (eof "")))
      (bc-lex "x1_" = '((name "x1_") (eof "")))
      (bc-lex "/* c */ 1 # z" = '((num "1") (eof "")))
      ; and the shapes the runner is owed. the unary minus binds tighter than ^
      (nod "-2^2" = '(pow (neg (num "2")) (num "2")))
      (nod "2^-2" = '(pow (num "2") (neg (num "2"))))
      (nod "2^3^2" = '(pow (num "2") (pow (num "3") (num "2"))))
      (nod "1+2*3" = '(bin "+" (num "1") (bin "*" (num "2") (num "3"))))
      (nod "1<2<3" = '(cmp "<" (cmp "<" (num "1") (num "2")) (num "3")))
      (nod "x=y=1" = '(asgn "=" (var "x") (asgn "=" (var "y") (num "1"))))
      (nod "a[1]" = '(arr "a" (num "1"))) (nod "b[]" = '(aref "b"))
      (nod "scale" = '(reg scale)) (nod "scale(x)" = '(scl (var "x")))
      (nod "f(1,2)" = '(call "f" ((num "1") (num "2"))))
      (nod "++i" = '(incr 1 1 (var "i"))) (nod "i--" = '(incr 0 -1 (var "i")))
      (stm "if (1) 2" = '(if (num "1") (expr (num "2")) ()))
      (stm "while (1) 2" = '(while (num "1") (expr (num "2"))))
      (stm "for(;;)1" = '(for () () () (expr (num "1"))))
      ; POSIX spells return (E), GNU takes a bare E, and a statement's end means none
      (stm "return (1)" = '(ret (grp (num "1"))))
      (stm "return 1*2" = '(ret (bin "*" (num "1") (num "2"))))
      (stm "return" = '(ret ()))
      ; ... and what it refuses
      (refuses? (_ \ bc-lex "@"))
      (refuses? (_ \ bc-expr (bc-lex "(1")))
      (refuses? (_ \ bc-expr (bc-lex "1+")))
      (refuses? (_ \ bc-stmt (bc-lex "while 1")))))

; --- bc's algebra, seeded: writer/reader inverse, + and * commute, remainder below divisor, root within its ulp ---
(: st (bc-state 0)
   _ (pin st 'obase 10)
   (rnum s) (: a (random s 100000) b (random >a 5) c (random >b 2)
               [[(<c ? (0 - <a) <a) <b] >c])
   (fz i s)
    (i < 1 ? 'ok
       (: p (rnum s) q (rnum <>p) g (random <>q 8)
          a <p b <q sc <g
          n [(abs <a) <>a]
          bi [<b 0] ai [<a 0]
          rt (bn-sqrt sc n)
          up (bn-add rt [1 <>rt])
          ok (bn-cmp (bn-sub (bn-add a b) b) a = 0
                 && bn-cmp (bn-add a b) (bn-add b a) = 0
                 && bn-cmp (bn-mul sc a b) (bn-mul sc b a) = 0
                 && (<b = 0 ? 1
                       (bn-mod 0 ai bi @ r0
                        (0 < bn-cmp [(abs <b) 0] [(abs <r0) 0])))
                 && !(0 < bn-cmp (bn-mul 99 rt rt) n)
                 && (0 < bn-cmp (bn-mul 99 up up) n)
                 && (<n = 0 ? 1 (bc-numeral (bc-show st n) 10 = n)))
          (ok ? (fz (i - 1) >g) ['broke a b sc])))
   r (fz 300 (wheel 23))
   (test (r = 'ok)))

; --- the line endings: the three transforms; each idempotent, so a second pass never makes \r\r\n ---
(: dos "a\r\nb\r\nc\r\n" unx "a\nb\nc\n"
   (test
      (ucrlf dos = unx) (ulfcr unx = dos)
      (ucrlf unx = unx)
      (ulfcr dos = dos)                          ; already dos: not doubled to \r\r\n
      (ucrlf (ucrlf dos) = unx) (ulfcr (ulfcr unx) = dos)
      (ulfcr (ucrlf dos) = dos) (ucrlf (ulfcr unx) = unx)
      ; a lone cr is the classic mac break, and it is mac2unix's and not dos2unix's
      (ucrlone "a\rb\r" = "a\nb\n") (ucrlone dos = dos) (ucrlf "a\rb\r" = "a\rb\r")
      ; a cr that is not a line ending survives dos2unix -- only the pair is a break
      (ucrlf "a\rb\n" = "a\rb\n")
      (ucrlf "" = "") (ulfcr "" = "") (ucrlf "\r" = "\r")         ; a trailing bare cr stays
      ; the NUL that says binary, and the text that does not
      (ubin? "a\000b") (ubin? "\000") !(ubin? unx) !(ubin? "") !(ubin? "\r\n")))

; --- man's string half: the stem, gzip, redirect and mdoc readings, the escape strip ---
(test
   ; the stem: compression and section suffixes off the right, never cut at the first dot
   (man-stem "ls.1.gz" = "ls") (man-stem "ls.1" = "ls") (man-stem "ls" = "ls")
   (man-stem "tcl_endOfWord.n.gz" = "tcl_endOfWord")
   (man-stem "valac-0.56.1.gz" = "valac-0.56")
   (man-stem "systemd-mute-console@.service.7.gz" = "systemd-mute-console@.service")
   (man-stem "foo.1p.gz" = "foo") (man-stem "foo.3.xz" = "foo")
   (man-base "/usr/share/man/man1/ls.1.gz" = "ls.1.gz") (man-base "ls.1" = "ls.1")
   (man-head "man1/gzip.1" = "man1") (man-head "gzip.1" = "gzip.1")
   ; the magic decides, not the suffix -- a page named without .gz still reads
   (man-gz? "\x1f\x8b\x08\x00rest") !(man-gz? ".TH LS 1") !(man-gz? "") !(man-gz? "\x1f")
   ; a redirect page is a .so and nothing else; a comment ahead of it does not count
   (man-so ".so man1/gzip.1\n" = "man1/gzip.1")
   (man-so ".\\\" a comment\n.so man7/x.7\n" = "man7/x.7")
   !(man-so ".TH LS 1\n.SH NAME\n") !(man-so "")
   ; the root is up past the file and its section directory, in one step
   (man-root "/usr/share/man/man1/ls.1.gz" = "/usr/share/man")
   (man-root "/usr/share/man/man3/printf.3.gz" = "/usr/share/man")
   ; a section is a digit and up to three more, with a name behind it; 411toppm is a name
   (man-sec? ["3" "printf"]) (man-sec? ["3p" "x"]) (man-sec? ["3ssl" "x"])
   !(man-sec? ["411toppm"]) !(man-sec? ["411toppm" "x"])
   !(man-sec? ["3"]) !(man-sec? ["ls"]) !(man-sec? ["ls" "x"]) !(man-sec? [])
   ; the strip takes sgr runs and leaves every other byte
   (usgr "\x1b[1mbold\x1b[0m and \x1b[4mit\x1b[0m" = "bold and it")
   (usgr "plain" = "plain") (usgr "" = "")
   (usgr "\x1b[0m" = "") (usgr "a\x1b[38;5;9mb" = "ab"))

; --- markdown: the dispatch -- which face a -t names, and what the other flags are not for ---
(: md "# Title\n\nsome *text*.\n"
   h (md-lay md "html" 80 0 "")
   r (md-lay md "roff" 80 0 "")
   t (md-lay md "text" 80 0 "")
   (test
      (h = "<h1>Title</h1>\n<p>some <em>text</em>.</p>")
      (r = ".SH Title\n.PP\nsome \\fItext\\fR.\n")
      ; the width and the terminal belong to the text lane alone
      (h = (md-lay md "html" 40 1 "")) (r = (md-lay md "roff" 40 1 ""))
      ; ..where the attributes come off when the output is not one
      (t = (usgr t)) !(t = (md-lay md "text" 80 1 ""))
      ; an unnamed face is html: that is what a bare `markdown` means
      (h = (md-lay md "" 80 0 ""))
      (md-tos = ["html" "roff" "text"])
      ; one trailing newline on the way out, whether the shower left one or not
      (lensnl h = (h + "\n")) (lensnl r = r) (lensnl "" = "\n")))

; the --version answer: one spelling, name / love VERSION, for a symbol or a string name
(test (uvers 'cat = "cat / love " + love-version) (uvers "mooncc" = "mooncc / love " + love-version))

; android's names, reckoned off the id as bionic's getpwuid/getgrgid are, and back
(test
   (uidroid 0 = "root") (uidroid 1000 = "system") (uidroid 2000 = "shell") (uidroid 9999 = "nobody")
   (uidroid 10123 = "u0_a123") (uidroid 110123 = "u1_a123") (uidroid 101000 = "u1_system")
   (uidroid 99005 = "u0_i5") (uidroid 20123 = "u0_a123_cache") (uidroid 50123 = "all_a123")
   (uidroid 1022 = "1022")                                          ; no fixed name: the number
   (uidroid-of "u0_a123" = [1 10123]) (uidroid-of "u1_a123" = [1 110123]) (uidroid-of "shell" = [1 2000])
   (uidroid-of "u1_system" = [1 101000]) (uidroid-of "u0_i5" = [1 99005])
   !(uidroid-of "u0_zzz") !(uidroid-of "zzz") !(uidroid-of "ux_a1"))

; --- lex: the DFA against the one regex engine's longest match, rule by rule, over a seeded
; draw of texts (the earliest rule takes a tie); two-byte tables past 255 rules; dfa.c's
; refusals; the spec's errors by name ---
(: lexw-spec """
      D  [0-9]
      W  [a-c]
      %%
      {W}+({D}|_)*                     word
      {D}+("."{D}+)?                   num
      "<<"|"<"|"<="|"<<="              lt
      [ \t]+                           ws
      "/*"([^*]|"*"+[^*/])*"*"+"/"     com
      \n                               nl
      [^a-c0-9]                        other
      """
   lexw-rc (cite 'posix 'regcomp) lexw-rx (cite 'posix 'regexec) lexw-run (cite 'dfa 'run)
   lexw-r (lex-scan lexw-spec)
   lexw-t <lexw-r
   lexw-sp (lex-spec lexw-spec)
   lexw-ds (lex-defs <lexw-sp)
   ; each rule whole: ^( ere )$ under regcomp's own flags
   lexw-ms (map (r \ <(lexw-rc ("^(" + lex-ere lexw-ds <r + ")$") 1)) <>lexw-sp)
   (lexw-full k s) (two? (lexw-rx (lexw-ms k) s 0 0))
   ; the oracle at i: the longest prefix some rule matches whole, the earliest such rule
   (lexw-best txt i)
    (: (rl L k) (? (#lexw-ms <= k) 0 (lexw-full k (snip txt i (i + L))) (k + 1) (rl L (k + 1)))
       (go L) (? (L < 1) () (rl L 0 @ r (r ? [r (i + L)] (go (L - 1)))))
       (go (#txt - i)))
   lexw-abc "abc019._<=/* \t\nxz"
   (lexw-draw s n acc) (n < 1 ? [acc s] (random s #lexw-abc @ r (lexw-draw >r (n - 1) (acc + string [(lexw-abc <r)]))))
   (lexw-fz i s)
    (i < 1 ? 'ok
       (: d (lexw-draw s 14 "") txt <d
          bad (filter (j \ lex-next lexw-t txt j != lexw-best txt j) (jot #txt))
          (two? bad ? ['broke txt <bad] (lexw-fz (i - 1) <>d))))
   ; 260 one-word rules: past 255 the tables go two bytes a cell
   lexw-wide <(lex-scan ("%%\n" + join "" (map (k \ "k" + show k + "  w\n") (jot 260))))
   (test
      (lexw-fz 60 (wheel 7) = 'ok)
      (<>lexw-r = '("word" "num" "lt" "ws" "com" "nl" "other"))
      (lex-next lexw-t "ab12_x" 0 = [1 5]) (lex-next lexw-t "1.5." 0 = [2 3])
      (lex-next lexw-t "<<=" 0 = [3 3]) (lex-next lexw-t "/* * */x" 0 = [5 7])
      (lex-next lexw-t "/* *" 0 = [7 1])                   ; an open comment is no comment
      ; a negated class takes a nul, as flex's does; regcomp's own sets never hold one
      (lex-next lexw-t "\0x" 0 = [7 1]) (lex-next lexw-t "/*\0*/" 0 = [5 5])
      (lexw-t 0 = 1) (lexw-wide 0 = 2)
      (lex-next lexw-wide "k123x" 0 = [124 4]) (lex-next lexw-wide "k259" 0 = [260 4])
      (lex-next lexw-wide "k" 0 = ())
      ; dfa.c answers 0 for anything it cannot walk
      (lexw-run "x" "abc" 0 = 0) (lexw-run lexw-t "ab" 2 = 0) (lexw-run lexw-t "ab" 3 = 0)
      (lexw-run lexw-t "ab" -1 = 0) (lexw-run lexw-t 7 0 = 0) (lexw-run (lexw-t + "x") "ab" 0 = 0)
      (lex-scan "x  y\n" = "no %% before the rules")
      (lex-scan "%%\n" = "no rules")
      (lex-scan "%%\n\"ab  q\n" = "an open quote")
      (lex-scan "%%\n[ab  q\n" = "an open bracket")
      (lex-scan "%%\n{X}  q\n" = "no definition {X}")
      (lex-scan "%%\na/b  q\n" = "not yet: / in a/b")
      (lex-scan "%%\na*  q\n" = "a rule matches the empty text")
      (lex-scan "%%\n[b-a]  q\n" = "a backward range")
      (lex-scan "%%\n\\0  q\n" = "a nul byte in a pattern")
      (lex-scan "%%\n[^\\0]  q\n" = "a nul byte in a pattern")
      (snip (lex-text "moon" "t-tab" "t.lex" lexw-r) 0 36 = "; generated by `love lex t.lex`; edi")))


; --- yacc: LALR(1) tables played back through actions. a seeded draw of expression trees laid
; in tokens with the fewest parens precedence allows, parsed back whole; DeRemer and Pennello on
; a grammar SLR cannot take and on empty rules; the reduce/reduce clash LALR's merge makes; the
; dangling else shifted; nonassoc refused; a kind said late, once the actions before it ran;
; lr.c against a love walk of its tables; its step cap and refusals; the spec's errors by name ---
(: yaccw-calc """
      %token NUM
      %left '+' '-'
      %left '*' '/'
      %right NEG
      %%
      e : e '+' e   { ['+ $1 $3] }
        | e '-' e   { ['- $1 $3] }
        | e '*' e   { ['* $1 $3] }
        | e '/' e   { ['/ $1 $3] }
        | '-' e %prec NEG { ['neg $2] }
        | '(' e ')' { $2 }
        | NUM
        ;
      """
   yaccw-lrun (cite 'lr 'run)
   (yaccw-ks ks) (string (catmap (k \ [(k & 255) (k >> 8)]) ks))
   ; tokens (name value).., the name "?" a kind the need says
   (yaccw-go r acts toks ps need)
    (: tm {} ts (<>r 'terms) _ (map (k \ pin tm (ts k) k) (jot #ts))
       (yacc-run <r acts (yaccw-ks (map (t \ (<t = "?" ? 65535 (tm <t))) toks)) (map (t \ <>t) toks) ps need))
   ; the walk lr.c makes, in love: the cursor it answers, byte for byte
   (yaccw-walk t k c look)
    (: (u16 s i) (s (2 * i) + 256 * s (2 * i + 1))
       T (u16 t 0) N (u16 t 1) S (u16 t 2) R (u16 t 3) AN (u16 t 4) GN (u16 t 5)
       rlhs 6 rlen (6 + R) dflt (6 + 2 * R) abase (dflt + S) gdef (abase + S) gbase (gdef + N)
       atab (gbase + N) achk (atab + AN) gtab (achk + AN) gchk (gtab + GN)
       (at x) (u16 t x)
       nk (#k // 2)
       (w32 v) [(v & 255) ((v >> 8) & 255) ((v >> 16) & 255) (v >> 24)]
       (fin pos st z lg)
        (string (w32 pos + w32 #st + catmap (s \ [(s & 255) (s >> 8)]) (rev st) + [z] + w32 #lg +
                 catmap (e \ [(<e & 255) (<e >> 8)] + w32 <>e) (rev lg)))
       (drop n l) (n < 1 ? l (drop (n - 1) >l))
       ; would kind shift after the reductions it calls for (lr.c gives up past 256, or 64 deep)
       (act s kind) (: df (at (dflt + s)) ab (at (abase + s)) i (ab + kind)
                       (ab != 65535 && kind < T && i < AN && at (achk + i) = s ? (at (atab + i)) (df ? (32768 + df - 1) 0)))
       (takes st kind n)
        (? (255 < n) 1
           (act <st kind @ a
              (? (a = 0) () (a < 32768) 1
                 (: r (a - 32768) st2 (drop (at (rlen + r)) st) A (at (rlhs + r)) j (at (gbase + A) + <st2)
                    (takes ((j < GN && at (gchk + j) = A ? (at (gtab + j)) (at (gdef + A))) . st2) kind (n + 1))))))
       (go pos st look lg n)
        (? (n = 4096) (fin pos st 0 lg)
           (: s <st df (at (dflt + s)) a0 (df ? (32768 + df - 1) 0) ab (at (abase + s))
              kd (ab = 65535 ? 0 (pos < nk ? (u16 k pos) 0))
              (? (ab != 65535 && kd = 65535 && look = 65535) (fin pos st 3 lg)
                 (ab != 65535 && kd = 65535 && look > 65535)
                  (go pos st (takes st (look & 65535) 0 ? (look & 65535) ((look >> 16) - 1)) lg n)
                 (: kind (kd = 65535 ? look kd) i (ab + kind)
                    a (ab != 65535 && kind < T && i < AN && at (achk + i) = s ? (at (atab + i)) a0)
                    (? (a = 0) (fin pos st 2 lg)
                       (a < 32768) (kind = 0 ? (fin pos st 1 lg) (go (pos + 1) (a . st) 65535 lg (n + 1)))
                       (: r (a - 32768) st2 (drop (at (rlen + r)) st) A (at (rlhs + r))
                          j (at (gbase + A) + <st2)
                          ns (j < GN && at (gchk + j) = A ? (at (gtab + j)) (at (gdef + A)))
                          (go pos (ns . st2) look ([r pos] . lg) (n + 1))))))))
       (go (yacc-u32 c 0) (rev (map (i \ u16 c (4 + i)) (jot (yacc-u32 c 4)))) look () 0))
   ; a seeded draw of kind strings, some said late, walked to the end both ways from each cursor
   (yaccw-cmp t T i s)
    (? (i < 1) 'ok
       (random s 10 @ r
          (: (draw s n acc) (n < 1 ? (acc . s) (random s (T + 2) @ q (draw >q (n - 1) ((<q < T ? <q 65535) . acc))))
             d (draw >r <r ())
             ks (yaccw-ks <d)
             (chain c look n)
              (: a (yaccw-lrun t ks c look) b (yaccw-walk t ks c look)
                 z (a (8 + 2 * yacc-u32 a 4))
                 (? (a != b) ['broke <d c look]
                    (z = 3 && n > 0) (chain a (n % 2 ? (n % T) (n % T + 65536 * (n % 3 + 1))) (n - 1))
                    'ok))
             (chain yacc-c0 65535 8 = 'ok ? (yaccw-cmp t T (i - 1) >d) ['broke <d]))))
   yaccw-cr (yacc-scan yaccw-calc)
   yaccw-ca {1 (\ _ [a _ b] ['+ a b]) 2 (\ _ [a _ b] ['- a b]) 3 (\ _ [a _ b] ['* a b])
             4 (\ _ [a _ b] ['/ a b]) 5 (\ _ [_ a] ['neg a]) 6 (\ _ [_ a _] a)}
   ; -> (tree . seed)
   (yaccw-tree s d)
    (random s (d < 1 ? 1 6) @ r
       (: k <r s1 >r
          (? (k = 0) (random s1 100)
             (k = 5) (yaccw-tree s1 (d - 1) @ (a . s2) (['neg a] . s2))
             (yaccw-tree s1 (d - 1) @ (a . s2)
                (yaccw-tree s2 (d - 1) @ (b . s3) ([(['+ '- '* '/] (k - 1)) a b] . s3))))))
   (yaccw-pr e) (charm? e ? 4 (<e @ 'neg 3 '+ 1 '- 1 2))
   (yaccw-sub e p right)
    (: l (yaccw-lay e)
       (yaccw-pr e < p || right && yaccw-pr e = p ? ([["'('" ()]] + l + [["')'" ()]]) l))
   (yaccw-lay e)
    (? (charm? e) [["NUM" e]]
       (<e = 'neg) ([["'-'" ()]] + yaccw-sub <>e 3 ())
       (: p (yaccw-pr e) (yaccw-sub (e 1) p () + [[("'" + show <e + "'") ()]] + yaccw-sub (e 2) p 1)))
   (yaccw-fz i s)
    (i < 1 ? 'ok
       (yaccw-tree s 4 @ (e . s2)
          (yaccw-go yaccw-cr yaccw-ca (yaccw-lay e) () () @ r
             (r = ['ok e] ? (yaccw-fz (i - 1) s2) ['broke e r]))))
   yaccw-long (foldl (a \ k \ ['+ a k]) 0 (map (+ 1) (jot 2999)))
   ; LALR, not SLR: an l's lookahead set by where it stands
   yaccw-lr (yacc-scan """
      %token ID
      %%
      s : l '=' r { ['asn $1 $3] } | r ;
      l : '*' r { ['deref $2] } | ID ;
      r : l ;
      """)
   yaccw-la {1 (\ _ [a _ b] ['asn a b]) 3 (\ _ [_ a] ['deref a])}
   yaccw-nul (yacc-scan "%%\ns : a b 'x' ;\na : | 'y' ;\nb : | 'z' ;\n")
   yaccw-na {1 (\ _ [a b _] [a b])}
   (yaccw-cs s) (map (c \ [("'" + string [c] + "'") (string [c])]) (map s (jot #s)))
   ; LR(1), not LALR: the two c states merge, and A and B clash on d and on e
   yaccw-rr (yacc-scan "%%\ns : 'a' A 'd' | 'b' B 'd' | 'a' B 'e' | 'b' A 'e' ;\nA : 'c' ;\nB : 'c' ;\n")
   yaccw-de (yacc-scan "%token IF E X\n%%\ns : IF s E s { ['ife $2 $4] } | IF s { ['if $2] } | X ;\n")
   yaccw-da {1 (\ _ [_ a _ b] ['ife a b]) 2 (\ _ [_ a] ['if a])}
   yaccw-nas (yacc-scan "%token N\n%nonassoc '<'\n%left '+'\n%%\ne : e '<' e | e '+' e | N ;\n")
   ; a typedef's name is a type from the next token on: the need runs after the actions before it
   yaccw-td (yacc-scan """
      %token TYPEDEF TYPE ID UNSIGNED
      %%
      p : | p i ;
      i : TYPEDEF ID ';' | TYPE ID ';' | ID '=' ID ';' | UNSIGNED ID ';' ;
      """)
   yaccw-tda {1 (\ _ _ ()) 2 (\ _ [l x] (l + [x])) 3 (\ ps [_ n _] (pin ps n 1, ['tdef n]))
              4 (\ _ [t n _] ['decl t n]) 5 (\ _ [a _ b _] ['asn a b]) 6 (\ _ [_ n _] ['uns n])}
   yaccw-tdt [["TYPEDEF" ()] ["?" "T"] ["';'" ()] ["?" "T"] ["?" "x"] ["';'" ()] ["?" "x"] ["'='" ()] ["?" "y"] ["';'" ()]
              ["UNSIGNED" ()] ["?" "T"] ["';'" ()]]
   ; a type's name is TYPE where a type may stand, else the declarator's ID: lr.c's pair
   (yaccw-tdn ps i) (: ts (<>yaccw-td 'terms) (k nm) <(filter (j \ ts j = nm) (jot #ts))
                       (peep ps <>(yaccw-tdt i) () ? (k "TYPE" + 65536 * (k "ID" + 1)) (k "ID")))
   (test
      (string? <yaccw-cr) (<>yaccw-cr 'sr = 0) (<>yaccw-cr 'rr = 0)
      (yaccw-fz 80 (wheel 11) = 'ok)
      (yaccw-cmp <yaccw-cr #(<>yaccw-cr 'terms) 300 (wheel 5) = 'ok)
      (yaccw-go yaccw-cr yaccw-ca (yaccw-lay yaccw-long) () () = ['ok yaccw-long])   ; past lr.c's 4096 steps a call
      (yaccw-go yaccw-cr yaccw-ca [["NUM" 1] ["'+'" ()] ["'*'" ()] ["NUM" 2]] () () = ['err 2])
      (yaccw-go yaccw-cr yaccw-ca [["NUM" 1] ["'+'" ()]] () () = ['err 2])
      (yaccw-go yaccw-cr yaccw-ca () () () = ['err 0])
      ; a token's value off its tail: here how many tokens stand from it on
      (yacc-runv <yaccw-cr {} (yaccw-ks [1 2 1]) [5 () 6] () () (l \ #l) = ['ok 3])
      (<>yaccw-lr 'sr = 0) (<>yaccw-lr 'rr = 0)
      (yaccw-go yaccw-lr yaccw-la [["'*'" ()] ["ID" "p"] ["'='" ()] ["ID" "q"]] () () = ['ok ['asn ['deref "p"] "q"]])
      (yaccw-go yaccw-lr yaccw-la [["'*'" ()] ["'*'" ()] ["ID" "p"]] () () = ['ok ['deref ['deref "p"]]])
      (<>yaccw-nul 'sr = 0) (<>yaccw-nul 'rr = 0)
      (yaccw-go yaccw-nul yaccw-na (yaccw-cs "yzx") () () = ['ok ["y" "z"]])
      (yaccw-go yaccw-nul yaccw-na (yaccw-cs "x") () () = ['ok [() ()]])
      (yaccw-go yaccw-nul yaccw-na (yaccw-cs "zx") () () = ['ok [() "z"]])
      (yaccw-go yaccw-nul yaccw-na (yaccw-cs "zyx") () () = ['err 1])
      (<>yaccw-rr 'rr = 2) (<>yaccw-rr 'sr = 0)
      (<>yaccw-de 'sr = 1)
      (yaccw-go yaccw-de yaccw-da [["IF" ()] ["IF" ()] ["X" 'x] ["E" ()] ["X" 'y]] () () = ['ok ['if ['ife 'x 'y]]])
      (<(yaccw-go yaccw-nas {} [["N" 1] ["'<'" ()] ["N" 2] ["'+'" ()] ["N" 3]] () ()) = 'ok)
      (yaccw-go yaccw-nas {} [["N" 1] ["'<'" ()] ["N" 2] ["'<'" ()] ["N" 3]] () () = ['err 3])
      (yaccw-go yaccw-td yaccw-tda yaccw-tdt {} yaccw-tdn = ['ok [['tdef "T"] ['decl "T" "x"] ['asn "x" "y"] ['uns "T"]]])
      ; lr.c answers () for anything it cannot walk
      (yaccw-lrun "x" "" yacc-c0 65535 = ()) (yaccw-lrun <yaccw-cr "\0" yacc-c0 65535 = ())
      (yaccw-lrun <yaccw-cr "" "\0\0\0\0\0\0\0\0\0\0" 65535 = ()) (yaccw-lrun (<yaccw-cr + "xx") "" yacc-c0 65535 = ())
      (yacc-scan "%token A\n" = "no %% before the rules")
      (yacc-scan "%%\n" = "no rules")
      (yacc-scan "%%\ns : t ;\n" = "t is neither a token nor a rule on line 2")
      (yacc-scan "%token s\n%%\ns : 'x' ;\n" = "s is a token and a rule on line 3")
      (yacc-scan "%%\ns : {a} 'x' ;\n" = "not yet: an action mid-rule on line 2")
      (yacc-scan "%define x\n%%\ns : 'x' ;\n" = "not yet: %define")
      (yacc-scan "%%\ns : 'x' %prec 'y' ;\n" = "'y' has no precedence on line 2")
      (yacc-scan "%%\ns : 'x' { [ ;\n" = "an open action on line 2")
      (snip (yacc-text "moon" "c-tab" "c.y" <>yaccw-cr <yaccw-cr) 0 38 = "; generated by `love yacc c.y`; edit t")
      ; the text after a second %% is laid last, after the actions it may call through
      (: g (yacc-scan "%%\ns : 'x' { 1 } ;\n%%\n   zz 1\n")
         (has? (yacc-text "m" "n" "s.y" <>g <g) "(\\ yy [_1] (1))}\n\n   zz 1\n"))
      (elem "      1 (\\ yy [_1 _2 _3] (['+ _1 _3]))" (yacc-acts <>yaccw-cr))))
(test_fin ())                                        ; no zz-fin here: quit before claiming ok
(say err "test/law/kore: myers + patience + lines/unlines + unified hunks + the u-floor + the regex floor + the find, awk, pager, man, markdown, bc, lex and yacc floors -- projections + minimality (lcs oracle) + anchors + seeded fuzz (lcs + bc oracles) ok
")
