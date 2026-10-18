; src/apps/kore/expr.l -- expr, POSIX's arithmetic-and-matching language. `:` rides re.l's
; BRE engine, so this loads after re.l. grammar, loosest first:
;   |   &   < <= = == != >= >   + -   * / %   :   then ( E ) length substr index match, + TOKEN
; a text that reads as a whole number is a number where one is wanted (`2 < 10a` is 0).
; exit 0 the answer is neither "" nor "0", 1 it is, 2 malformed or bad arithmetic.
(module 'kore
(:
   ; the operators by level, loosest first; the walk below indexes this list by depth
   ex-ops '(("|") ("&") ("<" "<=" "=" "==" "!=" ">=" ">") ("+" "-") ("*" "/" "%") (":"))
   (ex-die m) (udie 2 ("expr: " + m))
   ; a whole-number text -> (1 n) | () is test's t-int: a leading - belongs to the number and
   ; nothing else does. expr has no unary minus, so "-3" is a numeral and "- 3" is a syntax error
   (ex-true? v) (!(v = "") && !(v = "0"))
   (ex-bool b) (b ? "1" "0")
   ; division truncates toward zero, the remainder wears the dividend's sign (C's rule and
   ; expr's), computed on magnitudes with the sign put back
   (ex-arith op a b)
    (: x (t-int a) y (t-int b)
       _ (two? x && two? y ? () (ex-die "non-integer argument"))
       p <>x q <>y
       _ ((op = "/" || op = "%") && q = 0 ? (ex-die "division by zero"))
       tq (? (op = "+") 0 (op = "-") 0 (op = "*") 0
             (abs p // abs q @ m ((p < 0) = (q < 0) ? m (0 - m))))
       (show (? (op = "+") (p + q) (op = "-") (p - q) (op = "*") (p * q)
                (op = "/") tq (p - tq * q))))
   (ex-cmp op a b)
    (: x (t-int a) y (t-int b)
       both (two? x && two? y)
       lt (both ? (<>x < <>y) (a < b))
       eq (both ? (<>x = <>y) (a = b))
       (ex-bool (? (op = "<") lt
                   (op = "<=") (lt || eq)
                   (op = "=" || op = "==") eq
                   (op = "!=") !eq
                   (op = ">=") !lt
                   (!lt && !eq))))
   ; S : re -- the BRE anchored at the head: group 1's text with \( \), else the match's
   ; length. the leftmost match, so the anchor is a check on its start
   (ex-match a b)
    (: r (rebre b)
       _ (two? r ? () (ex-die ("invalid regular expression: " + b)))
       nds <>r ng <>>r
       m (refind nds a 0 @ h (two? h && <>h = 0 ? h))
       (ng ? (two? m ? (assoc 1 (m 3) @ e
                          (two? e ? (snip a <>e <>>e) ""))
              "")
          (two? m ? (show (<>>m - <>m)) "0")))
   ; index S chars: the 1-based seat of the first charm of S that chars also holds, or 0
   (ex-index s cs)
    (: n #s m #cs
       (has c) (: (hit j) (? (m <= j) 0 (cs j = c) 1 (hit (j + 1)))
                  (hit 0))
       (go i) (? (n <= i) "0" (has (s i)) (show (i + 1)) (go (i + 1)))
       (go 0))
   ; substr S pos len: 1-based, and every way of falling outside answers the empty text
   (ex-substr s ps ls)
    (: n #s
       x (t-int ps) y (t-int ls)
       p (two? x ? <>x 0) l (two? y ? <>y 0)
       st (p - 1)
       en (st + l)
       (? ((atom? x || atom? y) || (l < 1 || st < 0)) ""
          (n <= st) ""
          (snip s st (n < en ? n en))))
   (ex-app op a b)
    (? (op = "|") (ex-true? a ? a (ex-true? b ? b "0"))
       (op = "&") (ex-true? a && ex-true? b ? a "0")
       (op = ":") (ex-match a b)
       (elem op '("+" "-" "*" "/" "%")) (ex-arith op a b)
       (ex-cmp op a b))
   ; the whole descent is one function taking its depth, so a primary can call back into the
   ; loosest level: a body sees its own name, and nothing after it
   (ex-parse lv ts)
    (: (prim m)
        (atom? m ? (ex-die "syntax error: missing operand")
         (<m @ w
            (? (w = "(")
               (: r (ex-parse 0 >m)
                  t2 <>r
                  (two? t2 && <t2 = ")" ? () (ex-die "syntax error: expecting )"),
                   [<r >t2]))
               (w = "+") (two? >m ? [<>m >>m]
                          (ex-die "syntax error: missing argument after '+'"))
               (w = "length") (two? >m ? [(show #<>m) >>m]
                               (ex-die "syntax error: missing argument after 'length'"))
               (w = "index") (two? >>m ? [(ex-index <>m <>>m) >>>m]
                              (ex-die "syntax error: missing argument after 'index'"))
               (w = "match") (two? >>m ? [(ex-match <>m <>>m) >>>m]
                              (ex-die "syntax error: missing argument after 'match'"))
               (w = "substr") (two? >>>m ? [(ex-substr <>m <>>m <>>>m) >>>>m]
                               (ex-die "syntax error: missing argument after 'substr'"))
               [w >m])))
       (5 < lv ? (prim ts)
        (: ops (ex-ops lv)
           r (ex-parse (lv + 1) ts)
           (go v m) (two? m && elem <m ops ?
                       (ex-parse (lv + 1) >m @ r2
                          (go (ex-app <m v <r2) <>r2))
                       [v m])
           (go <r <>r))))
   (expr-main as)
    (atom? as ? (ex-die "syntax error: missing operand")
     (: r (ex-parse 0 as)
        rest <>r
        _ (two? rest ? (ex-die ("syntax error: unexpected argument '" + <rest + "'")))
        v <r
        (say out v, put out 10, flush out,
         ex-true? v ? 0 1))))
) ; module 'kore
