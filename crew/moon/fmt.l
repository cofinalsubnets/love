; crew/moon/fmt.l -- moonfmt, the C reindenter (v2). shares NOTHING with the
; parser/codegen: it reads text and writes text, a pure line-preserving pass.
; the house C style is the .l style ported to C -- 1-space indent, cuddled close
; braces, one-liners where they fit, hand-aligned tables -- so it REINDENTS
; statement/block lines from brace depth, strips trailing whitespace, and leaves
; every deliberate line-break, continuation-alignment, macro body and comment
; EXACTLY as written. on reindented, comment-free code lines it also RESPACES,
; ADDITIVELY -- it INSERTS a space around a glued operator but never DELETES one,
; so already-spaced code and hand alignment are untouched. binary +/-/& use the
; value-prev heuristic (reliable in C) with a keyword guard (`return -1` stays);
; `*` is spaced only after ) ] or a digit (unambiguous multiply) -- an id-adjacent
; `*` is left alone, since `word *p` (pointer) and `a * b` (multiply) are
; indistinguishable without the typedef set (the v3 hook). cfmt : text -> text.
(:
   iw 1                                                             ; indent WIDTH -- spaces per brace level (the one house knob)
   ; --- little string tools ---
   (ws? c) (|| (c = 32) (c = 9))
   (bnd? x) (|| (x = 59) (|| (x = 123) (|| (x = 125) (x = 58))))   ; ; { } : end a statement/block
   (mx a b) (? (a < b) b a)
   (ltrim s) (: n (tally s) (g i) (? (&& (i < n) (ws? (s i))) (g (i + 1)) (snip s i n)) (g 0))
   (rtrim s) (: n (tally s) (g j) (? (&& (0 < j) (ws? (s (j - 1)))) (g (j - 1)) (snip s 0 j)) (g n))
   (endsl t) (: n (tally t) (&& (0 < n) ((t (n - 1)) = 92)))       ; ends with a backslash (line splice)
   (spaces k) (? (k < 1) "" ((string 32) + (spaces (k - 1))))
   (linesof s) (: n (tally s)
                  (g i st acc) (? (n <= i) (rev (link (snip s st n) acc))
                                  ((s i) = 10) (g (i + 1) (i + 1) (link (snip s st i) acc))
                                  (g (i + 1) st acc))
                  (g 0 0 ()))
   (unlines ls) (? (! (two? ls)) "" (foldl (\ a x (a + "\n" + x)) <ls >ls))

   ; --- v2 respacing (additive: INSERTS a space around a glued operator, never
   ; deletes one -- so already-spaced code and hand alignment are untouched; runs on
   ; reindented, comment-free code lines only) ---
   (idc? c) (|| (&& (97 <= c) (c <= 122)) (|| (&& (65 <= c) (c <= 90)) (|| (&& (48 <= c) (c <= 57)) (c = 95))))
   (dig? c) (&& (48 <= c) (c <= 57))
   (kw? w) (|| (w = "if") (|| (w = "for") (|| (w = "while") (w = "switch"))))   ; keywords that take a spaced (
   both2 '("==" "!=" "<=" ">=" "&&" "||" "<<" ">>" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>=")  ; always-binary multi-char ops
   noop2 '("->" "++" "--")                                                     ; multi-char ops that take NO surrounding space
   both1 '(61 60 62 47 37 124 94)                                             ; = < > / % | ^  -- always-binary single chars
   nonval '("return" "case" "sizeof" "else" "do" "goto")                     ; an id after which +/-/& reads UNARY
   ; longest operator at i (3- then 2-char), or () -- so <<= / == / -> aren't split
   (opat s i n) (? (&& ((i + 3) <= n) (member? (snip s i (i + 3)) both2)) (snip s i (i + 3))
                   (&& ((i + 2) <= n) (member? (snip s i (i + 2)) (both2 + noop2))) (snip s i (i + 2))
                   ())
   ; is the token before an operator a VALUE (so +/-/& is binary)? an id/number is,
   ; UNLESS it is a nonval keyword; a closing ] is. NOT a closing ) -- `(T) &x` /
   ; `(T) -x` are cast-then-unary, indistinguishable from an expression without the
   ; type set -- nor an operator. so )-adjacent +/-/& is left glued (the v3 gap).
   (pval? pv pw) (|| (&& (idc? pv) (! (member? pw nonval))) (pv = 93))
   ; render a binary operator: a leading space unless the last out char is already a
   ; space (or line start), then a trailing space unless the next char is a space or `)`
   ; (an operator glued to `)` is a token passed to a macro -- bit_slow(bor, |) -- leave it).
   (spaced? lo nxt) (&& (0 < nxt) (&& (! (nxt = 32)) (! (nxt = 41))))         ; will binsp add a trailing space? (-> new lo)
   (binsp op lo nxt) ((? (|| (lo = 32) (lo = 0)) "" " ") + op + (? (spaced? lo nxt) " " ""))
   ; does the code line carry a // or /* comment? (then skip respacing, to keep the comment's column)
   (hascmt? s) (: n (tally s)
                  (w i st) (? (n <= i) ()
                              (: c (s i)
                                 (? (id? st 'str) (? (c = 92) (w (i + 2) 'str) (c = 34) (w (i + 1) 'code) (w (i + 1) 'str))
                                    (id? st 'chr) (? (c = 92) (w (i + 2) 'chr) (c = 39) (w (i + 1) 'code) (w (i + 1) 'chr))
                                    (&& (c = 47) (&& ((i + 1) < n) (|| ((s (i + 1)) = 47) ((s (i + 1)) = 42)))) 1
                                    (c = 34) (w (i + 1) 'str)
                                    (c = 39) (w (i + 1) 'chr)
                                    (w (i + 1) 'code))))
                  (w 0 'code))
   ; the walk. word = the identifier being built; pw = the last COMPLETED identifier
   ; (the token just left of an operator); lo = last out char (for space-dedup); pv =
   ; last significant (non-space) char (for the binary/unary decision).
   (respace s)
    (: n (tally s)
       (w i st word pw lo pv out)
        (? (n <= i) out
           (: c (s i)
              (? (id? st 'str)
                  (? (c = 92) (w (i + 2) 'str "" pw c c (out + (string c) + (? ((i + 1) < n) (string (s (i + 1))) "")))
                     (c = 34) (w (i + 1) 'code "" pw c c (out + (string c)))
                     (w (i + 1) 'str "" pw c c (out + (string c))))
                 (id? st 'chr)
                  (? (c = 92) (w (i + 2) 'chr "" pw c c (out + (string c) + (? ((i + 1) < n) (string (s (i + 1))) "")))
                     (c = 39) (w (i + 1) 'code "" pw c c (out + (string c)))
                     (w (i + 1) 'chr "" pw c c (out + (string c))))
                 (c = 34) (w (i + 1) 'str "" pw 34 34 (out + (string c)))
                 (c = 39) (w (i + 1) 'chr "" pw 39 39 (out + (string c)))
                 (idc? c) (w (i + 1) 'code (word + (string c)) pw c c (out + (string c)))   ; grow the identifier
                 ; a non-id char: first settle pw from a just-ended identifier run
                 (: pw2 (? (0 < (tally word)) word pw)
                    (? (ws? c) (w (i + 1) 'code "" pw2 c pv (out + (string c)))   ; whitespace: copy, KEEP pv
                       (: op (opat s i n)
                          (? op                                                  ; a multi-char operator
                              (: L (tally op)  nc (op (L - 1))
                                 (? (member? op both2)                           ; binary: space both (additively)
                                     (: nxt (? ((i + L) < n) (s (i + L)) 0)
                                        (w (i + L) 'code "" pw2 (? (spaced? lo nxt) 32 nc) nc (out + (binsp op lo nxt))))
                                     (w (i + L) 'code "" pw2 nc nc (out + op))))  ; -> ++ -- : copy, no space
                             (c = 40) (: sp (&& (kw? pw2) (! (lo = 32)))          ; keyword glued to (
                                         (w (i + 1) 'code "" "" (? sp 32 40) 40 (out + (? sp " (" "("))))
                             (|| (c = 44) (c = 59))                              ; , ; : space after when glued
                              (: nx (? ((i + 1) < n) (s (i + 1)) 0)
                                 sp? (&& (0 < nx) (&& (! (ws? nx)) (&& (! (nx = 41)) (&& (! (nx = 44)) (! (nx = 59))))))
                                 (w (i + 1) 'code "" "" (? sp? 32 c) c (out + (string c) + (? sp? " " ""))))
                             (member? c both1)                                   ; = < > / % | ^ : always binary
                              (: nxt (? ((i + 1) < n) (s (i + 1)) 0)
                                 (w (i + 1) 'code "" pw2 (? (spaced? lo nxt) 32 c) c (out + (binsp (string c) lo nxt))))
                             (|| (c = 43) (|| (c = 45) (c = 38)))                ; + - & : heuristic (binary iff prev is a value)
                              (? (&& (pval? pv pw2)                             ; ...but an e/E/p/P exponent sign (1e-5, 0x1.0p-53) stays glued
                                     (! (&& (|| (c = 43) (c = 45))
                                            (&& (|| (pv = 101) (|| (pv = 69) (|| (pv = 112) (pv = 80))))
                                                (&& ((i + 1) < n) (dig? (s (i + 1))))))))
                                 (: nxt (? ((i + 1) < n) (s (i + 1)) 0)
                                    (w (i + 1) 'code "" pw2 (? (spaced? lo nxt) 32 c) c (out + (binsp (string c) lo nxt))))
                                 (w (i + 1) 'code "" pw2 c c (out + (string c))))   ; unary / exponent sign: copy glued
                             (c = 42)                                            ; * : SAFE subset -- binary only after ] or a digit
                              (? (|| (pv = 93) (dig? pv))                        ;   (id- or )-adjacent * is left alone: a cast-deref
                                                                                 ;   `(T*) *p` or a typedef `a*b` needs the type set)
                                 (: nxt (? ((i + 1) < n) (s (i + 1)) 0)
                                    (w (i + 1) 'code "" pw2 (? (spaced? lo nxt) 32 42) 42 (out + (binsp "*" lo nxt))))
                                 (w (i + 1) 'code "" pw2 c c (out + (string c))))
                             (w (i + 1) 'code "" pw2 c c (out + (string c))))))))))   ; ) ] [ { } ~ ! ? : . # : copy verbatim
       (w 0 'code "" "" 0 0 ""))

   ; --- scan ONE line for brace/paren deltas + its last significant code char.
   ; entry inb = already inside a /* */ block. answers (bdelta pdelta lastsig endb?):
   ; braces/parens counted in CODE state only (strings, chars, comments skipped);
   ; lastsig is the last non-ws code char (a trailing // comment never moves it),
   ; 0 if the line carried no code; endb true if the line ends still in a block. ---
   (scanline s inb)
    (: n (tally s)
       (w i st d p ls)
        (? (n <= i) `(d p ls (id? st 'blk))
           (: c (s i)
              (? (id? st 'blk)                                          ; inside /* .. */
                  (? (&& ((i + 1) < n) (&& (c = 42) ((s (i + 1)) = 47))) (w (i + 2) 'code d p ls)
                     (w (i + 1) 'blk d p ls))
                 (id? st 'str)                                          ; inside "..."
                  (? (c = 92) (w (i + 2) 'str d p ls)
                     (c = 34) (w (i + 1) 'code d p ls)
                     (w (i + 1) 'str d p ls))
                 (id? st 'chr)                                          ; inside '.'
                  (? (c = 92) (w (i + 2) 'chr d p ls)
                     (c = 39) (w (i + 1) 'code d p ls)
                     (w (i + 1) 'chr d p ls))
                 (&& (c = 47) (&& ((i + 1) < n) ((s (i + 1)) = 47))) `(d p ls ())   ; // -> rest ignored
                 (&& (c = 47) (&& ((i + 1) < n) ((s (i + 1)) = 42))) (w (i + 2) 'blk d p ls)   ; /*
                 (c = 34) (w (i + 1) 'str d p ls)
                 (c = 39) (w (i + 1) 'chr d p ls)
                 (c = 123) (w (i + 1) 'code (d + 1) p c)                ; {
                 (c = 125) (w (i + 1) 'code (d - 1) p c)                ; }
                 (|| (c = 40) (c = 91)) (w (i + 1) 'code d (p + 1) c)   ; ( [
                 (|| (c = 41) (c = 93)) (w (i + 1) 'code d (p - 1) c)   ; ) ]
                 (ws? c) (w (i + 1) 'code d p ls)
                 (w (i + 1) 'code d p c))))
       (w 0 (? inb 'blk 'code) 0 0 0))

   ; --- the pass. state: bd brace depth, pd paren depth, inb in-block-comment,
   ; inc in a \-continued cpp directive, bnd? did the last code line end at a
   ; statement boundary. a line is REINDENTED only when pd=0 AND the previous line
   ; closed a statement -- so continuation lines (open paren, or a prior line
   ; ending in `,` / an operator), aligned tables, macro bodies and comments all
   ; ride through verbatim. ---
   (cfmt src)
    (: lines (linesof src)
       (g ls out bd pd inb inc bnd)
        (? (! (two? ls)) (unlines (rev out))
           (: raw <ls  rest >ls  t (rtrim raw)
              (? inc                                                    ; cpp continuation -- verbatim
                  (g rest (link t out) bd pd inb (endsl t) bnd)
                 inb                                                    ; inside a block comment -- verbatim
                  (: r (scanline t 1)
                     (g rest (link t out) (bd + <r) (mx 0 (pd + <>r)) <>>>r (endsl t)
                        (? (<>>r = 0) bnd (bnd? <>>r))))
                 (: c (ltrim t)
                    (? ((tally c) = 0) (g rest (link "" out) bd pd inb inc bnd)   ; blank line
                       ; a # directive OR a line that OPENS with a comment rides verbatim:
                       ; the author placed the indent (cpp nesting, hand-aligned prose)
                       (|| ((c 0) = 35) (&& (&& (1 < (tally c)) ((c 0) = 47)) (|| ((c 1) = 47) ((c 1) = 42))))
                        (: r (scanline c ()) (g rest (link t out) bd pd <>>>r (endsl t) bnd))
                       (: r (scanline c ())
                          re? (&& (pd = 0) bnd)                         ; reindent this line?
                          fc (? ((c 0) = 125) 1 0)                      ; leading } dedents
                          body (? (&& re? (! (hascmt? c))) (respace c) c)   ; respace only reindented, comment-free lines
                          line (? re? ((spaces (iw * (mx 0 (bd - fc)))) + body) t)
                          (g rest (link line out) (bd + <r) (mx 0 (pd + <>r)) <>>>r (endsl t)
                             (? (<>>r = 0) bnd (bnd? <>>r)))))))))
       (g lines () 0 0 () () 1))

   ; --- driver: moonfmt FILE ..  -> formatted text on stdout (gofmt-style, no -w).
   ; the seat drops the interpreter + this script, formatting each remaining path. ---
   (rdf p) (: q (open p "r") (? q (: t (slurp q) _ (close q) `(1 t)) ()))
   (fmt-each fs) (? (! (two? fs)) 0
                    (: r (rdf <fs)
                       _ (? (two? r) (puts (cfmt <>r))
                            (say err ("moonfmt: cannot open " + <fs + "\n")))
                       (fmt-each >fs)))
   files (? (two? >>cmdline) >>cmdline (: _ (say err "usage: moonfmt FILE ..\n") ()))
   (fmt-each files))
