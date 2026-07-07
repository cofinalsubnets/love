; crew/cc/lex.l -- the C lexer (rung 3 stage 0; doc/cc.md is the plan). text ->
; (1 tokens) | () on a lex error. a token is (kind val line): ('kw nom), ('id
; text), ('num charm), ('p text) -- the punctuator by maximal munch. comments
; both kinds; line numbers carried for diagnostics. char literals 'a' (with
; \n \t \r \0 \\ \') read as ('num code); string literals (same escapes,
; plus \") as ('str text). not yet (staged): hex/octal/float literals,
; adjacent-string pasting, the preprocessor's # lines.
(:
   (clex src)
    (: n (tally src)
       kws '(auto break case char const continue default do double else enum
             extern float for goto if inline int long register restrict return
             short signed sizeof static struct switch typedef union unsigned
             void volatile while)
       p3 '("<<=" ">>=" "...")
       p2 '("==" "!=" "<=" ">=" "&&" "||" "<<" ">>" "+=" "-=" "*=" "/=" "%="
            "&=" "|=" "^=" "->" "++" "--" "##")
       p1 "()[]{};,.:?~!+-*/%<>=&|^#"
       (ws? c) (|| (= c 32) (|| (= c 9) (= c 13)))
       (dig? c) (&& (<= 48 c) (<= c 57))
       (idh? c) (|| (&& (<= 97 c) (<= c 122)) (|| (&& (<= 65 c) (<= c 90)) (= c 95)))
       (idc? c) (|| (idh? c) (dig? c))
       (at? i pat) (: m (tally pat)                 ; does pat sit at i?
                      (go k) (? (<= m k) 1
                                (<= n (+ i k)) ()
                                (= (src (+ i k)) (pat k)) (go (+ k 1))
                                ())
                      (go 0))
       (firstat i ps) (? (! (two? ps)) ()
                         (at? i (cap ps)) (cap ps)
                         (firstat i (cup ps)))
       (in1? c) (: m (tally p1)
                   (go k) (? (<= m k) () (= (p1 k) c) 1 (go (+ k 1)))
                   (go 0))
       (go i line acc)
        (? (<= n i) (L 1 (rev acc))
           (: c (src i)
              (? (= c 10) (go (+ i 1) (+ line 1) acc)
                 (&& (= c 92) (&& (< (+ i 1) n) (= (src (+ i 1)) 10)))     ; \<nl> splice: ONE logical line
                  (go (+ i 2) line acc)                                    ; (line unadvanced so a directive stays grouped)
                 (&& (= c 92) (&& (< (+ i 2) n) (&& (= (src (+ i 1)) 13) (= (src (+ i 2)) 10))))  ; \<cr><nl>
                  (go (+ i 3) line acc)
                 (ws? c) (go (+ i 1) line acc)
                 (at? i "//") (: (eat j) (? (|| (<= n j) (= (src j) 10)) j (eat (+ j 1)))
                                (go (eat i) line acc))
                 (at? i "/*") (: (eat j l2) (? (<= n (+ j 1)) (L () l2)   ; unterminated
                                              (at? j "*/") (L (+ j 2) l2)
                                              (eat (+ j 1) (? (= (src j) 10) (+ l2 1) l2)))
                                r (eat (+ i 2) line)
                                (? (charm? (cap r)) (go (cap r) (caup r) acc) ()))
                 (= c 34) (: (eat j acc2)                     ; a string literal
                              (? (<= n j) ()
                                 (: c2 (src j)
                                    (? (= c2 34) (L acc2 (+ j 1))
                                       (= c2 10) ()
                                       (&& (= c2 92) (< (+ j 1) n))
                                        (: d (src (+ j 1))
                                           v (? (= d 110) 10 (= d 116) 9 (= d 114) 13
                                                (= d 48) 0 (= d 92) 92 (= d 34) 34 (= d 39) 39 ())
                                           (? (charm? v) (eat (+ j 2) (+ acc2 (string v))) ()))
                                       (eat (+ j 1) (+ acc2 (string c2))))))
                             r (eat (+ i 1) "")
                             (? (two? r) (go (caup r) line (link (L 'str (cap r) line) acc)) ()))
                 (= c 39) (: esc (&& (< (+ i 2) n) (= (src (+ i 1)) 92))
                             v (? esc (: d (src (+ i 2))
                                         (? (= d 110) 10 (= d 116) 9 (= d 114) 13
                                            (= d 48) 0 (= d 92) 92 (= d 39) 39 ()))
                                  (< (+ i 1) n) (src (+ i 1))
                                  ())
                             j (+ i (? esc 4 3))
                             (? (&& (charm? v) (&& (<= j n) (= (src (- j 1)) 39)))
                                (go j line (link (L 'num v line) acc))
                                ()))
                 (dig? c) (: (num j v) (? (&& (< j n) (dig? (src j)))
                                          (num (+ j 1) (+ (* 10 v) (- (src j) 48)))
                                          (L j v))
                             r (num i 0)
                             (go (cap r) line (link (L 'num (caup r) line) acc)))
                 (idh? c) (: (idr j) (? (&& (< j n) (idc? (src j))) (idr (+ j 1)) j)
                             j (idr i)
                             t (snip src i j)
                             s (intern t)
                             (go j line (link (? (member? s kws) (L 'kw s line) (L 'id t line)) acc)))
                 (: hit (firstat i (cat p3 p2))
                    (? hit (go (+ i (tally hit)) line (link (L 'p hit line) acc))
                       (in1? c) (go (+ i 1) line (link (L 'p (string c) line) acc))
                       ())))))
       (go 0 1 ())))
