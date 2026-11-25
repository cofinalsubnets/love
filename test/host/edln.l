; test/host/edln.l -- tab in lush on a real pty: keys typed, the cells of a quay screen read.
; not in the corpus: the screen nifs are not in love0. run: cat test/00-init.l test/host/00-host.l test/host/edln.l | out/love
(borrow "src/apps/mitty/mooring.l")
(: D ("/tmp/edln-" + show (getpid 0))
   L (cwd 0 + "/out/love lush")
   (lay n) (close (open (D + "/" + n) "w"))
   (dir n) (mkdir (D + "/" + n) 448)
   _ (mkdir D 448)
   _ (each ["alpha-one" "alpha-two" "alphabet" "alpha sp" ".hid1" ".hid2" "wide-é" "wide-漢字" "wide-è" "q'uo" "q'up" "ct\x01la" "ctlb" "so\nlo" "$dol" "~til" "half-é" "half-è"] lay)
   _ (each ["alpha-dir" "many" "two" "deep dir"] dir)
   _ (each (jot 200) (i \ lay ("many/file" + show (1000 + i))))
   _ (each ["two/left" "two/right" "deep dir/in"] lay)
   ; the prompt is "~ $ ", home being D; nothing of the user's is read
   (chat s i) (2097151 & glass s i 0)
   (trim t) (: (go n) (0 < n && t (n - 1) = 32 ? (go (n - 1)) (snip t 0 n)) (go #t))
   (rowtx s r) (gaze s 2 @ c
     (trim (foldl (a \ i \ chat s (r * c + i) @ ch a + (ch = 0 ? (r * c + i - 1 @ p (0 < i && 0x1100 <= chat s p ? "" " ")) (utf8 ch))) "" (jot c))))
   (trail l) (rev (: (go x) (two? x && <x = "" ? (go >x) x) (go (rev l))))
   (look s) (trail (map (rowtx s) (jot (gaze s 1))))
   (at s) (gaze s 0 @ p [(p // gaze s 2) (p % gaze s 2)])
   (start r c)
     (: md (tether ["sh" "-c" "stty rows \(show r) columns \(show c) -echo; cd \(D); exec env -i HOME=\(D) PATH=/nowhere LOVE_NEST=\(D)/.nest TERM=xterm \(L)"])
        bx {() (h-mkscr r c)}
        _ (twirl (_ \ moor bx >md ()) 0)
        [(bx ()) >md <md])
   (until f ms) (: t0 (clock 0) (go _) (f () ? 1 (ms < clock t0) 0 (rest 10, go ())) (go ()))
   ; screen x shows just these rows, and the cursor is at rc (() for anywhere)
   (shows x rows rc)
     (: s <x ok (until (_ \ look s = rows && (rc = () || at s = rc)) 8000)
        (ok ? 1 (putx ["want" rows rc "got" (look s) (at s)], putc 10, 0)))
   (type x k) (say (x 1) k, flush (x 1))
   (end x) (still (0 - x 2) 9, h-wf (x 2), close (x 1))
   P "~ $ "
   LS (P + "ls ")
   ; a shell r by c, its prompt up, f on it
   (with r c f) (: x (start r c) up (shows x ["~ $"] [0 4]) _ (test up) _ (? up (f x) 0) (end x))
   M "alpha-dir/  alphabet"
   menu ["alpha sp    alpha-dir/  alpha-one   alpha-two   alphabet"])

; the prefix first, with no list; then the list, one prompt; then the choices round and back
(with 12 60 (x \
(  type x "ls al\t",
  test (shows x [(LS + "alpha")] [0 12]),
  type x "\t",
  test (shows x ((LS + "alpha") . menu) [0 12]),
  test (0 = glass <x 60 0 >> 24),
  type x "\t", test (shows x ((LS + "alpha\\ sp") . menu) [0 16]),
  test (4 = glass <x 60 0 >> 24 && 4 = glass <x 67 0 >> 24 && 0 = glass <x 68 0 >> 24),
  type x "\t", test (shows x ((LS + "alpha-dir/") . menu) [0 17]),
  type x "\t", test (shows x ((LS + "alpha-one") . menu) [0 16]),
  type x "\t\t", test (shows x ((LS + "alphabet") . menu) [0 15]),
  type x "\t", test (shows x ((LS + "alpha\\ sp") . menu) [0 16]),
  type x "\e[Z", test (shows x ((LS + "alphabet") . menu) [0 15]),
  type x "\e[Z", test (shows x ((LS + "alpha-two") . menu) [0 16]))))

; a terminal's report coming late is no key: the list stays, and tab goes on from it
(with 12 60 (x \
(  type x "ls al\t\t", test (shows x ((LS + "alpha") . menu) [0 12]),
  type x "\e[?2027;1$y", rest 300, test (shows x ((LS + "alpha") . menu) [0 12]),
  type x "\t", test (shows x ((LS + "alpha\\ sp") . menu) [0 16]),
  type x "\e[?2027;1$y\t", test (shows x ((LS + "alpha-dir/") . menu) [0 17]))))

; shift-tab from the bare list is the last one
(with 12 60 (x \ (type x "ls al\t\t\e[Z", test (shows x ((LS + "alphabet") . menu) ()))))

; a letter leaves the list for the next tab, which lays the fewer
(with 12 60 (x \
(  type x "ls al\t\t-",
  test (shows x ((LS + "alpha-") . menu) [0 13]),
  type x "\t", test (shows x [(LS + "alpha-") "alpha-dir/  alpha-one   alpha-two"] [0 13]),
  type x "t\t", test (shows x [(LS + "alpha-two")] [0 17]))))

; a letter after a choice stays on it
(with 12 60 (x \ (type x "ls al\t\t\t\t\tx", test (shows x ((LS + "alpha-onex") . menu) [0 17]))))

; enter takes the choice and does not run it; the next runs it, on a clean row
(with 12 60 (x \
(  type x "echo al\t\t\t\r", test (shows x [(P + "echo alpha\\ sp")] [0 19]),
  type x "\r", test (shows x [(P + "echo alpha\\ sp") "alpha sp" "~ $"] [2 4]))))
; with a list alone enter runs the line
(with 12 60 (x \ (type x "echo al\t\t\r", test (shows x [(P + "echo alpha") "alpha" "~ $"] [2 4]))))
; / after a directory is the one it has
(with 12 60 (x \ (type x "ls al\t\t\t\t/", test (shows x [(LS + "alpha-dir/")] [0 17]))))

; every key that ends it leaves no list
(each ["\x7f" "\e[D" " " "\x01" "\x04" "\e[A"] (k \
(  with 12 60 (x \
(    type x "ls al\t\t", test (shows x ((LS + "alpha") . menu) [0 12]),
    type x k,
    test (until (_ \ #(look <x) < 2) 3000))))))
(with 12 60 (x \ (type x "ls al\t\t\x03", test (shows x [(LS + "alpha^C") "~ $"] [1 4]))))
(with 12 60 (x \ (type x "ls al\t\t\x12", test (until (_ \ look <x = ["(reverse-i-search)`': ls alpha"]) 3000),
                 type x "\x07", test (shows x [(LS + "alpha")] [0 12]))))

; on the last row the screen gives way by the list's rows; the line goes on from there
(with 5 60 (x \
(  type x "echo 1;echo 2\r", test (shows x [(P + "echo 1;echo 2") "1" "2" "~ $"] [3 4]),
  type x "echo 3\r", test (shows x ["1" "2" (P + "echo 3") "3" "~ $"] [4 4]),
  type x "ls al\t\t", test (shows x ["2" (P + "echo 3") "3" (LS + "alpha") <menu] [3 12]),
  type x "\t\t\t", test (shows x ["2" (P + "echo 3") "3" (LS + "alpha-one") <menu] [3 16]),
  type x "\x7f", test (shows x ["2" (P + "echo 3") "3" (LS + "alpha-on")] [3 15]))))

; a line that wraps, one column of names under it, and one ending on the margin
(with 12 20 (x \
(  type x "echo xxxxxxxxxxxx al\t\t",
  test (shows x ["~ $ echo xxxxxxxxxxx" "x alpha" "alpha sp" "alpha-dir/" "alpha-one" "alpha-two" "alphabet"] [1 7]),
  type x "\t\t", test (shows x ["~ $ echo xxxxxxxxxxx" "x alpha-dir/" "alpha sp" "alpha-dir/" "alpha-one" "alpha-two" "alphabet"] [1 12]))))
(with 12 20 (x \
(  type x "echo xxxxx al\t\t",
  test (shows x ["~ $ echo xxxxx alpha" "" "alpha sp" "alpha-dir/" "alpha-one" "alpha-two" "alphabet"] [1 0]))))

; a letter landing on the margin with the list up moves the list down a row
(with 12 20 (x \
(  type x "echo xxxx al\t\t", test (shows x ["~ $ echo xxxx alpha" "alpha sp" "alpha-dir/" "alpha-one" "alpha-two" "alphabet"] [0 19]),
  type x "x", test (shows x ["~ $ echo xxxx alphax" "" "alpha sp" "alpha-dir/" "alpha-one" "alpha-two" "alphabet"] [1 0]))))

; more than the screen holds: what fits and a count, every one still reached, a page at a time
(: nm (i \ "file" + show (1000 + i))
   (row b r) (foldl (a \ c \ (? (a = "") "" (a + "  ")) + nm (b + c * 4 + r)) "" (jot 6))
   (big b) [(row b 0) (row b 1) (row b 2) (row b 3) "and 176 more"]
 (with 6 60 (x \
(  type x "ls many/\t", test (shows x [(LS + "many/file1")] ()),
  type x "\t", test (shows x ((LS + "many/file1") . big 0) ()),
  type x (foldl (+) "" (map (_ \ "\t") (jot 24))), test (shows x ((LS + "many/file1023") . big 0) ()),
  type x "\t", test (shows x ((LS + "many/file1024") . big 24) ()),
  type x "\e[Z\e[Z\x03", type x "ls many/\t\t\e[Z",
  test (until (_ \ elem (LS + "many/file1199") (look <x)) 3000)))))

; widths by column, and what is shared ends on a whole character
(with 12 60 (x \
(  type x "ls wi\t", test (shows x [(LS + "wide-")] [0 12]),
  type x "\t", test (shows x [(LS + "wide-") "wide-è     wide-é     wide-漢字"] [0 12]),
  type x "\t\t\t", test (shows x [(LS + "wide-漢字") "wide-è     wide-é     wide-漢字"] [0 16]))))
(with 12 60 (x \ (type x "ls ha\t", test (shows x [(LS + "half-")] [0 12]), type x "x", test (shows x [(LS + "half-x")] [0 13]))))

; spaces and quotes
(with 12 60 (x \ (type x "echo alpha\\ s\t\r", test (shows x [(P + "echo alpha\\ sp") "alpha sp" "~ $"] ()))))
(with 12 60 (x \ (type x "echo \"alpha s\t\r", test (shows x [(P + "echo \"alpha sp\"") "alpha sp" "~ $"] ()))))
(with 12 60 (x \ (type x "echo 'alpha s\t\r", test (shows x [(P + "echo 'alpha sp'") "alpha sp" "~ $"] ()))))
(with 12 60 (x \ (type x "echo \"al\t\t\t\t\t\r\r", test (shows x [(P + "echo \"alpha-one\"") "alpha-one" "~ $"] ()))))
(with 12 60 (x \ (type x "echo q\t", test (shows x [(P + "echo q\\'u")] ()),
                 type x "\t", test (shows x [(P + "echo q\\'u") "q'uo  q'up"] ()),
                 type x "\t\r\r", test (shows x [(P + "echo q\\'uo") "q'uo" "~ $"] ()))))
(with 12 60 (x \ (type x "echo \\$\t\r", test (shows x [(P + "echo \\$dol") "$dol" "~ $"] ()))))
(with 12 60 (x \ (type x "echo \\~\t\r", test (shows x [(P + "echo \\~til") "~til" "~ $"] ()))))
(with 12 60 (x \ (type x "echo ~/alpha\\ \t\r", test (shows x [(P + "echo ~/alpha\\ sp") (D + "/alpha sp") "~ $"] ()))))
(with 12 60 (x \ (type x "echo \"deep\t", test (shows x [(P + "echo \"deep dir/")] ()),
                 type x "\t\r", test (shows x [(P + "echo \"deep dir/in\"") "deep dir/in" "~ $"] ()))))
; a name with a newline goes in quotes, whole
(with 12 60 (x \ (type x "echo so\t\r", test (shows x [(P + "echo 'so lo'") "so" "lo" "~ $"] ()))))
; a control byte is shown as ^X, never sent
(with 12 60 (x \ (type x "ls ct\t", test (shows x [(LS + "ct") "ct^Ala  ctlb"] ()))))
; a directory's names alone, and a dot name only by its dot
(with 12 60 (x \ (type x "ls two/\t", test (shows x [(LS + "two/") "left   right"] ()))))
(with 12 60 (x \ (type x "ls .h\t\t", test (shows x [(LS + ".hid") ".hid1  .hid2"] ()))))
; a command, its builtins
(with 12 60 (x \ (type x "unse\t", test (shows x [(P + "unset")] [0 10]))))
; nothing matches: the line stays, and a stale list goes
(with 12 60 (x \ (type x "ls al\t\tzz\t", test (shows x [(LS + "alphazz")] [0 14]))))

(h-wf <(tether ["rm" "-rf" D]))
(test_fin ())
(puts "edln: ok\n")
