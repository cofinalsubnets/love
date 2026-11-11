; src/apps/libra/lint.l -- the .l balance scan under `libra` and vi's :lint. delimiters
; and strings, not a parse, so a crossed ([)] is caught and a torn file still reports;
; `'` is a reader operator, never a delimiter.
;
; (lint-scan src) answers warnings, each [line col text 'balance] 1-based; an unclosed
; opener or string reports where it opened.
;
(module (lint lint-scan)
(: (lclose c) (c @ 40 41 91 93 125)          ; ( -> )   [ -> ]   { -> }
   (lopen c)  (c @ 41 40 93 91 123)          ; ...and back, for the report

   ; --- raw texts -------------------------------------------------------------
   ; three or more quotes open one and as many close it; an opener ending its line closes on
   ; a line of only spaces and quotes. (lraw src n i) is the index past the closer, () when
   ; it never closes. a longer one-line closing run keeps its extra quotes as text
   (lraw? src n i) (i + 2 < n && src (i + 1) = 34 && src (i + 2) = 34)
   (lraw src n i)
    (: (qs k) (k < n && src k = 34 ? (qs (k + 1)) k)
       (hws k) (k < n && (src k = 32 || src k = 9) ? (hws (k + 1)) k)
       (nl k) (? (n <= k) n (src k = 10) (k + 1) (nl (k + 1)))
       e (qs i)
       q (e - i)
       s (hws e)
       (one k) (? (n <= k) () (src k != 34) (one (k + 1)) (qs k @ r (r - k < q ? (one r) r)))
       (many k) (? (n <= k) () (hws k @ t (qs t - t < q ? (many (nl t)) (t + q))))
       (? (s < n && src s = 10) (many (nl s))
          (s + 1 < n && src s = 13 && src (s + 1) = 10) (many (nl s))
          (one e)))
   ; a hole's frame: it closes back into its text, and its parens are the hole's own
   (lholef stk line col sl sc) ({'cl 41 'ln line 'co col 'hole 1 'sl sl 'sc sc} . stk)
   ; [line col] at j, from [line col] at i
   (lpos src i j line col)
    (i < j ? (lpos src (i + 1) j (src i @ 10 (line + 1) line) (src i @ 10 1 (col + 1)))
     [line col])

   ; --- the scan -------------------------------------------------------------
   ; stk the frames above, so ([)] is caught; sl/sc a string's opening spot; st is
   ; code | cmt | str
   (lint-scan src)
    (: n #src
       (w i st stk line col sl sc warns)
        (n <= i ?
            (: w1 (st @ 'str ([sl sc "unclosed string" 'balance] . warns) warns)
               (rev (foldl (a \ o \ (o @ {'cl cl 'ln ln 'co co}
                              ([ln co "unclosed \(string (lopen cl))" 'balance] . a)))
                     w1 stk)))
           (src i @ c
              (? (st = 'str)                                    ; inside "..."
                  (c @ 92 (i + 1 < n && src (i + 1) = 40 ?                   ; \( opens a hole
                           (w (i + 2) 'code (lholef stk line col sl sc) line (col + 2) sl sc warns)
                           (w (i + 2) 'str stk line (col + 2) sl sc warns))   ; \ escape: skip next
                       34 (w (i + 1) 'code stk line (col + 1) sl sc warns)
                       10 (w (i + 1) 'str stk (line + 1) 1 sl sc warns)
                          (w (i + 1) 'str stk line (col + 1) sl sc warns))
                 (st = 'cmt)                                    ; ; comment to eol
                  (c @ 10 (w (i + 1) 'code stk (line + 1) 1 sl sc warns)
                          (w (i + 1) 'cmt stk line (col + 1) sl sc warns))
                 (c = 59) (w (i + 1) 'cmt stk line (col + 1) sl sc warns)
                 (c = 35 && i + 1 < n && src (i + 1) = 33)                     ; #! shebang, to eol
                  (w (i + 2) 'cmt stk line (col + 2) sl sc warns)
                 (c = 34 && lraw? src n i)                                     ; """ -- a raw text, whole
                  (lraw src n i @ j
                     (j ? (lpos src i j line col @ lc (w j 'code stk <lc <>lc sl sc warns))
                        (w n 'str stk line col line col warns)))
                 (c = 34) (w (i + 1) 'str stk line (col + 1) line col warns)
                 (c = 10) (w (i + 1) 'code stk (line + 1) 1 sl sc warns)
                 (c = 40 || c = 91 || c = 123)                                 ; ( [ {  -- push
                  (w (i + 1) 'code ({'cl (lclose c) 'ln line 'co col} . stk) line (col + 1) sl sc warns)
                 ((c = 41 || c = 93 || c = 125) && two? stk && <stk 'hole)    ; a hole's closer: the text runs on
                  (w (i + 1) 'str >stk line (col + 1) (<stk 'sl) (<stk 'sc) warns)
                 (c = 41 || c = 93 || c = 125)                                 ; ) ] }  -- match
                  (? (atom? stk)
                      (w (i + 1) 'code stk line (col + 1) sl sc ([line col "stray \(string c)" 'balance] . warns))
                     !(<stk 'cl = c)
                      (w (i + 1) 'code >stk line (col + 1) sl sc ([line col "mismatched \(string c)" 'balance] . warns))
                     (w (i + 1) 'code >stk line (col + 1) sl sc warns))
                 (w (i + 1) 'code stk line (col + 1) sl sc warns))))
       (w 0 'code () 1 1 1 1 ()))
)) ; module lint
