; test/host/seek.l -- the picker and help's lines, headless
; seek is a pure step and a pure frame (src/apps/seek.l): this drives both over a small list,
; then help's line table over a tree laid here. run: cat test/00-init.l test/host/seek.l | out/love
(borrow 'seek)
(borrow 'help)
(borrow 'posix)

(: (sk-has? h n) (0 <= findsub h n)
   (sk-keys! d s) (each (map (i \ s i) ^#s) (c \ seek-key d c))
   items ["alpha beta" "beta gamma" "Gamma delta" "alphabet"]
   d (seek-new items (x \ x) (x \ "> " + x) "t")
   _ (test (d 'n = 4) (d 'sel = 0) (d 'q = ""))
   ;; a word narrows, case and all; a second word must sit in the line too
   _ (sk-keys! d "alpha", test (d 'n = 2) (d 'hits = ["alpha beta" "alphabet"]))
   _ (sk-keys! d " be", test (d 'hits = ["alpha beta" "alphabet"]))
   _ (sk-keys! d "ta", test (d 'hits = ["alpha beta"]))
   ;; backspace widens again: the hits are read afresh, not from the narrowed ones
   _ (each ^4 (_ \ seek-key d 127), test (d 'q = "alpha ") (d 'n = 2))
   _ (seek-key d 21, test (d 'q = "") (d 'n = 4))
   _ (sk-keys! d "gamma", test (d 'hits = ["beta gamma"]))
   ;; the choice moves and stays on the list; enter takes it, esc takes none
   _ (seek-key d 21, seek-key d -9, seek-key d -9, test (d 'sel = 2))
   _ (seek-key d -6, test (d 'sel = 3))
   _ (seek-key d -9, test (d 'sel = 3))
   _ (seek-key d -5, seek-key d -8, test (d 'sel = 0))
   _ (seek-key d 14, seek-key d 13, test (d 'pick = "beta gamma") (d 'over = 1))
   e (seek-new items (x \ x) (x \ x) "t")
   _ (sk-keys! e "zzz", seek-key e 13, test (e 'n = 0) (e 'pick = ()) (e 'over = 0))
   _ (seek-key e 27, test (e 'over = 1) (e 'pick = ()))
   ;; the frame: the query and its count on top, the chosen row reversed, the window
   ;; following the choice down a list longer than the screen
   f (seek-frame d 40 4)
   _ (test (sk-has? f "> ") (sk-has? f "4 of 4  t") (sk-has? f "\e[7m> beta gamma"))
   g (seek-new (map show ^10) (x \ x) (x \ "row " + x) "t")
   _ (seek-frame g 40 4, each ^7 (_ \ seek-key g -9))
   f (seek-frame g 40 4)
   _ (test (g 'sel = 7) (g 'top = 5) (sk-has? f "row 5") (sk-has? f "\e[7mrow 7") (!(sk-has? f "row 4")))
   ;; help's lines: every line of every text file, numbered from 1; a file with a NUL is skipped
   r "out/.seek-test"
   _ (mkdir r 493, mkdir (r + "/b") 493)
   _ (open (r + "/a.l") "w" @ p (say p "one\ntwo stage\n", close p))
   _ (open (r + "/b/c.l") "w" @ p (say p "stage three", close p))
   _ (open (r + "/b/bin") "w" @ p (say p ("stage" + string 0), close p))
   _ (mkdir (r + "/.hid") 493, open (r + "/.hid/x.l") "w" @ p (say p "stage hidden", close p))
   ls (help-lines r)
   _ (test (#ls = 3) (ls 0 = [(r + "/a.l") 1 "one"]) (ls 1 = [(r + "/a.l") 2 "two stage"])
           (ls 2 = [(r + "/b/c.l") 1 "stage three"]))
   ;; vi's :find and :grep, over the tree under the working directory: a dot name is passed by
   _ (chdir r)
   _ (test (seek-files "." = ["a.l" "b/bin" "b/c.l"]))
   st ((cite 'vi 'vi-open) "")
   fc ((cite 'vi 'vi-face) st {})
   (vk s) (each (map (i \ s i) ^#s) (c \ (fc 1) c))
   _ (vk ":find c\r")
   _ (test (!(nil? (st 'seek))) ((st 'seek) 'n = 1) (sk-has? ((fc 0) 60 10) "b/c.l"))
   _ ((fc 1) 13, test (() = st 'seek) (st 'file = "b/c.l") (st 'lines = ["stage three"]))
   _ (vk ":grep stage\r")
   _ (test ((st 'seek) 'n = 2) (sk-has? ((fc 0) 60 10) "a.l:2: two stage"))
   _ ((fc 1) 13, test (st 'file = "a.l") (st 'row = 1) (() = st 'seek))
   ;; esc goes back to the buffer untouched; a dirty buffer is not left for another file
   _ (vk ":find\r", (fc 1) 27, test (() = st 'seek) (st 'file = "a.l"))
   _ (vk "ix", (fc 1) 27, vk ":find c\r", (fc 1) 13, test (st 'file = "a.l") (st 'dirty))
   _ (chdir "../.."))

(test_fin ())
(puts "src/apps/seek: ok -- the query narrows, case and all, and widens again; the choice and its window; help's line table\n")
