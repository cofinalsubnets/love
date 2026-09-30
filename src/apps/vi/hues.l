; src/apps/vi/hues.l -- the paint for the languages that are not .l: c, js, awk, css,
; html, sh, make, json, diff, roff, assembly and markdown. each lexer answers what
; hue-lex does, (lx s in keep) -> [runs out], so the painter, the carry fold and %
; take any of them. the file name decides, else a #! naming a shell or an awk;
; `in` is 0 at the top and whatever a line left open.
(module 'vi
(:
   ; class -> vim group for the classes only these lexers emit; comment string
   ; number const are hue.l's own and paint as they do there
   hues-classes
    '((keyword Statement) (type Type) (pre PreProc) (func Function)
      (var Identifier) (attr Type) (ent Special) (added Function) (removed Operator))

   ; --- bytes -----------------------------------------------------------------
   (hues-dig? c) (48 <= c <= 57)
   (hues-alf? c) ((97 <= c <= 122) || (65 <= c <= 90) || (c = 95))
   (hues-idc? c) (hues-alf? c || hues-dig? c)
   (hues-bl? c)  ((c = 32) || (c = 9))
   (hues-lowb c) (? (65 <= c <= 90) (c + 32) c)
   (hues-run s i ok?) (? ((i < #s) && ok? (s i)) (hues-run s (i + 1) ok?) i)
   (hues-skip s i)  (hues-run s i hues-bl?)
   (hues-idend s i) (hues-run s i hues-idc?)
   (hues-cssend s i) (hues-run s i (c \ hues-idc? c || c = 45))
   (hues-nmend s i) (hues-run s i (c \ hues-idc? c || hue-has? "-:." c))
   (hues-mkw s i)   (hues-run s i (c \ hues-alf? c || c = 45))
   (hues-wend s i)  (hues-run s i (c \ 32 < c && !(hue-has? ";|&()<>`'\"$\\" c)))
   (hues-find s i t) (: n #s (go j) (? (n <= j) n (hue-at? s j t) j (go (j + 1))) (go i))
   (hues-ati? s i t)                                   ; t in lower case
    (: n #s m #t
       (go k) (? (m <= k) 1 (n <= (i + k)) () (hues-lowb (s (i + k)) = t k) (go (k + 1)) ())
       (go 0))
   (hues-findi s i t) (: n #s (go j) (? (n <= j) n (hues-ati? s j t) j (go (j + 1))) (go i))
   ; i is past the opening quote: past the close, or () when the line ends open
   (hues-qend s i q esc)
    (: n #s (go j) (? (n <= j) ()
                      (: c (s j) (? (esc && (c = esc)) (go (j + 2)) (c = q) (j + 1) (go (j + 1)))))
       (go i))
   ; s j opens ( or {: past its mate, or the line's end
   (hues-close s j)
    (: n #s o (s j) k (? (o = 40) 41 125)
       (go i d) (? (n <= i) n (s i = o) (go (i + 1) (d + 1))
                   (s i = k) (? (d < 2) (i + 1) (go (i + 1) (d - 1))) (go (i + 1) d))
       (go j 0))
   ; 12 0x1f 1.5e-3 10UL 2px: the first byte is taken, the rest is the token
   (hues-numend s i)
    (: n #s hex (hue-at? s i "0x" || hue-at? s i "0X")
       (go j) (? (n <= j) j
                 (: c (s j)
                    (? (hues-idc? c || c = 46) (go (j + 1))
                       ((c = 43 || c = 45) && !hex && hue-has? "eEpP" (s (j - 1))) (go (j + 1))
                       j)))
       (go (i + 1)))
   (hues-kws rows) (foldl (\ b r (foldl (\ b2 w (pin b2 w <r)) b (words <>r))) (tablet ()) rows)

   ; --- c, js and awk: one lexer, a spec apiece -----------------------------
   ; the spec: 'kw words, 'q quotes, 'ln the line comment, 'bc /* */, 'cpp #lines,
   ; 'fld awk's $fields, 'rx /regex/ where an operand is due. carry: 1 inside /* */,
   ; 2 inside a js `template`
   hues-c
    {'kw (hues-kws
          '((keyword "if else for while do switch case default break continue return goto sizeof _Alignof alignof _Generic asm __asm__ __attribute__ typeof __typeof__ _Static_assert static_assert")
            (type "void char short int long float double signed unsigned _Bool bool _Complex size_t ssize_t ptrdiff_t intptr_t uintptr_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t FILE va_list struct union enum typedef static extern register inline restrict volatile const auto _Atomic _Thread_local thread_local _Noreturn _Alignas alignas constexpr")
            (const "NULL true false EOF stdin stdout stderr __FILE__ __LINE__ __func__ nullptr")))
     'q "\"'" 'ln "//" 'bc 1 'cpp 1}
   hues-jsp
    {'kw (hues-kws
          '((keyword "break case catch continue debugger default delete do else export extends finally for function if import in instanceof new return super switch this throw try typeof var void while with yield let const class async await of from static get set")
            (const "true false null undefined NaN Infinity")))
     'q "\"'`" 'ln "//" 'bc 1 'rx 1}
   hues-awkp
    {'kw (hues-kws
          '((keyword "BEGIN END BEGINFILE ENDFILE function func if else while for do break continue next nextfile exit return delete getline in print printf")
            (func "length substr index split sub gsub gensub match sprintf sin cos atan2 exp log sqrt int rand srand tolower toupper system close fflush")
            (var "NR NF FS OFS RS ORS FNR FILENAME SUBSEP RSTART RLENGTH ENVIRON ARGC ARGV CONVFMT OFMT")))
     'q "\"" 'ln "#" 'fld 1 'rx 1}
   ; a / at i opens a regex when no operand stands before it
   (hues-rx? s i)
    (: p (: (go j) (? (j < 0) j (hues-bl? (s j)) (go (j - 1)) j) (go (i - 1)))
       ((p < 0) || hue-has? "(,=~!&|{};:?[" (s p)))

   (hues-cl sp s in keep)
    (: n #s kw (sp 'kw) qs (sp 'q) ln (sp 'ln)
       (emit acc k a b) (? (keep && (a < b)) ([k a b] . acc) acc)
       lead (hues-skip s 0)
       (cm i a acc)
        (: j (hues-find s i "*/")
           (? (n <= j) [(rev (emit acc 'comment a n)) 1] (w (j + 2) (emit acc 'comment a (j + 2)))))
       (tq i a acc)
        (: j (hues-qend s i 96 92)
           (? j (w j (emit acc 'string a j)) [(rev (emit acc 'string a n)) 2]))
       (pre i acc)                                     ; #directive, and an <include>
        (: j (hues-skip s (i + 1)) e (hues-idend s j) acc2 (emit acc 'pre i e) k (hues-skip s e)
           (? (snip s j e = "include" && k < n && s k = 60)
               (: m (hues-find s k ">") f (? (m < n) (m + 1) n) (w f (emit acc2 'string k f)))
              (w e acc2)))
       (w i acc)
        (? (n <= i) [(rev acc) 0]
           (: c (s i) d (? ((i + 1) < n) (s (i + 1)) 0)
              (? (hues-bl? c) (w (i + 1) acc)
                 (sp 'bc && hue-at? s i "/*") (cm (i + 2) i acc)
                 (ln && hue-at? s i ln) [(rev (emit acc 'comment i n)) 0]
                 ((c = 36) && sp 'fld)
                  (: j (? (hues-dig? d) (hues-run s (i + 1) hues-dig?) (hues-idend s (i + 1)))
                     (w j (emit acc 'var i j)))
                 ((c = 47) && sp 'rx && hues-rx? s i)
                  (: j (hues-qend s (i + 1) 47 92) e (? j j n) (w e (emit acc 'string i e)))
                 (c = 35 && sp 'cpp && i = lead) (pre i acc)
                 (c = 96 && hue-has? qs c) (tq (i + 1) i acc)
                 (hue-has? qs c) (: j (hues-qend s (i + 1) c 92) e (? j j n) (w e (emit acc 'string i e)))
                 (hues-dig? c || c = 46 && hues-dig? d) (: j (hues-numend s i) (w j (emit acc 'number i j)))
                 (hues-alf? c) (: j (hues-idend s i) k (kw (snip s i j)) (w j (nom? k ? (emit acc k i j) acc)))
                 (w (i + 1) acc))))
       (in @ 1 (cm 0 0 ()) 2 (tq 0 0 ()) (w 0 ())))
   (hues-js s in keep) (hues-cl hues-jsp s in keep)
   (hues-awk s in keep) (hues-cl hues-awkp s in keep)

   ; --- css -------------------------------------------------------------------
   ; the mode m: 0 a rule's start, 1 a selector, 2 a value. a declaration opens on
   ; `name:` in a segment no { ends. carry: 0 or 2 by mode, plus 1 inside /* */
   (hues-css s in keep)
    (: n #s
       (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
       (cm i a acc m)
        (hues-find s i "*/" @ j
         (n <= j ? [(rev (emit acc 'comment a n)) (m + 1)] (w (j + 2) (emit acc 'comment a (j + 2)) m)))
       (segend i) (n <= i || hue-has? "{;}" (s i) ? i (segend (i + 1)))
       (start i acc)
        (: j (hues-cssend s i) k (hues-skip s j) e (segend i)
           (i < j && k < n && s k = 58 && !(e < n && s e = 123) ?
            (w j (emit acc (hue-at? s i "--" ? 'var 'type) i j) 2)
            (w i acc 1)))
       (sel i c acc)
        (? (c = 46 || c = 35) (hues-cssend s (i + 1) @ j (w j (emit acc 'func i j) 1))
           (c = 58) (hues-cssend s (? (hue-at? s i "::") (i + 2) (i + 1)) @ j (w j (emit acc 'ent i j) 1))
           (hues-alf? c) (hues-cssend s i @ j (w j (emit acc 'keyword i j) 1))
           (w (i + 1) acc 1))
       (val i c acc)
        (: d (? ((i + 1) < n) (s (i + 1)) 0)
           (? (c = 35) (: j (hues-cssend s (i + 1)) (w j (emit acc 'number i j) 2))
              (hues-dig? c || (c = 46 || c = 45) && hues-dig? d)
               (: j (hues-numend s i) e (j < n && s j = 37 ? (j + 1) j) (w e (emit acc 'number i e) 2))
              (c = 33) (hues-cssend s (i + 1) @ j (w j (emit acc 'keyword i j) 2))
              (hue-at? s i "--") (hues-cssend s i @ j (w j (emit acc 'var i j) 2))
              (hues-alf? c) (hues-cssend s i @ j (w j (j < n && s j = 40 ? (emit acc 'func i j) acc) 2))
              (w (i + 1) acc 2)))
       (w i acc m)
        (? (n <= i) [(rev acc) (m @ 2 2 0)]
           (: c (s i)
              (? (hues-bl? c) (w (i + 1) acc m)
                 (hue-at? s i "/*") (cm (i + 2) i acc (m @ 2 2 0))
                 (c = 34 || c = 39)
                  (: j (hues-qend s (i + 1) c 92) e (? j j n) (w e (emit acc 'string i e) m))
                 (hue-has? "{;}" c) (w (i + 1) acc 0)
                 (m = 0) (start i acc)
                 (c = 64) (hues-cssend s (i + 1) @ j (w j (emit acc 'pre i j) m))
                 (m = 1) (sel i c acc)
                 (val i c acc))))
       (in @ 1 (cm 0 0 () 0) 2 (w 0 () 2) 3 (cm 0 0 () 2) (w 0 () 0)))

   ; --- html ------------------------------------------------------------------
   ; carry: 0 text, 1 inside <!-- -->, ['tag name closing?] inside a tag, and
   ; [css in] or [js in] inside a style or script body, the inner lexer's own
   (hues-ent s i)                                      ; i past the &: past the ;, or ()
    (hues-run s i (c \ hues-idc? c || c = 35) @ j (i < j && j < #s && s j = 59 ? (j + 1)))
   (hues-html s in keep)
    (: n #s
       (emit acc k a b) (? (keep && (a < b)) ([k a b] . acc) acc)
       (txt i acc)
        (? (n <= i) [(rev acc) 0]
           (: c (s i) d (i + 1 < n ? (s (i + 1)) 0)
              (? (hue-at? s i "<!--") (hcm (i + 4) i acc)
                 (c = 60 && (d = 33 || d = 63))       ; <!doctype, <?xml
                  (: j (hues-find s i ">") e (? (j < n) (j + 1) n) (txt e (emit acc 'pre i e)))
                 (c = 60 && (hues-alf? d || (d = 47)))
                  (: a (d @ 47 (i + 2) (i + 1)) e (hues-nmend s a)
                     (tag e (lower (snip s a e)) (d = 47) (emit acc 'keyword i e)))
                 (c = 38) (hues-ent s (i + 1) @ e (? e (txt e (emit acc 'ent i e)) (txt (i + 1) acc)))
                 (txt (i + 1) acc))))
       (hcm i a acc)
        (hues-find s i "-->" @ j
         (n <= j ? [(rev (emit acc 'comment a n)) 1] (txt (j + 3) (emit acc 'comment a (j + 3)))))
       (tag i nm cl acc)
        (? (n <= i) [(rev acc) ['tag nm cl]]
           (: c (s i)
              (? (hues-bl? c) (tag (i + 1) nm cl acc)
                 (c = 62) (: acc2 (emit acc 'keyword i (i + 1))
                             (? cl (txt (i + 1) acc2)
                                (nm = "style") (emb 'css (i + 1) 0 acc2)
                                (nm = "script") (emb 'js (i + 1) 0 acc2)
                                (txt (i + 1) acc2)))
                 (hue-at? s i "/>") (txt (i + 2) (emit acc 'keyword i (i + 2)))
                 ((c = 34) || (c = 39))
                  (: j (hues-qend s (i + 1) c ()) e (? j j n) (tag e nm cl (emit acc 'string i e)))
                 (hues-alf? c) (hues-nmend s i @ e (tag e nm cl (emit acc 'attr i e)))
                 (tag (i + 1) nm cl acc))))
       ; a style or script body: its own lexer up to the closing tag, runs shifted home
       (emb k i st acc)
        (: j (hues-findi s i (? (k = 'css) "</style" "</script"))
           r ((k @ 'css hues-css hues-js) (snip s i j) st keep)
           acc2 (foldl (\ a q ([<q (<>q + i) (<>>q + i)] . a)) acc <r)
           (n <= j ? [(rev acc2) [k <>r]] (txt j acc2)))
       (? (in = 0) (txt 0 ()) (in = 1) (hcm 0 0 ())
          (<in = 'tag) (tag 0 (in 1) (in 2) ())
          (emb <in 0 <>in ())))

   ; --- sh --------------------------------------------------------------------
   ; carry: 1 inside '...', 2 inside "...", or a heredoc's terminator, a text.
   ; mk is make's recipe line, where $(..) is make's and runs to its mate
   hues-shkw
    (hues-kws
     '((keyword "if then else elif fi for while until do done case esac in function select time return break continue exit local export readonly shift set unset eval exec trap source . [[ ]] !")
       (func "echo printf cd read pwd alias unalias umask wait kill getopts command type hash test [ ] ulimit jobs fg bg")
       (const "true false")))
   (hues-untab s) (snip s (hues-run s 0 (= 9)) #s)
   (hues-sh s in keep) (hues-shx () s in keep)
   (hues-shx mk s in keep)
    (: n #s
       (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
       (brk? c) (hue-has? " \t;|&()<>`" c)
       (wstart? i) (i < 1 || brk? (s (i - 1)))
       (out hd) (string? hd ? hd 0)
       (dol i)                                         ; s i is $: past the parameter, or i
        (: j (i + 1) c (j < n ? (s j) 0)
           (? (c = 123) (hues-close s j)
              (c = 40) (? mk (hues-close s j) (j + 1))
              (hues-alf? c) (hues-idend s j)
              (mk && c = 36 && j + 1 < n && hues-alf? (s (j + 1))) (hues-idend s (j + 1))  ; $$x, the shell's
              (hue-has? (? mk "0123456789?@#$!*-<^+%|" "0123456789?@#$!*-") c) (j + 1)
              i))
       (sq i a acc hd)
        (: j (hues-find s i "'")
           (? (n <= j) [(rev (emit acc 'string a n)) 1] (w (j + 1) (emit acc 'string a (j + 1)) hd)))
       (dq i a acc hd)                                 ; the string in pieces around its parameters
        (n <= i ? [(rev (emit acc 'string a n)) 2] (s i @
         92 (dq (i + 2) a acc hd)
         34 (w (i + 1) (emit acc 'string a (i + 1)) hd)
         36 (dol i @ e (i < e ? (dq e e (emit (emit acc 'string a i) 'var i e) hd)
                                (dq (i + 1) a acc hd)))
         (dq (i + 1) a acc hd)))
       (here i acc hd)                                 ; <<[-]['"]word
        (: d (? (hue-at? s i "<<-") 3 2)
           j (hues-skip s (i + d))
           q (j < n && hue-has? "'\"\\" (s j) ? 1 0)
           e (hues-wend s (j + q))
           f (0 < q && e < n && hue-has? "'\"" (s e) ? (e + 1) e)
           (j + q < e ? (w f (emit acc 'pre i f) (snip s (j + q) e)) (w (i + d) acc hd)))
       (w i acc hd)
        (? (n <= i) [(rev acc) (out hd)]
           (: c (s i)
              (? (hues-bl? c) (w (i + 1) acc hd)
                 (c = 35 && wstart? i) [(rev (emit acc 'comment i n)) (out hd)]
                 (c = 92) (w (i + 2) acc hd)
                 (c = 39) (sq (i + 1) i acc hd)
                 (c = 34) (dq (i + 1) i acc hd)
                 (c = 36) (: e (dol i) (? (i < e) (w e (emit acc 'var i e) hd) (w (i + 1) acc hd)))
                 (hue-at? s i "<<" && !(hue-at? s i "<<<")) (here i acc hd)
                 (brk? c) (w (i + 1) acc hd)
                 (: e (hues-wend s i) t (snip s i e) a (hues-idend s i)
                    (? (i < a && a < n && s a = 61 && !(hues-dig? c) && wstart? i)
                        (w a (emit acc 'var i a) hd)
                       (wstart? i && ((n <= e) || brk? (s e)))
                        (: k (hues-shkw t)
                           (w e (? (nom? k) (emit acc k i e) (hue-num? t) (emit acc 'number i e) acc) hd))
                       (w e acc hd))))))
       (? (string? in) (? (hues-untab s = in) [(rev (emit () 'pre 0 n)) 0] [(rev (emit () 'string 0 n)) in])
          (in = 1) (sq 0 0 () ())
          (in = 2) (dq 0 0 () ())
          (w 0 () ())))

   ; --- make ------------------------------------------------------------------
   ; a tab-led line is a recipe and reads as sh. otherwise the head decides: a
   ; directive, a NAME = of any flavour, or the targets before a rule's colon
   hues-mkdirs (words "include -include sinclude ifeq ifneq ifdef ifndef else endif define endef export unexport override undefine vpath private")
   (hues-mkref s i) (: j (i + 1) (? (#s <= j) j (hue-has? "({" (s j)) (hues-close s j) (j + 1)))
   (hues-assign s i)                                   ; the name's end, or ()
    (: j (hues-run s i (\ c !(hue-has? " \t:=?+!#" c))) k (hues-skip s j)
       (? ((i < j) && any (hue-at? s k) '("=" ":=" "::=" "?=" "+=" "!=")) j ()))
   (hues-colon s i)                                    ; a rule's colon, or ()
    (: n #s
       (go j) (? (n <= j) ()
                 (: c (s j)
                    (? (c = 36) (go (hues-mkref s j))
                       (c = 35 || c = 61) ()
                       (c = 58) j
                       (go (j + 1)))))
       (go i))
   (hues-mk s in keep)
    (? ((0 < #s) && (s 0 = 9)) [<(hues-shx 1 s 0 keep) 0]
       (: n #s
          (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
          (rest i acc)
           (n <= i ? [(rev acc) 0] (s i @
            92 (rest (i + 2) acc)
            35 [(rev (emit acc 'comment i n)) 0]
            36 (hues-mkref s i @ j (rest j (emit acc 'var i j)))
            (rest (i + 1) acc)))
          lead (hues-skip s 0)
          e (hues-mkw s lead)
          a (hues-assign s lead)
          t (hues-colon s lead)
          (? (elem (snip s lead e) hues-mkdirs) (rest e (emit () 'pre lead e))
             a (rest a (emit () 'var lead a))
             t (rest t (emit () 'func lead t))
             (rest lead ()))))

   ; --- json ------------------------------------------------------------------
   ; a string before a : is a key. jsonc's // comments too; nothing spans lines
   (hues-json s in keep)
    (:- (w 0 ()) n #s
     (emit acc k a b) (? (keep && (a < b)) ([k a b] . acc) acc)
     (w i acc)
      (? (n <= i) [(rev acc) 0]
         (: c (s i)
            (? (hues-bl? c) (w (i + 1) acc)
               (hue-at? s i "//") [(rev (emit acc 'comment i n)) 0]
               (c = 34) (: j (hues-qend s (i + 1) 34 92) e (? j j n) k (hues-skip s e)
                           (w e (emit acc (k < n && s k = 58 ? 'type 'string) i e)))
               (c = 45 || hues-dig? c) (hues-numend s i @ j (w j (emit acc 'number i j)))
               (hues-alf? c) (: j (hues-idend s i)
                                (w j (? (elem (snip s i j) '("true" "false" "null")) (emit acc 'const i j) acc)))
               (w (i + 1) acc)))))

   ; --- diff ------------------------------------------------------------------
   ; unified and normal: a line is one class, told by how it starts
   hues-dhead '("+++" "---" "diff " "index " "new file" "deleted file" "old mode" "new mode"
                "similarity" "rename " "Only in " "Binary files")
   (hues-diff s in keep)
    (: n #s
       k (? (n < 1) ()
            (any (hue-at? s 0) hues-dhead) 'type
            (hue-at? s 0 "@@") ()
            (hue-has? "+>" (s 0)) 'added
            (hue-has? "-<" (s 0)) 'removed
            (s 0 = 92) 'comment)
       e (? (hue-at? s 0 "@@") (hues-find s 2 "@@" @ j (j < n ? (j + 2) n)) 0)
       [(? !keep () (0 < e) [['ent 0 e]] (nom? k) [[k 0 n]] ()) 0])

   ; --- roff ------------------------------------------------------------------
   ; a request line's name, its "arguments", escapes anywhere, and \" to the end
   (hues-resc s i)                                     ; s i is \: past the escape
    (: n #s c (i + 1 < n ? (s (i + 1)) 0) d (i + 2) a (d < n ? (s d) 0)
       e (? (c = 40) (i + 4)
            (c = 91) (: k (hues-find s d "]") (k < n ? (k + 1) n))
            (hue-has? "fFsnk*$gmM" c)
             (? (a = 40) (d + 3)
                (a = 91) (hues-find s d "]" @ k (k < n ? (k + 1) n))
                (c = 115 && hue-has? "+-" a) (d + 2)
                (d + 1))
            d)
       (? (n < e) n e))
   (hues-roff s in keep)
    (: n #s
       (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
       (w i acc q)
        (n <= i ? [(rev acc) 0]
           (: c (s i)
              (? (hue-at? s i "\\\"" || hue-at? s i "\\#") [(rev (emit acc 'comment i n)) 0]
                 (c = 92) (: e (hues-resc s i) (w e (emit acc 'ent i e) q))
                 (q && c = 34) (: k (hues-find s (i + 1) "\"") e (? (k < n) (k + 1) n)
                                (w e (emit acc 'string i e) q))
                 (w (i + 1) acc q))))
       (? (0 < n && hue-has? ".'" (s 0))
           (: j (hues-skip s 1) e (hues-run s j (c \ 32 < c && c != 92))
              (? (hue-at? s j "\\\"") [(rev (emit () 'comment 0 n)) 0]
                 (w e (emit () 'keyword 0 e) 1)))
          (w 0 () ())))

   ; --- assembly --------------------------------------------------------------
   ; gas in any dialect: at&t's %reg and $imm, intel's bare names and sizes, a64,
   ; rv64 and arm. a statement's head is a label, a .directive or the mnemonic;
   ; # comments unless an arm immediate follows, @ where arm32 has it. carry: 1
   ; inside /* */
   hues-regs
    (hues-kws '((var "rax rbx rcx rdx rsi rdi rbp rsp rip eax ebx ecx edx esi edi ebp esp eip ax bx cx dx si di bp al bl cl dl ah bh ch dh sil dil bpl spl cs ds es fs gs ss sp lr pc fp xzr wzr zero ra gp tp")
                (type "byte word dword qword tbyte oword xmmword ymmword zmmword ptr offset")))
   hues-cppw (words "include define undef if ifdef ifndef elif else endif error pragma line")
   hues-lockw '("lock" "rep" "repe" "repne" "repz" "repnz")
   ; a register by shape: a letter prefix then digits, and r8d r8w r8b
   (hues-reg? t)
    (: n #t
       (tail k) (: j (hues-run t k hues-dig?)
                   ((k < j) && ((j = n) || (((j + 1) = n) && (t 0 = 114) && hue-has? "dwb" (t j)))))
       (? (n < 2) ()
          (any (\ p (hue-at? t 0 p && tail #p)) '("xmm" "ymm" "zmm" "cr" "dr" "st")) 1
          (hue-has? "rxwvqdsbhatfk" (t 0)) (tail 1)
          ()))
   (hues-asm s in keep)
    (: n #s
       (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
       lead (hues-skip s 0)
       (cm i a acc hd)
        (: j (hues-find s i "*/")
           (n <= j ? [(rev (emit acc 'comment a n)) 1] (w (j + 2) (emit acc 'comment a (j + 2)) hd)))
       (rest i acc) [(rev (emit acc 'comment i n)) 0]
       (word i acc hd)
        (: c (s i) j (hues-run s i (b \ hues-idc? b || b = 46 || b = 36))
           lt (lower (snip s i j)) k (hues-skip s j) r (hues-regs lt)
           (? (k < n && s k = 58 && !(hue-at? s k "::")) (w (k + 1) (emit acc 'func i j) 1)
              (c = 46 && hd) (w j (emit acc 'pre i j) 0)
              hd (w j (emit acc 'keyword i j) (elem lt hues-lockw))
              (nom? r) (w j (emit acc r i j) 0)
              (hues-reg? lt) (w j (emit acc 'var i j) 0)
              (w j acc 0)))
       (w i acc hd)
        (? (n <= i) [(rev acc) 0]
           (: c (s i) d (? (i + 1 < n) (s (i + 1)) 0)
              (? (hues-bl? c) (w (i + 1) acc hd)
                 (hue-at? s i "/*") (cm (i + 2) i acc hd)
                 (hue-at? s i "//") (rest i acc)
                 (c = 35 && i = lead && hues-alf? d &&
                  elem (snip s (i + 1) (hues-idend s (i + 1))) hues-cppw)
                  (: j (hues-idend s (i + 1)) (w j (emit acc 'pre i j) 0))
                 (c = 35 && (hues-dig? d || (d = 45))) (hues-numend s (i + 1) @ j (w j (emit acc 'number i j) 0))
                 (c = 35) (rest i acc)
                 ((c = 64) && ((i = lead) || hues-bl? (s (i - 1))) && !(hues-alf? d)) (rest i acc)
                 (c = 59) (w (i + 1) acc 1)
                 (c = 34) (: j (hues-qend s (i + 1) 34 92) e (? j j n) (w e (emit acc 'string i e) 0))
                 (c = 39) (: e (? (i + 2 < n && s (i + 2) = 39) (i + 3) (i + 2 < n) (i + 2) n)
                             (w e (emit acc 'string i e) 0))
                 (c = 37) (: j (hues-idend s (i + 1)) (w j (emit acc 'var i j) 0))
                 (c = 36) (: j (? (hues-dig? d || d = 45) (hues-numend s (i + 1)) (hues-idend s (i + 1)))
                             (w j (emit acc 'number i j) 0))
                 (hues-dig? c || c = 45 && hues-dig? d)
                  (: j (hues-numend s i) k (hues-skip s j)
                     (? (hd && (k < n) && (s k = 58)) (w (k + 1) (emit acc 'func i j) 1)   ; 1: a local label
                        (w j (emit acc 'number i j) 0)))
                 (hues-alf? c || c = 46) (word i acc hd)
                 (w (i + 1) acc 0))))
       (? (in = 1) (cm 0 0 () 1) (w 0 () 1)))

   ; --- which lexer -----------------------------------------------------------
   (hues-pairs t rows) (foldl (\ b r (pin b <r <>r)) t rows)
   hues-exts
    (hues-pairs (tablet ())
     '(("l" l) ("c" c) ("h" c) ("html" html) ("htm" html) ("css" css) ("js" js) ("mjs" js) ("cjs" js)
       ("sh" sh) ("bash" sh) ("mk" make) ("mak" make) ("md" md) ("markdown" md) ("json" json)
       ("s" asm) ("S" asm) ("asm" asm) ("diff" diff) ("patch" diff) ("awk" awk)
       ("man" roff) ("roff" roff) ("1" roff) ("2" roff) ("3" roff) ("4" roff) ("5" roff)
       ("6" roff) ("7" roff) ("8" roff) ("9" roff)))
   ; a fence's info word: an extension, or a name for one
   hues-fences
    (hues-pairs (hues-pairs (tablet ()) (map (\ k [k (hues-exts k)]) (keys hues-exts)))
     '(("love" l) ("shell" sh) ("lush" sh) ("console" sh) ("javascript" js) ("make" make)
       ("makefile" make) ("assembly" asm) ("gas" asm)))
   hues-mknames '("Makefile" "makefile" "GNUmakefile" "Cookfile")

   ; --- markdown --------------------------------------------------------------
   ; the block a line opens, then the inline spans. a fence naming a language this
   ; file knows is lexed as that language. carry: 0, or ['fence char length lang
   ; inner] inside a fence
   (hues-md sub s in keep)
    (: n #s
       (emit acc k a b) (? (keep && (a < b)) ([k a b] . acc) acc)
       lead (hues-skip s 0)
       (fence i) (: c (? (i < n) (s i) 0) j (hues-run s i (\ b (b = c)))
                    (? (((c = 96) || (c = 126)) && (2 < (j - i))) [c (j - i) j] ()))
       ; `code`, <!-- -->, [text](url), <autolink>, *em* and **strong**
       (inl i acc)
        (? (n <= i) [(rev acc) 0]
           (: c (s i) b (? (0 < i) (s (i - 1)) 32)
              (? (c = 92) (inl (i + 2) acc)
                 (c = 96) (: j (hues-run s i (= 96)) m (j - i) k (hues-find s j (snip s i j))
                             (? (k < n) (inl (k + m) (emit acc 'string i (k + m))) (inl j acc)))
                 (hue-at? s i "<!--") (: k (hues-find s i "-->") e (? (k < n) (k + 3) n) (inl e (emit acc 'comment i e)))
                 (c = 91) (: k (hues-find s i "]")
                             (k + 1 < n && s (k + 1) = 40 ?
                                 (: u (hues-find s k ")") e (u < n ? (u + 1) n)
                                    (inl e (emit (emit acc 'func i (k + 1)) 'string (k + 1) e)))
                                (inl (i + 1) acc)))
                 (c = 60 && hues-alf? (i + 1 < n ? (s (i + 1)) 0))
                  (: k (hues-find s i ">") t (snip s i k)
                     (? ((k < n) && ((hues-find t 0 ":" < #t) || (hues-find t 0 "@" < #t)))
                         (inl (k + 1) (emit acc 'string i (k + 1)))
                        (inl (i + 1) acc)))
                 ((c = 42 || c = 95 && !(hues-idc? b)) && i + 1 < n)
                  (: j (hues-run s i (= c)) m (j - i) k (hues-find s j (snip s i j))
                     (? (j < n && !(hues-bl? (s j)) && k < n && m < 3)
                         (inl (k + m) (emit acc (m @ 1 'ent 'const) i (k + m)))
                        (inl j acc)))
                 (inl (i + 1) acc))))
       ; a list marker, - * + or 1. 1) then a blank: its end, or ()
       (item i) (: c (i < n ? (s i) 0) j (hues-run s i hues-dig?)
                   e (? (hue-has? "-*+" c) (i + 1)
                        (i < j && j < n && hue-has? ".)" (s j)) (j + 1))
                   (? (e && ((n <= e) || hues-bl? (s e))) e ()))
       (rule? i) (: c (i < n ? (s i) 0)            ; --- === *** ___, blanks between
                    (hue-has? "-=*_" c && hues-run s i (x \ x = c || hues-bl? x) = n
                     && 2 < #(filter (k \ s k = c) ^n)))
       (open x)
        (: f (fence lead) hs (hues-run s lead (= 35)) it (item lead)
           (? (3 < lead) [(? keep [['string 0 n]] ()) 0]           ; an indented code block
              (two? f)
               (: a (hues-skip s (f 2)) z (hues-run s a (x \ 32 < x && x != 96))
                  g (hues-fences (lower (snip s a z)))
                  [(rev (emit () 'pre 0 n)) ['fence <f <>f g 0]])
              (lead < hs && hs - lead < 7 && (n <= hs || hues-bl? (s hs)))
               [(rev (emit () 'keyword 0 n)) 0]
              (rule? lead) [(rev (emit () 'pre 0 n)) 0]
              (lead < n && s lead = 62) (inl (lead + 1) (emit () 'comment lead (lead + 1)))
              it (inl it (emit () 'pre lead it))
              (inl lead ())))
       (? !(two? in) (open ())
          (: f (fence lead) g (in 3) lx (? (nom? g) (sub g) ())
             (? ((two? f) && (<f = in 1) && (in 2 <= <>f) && (hues-skip s (f 2) = n))
                 [(rev (emit () 'pre 0 n)) 0]
                (lit? lx) (: r (lx s (in 4) keep) [<r ['fence (in 1) (in 2) g <>r]])
                [(rev (emit () 'string 0 n)) in]))))
   ; the markdown lexer keeps the lexers its fences asked for
   (hues-mdlx x)
    (: cache (tablet ())
       (sub g) (: k (cache g) (? (lit? k) k (: l (hues-lexer g) _ (pin cache g l) l)))
       (\ s in keep (hues-md sub s in keep)))

   (hues-base f) (: (go i) (? (i < 1) 0 (f (i - 1) = 47) i (go (i - 1))) (snip f (go #f) #f))
   (hues-ext b) (: (go i) (? (i < 1) "" (b (i - 1) = 46) (snip b i #b) (go (i - 1))) (go #b))
   (hues-bang l)                                       ; a #! line naming a shell or an awk
    (? !((string? l) && hue-at? l 0 "#!") ()
       (: (go ws) (? !(two? ws) ()
                     (: b (hues-base <ws) m #b
                        (? (1 < m && snip b (m - 2) m = "sh") 'sh
                           (2 < m && snip b (m - 3) m = "awk") 'awk
                           (go >ws))))
          (go (words (snip l 2 #l)))))
   ; the language of a file, by its name, else its first line; () for none
   (hues-lang f l0)
    (: b (hues-base f) g (hues-exts (hues-ext b))
       (? (nom? g) g
          (elem b hues-mknames) 'make
          (hues-bang l0)))
   ; the lexer for a language; the .l one folds the book, so a caller keeps it
   (hues-lexer g) (g @
    'l (: bk (hue-book ()) (\ s in keep (hue-lex bk s in keep)))
    'c (\ s in keep (hues-cl hues-c s in keep))
    'js hues-js
    'awk hues-awk
    'css hues-css
    'html hues-html
    'sh hues-sh
    'make hues-mk
    'json hues-json
    'diff hues-diff
    'roff hues-roff
    'asm hues-asm
    'md (hues-mdlx ()))

   ; --- the pens: hue.l's, and one per class above ------------------------------
   (hues-pens rows deep)
    (foldl (\ b c (: r (filter (r \ <r = hue-grp c) rows)
                     (? (two? r) (pin b (hue-cls c) (hue-pen <r deep)) b)))
           (hue-pens rows deep) hues-classes)
   (hues-wake x) (hues-pens (hue-rows ()) (hue-deep ())))
) ; module 'vi
