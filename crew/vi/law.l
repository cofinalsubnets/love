; crew/vi/law.l -- the editor's laws, held by assertion: every key sequence
; below drives the PURE engine (vstep, one byte at a time) and reads the
; tablet back -- no tty, no port, no file. the cat (`make test_vi`):
;
;   cat test/00-init.l crew/kore/text.l crew/kore/core.l crew/kore/re.l crew/vi/core.l crew/vi/law.l | out/host/love
;
; (vgo lines keys) births a buffer, feeds the TEXT's bytes (27 spelled \e via
; the 27-element list shape), and answers the state; the helpers read it back.
(: (bytes s) (: n (tally s) (go i acc) (? (< i 0) acc (go (- i 1) (link (s i) acc))) (go (- n 1) ()))
   (vgo ls ks) (vfeed (vnew ls "t") (bytes ks))
   (vgob ls bs) (vfeed (vnew ls "t") bs)
   BS 127 CR 13
   (lns st) (st 'lines) (at st) (L (st 'row) (st 'col))
   (st? st k) (st k)

; --- motion: hjkl, 0 ^ $, counts, the goal column, G/gg ---
   _ (assert
      (= (at (vgo '("abc" "de") "ll")) '(0 2))
      (= (at (vgo '("abc" "de") "lll")) '(0 2))                ; the col fence
      (= (at (vgo '("abc" "de") "llh")) '(0 1))
      (= (at (vgo '("abc" "de") "j")) '(1 0))
      (= (at (vgo '("abc" "de") "jj")) '(1 0))                 ; the row fence
      (= (at (vgo '("abc" "de") "jk")) '(0 0))
      (= (at (vgo '("abc") "$")) '(0 2))
      (= (at (vgo '("abc") "$0")) '(0 0))
      (= (at (vgo '("  xy") "^")) '(0 2))
      (= (at (vgo '("abcdef") "3l")) '(0 3))
      (= (at (vgo '("abcdef" "ab") "$j")) '(1 1))              ; clamp on the short line ...
      (= (at (vgo '("abcdef" "ab" "abcdef") "$jj")) '(2 5))    ; ... but the GOAL survives
      (= (at (vgo '("a" "b" "c") "G")) '(2 0))
      (= (at (vgo '("a" "b" "c") "2G")) '(1 0))
      (= (at (vgo '("a" "b" "c") "Ggg")) '(0 0))
      (= (at (vgo '("a" "b" "c") "3gg")) '(2 0)))

; --- words: w e b across lines ---
   _ (assert
      (= (at (vgo '("foo bar baz") "w")) '(0 4))
      (= (at (vgo '("foo bar baz") "2w")) '(0 8))
      (= (at (vgo '("foo.bar") "w")) '(0 3))                   ; punct is its own word
      (= (at (vgo '("foo" "bar") "w")) '(1 0))                 ; w crosses the line
      (= (at (vgo '("foo bar") "e")) '(0 2))
      (= (at (vgo '("foo bar") "ee")) '(0 6))
      (= (at (vgo '("foo bar") "$b")) '(0 4))
      (= (at (vgo '("foo bar") "$bb")) '(0 0))
      (= (at (vgo '("foo" "bar") "jb")) '(0 0)))               ; b crosses back

; --- f F t T ---
   _ (assert
      (= (at (vgo '("abcabc") "fc")) '(0 2))
      (= (at (vgo '("abcabc") "2fc")) '(0 5))
      (= (at (vgo '("abcabc") "tc")) '(0 1))
      (= (at (vgo '("abcabc") "$Fa")) '(0 3))
      (= (at (vgo '("abcabc") "$Ta")) '(0 4))
      (= (at (vgo '("abc") "fz")) '(0 0)))                     ; a miss stands still

; --- insert: i a I A o O, enter, backspace, escape ---
   _ (assert
      (= (lns (vgo '("bc") "iaX")) '("aXbc"))                  ; i, then a and X insert
      (= (lns (vgob '("ac") (L 105 98 27 88))) '("bac"))       ; i b ESC, then X at col 0 bites nothing
      (= (lns (vgo '("") "ihello")) '("hello"))
      (= (lns (vgo '("xy") "aZ")) '("xZy"))
      (= (lns (vgo '("xy") "AZ")) '("xyZ"))
      (= (lns (vgo '("  xy") "IZ")) '("  Zxy"))
      (= (lns (vgo '("ab") "ocd")) '("ab" "cd"))
      (= (at (vgo '("ab") "ocd")) '(1 2))
      (= (lns (vgo '("ab") "Ocd")) '("cd" "ab"))
      (= (lns (vgo '("ab" "cd") "jOx")) '("ab" "x" "cd")))
   _ (assert
      (= (lns (vgob '("abcd") (L 108 108 105 13))) '("ab" "cd"))          ; ll i CR splits
      (= (at (vgob '("abcd") (L 108 108 105 13))) '(1 0))
      (= (lns (vgob '("abcd") (L 65 120 BS BS 121))) '("abcy"))           ; A x bsp bsp y
      (= (lns (vgob '("ab" "cd") (L 106 105 BS))) '("abcd"))              ; bsp at col 0 joins up
      (= (at (vgob '("ab" "cd") (L 106 105 BS))) '(0 2))
      (= (at (vgob '("abc") (L 65 27))) '(0 2))                           ; esc steps left, fenced
      (= (st? (vgob '("a") (L 105 120 27)) 'mode) 'n))

; --- operators: x X D C s r J, dd yy cc, d+motion, spans ---
   _ (assert
      (= (lns (vgo '("abc") "x")) '("bc"))
      (= (lns (vgo '("abc") "2x")) '("c"))
      (= (lns (vgo '("abc") "lx")) '("ac"))
      (= (lns (vgo '("abc") "$X")) '("ac"))
      (= (lns (vgo '("abcdef") "llD")) '("ab"))
      (= (at (vgo '("abcdef") "llD")) '(0 1))
      (= (lns (vgo '("abc" "def") "dd")) '("def"))
      (= (lns (vgo '("abc" "def") "jdd")) '("abc"))
      (= (lns (vgo '("a" "b" "c") "2dd")) '("c"))
      (= (lns (vgo '("only") "dd")) '(""))                     ; the vi invariant: one line stays
      (= (lns (vgo '("foo bar") "dw")) '("bar"))
      (= (lns (vgo '("foo bar") "d$")) '(""))
      (= (lns (vgo '("foo bar") "wdb")) '("bar"))
      (= (lns (vgo '("abcabc") "dfb")) '("cabc"))
      (= (lns (vgo '("abcabc") "dtb")) '("bcabc"))
      (= (lns (vgo '("a" "b" "c") "dj")) '("c"))               ; d+linewise takes both rows
      (= (lns (vgo '("a" "b" "c") "jdk")) '("c"))
      (= (lns (vgo '("a" "b" "c") "dG")) '(""))
      (= (lns (vgo '("abc") "rz")) '("zbc"))
      (= (lns (vgo '("abcd") "2rz")) '("zzcd"))
      (= (at (vgo '("abcd") "2rz")) '(0 1))
      (= (lns (vgo '("ab" "  cd") "J")) '("ab cd"))
      (= (at (vgo '("ab" "  cd") "J")) '(0 2))
      (= (lns (vgo '("a" "b" "c") "3J")) '("a b c")))
   _ (assert
      (= (lns (vgo '("foo bar") "cwxy")) '("xy bar"))          ; c enters insert
      (= (st? (vgo '("foo bar") "cw") 'mode) 'i)
      (= (lns (vgo '("abc") "sZ")) '("Zbc"))
      (= (lns (vgo '("abcdef") "llCxy")) '("abxy"))
      (= (lns (vgo '("aa" "bb") "ccX")) '("X" "bb")))          ; cc keeps a fresh line

; --- yank + paste, both kinds ---
   _ (assert
      (= (lns (vgo '("ab" "cd") "yyp")) '("ab" "ab" "cd"))
      (= (at (vgo '("ab" "cd") "yyp")) '(1 0))
      (= (lns (vgo '("ab" "cd") "yyP")) '("ab" "ab" "cd"))
      (= (at (vgo '("ab" "cd") "yyP")) '(0 0))
      (= (lns (vgo '("ab" "cd") "ddp")) '("cd" "ab"))          ; the line swap idiom
      (= (lns (vgo '("abc") "ylp")) '("aabc"))                 ; charwise p lands past the cursor
      (= (lns (vgo '("foo bar") "ywP")) '("foo foo bar"))
      (= (lns (vgo '("ab" "cd") "2yyjp")) '("ab" "cd" "ab" "cd")))

; --- undo / redo ---
   _ (assert
      (= (lns (vgo '("abc") "xu")) '("abc"))
      (= (lns (vgob '("abc") (L 105 122 27 117))) '("abc"))    ; the whole insert, one undo
      (= (lns (vgob '("abc") (L 120 117 18))) '("bc"))        ; x u ^R
      (= (lns (vgo '("a" "b") "dduu")) '("a" "b"))
      (= (at (vgo '("abc") "lxu")) '(0 1)))

; --- search over re.l: / ? n N, wrap ---
   (skeys s) (cat (bytes "/") (cat (bytes s) (L CR)))
   _ (assert
      (= (at (vgob '("foo" "bar" "foobar") (skeys "bar"))) '(1 0))
      (= (at (vgob '("foo" "bar" "foobar") (cat (skeys "bar") (bytes "n")))) '(2 3))
      (= (at (vgob '("foo" "bar" "foobar") (cat (skeys "bar") (bytes "nn")))) '(1 0))   ; wraps
      (= (at (vgob '("foo" "bar" "foobar") (cat (skeys "bar") (bytes "nN")))) '(1 0))
      (= (at (vgob '("ab" "cd") (cat (bytes "j$?ab") (L CR)))) '(0 0))
      (= (at (vgob '("xax" "b") (skeys "q"))) '(0 0)))         ; a miss stands still

; --- the ex line: :N, :$, :q with dirt, :q!, :w's request ---
   _ (assert
      (= (at (vgob '("a" "b" "c") (cat (bytes ":3") (L CR)))) '(2 0))
      (= (at (vgob '("a" "b" "c") (cat (bytes ":$") (L CR)))) '(2 0))
      (= (st? (vgob '("a") (cat (bytes ":q") (L CR))) 'quit) 1)
      (! (st? (vgob '("a") (cat (bytes "x:q") (L CR))) 'quit)) ; dirty q refuses
      (= (st? (vgob '("a") (cat (bytes "x:q!") (L CR))) 'quit) 1)
      (= (st? (vgob '("a") (cat (bytes ":w") (L CR))) 'dow) '("t"))
      (= (st? (vgob '("a") (cat (bytes ":w other") (L CR))) 'dow) '("other"))
      (: q (vgob '("a") (cat (bytes "x:wq") (L CR)))
         (&& (= (q 'dow) '("t")) (= (q 'quit) 1)))
      (: q (vgob '("a") (bytes "xZZ"))
         (&& (= (q 'dow) '("t")) (= (q 'quit) 1))))

; --- the frame: escapes exact on a tiny screen ---
   (mini ls ks) (: st (vgo ls ks) _ (pin st 'w 8) _ (pin st 'h 4) (vframe st))
   E$ (+ "" 27)
   _ (assert
      (= (mini '("ab") "")
         (+ E$ (+ "[H" (+ "ab" (+ E$ (+ "[K\r\n" (+ "~" (+ E$ (+ "[K\r\n" (+ "~" (+ E$ (+ "[K\r\n"
            (+ "t  1,1" (+ E$ (+ "[K" (+ E$ "[1;1H"))))))))))))))))
      ; a long line clips at w; the cursor never leaves the view
      (= (mini '("abcdefghij") "$")
         (+ E$ (+ "[H" (+ "abcdefgh" (+ E$ (+ "[K\r\n" (+ "~" (+ E$ (+ "[K\r\n" (+ "~" (+ E$ (+ "[K\r\n"
            (+ "t  1,10" (+ E$ (+ "[K" (+ E$ "[1;8H"))))))))))))))))
      ; scrolling: the cursor's row stays inside the 3 text rows
      (: st (vgo '("a" "b" "c" "d" "e") "G") _ (pin st 'w 8) _ (pin st 'h 4)
         f (vframe st)
         (&& (= (st 'top) 2) (two? (L f)))))

   _ (say err "crew/vi/law: motions + words + finds + insert + operators + registers + undo + search + ex + frames ok") _ (put err 10) 0)
