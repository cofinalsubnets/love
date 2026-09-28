; test/law/vi.l -- the editor's laws, held by assertion: every key sequence
; below drives the pure engine (vstep, one byte at a time) and reads the
; tablet back -- no tty, no port, no file. the cat (`make test_vi`):
;
;   cat test/00-init.l apps/kore/text.l apps/kore/core.l apps/kore/re.l apps/kore/sed.l apps/libra/lint.l \
;       apps/vi/config.l apps/vi/hue.l apps/vi/hues.l apps/vi/core.l test/law/vi.l | out/love
;
; (vgo lines keys) births a buffer, feeds the TEXT's bytes (27 spelled \e via
; the 27-element list shape), and answers the state; the helpers read it back.
(borrow 'vi) ; the editor's engine just registered module 'vi in this cat

(: (bytes s) (: n #s (go i acc) (? (i < 0) acc (go (i - 1) (s i . acc))) (go (n - 1) ()))
   (vgo ls ks) (vfeed (vnew ls "t") (bytes ks))
   (vgol ls ks) (vfeed (vnew ls "t.l") (bytes ks))   ; the same, in a .l buffer
   (vgob ls bs) (vfeed (vnew ls "t") bs)
   BS 127 CR 13
   (lns st) (st 'lines) (at st) [(st 'row) (st 'col)]
   (st? st k) (st k)

; --- motion: hjkl, 0 ^ $, counts, the goal column, G/gg ---
   _ (test
      (at (vgo '("abc" "de") "ll") = '(0 2))
      (at (vgo '("abc" "de") "lll") = '(0 2))                ; the col fence
      (at (vgo '("abc" "de") "llh") = '(0 1))
      (at (vgo '("abc" "de") "j") = '(1 0))
      (at (vgo '("abc" "de") "jj") = '(1 0))                 ; the row fence
      (at (vgo '("abc" "de") "jk") = '(0 0))
      (at (vgo '("abc") "$") = '(0 2))
      (at (vgo '("abc") "$0") = '(0 0))
      (at (vgo '("  xy") "^") = '(0 2))
      (at (vgo '("abcdef") "3l") = '(0 3))
      (at (vgo '("abcdef" "ab") "$j") = '(1 1))              ; clamp on the short line ...
      (at (vgo '("abcdef" "ab" "abcdef") "$jj") = '(2 5))    ; ... but the goal survives
      (at (vgo '("a" "b" "c") "G") = '(2 0))
      (at (vgo '("a" "b" "c") "2G") = '(1 0))
      (at (vgo '("a" "b" "c") "Ggg") = '(0 0))
      (at (vgo '("a" "b" "c") "3gg") = '(2 0)))

; --- the diagonals: alt-y u b n arrive as 256 + the letter, a vertical then a
; horizontal, the count on both; fenced like their halves; not a range, so an
; operator is dropped ---
   _ (test
      (at (vgob '("abc" "def" "ghi") (bytes "l" + [354])) = '(1 0))        ; alt-b: down-left
      (at (vgob '("abc" "def" "ghi") [366]) = '(1 1))                      ; alt-n: down-right
      (at (vgob '("abc" "def" "ghi") [366 366]) = '(2 2))
      (at (vgob '("abc" "def" "ghi") [366 366 377]) = '(1 1))              ; alt-y: up-left
      (at (vgob '("abc" "def" "ghi") [366 373]) = '(0 2))                  ; alt-u: up-right
      (at (vgob '("abc" "def" "ghi") (bytes "2" + [366])) = '(2 2))        ; the count rides both halves
      (at (vgob '("abc" "def" "ghi") [377]) = '(0 0))                      ; the fences hold
      (at (vgob '("abcdef" "ab") [366]) = '(1 1))                          ; the short line clamps
      (((vgob '("abc" "def") (bytes "d" + [366])) 'lines) = '("abc" "def"))  ; d then a diagonal: nothing cut
      (at (vgob '("abc" "def") (bytes "d" + [366])) = '(0 0)))             ; ..and nothing moves either

; --- words: w e b across lines ---
   _ (test
      (at (vgo '("foo bar baz") "w") = '(0 4))
      (at (vgo '("foo bar baz") "2w") = '(0 8))
      (at (vgo '("foo.bar") "w") = '(0 3))                   ; punct is its own word
      (at (vgo '("foo" "bar") "w") = '(1 0))                 ; w crosses the line
      (at (vgo '("foo bar") "e") = '(0 2))
      (at (vgo '("foo bar") "ee") = '(0 6))
      (at (vgo '("foo bar") "$b") = '(0 4))
      (at (vgo '("foo bar") "$bb") = '(0 0))
      (at (vgo '("foo" "bar") "jb") = '(0 0)))               ; b crosses back

; --- f F t T ---
   _ (test
      (at (vgo '("abcabc") "fc") = '(0 2))
      (at (vgo '("abcabc") "2fc") = '(0 5))
      (at (vgo '("abcabc") "tc") = '(0 1))
      (at (vgo '("abcabc") "$Fa") = '(0 3))
      (at (vgo '("abcabc") "$Ta") = '(0 4))
      (at (vgo '("abc") "fz") = '(0 0)))                     ; a miss stands still

; --- insert: i a I a o O, enter, backspace, escape ---
   _ (test
      (lns (vgo '("bc") "iaX") = '("aXbc"))                  ; i, then a and X insert
      (lns (vgob '("ac") [105 98 27 88]) = '("bac"))         ; i b ESC, then X at col 0 bites nothing
      (lns (vgo '("") "ihello") = '("hello"))
      (lns (vgo '("xy") "aZ") = '("xZy"))
      (lns (vgo '("xy") "AZ") = '("xyZ"))
      (lns (vgo '("  xy") "IZ") = '("  Zxy"))
      (lns (vgo '("ab") "ocd") = '("ab" "cd"))
      (at (vgo '("ab") "ocd") = '(1 2))
      (lns (vgo '("ab") "Ocd") = '("cd" "ab"))
      (lns (vgo '("ab" "cd") "jOx") = '("ab" "x" "cd")))
   _ (test
      (lns (vgob '("abcd") [108 108 105 13]) = '("ab" "cd"))            ; ll i cr splits
      (at (vgob '("abcd") [108 108 105 13]) = '(1 0))
      (lns (vgob '("abcd") [65 120 BS BS 121]) = '("abcy"))             ; a x bsp bsp y
      (lns (vgob '("ab" "cd") [106 105 BS]) = '("abcd"))                ; bsp at col 0 joins up
      (at (vgob '("ab" "cd") [106 105 BS]) = '(0 2))
      (at (vgob '("abc") [65 27]) = '(0 2))                             ; esc steps left, fenced
      (st? (vgob '("a") [105 120 27]) 'mode = 'n))
   ; the arrows in insert (edkey's -1 -2 -8 -9): the cursor may sit past the last
   ; char, the fences are the line's ends, and up and down keep the goal column
   _ (test
      (lns (vgob '("abc") [65 -1 120]) = '("abxc"))                     ; A, left, x
      (lns (vgob '("abc") [105 -2 -2 -2 -2 120]) = '("abcx"))          ; i, right past the end
      (at (vgob '("abc") [105 -2 -2 -2 -2]) = '(0 3))
      (at (vgob '("abc") [65 -1 -1 -1 -1]) = '(0 0))                    ; left stops at 0
      (lns (vgob '("abcdef" "de") [65 -9 120]) = '("abcdef" "dex"))    ; down: col clamped to 2
      (at (vgob '("abcdef" "de") [65 -9]) = '(1 2))
      (lns (vgob '("abcdef" "de") [65 -9 -8 120]) = '("abcdefx" "de")) ; up again: the goal 6 returns
      (at (vgob '("abcdef" "de") [65 -8]) = '(0 6))                     ; up at the top: nothing
      (at (vgob '("ab" "cd") [106 65 -9]) = '(1 2))                     ; down at the foot: nothing
      (st? (vgob '("abc") [65 -1 -9 -8]) 'mode = 'i))                  ; still inserting

; --- operators: x X D C s r J, dd yy cc, d+motion, spans ---
   _ (test
      (lns (vgo '("abc") "x") = '("bc"))
      (lns (vgo '("abc") "2x") = '("c"))
      (lns (vgo '("abc") "lx") = '("ac"))
      (lns (vgo '("abc") "$X") = '("ac"))
      (lns (vgo '("abcdef") "llD") = '("ab"))
      (at (vgo '("abcdef") "llD") = '(0 1))
      (lns (vgo '("abc" "def") "dd") = '("def"))
      (lns (vgo '("abc" "def") "jdd") = '("abc"))
      (lns (vgo '("a" "b" "c") "2dd") = '("c"))
      (lns (vgo '("only") "dd") = '(""))                     ; the vi invariant: one line stays
      (lns (vgo '("foo bar") "dw") = '("bar"))
      (lns (vgo '("foo bar") "d$") = '(""))
      (lns (vgo '("foo bar") "wdb") = '("bar"))
      (lns (vgo '("abcabc") "dfb") = '("cabc"))
      (lns (vgo '("abcabc") "dtb") = '("bcabc"))
      (lns (vgo '("a" "b" "c") "dj") = '("c"))               ; d+linewise takes both rows
      (lns (vgo '("a" "b" "c") "jdk") = '("c"))
      (lns (vgo '("a" "b" "c") "dG") = '(""))
      (lns (vgo '("abc") "rz") = '("zbc"))
      (lns (vgo '("abcd") "2rz") = '("zzcd"))
      (at (vgo '("abcd") "2rz") = '(0 1))
      (lns (vgo '("ab" "  cd") "J") = '("ab cd"))
      (at (vgo '("ab" "  cd") "J") = '(0 2))
      (lns (vgo '("a" "b" "c") "3J") = '("a b c")))
   _ (test
      (lns (vgo '("foo bar") "cwxy") = '("xy bar"))          ; c enters insert
      (st? (vgo '("foo bar") "cw") 'mode = 'i)
      (lns (vgo '("abc") "sZ") = '("Zbc"))
      (lns (vgo '("abcdef") "llCxy") = '("abxy"))
      (lns (vgo '("aa" "bb") "ccX") = '("X" "bb")))          ; cc keeps a fresh line

; --- the WORD family, the paragraph motions, and the column motions -----------
   _ (test
      (at (vgo '("a.b c.d") "W") = '(0 4))
      (at (vgo '("a.b c.d") "E") = '(0 2))
      (at (vgo '("a.b c.d") "$B") = '(0 4))
      (at (vgo '("a.b") "w") = '(0 1))                       ; w still splits on punct
      (at (vgo '("abcdef") "4|") = '(0 3))
      (at (vgo '("ab") "9|") = '(0 1))                       ; | fences at the line
      (at (vgo '("a" "b" "" "c") "}") = '(2 0))
      (at (vgo '("a" "" "b" "c") "G{") = '(1 0))
      (at (vgo '("a" "b" "c") "}") = '(2 0))                 ; no blank line: the end
      (at (vgo '("  ab" "  cd") "+") = '(1 2))               ; + lands on the first ink
      (at (vgo '("  ab" "  cd") "j-") = '(0 2))
      (at (vgo '("ab   ") "g_") = '(0 1))                    ; g_: the last ink
      ; space and backspace are l and h
      (at (vgo '("abc") " ") = '(0 1))
      (at (vgob '("abc") [108 108 8]) = '(0 1)))

; --- % over the delimiters. in a .l buffer the paint's lexer says which ( is
;     code, so a ) inside a literal is not a mate; in any other file every one
;     counts, which is the classic vi rule and the fallback ------------------
   _ (test
      (at (vgo '("(a (b) c)") "%") = '(0 8))
      (at (vgo '("(a (b) c)") "$%") = '(0 0))
      (at (vgo '("(a (b) c)") "3l%") = '(0 5))               ; the inner pair
      (at (vgo '("(a" "b)") "%") = '(1 1))                   ; rows are crossed
      (at (vgo '("[1 2]") "%") = '(0 4))
      (at (vgo '("a(b") "%") = '(0 0))                       ; no mate: nothing moves
      (lns (vgo '("x(ab)y") "ld%") = '("xy"))                ; d% is inclusive both ends
      (lns (vgo '("(a" "b)c") "d%") = '("c"))
      (at (vgol '("(a \")\" b)") "%") = '(0 8))              ; the quoted ) is not a mate
      (at (vgo '("(a \")\" b)") "%") = '(0 4)))              ; ..and in a plain file it is

; --- ; and , -- the last f F t T over again, forward and back ----------------
   _ (test
      (at (vgo '("abcabcabc") "fa;") = '(0 6))
      (at (vgo '("abcabcabc") "fa;,") = '(0 3))
      (at (vgo '("abcabcabc") "$Fa;") = '(0 3))
      (at (vgo '("abc") ";") = '(0 0)))                      ; with none remembered

; --- the text objects: i and a after an operator. every one answers a range in
;     vapply's vocabulary, so ci( di( yi( are one object under three operators --
   _ (test
      (lns (vgo '("f(ab)g") "lllci(X") = '("f(X)g"))
      (lns (vgo '("f(ab)g") "lci(X") = '("f(X)g"))            ; on the delimiter itself
      (lns (vgo '("f(ab)g") "4lci(X") = '("f(X)g"))           ; and on the closer
      (lns (vgo '("f(ab)g") "lllca)X") = '("fXg"))
      (lns (vgo '("x[1 2]y") "lda[") = '("xy"))
      (lns (vgo '("x[1 2]y") "3ldi[") = '("x[]y"))
      (lns (vgo '("x{1 2}y") "lda{") = '("xy"))
      (lns (vgo '("a<bc>d") "lldi<") = '("a<>d"))
      (lns (vgo '("(a (b) c)") "5ldab") = '("(a  c)"))        ; b is (, and the inner wins
      (st? (vgo '("f(ab)g") "lllci(") 'mode = 'i)
      (lns (vgo '("f()g") "lldi(") = '("f()g")))              ; an empty pair cuts nothing
   _ (test
      ; the bracket objects cross rows, which is the whole point in a .l file
      (lns (vgo '("(a" " b" " c)") "di(") = '("()"))
      (lns (vgo '("x(a" " b" " c)y") "lda(") = '("xy"))
      (((vgo '("(a" " b)" "z") "yi(") 'reg) = '(chr "a\n b"))
      ; ..and the register they fill is one p away from being lines again
      (lns (vgo '("(a" " b)" "z") "yi(jjp") = '("(a" " b)" "za" " b")))
   _ (test
      (lns (vgo '("foo bar baz") "wdiw") = '("foo  baz"))
      (lns (vgo '("foo bar baz") "wdaw") = '("foo baz"))
      (lns (vgo '("foo bar baz qux") "d2aw") = '("baz qux"))
      (lns (vgo '("foo bar") "wciwZZZ") = '("foo ZZZ"))
      (lns (vgo '("a.b c") "daW") = '("c"))                   ; aW takes the punct too
      (lns (vgo '("x  y") "ldaw") = '("x"))                   ; on blanks: them and the word
      (lns (vgo '("a \"bc\" d") "di\"") = '("a \"\" d"))
      (lns (vgo '("a \"bc\" d") "da\"") = '("a d"))           ; around eats the trailing blank
      (lns (vgo '("a 'bc' d") "di'") = '("a '' d"))
      (lns (vgo '("\"ab\" \"cd\"") "$di\"") = '("\"ab\" \"\""))
      (lns (vgo '("a" "b" "" "c") "dip") = '("" "c"))
      (lns (vgo '("a" "b" "" "c") "dap") = '("c"))
      (lns (vgo '("a" "" "" "b") "jdip") = '("a" "b")))       ; a blank run is a paragraph too

; --- `.` -- the last CHANGE again, and a count on it replaces the count it
;     carried. a motion, an undo and a yank are not changes and do not arm it --
   _ (test
      (lns (vgo '("abcdef") "x..") = '("def"))
      (lns (vgo '("abcdefgh") "x3.") = '("efgh"))             ; the count is replaced
      (lns (vgo '("abcdefgh") "3x.") = '("gh"))               ; ..and carried when none is given
      (lns (vgo '("a" "b" "c" "d") "dd.") = '("c" "d"))
      (lns (vgo '("a" "b" "c" "d" "e") "dd2.") = '("d" "e"))
      (lns (vgo '("foo bar") "ciwZZ\eww.") = '("ZZ ZZ"))      ; a whole insert, one entry
      (lns (vgo '("ab" "cd") "A!\ej.") = '("ab!" "cd!"))
      (lns (vgo '("abcd") "~.") = '("ABcd"))
      (lns (vgo '("ab" "cd") ">>j.") = '("  ab" "  cd"))
      (lns (vgo '("ab" "cd") "yyp.") = '("ab" "ab" "ab" "cd"))
      (st? (vgo '("ab") ".") 'msg = "nothing to repeat")
      (lns (vgo '("ab" "cd") "yy.") = '("ab" "cd")))          ; a yank arms nothing

; --- ~ Y S gJ, and the shifts -----------------------------------------------
   _ (test
      (lns (vgo '("aBc") "3~") = '("AbC"))
      (at (vgo '("aBc") "3~") = '(0 2))                       ; ~ fences at the line's end
      (lns (vgo '("ab" "cd") "Yp") = '("ab" "ab" "cd"))
      (lns (vgo '("ab" "cd") "SX\e") = '("X" "cd"))
      (lns (vgo '("ab" "  cd") "gJ") = '("ab  cd"))           ; gJ keeps the indent, adds nothing
      (lns (vgo '("ab" "cd") ">>") = '("  ab" "cd"))
      (lns (vgo '("ab" "cd") "2>>") = '("  ab" "  cd"))
      (lns (vgo '("    ab") "<<") = '("  ab"))
      (lns (vgo '("ab") "<<") = '("ab"))                      ; already home
      (lns (vgo '("ab" "cd" "ef") ">j") = '("  ab" "  cd" "ef"))
      (lns (vgo '("" "ab") ">j") = '("" "  ab"))              ; an empty line stays empty
      (lns (vgo '("ab" "cd") ">>u") = '("ab" "cd"))
      ; a shift is not a cut: it leaves the register alone
      (((vgo '("ab" "cd") "yy>>") 'reg) = '(lin ("ab")))
      (lns (vgob '("ab") ((bytes ":set sw=4") + [CR] + (bytes ">>"))) = '("    ab"))
      (st? (vgob '("ab") ((bytes ":set sw") + [CR])) 'msg = "shiftwidth=2")
      (st? (vgob '("ab") ((bytes ":set nu") + [CR])) 'msg = "not an option: nu"))

; --- ^A and ^X, * and #, H M L, zt zz zb, and insert's ^W and ^U -------------
   _ (test
      (lns (vgob '("x 41 y") [1]) = '("x 42 y"))
      (lns (vgob '("x 41 y") ((bytes "3") + [1])) = '("x 44 y"))
      (lns (vgob '("x 41 y") ((bytes "lll") + [1])) = '("x 42 y"))   ; standing on it
      (lns (vgob '("x -3 y") [24]) = '("x -4 y"))                    ; the sign rides along
      (st? (vgob '("abc") [1]) 'msg = "no number here"))
   _ (test
      ; * is word-bounded, which re.l has no node for -- the hunt checks the span
      (at (vgo '("foo bar" "xfoo" "foo") "*") = '(2 0))
      (at (vgo '("foo" "bar" "foo z") "G#") = '(0 0))
      (st? (vgo '("   ") "*") 'msg = "no word under the cursor")
      ; a name full of BRE metacharacters is spelled out, not read as a pattern
      (at (vgo '("a.c" "abc" "a.c") "*") = '(2 0)))
   (view ls ks h) (: st (vgo ls ks) _ (pin st 'h h) _ (vframe st) st)
   _ (test
      (at (vfeed (view '("a" "b" "c" "d") "G" 4) (bytes "H")) = '(1 0))
      (at (vfeed (view '("a" "b" "c" "d") "gg" 4) (bytes "L")) = '(2 0))
      (at (vfeed (view '("a" "b" "c" "d") "gg" 4) (bytes "M")) = '(1 0))
      (((vfeed (view '("a" "b" "c" "d" "e") "3G" 4) (bytes "zt")) 'top) = 2)
      (((vfeed (view '("a" "b" "c" "d" "e") "3G" 4) (bytes "zb")) 'top) = 0)
      ; the view slides, the cursor does not
      (at (vfeed (view '("a" "b" "c" "d" "e") "3G" 4) (bytes "zt")) = '(2 0)))
   _ (test
      (lns (vgob '("foo bar") ((bytes "A") + [23])) = '("foo "))
      (lns (vgob '("foo bar") ((bytes "A") + [23 23])) = '(""))
      (lns (vgob '("  foo bar") ((bytes "A") + [21])) = '("  "))
      (lns (vgob '("ab") ((bytes "I") + [21])) = '("ab")))            ; nothing before it

; --- an operator that crosses rows is charwise, the way vim's is. the linewise
;     motions (j k G gg) stay linewise, and dw stops at the line it ends -----
   _ (test
      (lns (vgo '("ab" "cd ef") "ldw") = '("a" "cd ef"))
      (lns (vgo '("a" "b" "c") "d2w") = '("" "c"))
      (lns (vgo '("ab" "cd") "jdb") = '("cd"))
      (lns (vgo '("abc" "def") "lld\e") = '("abc" "def"))            ; escape drops the operator
      (lns (vgo '("a" "b" "c") "dj") = '("c")))                      ; j is still linewise

; --- yank + paste, both kinds ---
   _ (test
      (lns (vgo '("ab" "cd") "yyp") = '("ab" "ab" "cd"))
      (at (vgo '("ab" "cd") "yyp") = '(1 0))
      (lns (vgo '("ab" "cd") "yyP") = '("ab" "ab" "cd"))
      (at (vgo '("ab" "cd") "yyP") = '(0 0))
      (lns (vgo '("ab" "cd") "ddp") = '("cd" "ab"))          ; the line swap idiom
      (lns (vgo '("abc") "ylp") = '("aabc"))                 ; charwise p lands past the cursor
      (lns (vgo '("foo bar") "ywP") = '("foo foo bar"))
      (lns (vgo '("ab" "cd") "2yyjp") = '("ab" "cd" "ab" "cd")))

; --- undo / redo ---
   _ (test
      (lns (vgo '("abc") "xu") = '("abc"))
      (lns (vgob '("abc") [105 122 27 117]) = '("abc"))      ; the whole insert, one undo
      (lns (vgob '("abc") [120 117 18]) = '("bc"))          ; x u ^R
      (lns (vgo '("a" "b") "dduu") = '("a" "b"))
      (at (vgo '("abc") "lxu") = '(0 1)))

; --- search over re.l: / ? n N, wrap ---
   (skeys s) ((bytes "/") + (bytes s) + [CR])
   _ (test
      (at (vgob '("foo" "bar" "foobar") (skeys "bar")) = '(1 0))
      (at (vgob '("foo" "bar" "foobar") ((skeys "bar") + (bytes "n"))) = '(2 3))
      (at (vgob '("foo" "bar" "foobar") ((skeys "bar") + (bytes "nn"))) = '(1 0))     ; wraps
      (at (vgob '("foo" "bar" "foobar") ((skeys "bar") + (bytes "nN"))) = '(1 0))
      (at (vgob '("ab" "cd") ((bytes "j$?ab") + [CR])) = '(0 0))
      (at (vgob '("xax" "b") (skeys "q")) = '(0 0)))         ; a miss stands still

; --- the ex line: :N, :$, :q with dirt, :q!, :w's request ---
   _ (test
      (at (vgob '("a" "b" "c") ((bytes ":3") + [CR])) = '(2 0))
      (at (vgob '("a" "b" "c") ((bytes ":$") + [CR])) = '(2 0))
      (st? (vgob '("a") ((bytes ":q") + [CR])) 'quit = 1)
      !(st? (vgob '("a") ((bytes "x:q") + [CR])) 'quit)        ; dirty q refuses
      (st? (vgob '("a") ((bytes "x:q!") + [CR])) 'quit = 1)
      (st? (vgob '("a") ((bytes ":w") + [CR])) 'dow = '("t"))
      (st? (vgob '("a") ((bytes ":w other") + [CR])) 'dow = '("other"))
      (: q (vgob '("a") ((bytes "x:wq") + [CR]))
         ((q 'dow = '("t")) && (q 'quit = 1)))
      (: q (vgob '("a") (bytes "xZZ"))
         ((q 'dow = '("t")) && (q 'quit = 1)))
      ; the split requests: a fresh buffer, or a file, beside or under
      (st? (vgob '("a") ((bytes ":vs") + [CR])) 'dos = '(beside ""))
      (st? (vgob '("a") ((bytes ":sp other") + [CR])) 'dos = '(stack "other"))
      (st? (vgob '("a") ((bytes ":vsplit x") + [CR])) 'dos = '(beside "x"))
      !(st? (vgob '("a") ((bytes ":w") + [CR])) 'dos))

; --- visual mode: v and V select from the cursor, the motions stretch it, o swaps
; --- the ends, an operator takes it charwise with both ends in or by lines, and
; --- escape or the same key again leaves; the frame reverses the selection ---
   (has? h n) (:- (go 0) (go i) (? (#h < i + #n) 0 (n = snip h i (i + #n)) 1 (go (i + 1))))
   (vmini ls ks) (: st (vgo ls ks) _ (pin st 'w 8) _ (pin st 'h 4) (vframe st))
   _ (test
      (st? (vgo '("abc") "v") 'mode = 'v)
      (st? (vgo '("abc") "v") 'va = '(0 0))
      (st? (vgo '("abc") "vv") 'mode = 'n)
      (st? (vgo '("abc") "vV") 'mode = 'V)
      (st? (vgo '("abc") "v\e") 'mode = 'n)
      !(st? (vgo '("abc") "v\e") 'va)
      (st? (vgo '("abcdef") "vlly") 'reg = '(chr "abc"))
      (at (vgo '("abcdef") "llvhhy") = '(0 0))                  ; backwards: the same three
      (st? (vgo '("abcdef") "llvhhy") 'reg = '(chr "abc"))
      (st? (vgo '("abcdef") "lv$y") 'reg = '(chr "bcdef"))
      (lns (vgo '("abcdef") "lvlld") = '("aef"))
      (lns (vgo '("abcdef") "lvllx") = '("aef"))
      (lns (vgo '("abc" "def") "lvjd") = '("af"))              ; across rows, both ends in
      (st? (vgo '("abc" "def") "lvjy") 'reg = '(chr "bc\nde"))
      (at (vgo '("abc" "def") "lvjy") = '(0 1))                 ; y lands on the start
      (lns (vgo '("a" "b" "c") "Vjd") = '("c"))
      (st? (vgo '("a" "b" "c") "jVky") 'reg = '(lin ("a" "b")))
      (lns (vgo '("abc") "vlc") = '("c"))                        ; c: gone, and inserting
      (st? (vgo '("abc") "vlc") 'mode = 'i)
      (lns (vgo '("a" "b") "Vj>") = '("  a" "  b"))
      (at (vgo '("abc" "def") "lvjo") = '(0 1))                  ; o: to the other end
      (st? (vgo '("abc" "def") "lvjo") 'va = '(1 1))
      (lns (vgo '("abc" "def") "lvjoy") = '("abc" "def"))
      (st? (vgo '("abc" "def") "vjkd") 'mode = 'n)               ; i in visual is nothing
      (lns (vgo '("abc") "vix") = '("bc"))
      (st? (vgo '("abc" "abc") "v/b\r") 'mode = 'v)               ; a search comes back to it
      (st? (vgo '("abc" "abc") "v/b\ry") 'reg = '(chr "ab"))
      (: f (vmini '("abc") "vl") (has? f "\e[7mab\e[0m"))
      (: q (vgo '("abc") "vl") _ (pins q 'w 40 'h 4) (has? ((vlay q) 1) "-- VISUAL --"))
      (: q (vgo '("abc") "Vl") _ (pins q 'w 40 'h 4) (has? ((vlay q) 1) "-- VISUAL LINE --"))
      (: f (vmini '("abc" "") "Vj") (has? f "\e[7m \e[0m"))     ; an empty line still shows
      (: f (vmini '("abc") "vl\e") (!(has? f "\e[7m"))))

; --- the frame: escapes exact on a tiny screen ---
   (mini ls ks) (: st (vgo ls ks) _ (pin st 'w 8) _ (pin st 'h 4) (vframe st))
   E$ (string 27)
   _ (test
      (mini '("ab") "" = (E$ + ("[H" + ("ab" + (E$ + ("[K\r\n" + ("~" + (E$ + ("[K\r\n" + ("~" + (E$ + ("[K\r\n" + ("t  1,1" + (E$ + ("[K" + (E$ + "[1;1H"))))))))))))))))
      ; a long line slides the view sideways; the cursor never leaves it
      (mini '("abcdefghij") "$" = (E$ + ("[H" + ("cdefghij" + (E$ + ("[K\r\n" + ("~" + (E$ + ("[K\r\n" + ("~" + (E$ + ("[K\r\n" + ("t  1,10" + (E$ + ("[K" + (E$ + "[1;8H"))))))))))))))))
      ; scrolling: the cursor's row stays inside the 3 text rows
      (: st (vgo '("a" "b" "c" "d" "e") "G") _ (pin st 'w 8) _ (pin st 'h 4)
         f (vframe st)
         ((st 'top = 2) && two? [f])))

; --- vfresh: the frame as a refresh. the first one is everything, and after that
;     only the rows that differ from the ones the last frame put there, each
;     placed absolutely. the whole thing rides the terminal's synchronised-output
;     bracket, so a scroll lands in one piece rather than line by line ---------
   (small ls ks) (: st (vgo ls ks) _ (pin st 'w 16) _ (pin st 'h 4) st)
   (hlon st) (pin st 'pens (hues-pens hue-theme ()), pin st 'hl 1, st)
   SY (E$ + "[?2026h") YS (E$ + "[?2026l")
   (place r s) (E$ + "[" + show r + ";1H" + s + E$ + "[K")
   _ (test
      ; the first refresh lays the whole screen, the way vframe does
      (: st (small '("ab") "")
         (vfresh st = (SY + E$ + "[H" + "ab" + E$ + "[K\r\n" + "~" + E$ + "[K\r\n" + "~" + E$ + "[K\r\n"
                + place 4 "t  1,1" + E$ + "[1;1H" + YS)))
      ; the same state again is the cursor and nothing else at all
      (: st (small '("ab") "") _ (vfresh st)
         (vfresh st = (SY + E$ + "[1;1H" + YS)))
      ; a motion inside the screen moves the cursor and the row,col it reports
      (: st (small '("ab") "") _ (vfresh st) _ (vstep st 108)
         (vfresh st = (SY + place 4 "t  1,2" + E$ + "[1;2H" + YS)))
      ; an edit places the one row it changed, and the status that noticed
      (: st (small '("ab" "cd") "") _ (vfresh st) _ (vfeed st (bytes "jx"))
         (vfresh st = (SY + place 2 "d" + place 4 "t [+]  2,1" + E$ + "[2;1H" + YS)))
      ; a scroll is a new set of rows, so it is a whole screen again
      (: st (small '("a" "b" "c" "d" "e") "") _ (vfresh st) _ (vfeed st (bytes "G"))
         f (vfresh st)
         (f = (SY + E$ + "[H" + "c" + E$ + "[K\r\n" + "d" + E$ + "[K\r\n" + "e" + E$ + "[K\r\n"
                 + place 4 "t  5,1" + E$ + "[3;1H" + YS))))
   ; and the law that keeps the two honest: what a fresh refresh lays is what
   ; vframe lays, rows for rows and status for status
   _ (test
      (: a (small '("ab" "cd") "j") b (small '("ab" "cd") "j")
         (vlay a = (vlay b)))
      (: st (small '("hello" "there") "jl")
         L (vlay st)
         (vframe st = (E$ + "[H" + <L 0 + E$ + "[K\r\n" + <L 1 + E$ + "[K\r\n" + <L 2 + E$ + "[K\r\n"
                + <>L + E$ + "[K" + E$ + "[" + show <>>L + ";" + show <>>>L + "H"))))

; --- the painted row is cached against the text that made it, so a keystroke
;     that only moves the cursor re-lexes nothing -----------------------------
   _ (test
      (: st (hlon (small '("(map f)" "(g 1)") "")) _ (vfresh st)
         r0 ((st 'hlrow) 0)
         ; [[text carry from to] painted]: the key is what it was painted from
         ((<r0 = ["(map f)" 0 0 7 'l]) && (0 < #<>r0)))
      ; the cache is keyed by SCREEN row, so it is the height of the view and
      ; never the height of the file
      (: st (hlon (small '("a" "b" "c" "d" "e" "f") "")) _ (vfresh st) _ (vfeed st (bytes "G"))
         _ (vfresh st)
         (3 = #(keys (st 'hlrow)))))

; --- long lines: the view slides sideways, and :set wrap folds them instead ---
   (box ls w h) (: st (vnew ls "t") _ (pins st 'w w 'h h) _ (vframe st) st)
   (see st ks) (vfeed st (? (string? ks) (bytes ks) ks), vframe st, st)
   (body st) <(vlay st)
   _ (test
      ; nowrap is the default: 'left slides so the cursor shows, and stops at
      ; the line's end rather than running off into blank columns
      (: st (see (box '("abcdefghij") 8 4) "$")
         ((st 'left = 2) && (body st = '("cdefghij" "~" "~"))))
      (: st (see (see (box '("abcdefghij") 8 4) "$") "0")
         ((st 'left = 0) && (body st = '("abcdefgh" "~" "~"))))
      ; and comes home when the cursor lands on a short line
      (: st (see (see (box '("abcdefghij" "x") 8 4) "$") "j")
         ((st 'left = 0) && (body st = '("abcdefgh" "x" "~"))))
      ; :set wrap folds the line onto as many screen rows as it needs
      (: st (see (box '("abcdefghij") 8 4) ":set wrap\r")
         ((st 'msg = "wrap") && (body st = '("abcdefgh" "ij" "~"))))
      ; the cursor follows it onto the second row
      (: st (see (see (box '("abcdefghij") 8 4) ":set wrap\r") "$")
         L (vlay st)
         ((<>>L = 2) && (<>>>L = 2)))
      ; a line taller than the whole view: the corner carries a segment offset
      (: st (see (see (box '("abcdefghijklmnopqrst") 4 4) ":set wrap\r") "$")
         L (vlay st)
         (((st 'top = 0) && (st 'tops = 2)) &&
          ((body st = '("ijkl" "mnop" "qrst")) && ((<>>L = 3) && (<>>>L = 4)))))
      ; :set nowrap puts it back, and no other word is an option
      (: st (see (see (box '("abcdefghij") 8 4) ":set wrap\r") ":set nowrap\r")
         ((st 'msg = "nowrap") && (body st = '("abcdefgh" "~" "~"))))
      (st? (vgob '("a") ((bytes ":set frobs") + [CR])) 'msg = "not an option: frobs"))
   ; H M L and the pages count SCREEN rows, so a folded line shortens their reach
   _ (test
      (at (see (box '("abcdefgh" "b" "c" "d") 4 5) "L") = '(3 0))
      (at (see (box '("abcdefgh" "b" "c" "d") 4 5) ":set wrap\rL") = '(2 0))
      (at (see (box '("abcdefgh" "b" "c" "d") 4 5) [6]) = '(3 0))
      (at (see (box '("abcdefgh" "b" "c" "d") 4 5) ((bytes ":set wrap\r") + [6])) = '(2 0))
      ; and zb cannot walk the view off the top of the file
      (((see (box '("a" "b" "c") 4 5) "2Gzb") 'top) = 0))

; --- :e and :o -- the request the face performs, and the buffer swap it calls -
   _ (test
      (st? (vgob '("a") ((bytes ":e other") + [CR])) 'doe = '("other"))
      (st? (vgob '("a") ((bytes ":o other") + [CR])) 'doe = '("other"))       ; the same door
      (st? (vgob '("a") ((bytes ":e") + [CR])) 'doe = '("t"))                 ; bare :e reloads
      !(st? (vgob '("a") ((bytes "x:e other") + [CR])) 'doe)                    ; dirty refuses ...
      (st? (vgob '("a") ((bytes "x:e! other") + [CR])) 'doe = '("other"))     ; ... and ! overrides
      (st? (vgob '("a") ((bytes "x:e!") + [CR])) 'doe = '("t"))
      ; a trailing blank is just blank: `:e ` reloads the way a bare `:e` does
      (st? (vgob '("a") ((bytes ":e ") + [CR])) 'doe = '("t")))
   _ (test
      ; the swap starts the file over -- and re-decides the paint from the new name
      (: q (vgo '("a" "b") "jx") _ (vload q '("x" "y" "z") "n.l")
         ((lns q = '("x" "y" "z")) &&
          (at q = '(0 0)) &&
          !(q 'dirty) && !(q 'undo) && q 'hl))
      (: q (vgo '("a") "") _ (pin q 'hl 1) _ (vload q '("z") "n.txt") !(q 'hl))
      (: q (vgo '("a") "") _ (vload q () "e.l") (lns q = '(""))))             ; an empty read is one empty line

; --- libra ⚖ on the buffer: :lint weighs what you are looking at. one scanner
;     (apps/libra/lint.l) under libra's faces and this one ---------------------------
   (ex ls s) (vgob ls ((bytes (":" + s)) + [CR]))
   _ (test
      (st? (ex '("(: a 1)") "lint") 'msg = "balance clean")
      (st? (ex '("(: a 1") "lint") 'msg = "1 warning: 1,1 unclosed (")
      (at (ex '("(: a 1") "lint") = '(0 0))                  ; and it goes there
      ; an unclosed opener reports where it opened, so the jump lands on the cause
      (: q (ex '("(f x)" "(: a 1" "(g y)") "lint")
         ((at q = '(1 0)) && (q 'msg = "1 warning: 2,1 unclosed ("))))

; --- the ex language: addresses, then the commands that read a range ---
; every line below goes in through the same `:` the hand does, so what is lawed
; is the parse as well as the edit.
   ab5 '("aa" "bb" "cc" "dd" "ee")
   _ (test
      ; addresses: N . $ , ; % and the +N / -N offsets
      (at (ex ab5 "3") = '(2 0))
      (at (ex ab5 "$") = '(4 0))
      (at (ex ab5 "+2") = '(2 0))
      (at (ex ab5 "$-1") = '(3 0))
      (at (ex ab5 ".+1") = '(1 0))
      (at (ex ab5 "2+") = '(2 0))                          ; a bare + steps one
      (at (ex ab5 "/cc/") = '(2 0))
      (at (ex ab5 "?bb?") = '(1 0))                        ; ? hunts backward, wrapping
      (at (ex ab5 "/aa/") = '(0 0))                        ; and the hunt wraps
      (st? (ex ab5 "/zz/") 'msg = "no match")              ; a failed address is an error ...
      (lns (ex ab5 "/zz/d") = ab5)                         ; ... and never a silent :d
      (at (ex ab5 "0") = '(0 0))                           ; a goto fences, it does not fail
      (at (ex ab5 "99") = '(4 0)))

   _ (test
      ; d y m t j -- the range commands
      (lns (ex ab5 "2d") = '("aa" "cc" "dd" "ee"))
      (lns (ex ab5 "2,3d") = '("aa" "dd" "ee"))
      (lns (ex ab5 "%d") = '(""))                          ; the buffer is never empty
      (lns (ex ab5 ",d") = '(""))                          ; a bare , is 1,$ too
      (lns (ex ab5 "d") = '("bb" "cc" "dd" "ee"))          ; no range is dot
      (lns (ex ab5 "/cc/d") = '("aa" "bb" "dd" "ee"))
      (lns (ex ab5 "1,2m4") = '("cc" "dd" "aa" "bb" "ee"))
      (lns (ex ab5 "4,5m0") = '("dd" "ee" "aa" "bb" "cc")) ; 0 is before the first line
      (lns (ex ab5 "1t2") = '("aa" "bb" "aa" "cc" "dd" "ee"))
      (lns (ex ab5 "1,2j") = '("aa bb" "cc" "dd" "ee"))
      (lns (ex ab5 "1,3j") = '("aa bb cc" "dd" "ee"))
      (st? (ex ab5 "2,1d") 'msg = "out of range")          ; a backward range refuses
      (st? (ex ab5 "2m2") 'msg = "destination inside the range")
      (lns (ex ab5 "2y") = ab5)                            ; y leaves the text alone ...
      (st? (ex ab5 "2y") 'reg = '(lin ("bb"))))            ; ... and fills the register

   _ (test
      ; :s -- over sed's own usub, so & and \1 read the same in both
      (lns (ex '("a b a") "s/a/X/") = '("X b a"))
      (lns (ex '("a b a") "s/a/X/g") = '("X b X"))
      (lns (ex '("ab" "ab") "%s/b/Y/") = '("aY" "aY"))
      (lns (ex '("ab" "cd") "s/./X/") = '("Xb" "cd"))      ; no range is dot only
      (lns (ex '("xy") "s/x/[&]/") = '("[x]y"))            ; & is the whole match
      (lns (ex '("ab") "s/\\(a\\)\\(b\\)/\\2\\1/") = '("ba"))
      (lns (ex '("a,b") "s,\\,,-,") = '("a-b"))            ; any delimiter, escaped in
      (lns (ex '("xbz") "s/x*/-/g") = '("-b-z-"))          ; the POSIX empty-match rule
      (lns (ex '("ab") "s/q/X/") = '("ab"))
      (st? (ex '("ab") "s/q/X/") 'msg = "not found: q")
      (st? (ex '("ab") "s/a/X/") 'msg = "1 line changed")
      ; a fresh :s pattern is the last search, which is where n picks it up
      (: q (ex '("ab" "cd" "ab") "s/ab/zz/") (q 'pattx = "ab")))

   _ (test
      ; :g and :v -- the body runs from the last row up, so a delete never
      ; moves a row still to be visited, and the whole sweep is one undo
      (lns (ex ab5 "g/[bd]/d") = '("aa" "cc" "ee"))
      (lns (ex ab5 "v/[bd]/d") = '("bb" "dd"))
      (lns (ex '("a1" "b2" "a3") "g/a/s/[0-9]/X/") = '("aX" "b2" "aX"))
      (lns (ex ab5 "1,3g/./d") = '("dd" "ee"))             ; g takes a range too
      (st? (ex ab5 "g/zz/d") 'msg = "not found: zz")
      (lns (ex ab5 "g/zz/d") = ab5)
      ; one u puts the whole global back
      (: q (ex ab5 "g/[bd]/d") _ (vfeed q (bytes "u")) (lns q = ab5))
      (: q (ex '("a1" "b2" "a3") "g/a/s/[0-9]/X/") _ (vfeed q (bytes "u"))
         (lns q = '("a1" "b2" "a3"))))

   _ (test
      ; the file half still answers, now through the one dispatch
      (st? (ex '("a") "w") 'dow = '("t"))
      (st? (ex '("a") "w other") 'dow = '("other"))
      (st? (ex '("a") "q") 'quit = 1)
      (st? (ex '("a") "=") 'msg = "1")
      (st? (ex ab5 "$=") 'msg = "5")
      (st? (ex '("a") "zz") 'msg = "not an ex command: zz")
      (st? (ex '("a") "zz 1 2") 'dox = '("zz" "1 2"))               ; ..and left for a face that knows it
      !(st? (ex '("a") "w") 'dox)
      ; a word is itself or the one word it heads
      (st? (ex '("a") "spl") 'dos = '(stack ""))
      (st? (ex '("a") "vsp x") 'dos = '(beside "x"))
      (st? (ex '("a") "se sw=3") 'sw = 3)
      (st? (ex '("a") "n") 'msg = "1 lines")                        ; nu and number mean one thing
      (st? (ex '("a") "ya") 'reg = '(lin ("a")))
      (: q (vgob '("a") ((bytes ":sen") + [CR]))                    ; the face's word, headed
         _ (pin q 'exmore '("send"))
         q2 (vgob '("a") ((bytes ":sen") + [CR]))
         (q 'msg = "not an ex command: sen"))
      (: q (vnew '("a") "t") _ (pin q 'exmore '("send"))
         _ (vfeed q ((bytes ":sen") + [CR])) d1 (q 'dox)
         _ (vfeed q ((bytes ":se") + [CR])) m2 (q 'msg)
         (d1 = '("send" "") && 0 < #m2 && "ambiguous" = snip m2 0 9))
      ; a no-op line is a no-op, not a complaint
      (st? (ex '("a") "") 'msg = ""))

; --- the status line clips from the left: its tail is the news ---------------
   (miniw ls ks m) (: st (vgo ls ks) _ (vmsg st m) _ (pin st 'w 8) _ (pin st 'h 4)
                      (vframe st))
   (frame3 tail) (E$ + "[H" + "ab" + E$ + "[K\r\n" + "~" + E$ + "[K\r\n" + "~" + E$ + "[K\r\n"
                     + tail + E$ + "[K" + E$ + "[1;1H")
   _ (test
      ; 11 characters into a view 8 wide: the head goes, `<` says so, and the
      ; tail -- which is where the news lives -- is what you are left looking at
      (miniw '("ab") "" "abcdefghijk" = (frame3 "<efghijk"))
      (miniw '("ab") "" "12345678" = (frame3 "12345678"))    ; exactly w: untouched
      (miniw '("ab") "" "short" = (frame3 "short")))

; --- the cursor sits where you are typing: on the status line in ex and search -
   _ (test
      (: f (mini '("ab") ":") (snip f (#f - 6) #f = (E$ + "[4;2H")))
      (: f (mini '("ab") ":wq") (snip f (#f - 6) #f = (E$ + "[4;4H")))
      (: f (mini '("ab") "/x") (snip f (#f - 6) #f = (E$ + "[4;3H")))
      (: f (mini '("ab") "") (snip f (#f - 6) #f = (E$ + "[1;1H"))))

; --- the syntax paint (apps/vi/hue.l): classes, the carry, and the one law
; that keeps every exact-frame assertion above honest --------------------------
   hbk (hue-book ())
   hlx (\ s in keep (hue-lex hbk s in keep))
   (klass s) (map (\ r <r) <(hue-lex hbk s 0 1))
   (runs s in) <(hue-lex hbk s in 1)
   ; strip SGR and only SGR: \e[<digits;>m goes, \e[H and \e[K and \e[r;cH stay,
   ; because those are the frame's own geometry and the whole point is that the
   ; paint did not touch it
   (bare s)
    (: n #s
       (dig? c) (((48 <= c) && (c <= 57)) || (c = 59))
       (go i acc)
        (? (n <= i) acc
           ((s i = 27) && ((i + 1) < n) && (s (i + 1) = 91))
            (: (sk j) (? ((j < n) && dig? (s j)) (sk (j + 1)) j)
               k (sk (i + 2))
               (? ((k < n) && (s k = 109)) (go (k + 1) acc)
                  (go (i + 1) (acc + string (s i)))))
           (go (i + 1) (acc + string (s i))))
       (go 0 ""))

; --- one class per token, table order: a word lane beats the punct lanes, the
;     number lane beats a leading sigil, and punct inside a name is the name ---
   _ (test
      (klass "; hi" = '(comment))
      (klass "#!/x" = '(comment))
      (klass "\"a ; b\"" = '(string))               ; a ; inside a string is no comment
      (klass "'foo" = '(atom))
      (klass "[1]" = '(paren number paren))
      (klass "map" = '(book))
      (klass "zzznope" = ())                        ; not in the book: plain, and that is the tell
      (klass "zzz?" = ())
      (klass ":" = '(form))
      (klass "&&" = '(macro))
      (klass "tau" = '(const))
      (klass "$x" = '(mono))                        ; the valence law, in colour
      (klass "a $ b" = '(dyad))
      (klass "+" = '(dyad))                         ; a bare operator is not a book name
      (klass "-3" = '(number))
      (klass ".5" = '(number))
      (klass "1.5e-3" = '(number))
      (klass "1e10" = '(number)))

; --- a stop still ends the token and the walk still moves on. `,` is one: it
;     reads as a symbol and terminates one ((sound "a,b") answers a, then ,b),
;     so the lexer meets it bare. it wears the `comma` class (hue.l's `sep` tag)
;     because it is its own case everywhere else too. a control byte is the case
;     that stays unclaimed, and it ends a token exactly the same way ----------
   _ (test
      (klass "," = '(comma))
      (runs "," 0 = '((comma 0 1)))
      (runs "map,map" 0 = '((book 0 3) (comma 3 4) (book 4 7)))
      (runs ("map" + (string 1) + "map") 0 = '((book 0 3) (book 4 7))))   ; unclaimed: no run of its own

; --- the carry: a string spans lines (papel.l's css is forty of them), so a
;     line's class depends on where the line before it ended -----------------
   _ (test
      (hue-carry hlx '("(: css \"a" "b\" 1)" "x") = '(0 1 0))
      (runs "a ; b\" c" 1 = '((string 0 6)))        ; carried in: the ; is still string
      (runs "a ; b" 1 = '((string 0 5)))            ; and it stays open to the end
      ; keep () is the same walk with its answers dropped -- one lexer, provably
      (: a (hue-lex hbk "\"x" 0 1) b (hue-lex hbk "\"x" 0 ())
         ((<>a = <>b) && !(two? <b))))

; --- the word lanes are asked, not listed. only the three special forms are
;     written out, and they are the grammar rather than the book ---------------
   _ (test
      (: ls (map hue-arg (hue-tagged 'word))
         ((#(filter nom? ls) = 3) &&                ; macros values names
          (#(filter two? ls) = 1)))                 ; the forms, and nothing else
      (0 < #(hue-words 'macros))
      (0 < #(hue-words 'values))
      (0 < #(hue-words 'names))
      ; the probes answer what they claim to: a known macro, a known constant, a
      ; known verb -- each in its lane and no other
      (elem "assert" (hue-words 'macros))
      (elem "&&" (hue-words 'macros))                   ; not filtered: a sigil macro is a macro
      (elem "tau" (hue-words 'values))
      (elem "map" (hue-words 'names))
      !(elem "+" (hue-words 'names))                    ; a bare operator belongs to the punct lanes
      !(elem "$" (hue-words 'values))
      ; sorted, because the generator freezes them into a diff-gated file
      (: w (hue-words 'names) (w = (sort w)))
      ; the stability law. both book lanes are positive tests -- a name does
      ; something or is something -- so session data (argv, cmdline, `parsed`,
      ; which is bound only when love was handed a file) falls out of both, and
      ; the generated syntax file cannot depend on how the generator was started.
      (all (\ w (lit? (ev (intern w)))) (hue-words 'names))
      (all (\ w !(lit? (ev (intern w)))) (hue-words 'values))
      !(elem "argv" (hue-words 'names))
      !(elem "argv" (hue-words 'values))
      ; earlier row wins in the one tablet, exactly as the table reads top-down
      (: b (hue-book ()) (b "assert" = 'macro && (b "tau" = 'const) &&
                          (b "map" = 'book))))

; --- the pens: molokayo, and every class has one -----------------------------
   _ (test
      (hue-pen '(Comment 59 "#75715E" ()) () = "\e[38;5;59m")
      (hue-pen '(Statement 161 "#F92672" (bold)) () = "\e[1;38;5;161m")
      (hue-pen '(Statement 161 "#F92672" (bold)) 1 = "\e[1;38;2;249;38;114m")
      (: ps (hue-pens hue-theme ()) (all (\ c (string? (ps (hue-cls c)))) hue-classes))
      (: ps (hues-pens hue-theme ()) (all (\ c (string? (ps (hue-cls c)))) hues-classes))
      (all (\ r (any (\ c (hue-grp c = <r)) hue-classes || any (\ c (hue-grp c = <r)) hues-classes))
           hue-theme))

; --- paint invariance: colour adds colour and moves nothing. this is what keeps
;     every byte-exact frame law above meaningful once the paint exists -------
   (twin ls ks) (: a (vgo ls ks) b (vgo ls ks)
                   _ (pin a 'w 30) _ (pin a 'h 5) _ (pin b 'w 30) _ (pin b 'h 5)
                   _ (hlon b)
                   (bare (vframe b) = vframe a))
   _ (test
      (twin '("(map (+ 1) '(1 2 3)) ; hi" "(: x 2)") "")
      (twin '("(: css \"a" "b\" 1)") "j")
      (twin '("(f a, b)") "")
      (twin '("(a really quite long line that clips at the view edge)") "$")
      (twin '("") ""))

; --- the other languages (apps/vi/hues.l): the name picks the lexer, else a #!
;     naming a shell, and each answers hue-lex's shape, the carry included ----
   (hk g s in) (map (\ r <r) <((hues-lexer g) s in 1))
   (hc g ls) (hue-carry (hues-lexer g) ls)
   _ (test
      (hues-lang "a/b.c" "" = 'c)
      (hues-lang "x.h" "" = 'c)
      (hues-lang "Makefile" "" = 'make)
      (hues-lang "t.mk" "" = 'make)
      (hues-lang "x.html" "" = 'html)
      (hues-lang "x.css" "" = 'css)
      (hues-lang "x.sh" "" = 'sh)
      (hues-lang "run" "#!/bin/sh -e" = 'sh)
      (hues-lang "x.l" "#!/bin/sh" = 'l)                  ; the name first
      !(hues-lang "x.txt" "")
      !(hues-lang "run" "#!/usr/bin/env python3"))
   _ (test
      (hk 'c "#include <stdio.h>" 0 = '(pre string))
      (hk 'c "static int x = 0x1f; // n" 0 = '(type type number comment))
      (hk 'c "if (c == '\\'') return \"a\\\"b\";" 0 = '(keyword string keyword string))
      (hk 'c "x = 1.5e-3f;" 0 = '(number))
      (hk 'c "c */ d" 1 = '(comment))
      (hc 'c '("a /* b" "c */ d" "e") = '(0 1 0)))
   _ (test
      (hk 'css "a:hover, .x #y {" 0 = '(keyword ent func func))
      (hk 'css "  color: #fff; margin: -2px 10%;" 0 = '(type number type number number))
      (hk 'css "  --w: 3em !important;" 0 = '(var number keyword))
      (hk 'css "@media screen {" 0 = '(pre keyword))
      (hc 'css '("/* a" "b */ p {" "x") = '(0 1 0)))
   _ (test
      (hk 'html "<a href=\"x\">t &amp; u</a>" 0 = '(keyword attr string keyword ent keyword keyword))
      (hk 'html "<style>p { color: red }</style>" 0 = '(keyword keyword keyword type keyword keyword))
      (hc 'html '("<!-- a" "b --> <div" "  id=x>" "y") = [0 1 ['tag "div" 0] 0])
      (hc 'html '("<style>/* a" "b */</style>" "x") = [0 ['css 1] 0]))
   _ (test
      (hk 'sh "FOO=bar # c" 0 = '(var comment))
      (hk 'sh "a#b" 0 = ())                               ; # opens a comment only at a word
      (hk 'sh "if [ \"$x\" = 1 ]; then echo ${y}; fi" 0
          = '(keyword func string var string number func keyword func var keyword))
      (hc 'sh '("cat <<-'EOF'" "body $x" "\tEOF" "x") = '(0 "EOF" "EOF" 0))
      (hk 'sh "body $x" "EOF" = '(string))
      (hk 'sh "\tEOF" "EOF" = '(pre))
      (hc 'sh '("a 'b" "c' \"d" "e\"" "x") = '(0 1 2 0)))
   _ (test
      (hk 'make "CC ?= cc # c" 0 = '(var comment))
      (hk 'make "$(ho)/love: a.o $(b)" 0 = '(func var))
      (hk 'make "ifeq ($(A),1)" 0 = '(pre var))
      (hk 'make "\techo $@ $(X) 'q'" 0 = '(func var var string))   ; a recipe is sh
      (<((hues-lexer 'make) "\ttest -s $$t" 0 1) = '((func 1 5) (var 9 12)))
      (hk 'make "x.o: CFLAGS=1" 0 = '(func)))
   _ (test
      (map (\ f (hues-lang f "")) ["x.md" "x.json" "x.s" "x.S" "x.asm" "x.diff" "x.patch" "x.awk"
                                   "love.1" "x.man" "x.mjs" "Cookfile"]
       = '(md json asm asm asm diff diff awk roff roff js make))
      (hues-lang "run" "#!/usr/bin/awk -f" = 'awk))
   _ (test
      (hk 'json "{\"a\": [1, -2.5e3, true], \"b\": \"x\\\"y\"} // c" 0
          = '(type number number const type string comment))
      (hk 'diff "--- a/x" 0 = '(type))
      (<((hues-lexer 'diff) "@@ -1 +1 @@ fn" 0 1) = '((ent 0 11)))
      (hk 'diff "+new" 0 = '(added))
      (hk 'diff "-old" 0 = '(removed))
      (hk 'diff " ctx" 0 = ())
      (hk 'roff ".TH LOVE 1 \"2026\"" 0 = '(keyword string))
      (hk 'roff "a \\fBb\\fR \\(em \\*(Lq \\s+2" 0 = '(ent ent ent ent ent))
      (hk 'roff "text \"q\" \\\" c" 0 = '(comment))       ; quotes are literal outside a request
      (hk 'roff ".\\\" all comment" 0 = '(comment))
      (hk 'awk "/^a+/ && $3 > 1 { n = NF / 2; print $1 }  # c" 0
          = '(string var number var number keyword var comment))
      (hk 'awk "BEGIN { FS = \":\" }" 0 = '(keyword var string))
      (hk 'js "r = /a\\/b/g, d = x / 2 / y" 0 = '(string number)))
   _ (test
      (hk 'asm "main:  movq %rsp, %rbp  # c" 0 = '(func keyword var var comment))
      (hk 'asm "  movl $-1, -8(%rbp); ret" 0 = '(keyword number number var keyword))
      (hk 'asm "  .globl main" 0 = '(pre))
      (hk 'asm "  mov rax, qword ptr [rbx+8]" 0 = '(keyword var type type var number))
      (hk 'asm "  add x0, x1, #16 // a64" 0 = '(keyword var var number comment))
      (hk 'asm "  addi a0, a1, 3" 0 = '(keyword var var number))
      (hk 'asm "  bx lr @ thumb" 0 = '(keyword var comment))
      (hk 'asm "1: jmp 1b" 0 = '(func keyword number))
      (hk 'asm "#include <x.h>" 0 = '(pre))
      (hc 'asm '("/* a" "b */ nop" "x") = '(0 1 0)))
   _ (test
      (hk 'md "# Title" 0 = '(keyword))
      (hk 'md "a *em* **strong** `code` a_b_c [t](u) <https://y>" 0
          = '(ent const string func string string))
      (hk 'md "- item" 0 = '(pre))
      (hk 'md "12. item" 0 = '(pre))
      (hk 'md "> q" 0 = '(comment))
      (hk 'md "***" 0 = '(pre))
      ; a fence names its language and its body is lexed as that one, carry and all
      (hc 'md '("```c" "int x; /* a" "b */" "```" "t")
          = [0 ['fence 96 3 'c 0] ['fence 96 3 'c 1] ['fence 96 3 'c 0] 0])
      (hk 'md "int x;" ['fence 96 3 'c 0] = '(type))
      (hk 'md "(map f l)" ['fence 96 3 'l 0] = '(paren book paren))
      (hk 'md "raw *x*" ['fence 126 3 () 0] = '(string))
      (hk 'md "````" ['fence 96 3 'c 0] = '(pre)))         ; a longer run closes too
   ; paint invariance again, off the .l lexer: colour is added and nothing moves
   (twinf ls nm) (: a (vnew ls nm) b (vnew ls nm)
                    _ (pin a 'w 30) _ (pin a 'h 5) _ (pin a 'hl ())
                    _ (pin b 'w 30) _ (pin b 'h 5) _ (hlon b)
                    ((bare (vframe b) = vframe a) && !(vframe b = vframe a)))
   _ (test
      (twinf '("int x; /* a" "b */ char *s = \"q\";") "t.c")
      (twinf '("<p class=\"a\">x &lt; y</p>") "t.html")
      (twinf '("if true; then echo $x; fi") "t.sh")
      (twinf '("all: x.o" "\tcc -o $@ $^") "Makefile")
      (twinf '("p { color: red }") "t.css")
      (twinf '("{\"a\": 1}") "t.json")
      (twinf '("@@ -1 +1 @@" "-a" "+b") "t.diff")
      (twinf '(".SH NAME" "love \\- a lisp") "t.1")
      (twinf '("main: movq %rsp, %rbp") "t.s")
      (twinf '("# t" "```c" "int x;" "```") "t.md")
      (twinf '("{ print $1 }") "t.awk")
      ; % reads c's strings as the paint does: the quoted ) is not a mate
      (at (vfeed (vnew '("f(\")\", x)") "t.c") (bytes "%")) = '(0 8))
      (at (vgo '("f(\")\", x)") "%") = '(0 3)))

; --- born on for a language hues-lang names, off for everything else (which is
;     why "t" above is plain), and :hl flips it -------------------------------
   _ (test
      !(st? (vnew '("a") "t") 'hl)
      !(st? (vnew '("a") "") 'hl)
      !(st? (vnew '("a") "l") 'hl)
      !(st? (vnew '("a") "x.txt") 'hl)
      (st? (vnew '("a") "x.l") 'hl)
      (st? (vnew '("a") "apps/vi/hue.l") 'hl)
      (st? (vnew '("a") "x.c") 'hl)
      (st? (vnew '("a") "Makefile") 'hl)
      (st? (vnew '("#!/bin/sh") "run") 'hl)
      (st? (vgob '("a") ((bytes ":hl") + [CR])) 'hl)
      !(st? (vgob '("a") ((bytes ":hl") + [CR] + (bytes ":hl") + [CR])) 'hl))

; --- characters, not bytes: the cursor sits on a character's first byte, every
; motion steps whole ones, and the screen counts columns -- a wide one takes two.
; "a日本b" is a(0) 日(1) 本(4) b(7), eight bytes and six columns
   _ (test
      (at (vgo '("a日本b") "l") = '(0 1)) (at (vgo '("a日本b") "ll") = '(0 4))
      (at (vgo '("a日本b") "$") = '(0 7)) (at (vgo '("a日本b") "$h") = '(0 4))
      (at (vgo '("a日本b") "9l") = '(0 7))                   ; the fence is a character
      (lns (vgo '("a日本b") "lx") = '("a本b"))
      (lns (vgo '("a日本b") "l2x") = '("ab"))
      (lns (vgo '("a日本b") "llX") = '("a本b"))
      (lns (vgo '("a日本b") "ld$") = '("a"))                  ; $ takes its character whole
      (lns (vgo '("a日本b") "vld") = '("本b"))
      (lns (vgo '("a日本b") "lr中") = '("a中本b"))             ; a multibyte argument waits for its tail
      (lns (vgo '("a日本b") "l2r.") = '("a..b"))
      (at (vgo '("a日本b") "f本") = '(0 4)) (at (vgo '("a日本b") "t本") = '(0 1))
      (at (vgo '("a日本b") "$F日") = '(0 1)) (at (vgo '("a日本b") "$T日") = '(0 4))
      (at (vgo '("a日本b") "f本;") = '(0 4))
      (at (vgo '("日本 語") "w") = '(0 7)) (at (vgo '("日本 語") "e") = '(0 3))
      (at (vgo '("café au") "w") = '(0 6))                    ; é is a letter, not punctuation
      (at (vgo '("日本語" "abcdef") "$j") = '(1 4))           ; the goal is a screen column
      (at (vgo '("abcdef" "日本語") "4lj") = '(1 6))
      (at (vgo '("abcdef" "日本語") "3lj") = '(1 3))          ; a column inside 本 lands on it
      (lns (vgo '("") "i日\e") = '("日")) (at (vgo '("") "i日\e") = '(0 0))
      (lns (vgob '("a日") [65 BS 27]) = '("a"))              ; backspace takes a character
      (lns (vgo '("日b") "ax\e") = '("日xb"))                 ; a appends after the character
      (lns (vgo '("日b") "ylp") = '("日日b")) (at (vgo '("日b") "ylp") = '(0 3))
      (: st (see (box '("a日本b") 4 4) "")
         (body st = '("a日" "~" "~")))                        ; 本 would cross the margin
      (: st (see (box '("a日本b") 4 4) "$")
         L (vlay st)
         ((st 'left = 2) && (body st = '(" 本b" "~" "~")) && (<>>>L = 4)))
      (: st (see (box '("日本語日") 5 4) ":set wrap\r")
         (body st = '("日本" "語日" "~")))
      (: st (see (see (box '("日本語日") 5 4) ":set wrap\r") "$")
         L (vlay st)
         ((<>>L = 2) && (<>>>L = 3))))

   _ (test_fin ())                                    ; no zz-fin here: quit before claiming ok
   _ (say err "test/law/vi: motions + words + finds + insert + operators + registers + undo + search + ex + frames + hue + hues ok") _ (put err 10) 0)
