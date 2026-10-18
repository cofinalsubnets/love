; lapiz -- the document lens: markdown, html and roff(man) over one middle, a plain love AST.
; each surface has a reader and a shower. `surfaces` is the whole matrix: a conversion pairs a
; reader and a shower under one hub, anything else answers 'nolens; a new surface adds a row.
;
; the law a surface owes: the AST is its fixed point, (mdread (mdshow a)) = a. normal is what a
; shower emits: paragraphs on one line, `-` bullets, ``` fences, one blank line between blocks.
;
; a doc is a list of blocks:
;   ('meta ((key value) ..))  ('head N inl)  ('para inl)  ('fence lang text)  ('quote doc)
;   ('bullets (inl ..))  ('numbers (inl ..))  ('deflist ((term-inl body-inl) ..))  ('rule)
;   ('table aligns head rows): aligns 'n 'l 'c 'r per column, every row as wide as the head
; an inl is a list of spans:
;   ('text s)  ('em inl)  ('strong inl)  ('code s)  ('link inl url)  ('mark name)  ('img alt src)
; a mark is an html id; only html shows it. " main" and " article" hold a space no id can,
; and mark where a page's own content starts past its menus.
; meta heads the doc with all five metakeys (`mnorm`). a doc is normal when no two texts are
; adjacent in an inl (`mrg`) and no two lists of one kind in the doc (`bmrg`); every reader
; lands there. every list ends in the unit: `=` tells a 0 tail apart.
;
; rfread and htread also take hand-written pages: a scrub runs ahead of each, and a last-resort
; block rule costs what cannot be placed its own line, never the rest of the page.
; roff keeps law 1 on man-shaped docs and normalizes the rest: head 3+ -> 2, a fence loses its
; language, a rule vanishes, a link flattens to its text with the url in \(la..\(ra.
; the terminal (ttyshow) has no reader, so it is no lens and no row in `surfaces`.
; the parsers are peg's (src/love/boot/post.l): a parser is (\ s y n), payloads are lists.

; the head names the exports; the rest stays off the tablet. htb hti hq mget serve papel's
; template, hpe kore www. a consumer says (borrow 'lapiz) or (cite 'lapiz 'md->ht).
(module (lapiz mdread mdshow htread htshow rfread rfshow ttyshow ttlinks ttpage ttpics
         md->ht ht->md md->rf rf->md rf->tty md->tty ht->tty convert  htb hti hq hpe mget)

(borrow 'peg)
(borrow 'text)  ; a line's width in cells

; --- little utils ---
(: (rep s n)    (n < 1 ? "" (s + rep s (n - 1)))
   (splitnl s)  ((: (g i st acc) (? (i < #s) (s i = 10 ? (g (i + 1) (i + 1) (snip s st i . acc))
                                                      (g (i + 1) st acc))
                                    (st < i) (rev (snip s st i . acc))
                                    (rev acc)))
                 0 0 ())
   (endnl s)    (#s && s (#s - 1) = 10 ? s "\(s)\n")               ; one trailing newline, always
   ; a parser whose payload must also pass ok, or it fails where it began
   (pwhen ok a s y n) (a s (s1 \ x \ (ok x ? (y s1 x) (n s))) n)
   ; a row laid to n cells: the cells past its end empty, the ones past n gone
   (tfit n l) (n < 1 ? () ((two? l ? <l) . (tfit (n - 1) (two? l ? >l)))))


; --- character classes ---
(: (chr? c)  1
   (nonl? c) (c != 10)
   (sp? c)   (c = 32 || c = 9)
   (ws? c)   (sp? c || c = 10 || c = 13)
   (dig? c)  (47 < c < 58)
   (hash? c) (c = 35)
   (spec? c) (elem c '(92 42 96 91 93))                     ; \ * ` [ ] -- where an inline span can start
   (ord? c)  !(spec? c))

; --- the meta record: document-level fields, one canonical shape ---
; a key is interned, never `nom`ed: a nom symbol is not `=` to the literal of its spelling.
; values are single-line; a shower emits only the filled fields, a reader fills the rest with "".
(: metakeys '(title section date source manual)
   (mget kvs k) (atom? kvs ? "" (<kvs @ [^k v] v (mget >kvs k)))
   (mnorm kvs)  (map (k \ [k (mget kvs k)]) metakeys)
   mfilled (filter (tally * caup)))

; --- the roff glyph table, read both ways, so a bijection: no two names share a character.
; rq encodes from it because groff reads latin-1 unless preconv ran.
(: rglyphs '(("em" "—") ("en" "–") ("bu" "•") ("la" "⟨") ("ra" "⟩") ("mi" "−"))
   ; ..and the glyphs only the reader knows, outside the bijection: rq never emits them
   rglyphr '(("aq" "'") ("cq" "'") ("oq" "'") ("dq" "\"") ("lq" "“") ("rq" "”")
             ("ga" "`") ("rs" "\\") ("hy" "-") ("ti" "~") ("ha" "^") ("ul" "_")
             ("ru" "_") ("sl" "/") ("co" "©") ("rg" "®") ("tm" "™") ("at" "@")
             ("br" "|") ("bv" "|") ("de" "°") ("dg" "†") ("dd" "‡") ("ct" "¢")
             ("mu" "×") ("di" "÷") ("+-" "±") ("is" "∫") ("if" "∞") ("pd" "∂")
             ("->" "→") ("<-" "←") ("ua" "↑") ("da" "↓") ("na" "∇") ("ap" "~")
             ("==" "≡") ("!=" "≠") ("<=" "≤") (">=" "≥") ("sr" "√") ("fm" "′"))
   (glyph n)   ((: (g l) (? (atom? l) ((: (h m) (? (atom? m) "\\(\(n)" (<<m = n) <><m (h >m))) rglyphr)
                            (<<l = n) <><l (g >l))) rglyphs)
   (rqat s i)  ((: (g l) (atom? l ? ()                       ; does a glyph start at i? -> (name len)
                            (: gl <><l n #gl
                             (i + n <= #s && gl = snip s i (i + n) ? [<<l n] (g >l)))))
                rglyphs)
   ; \*(XX and \*[name]: the strings generators define, mostly quotes and dashes. the scrub
   ; drops every .ds, and an unset string is empty in groff too, so "" is the fallback.
   rstrs '(("Aq" "'") ("C`" "") ("C'" "") ("\"" "\"") ("``" "“") ("''" "”") ("lq" "“") ("rq" "”")
           ("L\"" "“") ("R\"" "”") ("Em" "—") ("En" "–") ("Tr" "") ("(A" "") ("(B" ""))
   (rstr n) ((: (g l) (? (atom? l) "" (<<l = n) <><l (g >l))) rstrs))

; --- normalizing an inl: adjacent texts are one text (the AST is the fixed point, so this matters) ---
(: (mrg l) (? (atom? l) () (<l @ h (<h = 'text && 0 = #<>h)) (mrg >l)     ; a \& contributes an empty text: drop it
              (atom? >l) (<l . ())
              (: a <l b <>l
               (<a = 'text && <b = 'text ? (mrg (['text (<>a + <>b)] . >>l))
                (a . mrg >l))))
   ; ..and at block level: adjacent lists of one kind are one list, as roff cannot keep two
   ; `.TP` runs apart
   (bmrg l) (? (atom? l) ()
               (atom? >l) (<l . ())
               (: a <l b <>l
                  (<a = <b && elem <a '(bullets numbers deflist) ?
                     (bmrg ([<a (<>a + <>b)] . >>l))
                     (a . bmrg >l))))
   plain (cats * map caup)                        ; an inl of pure texts back to a string
   (dpair (a . b . c)) ([a b] . dpair c)             ; a flat t/b payload into pairs
   (zipm (a . b) (c . d)) ([a c] . zipm b d))

; ---------------------------------------------------------------- markdown, read
; inline. the text leaf stops at every sigil, so a construct is never swallowed; a sigil
; starting nothing falls through to `mdchar` as one-char text and `mrg` glues it back on.
(: mdesc    (tag (p \ ['text (string <>p)]) (seq (lit "\\") (one chr?)))
   mdcode   (tag (p \ ['code <>p]) (seqs [(lit "`") (span (!= 96)) (lit "`")]))
   ; a text run stops short of a `!`, so a `![` can start an image
   mdtext   (tag (p \ ['text (cats p)]) (seq (one ord?) (span (c \ ord? c && c != 33))))
   mdimg    (tag (p \ ['img <p <>p])
                 (seqs [(skip (lit "![")) (span (!= 93)) (skip (lit "](")) (span (!= 41)) (skip (lit ")"))]))
   mdchar   (tag (p \ ['text (string <p)]) (one chr?))
   ; the leaves are values; the cycle (span -> strong/em/link -> inls -> span) rides
   ; eta-expanded parsers, so a member is reached at call time and not while the layer builds.
   (mdstrong s y n) (tag (p \ ['strong <p]) (seqs [(skip (lit "**")) (pack (mdinls "**")) (skip (lit "**"))]) s y n)
   (mdem s y n)     (tag (p \ ['em <p]) (seqs [(skip (lit "*")) (pack (mdinls "*")) (skip (lit "*"))]) s y n)
   (mdlink s y n)   ((tag (p \ ['link <p <>p])
                          (seqs [(skip (lit "[")) (pack (mdinls "]")) (skip (lit "]"))
                                 (skip (lit "(")) (span (!= 41)) (skip (lit ")"))])) s y n)
   (mdspan s y n)   (alts [mdesc mdcode mdstrong mdem mdimg mdlink mdtext mdchar] s y n)
   (mdinls stop) (pmap mrg (many (seq (notp (lit stop)) mdspan)))   ; spans up to a closer
   mdinl        (runp (pmap mrg (many mdspan))))

; blocks. every one of these is entered at the start of a line and eats its own newline.
(: eol       (skip (opt (lit "\n")))
   blankline (skip (seqs [(span sp?) (lit "\n")]))
   headmark  (seqs [(lit "#") (span hash?) (lit " ")])
   nummark   (seqs [(one dig?) (span dig?) (lit ". ")])
   defmark   (lit ":   ")                                                        ; the definition-list body marker
   starter   (alts [headmark nummark defmark (lit "```") (lit ">") (lit "- ") (lit "* ") (lit "---")])   ; what a paragraph must not be

   ; a GFM table: a head row, a row of --- :-- :-: --: cells, the body rows. a cell ends at
   ; an unescaped bar; only a head over a delimiter row starts one, else a bar line is prose
   (tbtrim s) (: n #s (l i) (i < n && sp? (s i) ? (l (i + 1)) i)
                 (r j) (0 < j && sp? (s (j - 1)) ? (r (j - 1)) j)
                 a (l 0) b (r n) (a < b ? (snip s a b) ""))
   (tcells s)
    (: n #s
       (go i cur acc)
        (? (n <= i) (rev (0 < #(tbtrim cur) ? (tbtrim cur . acc) acc))
           (s i = 92 && i + 1 < n && s (i + 1) = 124) (go (i + 2) "\(cur)|" acc)
           (s i = 92 && i + 1 < n) (go (i + 2) (cur + snip s i (i + 2)) acc)
           (s i = 124) (go (i + 1) "" (tbtrim cur . acc))
           (go (i + 1) (cur + string (s i)) acc))
       (go 0 "" ()))
   (tdel c)                        ; a delimiter cell -> its alignment, () for any other text
    (: n #c lc (0 < n && c 0 = 58) rc (1 < n && c (n - 1) = 58)
       mid (snip c (lc ? 1 0) (rc ? (n - 1) n))
       dash ((: (g i) (? (#mid <= i) 1 (mid i = 45) (g (i + 1)) 0)) 0)
       (0 < #mid && dash ? (? (lc && rc) 'c rc 'r lc 'l 'n)))
   (tdels? l) (? (atom? l) 1 !(tdel <l) 0 (tdels? >l))
   t-row   (tag (p \ tcells (cats p)) (seqs [(skip (lit "|")) (span nonl?) eol]))
   t-del   (pwhen (p \ two? <p && tdels? <p) t-row)
   t-start (pwhen (p \ #<p = #<>p) (seq t-row t-del))
   b-table (tag (p \ (#<p @ w ['table (map tdel <>p) (map mdinl <p) (map (r \ tfit w (map mdinl r)) >>p)]))
                (pwhen (p \ #<p = #<>p) (seqs [t-row t-del (many t-row)])))
   b-rule  (tag (_ \ '(rule)) (seqs [(lit "---") (skip (span sp?)) (lit "\n")]))
   b-head  (tag (p \ ['head (1 + #<>p) (mdinl <>>>p)])
                     (seqs [(lit "#") (span hash?) (lit " ") (span nonl?) eol]))
   f-line  (seqs [(notp (lit "```")) (span nonl?) (lit "\n")])       ; ..a fenced line keeps its newline
   b-fence (tag (p \ ['fence <p (cats <>p)])
                     (seqs [(skip (lit "```")) (span nonl?) eol (pack (many f-line))
                            (skip (lit "```")) (skip (span nonl?)) eol]))
   q-line  (seqs [(skip (lit ">")) (skip (opt (lit " "))) (span nonl?) (lit "\n")])
   ; a wrapped item is one item: a following `p-line` continues it
   (litrim s) ((: (g i) (i < #s && sp? (s i) ? (g (i + 1)) (snip s i #s))) 0)
   (lazyj p)  (join " " (map litrim p))
   ; a paragraph line must be neither blank nor a block opener -- and must eat a character
   ; (`one nonl?` before the span), else `many` spins forever on the empty tail.
   (p-line s y n)  ((tag cats                      ; ..`tag` does the wrapping; f yields the element
                         (seqs [(notp blankline) (notp starter) (notp t-start) (one nonl?) (span nonl?) eol])) s y n)
   u-item  (tag lazyj (seqs [(skip (alts [(lit "- ") (lit "* ")])) (span nonl?) eol (many p-line)]))
   o-item  (tag lazyj (seqs [(skip (one dig?)) (skip (span dig?)) (skip (lit ". "))
                             (span nonl?) eol (many p-line)]))
   b-bullets (tag (p \ ['bullets (map mdinl p)]) (many1 u-item))
   b-numbers (tag (p \ ['numbers (map mdinl p)]) (many1 o-item))
   ; a definition-list item: a term line, then its `:   ` body line. tried before b-para,
   ; which takes the line back when no body follows
   d-term    (tag cats (seqs [(notp blankline) (notp starter) (one nonl?) (span nonl?) eol]))
   d-body    (seqs [(skip defmark) (span nonl?) eol])
   d-item    (tag (p \ [(mdinl <p) (mdinl <>p)]) (seq d-term d-body))
   b-deflist (tag (p \ ['deflist p]) (many1 d-item))
   (b-para s y n)  (tag (p \ ['para (mdinl (join " " p))]) (many1 p-line) s y n)
   ; the last resort, which makes mdread total: a line `starter` claims and no block parses
   ; (`--- text`, a body with no term) is a paragraph, else the block loop stops there
   b-line  (tag (p \ ['para (mdinl (cats p))]) (seqs [(one nonl?) (span nonl?) eol]))
   ; yaml-ish front matter, the markdown face of the meta block: head-only (a `---` fence
   ; anywhere else is a rule), so it is read before the block loop and shown before it.
   kvline (tag (p \ [(name <p) <>p])
               (seqs [(span (c \ nonl? c && c != 58)) (skip (lit ": ")) (span nonl?) eol]))
   b-meta (tag (p \ ['meta (mnorm p)])
                    (seqs [(skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))
                           (many kvline) (skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))]))
   ; quote recurses into the block loop, so both are eta-expanded and sit after every value
   ; binding they use. it re-reads its text with the `> ` off, through the block loop, not mdread
   (b-quote s y n) ((tag (p \ ['quote (bmrg (runp (many mdblock) (cats <p)))])
                         (pack (many1 q-line))) s y n)
   (mdblock s y n)
    ((seqs [(skip (many blankline))
            (alts [b-rule b-head b-fence b-quote b-table b-bullets b-numbers b-deflist b-para b-line])]) s y n)
   (mdread t) (bmrg (runp (seqs [(opt b-meta) (many mdblock) (skip (many blankline))]) (endnl t))))

; ---------------------------------------------------------------- markdown, show
(: (mq s) (jug 0 @ j (each ^#s (i \ (s i @ c (say j ((spec? c ? "\\" "") + string c)))), slurp j))
   ; a text ending in `!` ahead of a link wears one backslash, else the pair reads as an image
   (mdi l)  (atom? l ? ""
               (mdi1 <l @ s
                  (<<l = 'text && two? >l && <<>l = 'link && 0 < #s && s (#s - 1) = 33 ?
                      "\(snip s 0 (#s - 1))\\!\(mdi >l)"
                     (s + mdi >l))))
   (mdi1 x) (<x @ 'text (mq <>x)
                  'code "`\(<>x)`"
                  'strong "**\(mdi <>x)**"
                  'em "*\(mdi <>x)*"
                  'link "[\(mdi <>x)](\(<>>x))"
                  'img "![\(<>x)](\(<>>x))"
                  "")
   ; a paragraph whose first characters would re-read as another block wears one backslash --
   ; the escape leaf takes it back off, so law 1 survives a paragraph that starts "- " or "# ".
   (shield s) (two? (runp starter (endnl s)) ? "\\\(s)" s)
   (qpre s)   (catmap (ln \ #ln ? "> \(ln)\n" ">\n") (splitnl s))
   (nlist l i) (atom? l ? "" "\(i). \(mdi <l)\n\(nlist >l (i + 1))")
   (mfront kvs) ("---\n" + cats (map (p \ "\(string <p): \(<>p)\n") (mfilled kvs)) + "---\n")
   (mdefs l)    (catmap (it \ "\(mdi <it)\n:   \(mdi <>it)\n") l)
   ; a table row, a cell's bars escaped so the row splits where it should
   (tbar l)     "| \(join " | " l) |"
   (tmcell i)   (mdi i @ s (cats (map (k \ s k @ 124 "\\|" c (string c)) ^#s)))
   (tmal a)     (a @ 'l ":--" 'c ":-:" 'r "--:" "---")
   (mtable x)   ("\(tbar (map tmcell (x 2)))\n\(tbar (map tmal (x 1)))\n"
                 + catmap (r \ "\(tbar (map tmcell r))\n") (x 3))
   (mdb x) (<x @ 'head    "\(rep "#" <>x) \(mdi <>>x)\n"
                 'para    "\(shield (mdi <>x))\n"
                 'fence   "```\(<>x)\n\(<>>x)```\n"
                 'quote   (qpre (mdshow <>x))
                 'bullets (catmap (i \ "- \(mdi i)\n") <>x)
                 'numbers (nlist <>x 1)
                 'deflist (mdefs <>x)
                 'table   (mtable x)
                 'meta    (mfront <>x)
                 'rule    "---\n"
                 "")
   (mdshow d) (join "\n" (map mdb d)))                        ; each block ends in \n, so \n between = a blank line

; ---------------------------------------------------------------- html, show
(: (hq s) (jug 0 @ j (each ^#s (i \ (s i @ c (say j (c @ 38 "&amp;" 60 "&lt;" 62 "&gt;" (string c))))), slurp j))
   (hti l)  (catmap hti1 l)
   (hti1 x) (<x @ 'text   (hq <>x)
                  'code   "<code>\(hq <>x)</code>"
                  'strong ("<strong>" + hti <>x + "</strong>")
                  'em     ("<em>" + hti <>x + "</em>")
                  'link   ("<a href=\"\(hq <>>x)\">" + hti <>x + "</a>")
                  'mark   "<a id=\"\(hq <>x)\"></a>"
                  'img    ("<img src=\"" + hqa <>>x + "\" alt=\"" + hqa <>x + "\">")
                  "")
   ; an attribute's value: hq's three and the quote that would end it
   (hqa s)  (catmap (c \ c @ 34 "&quot;" 38 "&amp;" 60 "&lt;" 62 "&gt;" (string c)) (map (i \ s i) ^#s))
   (hitems l t) "\(join "\n" (map (i \ "<li>" + hti i + "</li>") l))\n</\(t)>"
   (hmeta kvs)  (join "\n" (map (p \ "<meta name=\"\(string <p)\" content=\"\(hq <>p)\">") (mfilled kvs)))
   (hdefs l)    "<dl>\n\(join "\n" (map (it \ "<dt>" + hti <it + "</dt>\n<dd>" + hti <>it + "</dd>") l))\n</dl>"
   (hal a)      (a @ 'l " align=\"left\"" 'c " align=\"center\"" 'r " align=\"right\"" "")
   (hcells t al cs) (two? cs ? ("<\(t)\(hal <al)>" + hti <cs + "</\(t)>\(hcells t >al >cs)") "")
   (hrow t al cs) "<tr>\(hcells t al cs)</tr>"
   (htable x)   ("<table>\n<thead>\n\(hrow "th" (x 1) (x 2))\n</thead>\n<tbody>\n"
                 + cats (map (r \ "\(hrow "td" (x 1) r)\n") (x 3)) + "</tbody>\n</table>")
   (htb x) (<x @ 'head    (: h "h\(<>x)" ("<\(h)>" + hti <>>x + "</\(h)>"))
                 'para    ("<p>" + hti <>x + "</p>")
                 'fence   "<pre><code\(0 < #<>x ? " class=\"language-\(<>x)\"" "")>\(hq <>>x)</code></pre>"
                 'quote   "<blockquote>\n\(htshow <>x)\n</blockquote>"
                 'bullets "<ul>\n\(hitems <>x "ul")"
                 'numbers "<ol>\n\(hitems <>x "ol")"
                 'deflist (hdefs <>x)
                 'table   (htable x)
                 'meta    (hmeta <>x)
                 'rule    "<hr>"
                 "")
   (htshow d) (join "\n" (map htb d)))

; ---------------------------------------------------------------- html entities
; the named entities pages spell, and the numeric forms. an unknown name stays as written
(: hents '(("amp" "&") ("lt" "<") ("gt" ">") ("quot" "\"") ("apos" "'") ("nbsp" " ")
           ("middot" "·") ("mdash" "—") ("ndash" "–") ("hellip" "…") ("bull" "•")
           ("lsquo" "‘") ("rsquo" "’") ("ldquo" "“") ("rdquo" "”") ("copy" "©")
           ("reg" "®") ("trade" "™") ("deg" "°") ("times" "×") ("divide" "÷")
           ("laquo" "«") ("raquo" "»") ("dagger" "†") ("para" "¶") ("sect" "§")
           ("larr" "←") ("rarr" "→") ("harr" "↔") ("le" "≤") ("ge" "≥") ("ne" "≠"))
   (hnum nm)                                     ; &#NN; and &#xHH; -> the character
    (: n #nm
       (go i b v) (n <= i ? (v < 0 ? () (utf8 v))
                     (hexv (nm i) @ d
                        (d < 0 || b <= d ? () (go (i + 1) b ((v < 0 ? 0 v) * b + d)))))
       (? (n < 2 || nm 0 != 35) ()
          (elem (nm 1) '(120 88)) (go 2 16 -1) (go 1 10 -1)))
   (entof nm) ((: (g l) (? (atom? l) (hnum nm @ u (string? u ? u "&\(nm);"))
                           (<<l = nm) <><l (g >l))) hents)
   (hdec s)
    (: n #s o (jug 0)
       (semi i) ((: (g k) (? (n <= k || i + 12 < k) -1 (s k = 59) k (g (k + 1)))) (i + 1))
       (go i) (? (n <= i) (slurp o)
                 (s i = 38) (semi i @ e
                               (e < 0 ? (put o 38, go (i + 1))
                                  (say o (entof (snip s (i + 1) e)), go (e + 1))))
                 (put o (s i), go (i + 1)))
       (go 0)))

; ---------------------------------------------------------------- html, scrubbed
; a page in the wild is mostly not prose. the scrub deletes `hkill` tags whole, open to
; matching close, unwraps the containers in `hbare`, and renames `halias` to what the reader knows
(: hkill '("script" "style" "head" "svg" "noscript" "template" "iframe" "object" "select" "datalist")
   hbare '("div" "nav" "section" "article" "main" "header" "footer" "aside" "span" "body"
           "html" "figure" "figcaption" "form" "label" "picture" "video" "audio" "canvas"
           "caption" "colgroup" "col" "button"
           "font" "center" "small" "big" "abbr" "cite" "time" "mark" "ins" "del" "sup" "sub")
   halias '(("b" "strong") ("i" "em") ("u" "em") ("strike" "em") ("s" "em") ("q" "em")
            ("tt" "code") ("kbd" "code") ("samp" "code") ("var" "code") ("dfn" "em")
            ("h7" "h6") ("h8" "h6") ("menu" "ul") ("dir" "ul"))
   (hlow t) (jug 0 @ o (each ^#t (i \ (t i @ c (put o (64 < c < 91 ? (c + 32) c)))), slurp o))
   ; the tag starting at i: [name end-index open?], or () where none does
   (htag s i)
    (#s @ n
       (!(i < n && s i = 60) ? ()
          (: c? (i + 1 < n && s (i + 1) = 47)
             b (c? ? (i + 2) (i + 1))
             (nm k) (? (n <= k) k (elem (s k) '(32 9 10 13 47 62)) k (nm (k + 1)))
             e (nm b)
             ; a > inside a quoted value does not end the tag
             (go k q) (? (n <= k) k
                         (0 < q) (go (k + 1) (s k = q ? 0 q))
                         (s k = 62) (k + 1)
                         (elem (s k) '(34 39) && s (k - 1) = 61) (go (k + 1) (s k))
                         (go (k + 1) 0))
             (n <= b || e = b ? () [(hlow (snip s b e)) (go e 0) !c?]))))
   (halias? t) ((: (g l) (? (atom? l) t (<<l = t) <><l (g >l))) halias)
   ; from i, past the matching close of t, nesting counted; an unclosed one runs to the end
   (hpast s i t)
    (:- (go i 1) n #s (go k d)
     (n <= k ? k
      (htag s k @ h (?
     (atom? h) (go (k + 1) d)
     (<h != t) (go <>h d)
     <>>h (go <>h (d + 1))
     (d <= 1) <>h
     (go <>h (d - 1))))))
   ; an attribute's value by name, where the name starts a word (id= is not data-id=), quoted
   ; either way or bare to the next space. every open tag asks, so it allocates only the answer
   (hattr s k e nm)
    (: n #nm m (n + 1)
       (at? i) (: (g j) (? (n <= j) (s (i + n) = 61) (s (i + j) != nm j) 0 (g (j + 1))) (g 0))
       ((: (go i) (? (e <= i + m) ()
                     !(s i = nm 0 && elem (s (i - 1)) '(32 9 10 13) && at? i) (go (i + 1))
                     (s (i + m) @ ((34 || 39) @ c)
                      ((: (h j) (? (e <= j) () (s j = c) (snip s (i + m + 1) j) (h (j + 1))))
                       (i + m + 1))
                      ((: (h j) (e <= j || elem (s j) '(32 9 10 13) ? (snip s (i + m) j) (h (j + 1))))
                       (i + m)))))
        k))
   ; a mark in the one shape the reader knows; a name with a quote in it is none
   (hmk v)
    (string? v && 0 < #v && (: (g i) (? (#v <= i) 1 (v i = 34) 0 (g (i + 1))) (g 0)) ?
       "<a id=\"\(v)\"></a>" "")
   ; the tags whose content is a line of text: a mark goes inside, where the text is; any
   ; other tag holds blocks or is dropped, and its mark goes ahead of it
   hinside '("p" "h1" "h2" "h3" "h4" "h5" "h6" "li" "dt" "dd" "td" "th")
   ; where the page's own content starts: <main> or role=main, else an <article>
   (hmain s t k e)
    (? (t = "main" || hattr s k e "role" = "main") (hmk " main")
       (t = "article") (hmk " article")
       "")
   (hfind s i pat)                                  ; past the next pat, or the end
    (:- (go i) n #s m #pat
     (go k) (? (n < k + m) n (pat = snip s k (k + m)) (k + m) (go (k + 1))))
   ; a bare attribute -- <input checked> -- by name, where the name starts a word
   (hflag s k e nm)
    (: n #nm
       (go i) (? (e < i + n) 0
                 (elem (s (i - 1)) '(32 9 10 13) && nm = hlow (snip s i (i + n))
                  && (i + n = e || elem (s (i + n)) '(32 9 10 13 47 61 62))) 1
                 (go (i + 1)))
       (go k))
   ; a form's name or value as a query spells it: space a +, the rest past the unreserved %XX
   (hpe s)
    (: o (jug 0) hx "0123456789ABCDEF"
       (each ^#s (i \ (s i @ c (? (96 < c < 123 || 64 < c < 91 || 47 < c < 58 || elem c '(45 46 95 126)) (put o c)
                                  (c = 32) (put o 43)
                                  (put o 37, put o (hx (c // 16)), put o (hx (c % 16)))))),
        slurp o))
   ; an attribute's value decoded, or "" where there is none
   (hval s k e nm) (hattr s k e nm @ v (string? v ? (hdec v) ""))
   ; the option a <select> sends: the selected one, else the first; its value, else its text
   (hopt s i z)
    (: (val k e e2) (hattr s k e "value" @ v
                       (string? v ? (hdec v)
                          (hdec ((: (g j) (z <= j || s j = 60 ? (snip s e2 j) (g (j + 1)))) e2))))
       (go i first)
        (z <= i ? (string? first ? first "")
           (htag s i @ h
              (? (atom? h) (go (i + 1) first)
                 !(<h = "option" && <>>h) (go <>h first)
                 (: k (i + 7) e (<>h - 1) v (val k e <>h)
                    (hflag s k e "selected" ? v (go <>h (string? first ? first v)))))))
       (go i ()))
   ; a form's controls from i to z, in order: [at kind name value label], kind 'text for what
   ; a person types, 'fix for what goes as it stands, 'sub for a submit button
   (hctls s i z)
    (: (go i acc)
        (z <= i ? (rev acc)
           (htag s i @ h
              (atom? h ? (go (i + 1) acc)
                 (: t <h e2 <>h k (i + 1 + #t) e (e2 - 1)
                    nm (hattr s k e "name") v (hval s k e "value")
                    (? !(<>>h && string? nm) (go e2 acc)
                       (t = "input")
                        (: y (hattr s k e "type") ty (string? y ? (hlow y) "text")
                           (go e2 (? (ty = "hidden") ([i 'fix nm v ""] . acc)
                                     (elem ty '("checkbox" "radio"))
                                      (hflag s k e "checked" ? ([i 'fix nm (#v ? v "on") ""] . acc) acc)
                                     (ty = "submit") ([i 'sub nm v ""] . acc)
                                     (elem ty '("image" "reset" "button" "file")) acc
                                     ([i 'text nm v (#v ? v (hval s k e "placeholder" @ p (#p ? p nm)))] . acc))))
                       (t = "textarea")
                        (: z2 (hpast s e2 t)
                           c (hdec (snip s e2 ((: (g j) (? (j <= e2) e2 (s j = 60) j (g (j - 1)))) (z2 - 1))))
                           (go z2 ([i 'text nm c (#c ? c nm)] . acc)))
                       (t = "select") (hpast s e2 t @ z2 (go z2 ([i 'fix nm (hopt s e2 z2) ""] . acc)))
                       (t = "button")
                        (hattr s k e "type" @ y
                           (go e2 (!(string? y) || hlow y = "submit" ? ([i 'sub nm v ""] . acc) acc)))
                       (go e2 acc))))))
       (go i ()))
   ; a get form -> a tablet of its text fields' links by where each tag starts. a field links
   ; to form:ACTION?PAIRS, its own name=value last, so a browser replaces what follows that
   ; last = with what was typed. the first submit goes too; a post form lays no field
   (hform s k e0 e)
    (: m (hattr s k e0 "method") t {}
       (string? m && hlow m != "get" ? t
          (: a (hval s k e0 "action")
             act (: j ((: (g j) (#a <= j || elem (a j) '(35 63) ? j (g (j + 1)))) 0)
                    (hesc [[34 "%22"] [38 "%26"] [60 "%3C"]] (snip a 0 j)))
             cs (hctls s e (hpast s e "form"))
             sub (filter (c \ c 1 = 'sub) cs @ l (two? l ? [<l]))
             kept (filter (c \ c 1 != 'sub) cs)
             (pair c) "\(hpe (c 2))=\(hpe (c 3))"
             (link c) (: ot (map pair (filter (d \ <d != <c) kept + sub))
                         lb (c 4)
                         ("<a href=\"form:\(act)?" + cats (map (x \ "\(x)&") ot) + "\(pair c)\">["
                          + hq lb + rep "_" (12 - #lb) + "]</a>"))
             (map (c \ pin t <c (link c)) (filter (c \ c 1 = 'text) kept),
              t))))
   ; an image in the one shape the reader knows, src then alt; one with neither is not there
   (himg s k e)
    (: v (hval s k e "src") a (hval s k e "alt")
       (0 < #v || 0 < #a ? ("<img src=\"" + hqa v + "\" alt=\"" + hqa a + "\">") ""))
   ; s with each byte the table names spelled its way
   (hesc tb s)
    (: o (jug 0)
       (each ^#s (i \ (: c (s i) r ((: (g l) (? (atom? l) () (<(<l) = c) <>(<l) (g >l))) tb)
                         (r ? (say o r) (put o c)))),
        slurp o))
   ; the classes a <style> inside a <noscript> hides (display:none or visibility:hidden) by a
   ; plain .name selector, @-blocks skipped. the scrub drops images of those classes after it
   (hhas s pat) (: m #pat (go k) (? (#s < k + m) 0 (snip s k (k + m) = pat) 1 (go (k + 1))) (go 0))
   (hcss b)
    (:- (go 0 0 ()) n #b
     (shut i d) (? (n <= i) n (b i = 125) (d = 1 ? (i + 1) (shut (i + 1) (d - 1)))
                   (b i = 123) (shut (i + 1) (d + 1)) (shut (i + 1) d))
     (cls x) (: w (words x) c <w
                (? (#w = 1 && 1 < #c && c 0 = 46 && !(hhas c ":") && !(hhas c "[")
                    && !(hhas (snip c 1 #c) ".")) [(snip c 1 #c)] ()))
     (go i st acc)
      (? (n <= i) acc
         (b i != 123) (go (i + 1) st acc)
         (: sel (snip b st i) w (words sel)
            (? (two? w && <w 0 = 64) (shut (i + 1) 1 @ z (go z z acc))
               (: z (hfind b (i + 1) "}")
                  t (snip b (i + 1) (z - 1))
                  d (lower (string (filter (c \ !(elem c '(32 9 10 13))) (map (j \ t j) ^#t))))
                  hide (hhas d "display:none" || hhas d "visibility:hidden")
                  (go z z (? hide (foldl (\ a x (cls x + a)) acc (split "," sel)) acc)))))))
   (hnoshow s i e)
    (:- (go i ()) n #s
     (go i acc)
      (? (e <= i) acc
         (s i = 60 && i + 6 < n && hlow (snip s i (i + 6)) = "<style")
          (: b (hfind s i ">") z (hfind s b "</style") (go z (hcss (snip s b (z - 7)) + acc)))
         (go (i + 1) acc)))
   ; ..and the same off each <noscript> inside a <head>, which the scrub deletes whole
   (hheadns s i e)
    (:- (go i ()) n #s
     (go i acc)
      (? (e <= i) acc
         (s i = 60 && i + 9 < n && (s (i + 1) = 110 || s (i + 1) = 78) && hlow (snip s i (i + 9)) = "<noscript")
          (: b (hfind s i ">") z (hpast s b "noscript") (go z (hnoshow s b z + acc)))
         (go (i + 1) acc)))
   (hshown? s k e hid)
    (!(hflag s k e "hidden") && !(two? hid && (hattr s k e "class" @ c
                                              (string? c && two? (filter (x \ elem x hid) (words c))))))
   ; an id becomes a mark. `ba` is 1 while an <a> with no href is open: an anchor, so its
   ; tags go and only its mark and text stay
   (htscrub s)
    (:- (go 0 0) n #s o (jug 0) fs (pins {} 'f {} 'hid ())
     (field i) (peep (fs 'f) i "")
     (go i ba)
      (? (n <= i) (slurp o)
         (i + 3 < n && s i = 60 && s (i + 1) = 33 && s (i + 2) = 45 && s (i + 3) = 45)
          (go (hfind s (i + 4) "-->") ba)
         (i + 1 < n && s i = 60 && s (i + 1) = 33)                       ; <!doctype ..>
          (go ((: (g k) (? (n <= k) k (s k = 62) (k + 1) (g (k + 1)))) (i + 1)) ba)
         (htag s i @ h
            (atom? h ? (put o (s i), go (i + 1) ba)
               (: t <h e <>h op? <>>h
                  k (i + 1 + #t)
                  mk (op? ? (hmk (hattr s k (e - 1) "id") + hmain s t k (e - 1)) "")
                  (? (t = "form") (pin fs 'f (op? ? (hform s k (e - 1) e) {}), say o mk, go e ba)
                     (t = "input") (say o (mk + field i), go e ba)
                     (t = "textarea") (say o (mk + field i), go (op? ? (hpast s e t) e) ba)
                     (t = "img") (say o (mk + (op? && hshown? s k (e - 1) (fs 'hid) ? (himg s k (e - 1)) "")), go e ba)
                     (t = "head" && op?)
                      (: z (hpast s e t) (pin fs 'hid (hheadns s e z + fs 'hid), go z ba))
                     (t = "noscript" && op?)
                      (: z (hpast s e t) (pin fs 'hid (hnoshow s e z + fs 'hid), go z ba))
                     (elem t hkill) (go (op? ? (hpast s e t) e) ba)
                     (elem t hbare) (say o mk, go e ba)
                     (t = "br") (say o "</p><p>", go e ba)
                     ; a link keeps its href alone, the shape the reader knows
                     (t = "a") (: v (op? && hattr s k (e - 1) "href")
                                  m2 (? #mk mk op? (hmk (hattr s k (e - 1) "name")) "")
                                (? !op? (say o (ba ? "" "</a>"), go e 0)
                                   (string? v) (say o "\(m2)<a href=\"\(v)\">", go e 0)
                                   (say o m2, go e 1)))
                     (halias? t @ a
                      (say o $ op? ? ("<\(a)\(snip s k (e - 1))>" @ tg
                                        (elem a hinside ? (tg + mk) (mk + tg)))
                                     "</\(a)>",
                       go e ba)))))))))

; ---------------------------------------------------------------- html, read
; an open tag may carry attributes: `<h1 id="x">` is the same head as `<h1>`
(: (otag t)    (alts [(lit "<\(t)>")
                      (seqs [(lit "<\(t)") (one ws?) (span (!= 62)) (lit ">")])])
   (ctag t)    (lit "</\(t)>")
   hws         (skip (span ws?))
   (wrapt t a) (seqs [(skip (otag t)) a hws (skip (ctag t))])
   (hraw? c)   (c != 60 && c != 38)                        ; ordinary text runs to the next < or &

   (hname? c)  (96 < c < 123 || 64 < c < 91 || 47 < c < 58 || c = 35)
   ; an & that starts no entity is itself -- a query's a=1&b=2, or "fish & chips"
   hent    (alts [(tag (p \ ['text (entof <p)]) (seqs [(skip (lit "&")) (span hname?) (skip (lit ";"))]))
                  (tag (const '(text "&")) (lit "&"))])
   htext   (tag (p \ ['text (cats p)]) (seq (one hraw?) (span hraw?)))
   hcode   (tag (p \ ['code (plain <p)]) (wrapt "code" (pack (many (alts [hent htext])))))
   hmark   (tag (p \ ['mark (plain (runp (many (alts [hent htext])) <p))])
                (seqs [(skip (lit "<a id=\"")) (span (!= 34)) (skip (lit "\"></a>"))]))
   ; an image, src then alt as the scrub lays it, each entity-decoded as an href is
   himgp   (tag (p \ (: (dec s) (plain (runp (many (alts [hent htext])) s) @ r (string? r ? r ""))
                        ['img (dec <>p) (dec <p)]))
                (seqs [(skip (lit "<img src=\"")) (span (!= 34)) (skip (lit "\" alt=\""))
                       (span (!= 34)) (skip (lit "\">"))]))
   ; the inline cycle (htinl -> strong/em/link -> htinl) rides eta-expanded parsers
   (hstrong s y n) (tag (p \ ['strong <p]) (wrapt "strong" (pack htinl)) s y n)
   (hem s y n)     (tag (p \ ['em <p]) (wrapt "em" (pack htinl)) s y n)
   ; ..the href is entity-decoded by running the same two text leaves over it
   (hlink s y n)   ((tag (p \ ['link <>p (plain (runp (many (alts [hent htext])) <p))])
                         (seqs [(skip (lit "<a href=\"")) (span (!= 34)) (skip (lit "\">"))
                                (pack htinl) (skip (lit "</a>"))])) s y n)
   (htinl s y n)   (pmap mrg (many (alts [hent hcode hstrong hem hmark himgp hlink htext])) s y n)

   (hlev n)  (tag (p \ ['head n <p]) (wrapt "h\(n)" (pack htinl)))
   hlang     (seqs [(skip (lit " class=\"language-")) (span (!= 34)) (skip (lit "\""))])
   h-rule  (tag (_ \ '(rule)) (lit "<hr>"))
   h-head  (alts (map hlev '(1 2 3 4 5 6)))
   h-para  (tag (p \ ['para <p]) (wrapt "p" (pack htinl)))
   h-fence (tag (p \ ['fence <p (plain <>p)])
                (seqs [(skip (lit "<pre><code")) (dflt hlang "") (skip (lit ">"))
                       (pack (many (alts [hent htext]))) (skip (lit "</code></pre>"))]))
   h-li    (seqs [hws (wrapt "li" (pack htinl))])
   h-ul    (tag (p \ ['bullets p]) (wrapt "ul" (many h-li)))
   h-ol    (tag (p \ ['numbers p]) (wrapt "ol" (many h-li)))
   h-meta1 (tag (p \ [(name <p) (plain (runp (many (alts [hent htext])) <>p))])
                (seqs [hws (skip (lit "<meta name=\"")) (span (!= 34))
                       (skip (lit "\" content=\"")) (span (!= 34)) (skip (lit "\">"))]))
   h-meta  (tag (p \ ['meta (mnorm p)]) (many1 h-meta1))
   h-dt    (seqs [hws (wrapt "dt" (pack htinl)) hws (wrapt "dd" (pack htinl))])
   h-dl    (tag (p \ ['deflist (dpair p)]) (wrapt "dl" (many h-dt)))
   ; a table: the cells inline, th or td alike, an alignment off htshow's own attribute
   ; and none off any other; the head is the first row, whichever section held it
   (hcellp t) (alts (map (a \ tag (c \ [a <c]) (seqs [hws (skip (lit "<\(t)\(hal a)>")) (pack htinl) (skip (ctag t))]))
                         '(l c r)
                     + [(tag (c \ ['n <c]) (seqs [hws (skip (otag t)) (pack htinl) (skip (ctag t))]))]))
   h-tr    (pack (seqs [hws (skip (otag "tr")) (many (alts [(hcellp "th") (hcellp "td")])) hws (skip (ctag "tr"))]))
   (h-tsec t) (seqs [hws (skip (otag t)) (many h-tr) hws (skip (ctag t))])
   h-table (tag (p \ (: hd <p w #hd
                         ['table (map cap hd) (map (c \ <>c) hd) (map (r \ tfit w (map (c \ <>c) r)) >p)]))
                (pwhen (p \ two? p && two? <p)
                       (wrapt "table" (many (alts [(h-tsec "thead") (h-tsec "tbody") (h-tsec "tfoot") h-tr])))))
   ; the last resort: a tag no block could place is dropped and what it wrapped read on its
   ; own, else lenient `runp` drops the rest of the page. </blockquote> is exempt: h-quote's
   ; `many h-block` waits for it. it sits ahead of the lambdas, which see no later value binding
   h-close (lit "</blockquote>")
   h-lone  (skip (seqs [(notp h-close) (lit "<") (span (!= 62)) (lit ">")]))
   ; ..and text with no <p> around it, as an unwrapped container leaves it, is a paragraph.
   ; `many1` keeps it from matching nothing and looping
   h-loose (tag (p \ ['para <p])
                (pack (pmap mrg (many1 (alts [hent hcode hstrong hem hmark himgp hlink htext])))))
   ; quote recurses into the block loop, so it sits with it and stays eta-expanded
   (h-quote s y n) (tag (p \ ['quote <p]) (wrapt "blockquote" (pack (many h-block))) s y n)
   (h-block s y n)
    (seqs [hws (alts [h-rule h-head h-fence h-quote h-ul h-ol h-dl h-table h-meta h-para h-loose h-lone])] s y n)
   (htread t) (bmrg (runp (seqs [(many h-block) hws]) (htscrub t))))

; ---------------------------------------------------------------- a table, laid out
; roff and the terminal show a table as plain columns padded by alignment, a dashed rule under
; the head. widths count cells, not bytes; a ttlinks mark rides in sentinels 1 and 2, width 0
(: (tplain l) (catmap (x \ <x @ 'text <>x 'code <>x 'strong (tplain <>x) 'em (tplain <>x)
                            'link (tplain <>x) 'tmark (string 1 + <>x + string 2)
                            'img (0 < #<>x ? "[\(<>x)]" "") "") l)
   (tvw s) ((: (g i n) (? (#s <= i) n
                          (s i = 1) (g ((: (h k) (#s <= k || s k = 2 ? (k + 1) (h (k + 1)))) i) n)
                          (g (cpnext s i) (n + max 0 (wcwidth (cpat s i)))))) 0 0)
   (tpad a w s) (w - tvw s @ k
                   (? (k < 1) s (a = 'r) (rep " " k + s)
                      (a = 'c) (rep " " (k // 2) + s + rep " " (k - k // 2)) (s + rep " " k)))
   (tblines x)
    (: al (x 1) rows ((map tplain (x 2)) . (map (r \ map tplain r) (x 3)))
       ws (foldl (a \ r \ map (p \ max <p <>p) (zipm a (map tvw r))) (map (_ \ 0) (x 1)) rows)
       (line r) (: (g as wz cs) (atom? cs ? "" (tpad <as <wz <cs @ c
                                                 (atom? >cs ? c (c + "  " + g >as >wz >cs))))
                   (g al ws r))
       (strip s) (: (b j) (0 < j && s (j - 1) = 32 ? (b (j - 1)) j) (snip s 0 (b #s)))
       ([(strip (line <rows)) (join "  " (map (n \ rep "-" n) ws))] + map (r \ strip (line r)) >rows)))

; ---------------------------------------------------------------- roff (man), show
(: (rq s) ((: (g i acc)
              (!(i < #s) ? acc
                 (rqat s i @ hit
                    (two? hit ? (g (i + <>hit) "\(acc)\\(\(<hit)")
                       (s i @ c (g (i + 1) (acc + (c @ 92 "\\e" 45 "\\-" (string c)))))))))
           0 "")
   (rline s) (#s && (s 0 = 46 || s 0 = 39) ? "\\&\(s)" s)       ; a leading . or ' is text
   ; roff double-spaces after a period ending an input line, so one long line loses its
   ; sentence spacing. one sentence per line is lossless: the reader fills back with one space.
   (rsent s) ((: (g i st acc)
                 (? !(i < #s) (revcat (rline (snip s st i) . acc) ())
                    (s i = 46 && i + 1 < #s && s (i + 1) = 32)
                     (g (i + 2) (i + 2) (rline (snip s st (i + 1)) . acc))
                    (g (i + 1) st acc))) 0 0 ())
   (rfill s) (catmap (ln \ ln + "\n") (rsent s))
   (rfi l)  (catmap rfi1 l)
   (rfi1 x) (<x @ 'text   (rq <>x)
                  'code   "\\f(CR\(rq <>x)\\fR"     ; cr, not the deprecated cw: groff warns on that
                  'strong ("\\fB" + rfi <>x + "\\fR")
                  'em     ("\\fI" + rfi <>x + "\\fR")
                  'link   (rfi <>x + " \\(la\(rq <>>x)\\(ra")
                  'img    (0 < #<>x ? (rq "[\(<>x)]") "")
                  "")
   (rth kvs)   ".TH\(join "" (map (k \ " \"\(mget kvs k)\"") metakeys))\n"
   (rnums l i) (atom? l ? "" (".IP \"\(i).\" 4\n" + rline (rfi <l) + "\n\(rnums >l (i + 1))"))
   (rdefs l)   (catmap (it \ ".TP\n" + rline (rfi <it) + "\n" + rfill (rfi <>it)) l)
   ; roff has no cells here: a table that fits a page is its laid columns as a display,
   ; and a wider one each row a paragraph of head: cell lines, which the page can fill
   (rcell hc) (0 < #<hc ? ("\(<hc): " + tplain <>hc) (tplain <>hc))
   (rrow hd r) ".PP\n\(join "\n.br\n" (map (hc \ rline (rq (rcell hc))) (zipm hd r)))\n"
   (rtable x)
    (tblines x @ ls
       (foldl (a \ l \ a && tvw l <= 78) 1 ls ? (rfb ['fence "" (catmap (ln \ "\(ln)\n") ls)])
          (map tplain (x 2) @ hd (catmap (r \ rrow hd r) (x 3)))))
   (rfb x) (<x @ 'meta    (rth <>x)
                 'head    ((<>x < 2 ? ".SH " ".SS ") + rfi <>>x + "\n")
                 'para    (".PP\n" + rfill (rfi <>x))
                 'fence   (".EX\n" + cats (map (ln \ "\(rline (rq ln))\n") (splitnl <>>x)) + ".EE\n")
                 'quote   (".PP\n.RS\n" + rfshow <>x + ".RE\n")   ; the .pp spaces the display
                 'bullets (catmap (i \ ".IP \\(bu 2\n" + rline (rfi i) + "\n") <>x)
                 'numbers (rnums <>x 1)
                 'deflist (rdefs <>x)
                 'table   (rtable x)
                 "")                                        ; a rule has no roff form: it vanishes
   (rfshow d) (catmap rfb d))

; ---------------------------------------------------------------- roff (man), scrubbed
; generated pages carry macro definitions, conditionals, comments and index calls that are
; not blocks. the scrub is line-oriented, as they are: a .de runs to a lone `..`, a \{ group
; to its \}, a request is one line. it also balances .nf/.fi and .RS/.RE (see rfshut).
(: rfskip '(".IX" ".PD" ".ds" ".as" ".nr" ".rr" ".tm" ".ad" ".na" ".hy" ".nh" ".ne" ".ft"
            ".fam" ".ll" ".ps" ".vs" ".lf" ".hw" ".in" ".ti" ".rm" ".rn" ".cc" ".c2" ".eo"
            ".ec" ".sy" ".do" ".it" ".pl" ".po" ".mk" ".rt" ".ns" ".rs" ".UC" ".DT" ".tr"
            ".char" ".fc" ".so" ".nop" ".ev" ".di" ".wh" ".pso" ".blm" ".shift" ".return")
   ; the macros a generator defines for itself, read as the stock ones they stand for
   rfsame '((".Sp" ".sp") (".Vb" ".nf") (".Ve" ".fi") (".P" ".PP") (".HP" ".PP")
            (".Pp" ".PP") (".INDENT" ".RS") (".UNINDENT" ".RE") (".Ip" ".IP") (".IPs" ".IP"))
   rfdef  '(".de" ".de1" ".am" ".am1" ".ig")                ; .ig: a body never run
   rfcond '(".if" ".ie" ".el")
   ; the macro name: up to the first blank or \, so `.el\{\` names .el the way groff reads it
   (rfmac ln) ((: (g i) (? (#ln <= i) (snip ln 0 i)
                           (elem (ln i) '(32 9 92)) (snip ln 0 i)
                           (g (i + 1)))) 0)
   (rfas m)   ((: (g l) (? (atom? l) m (<<l = m) <><l (g >l))) rfsame)
   ; the \{ groups one line opens, less the ones it closes; a lone \} floors at none open
   (rfdepth ln d)
    ((: (g i k) (? (#ln <= i) (k < 0 ? 0 k)
                   (ln i = 92 && i + 1 < #ln && ln (i + 1) = 123) (g (i + 2) (k + 1))
                   (ln i = 92 && i + 1 < #ln && ln (i + 1) = 125) (g (i + 2) (k - 1))
                   (g (i + 1) k))) 0 d)
   ; a no-break control character is the same macro, so ' normalizes to .
   (rfdot ln) (#ln && ln 0 = 39 ? ".\(snip ln 1 #ln)" ln)
   ; a terminal is nroff: `.if n` text is read in the line's place, `.if t` answers "". 'no is
   ; a condition this cannot decide: an expression, a \{ group, or an .el (its .ie is not kept)
   (rfnro ln)
    (: r (snip ln #(rfmac ln) #ln)
       n #r
       i ((: (g k) (? (n <= k) k !(elem (r k) '(32 9)) k (g (k + 1)))) 0)
       (? (rfmac ln = ".el") 'no                         ; an .el carries no condition at all
          (rfdepth ln 0) 'no
          !(i + 1 < n && elem (r (i + 1)) '(32 9)) 'no
          (r i = 110) (snip r (i + 2) n)
          (r i = 116) ""
          'no))
   (rfcom? ln) (2 < #ln && ln 0 = 46 && ln 1 = 92 && ln 2 = 34)
   ; a macro line's first argument, bare or "quoted"
   (rffst ln)
    (: n #ln
       (go i) (? (n <= i) ""
                 (elem (ln i) '(32 9)) (go (i + 1))
                 (ln i = 34) ((: (h k) (n <= k || ln k = 34 ? (snip ln (i + 1) k) (h (k + 1)))) (i + 1))
                 ((: (h k) (n <= k || elem (ln k) '(32 9) ? (snip ln i k) (h (k + 1)))) i))
       (go #(rfmac ln)))
   (rfdigs? a) (#a && ((: (g i) (? (#a <= i) 1 (dig? (a i)) (g (i + 1)) 0)) 0))
   (rfbul? a)  (elem a '("\\(bu" "\\(em" "\\-" "•" "-" "*" "o"))
   (rfnum? a)  (#a @ n (1 < n && elem (a (n - 1)) '(46 41) && rfdigs? (snip a 0 (n - 1))))
   ; .IP is a bullet, a numbered item, or a tagged paragraph, which becomes a .TP. a bare .IP,
   ; or one with only an indent, is a paragraph
   (rfip ln)
    (rffst ln @ a
       (? (!#a || rfdigs? a) ".PP\n"
          (rfbul? a) ".IP \\(bu\n"
          (rfnum? a) ".IP \"\(a)\"\n"
          ".TP\n\(#a && a 0 = 46 ? "\\&\(a)" a)\n"))
   ; the reader never eats a stray closer, so balance is the scrub's job: a second .nf is a
   ; no-op, a .RE with no .RS goes, and what is still open at the end is shut here
   (rfshut nf rs) ((nf ? ".fi\n" "") + rep ".RE\n" rs)
   ; a macro the page defined for itself runs its body: \\$n an argument, \\$* all of them,
   ; \\n(.$ how many, and copy mode's \\\\ read as one \\. past the budget, its first argument
   (rfown ln) (rffst ln @ r (!#r ? "" "\(r 0 = 46 ? "\\&\(r)" r)\n"))
   (rfsub ln as)
    (: n #ln
       (arg k) (0 < k <= #as ? (as (k - 1)) "")
       (go i acc)
        (? (n <= i) (join "" (rev acc))
           (ln i = 92 && i + 1 < n && ln (i + 1) = 92)
            (i + 2 < n && ln (i + 2) = 36 ? (go (i + 1) acc) (go (i + 2) ("\\" . acc)))
           (ln i = 92 && i + 2 < n && ln (i + 1) = 36)
            (ln (i + 2) @ c
               (? (dig? c) (go (i + 3) (arg (c - 48) . acc))
                  (c = 42) (go (i + 3) (join " " as . acc))
                  (c = 64) (go (i + 3) (join " " (map (a \ "\"\(a)\"") as) . acc))
                  (go (i + 1) ("\\" . acc))))
           (ln i = 92 && i + 4 < n && snip ln i (i + 5) = "\\n(.$") (go (i + 5) (show #as . acc))
           (go (i + 1) (string (ln i) . acc)))
       (go 0 ()))
   ; a macro's arguments, bare or "quoted"
   (rargs s)
    ((: (g i acc)
        (? (i >= #s) (rev acc)
           (s i = 32) (g (i + 1) acc)
           (s i = 34) (: j ((: (h k) (k < #s && s k != 34 ? (h (k + 1)) k)) (i + 1))
                       (g (j + 1) (snip s (i + 1) j . acc)))
           ; an escape's two characters never split an argument: `\ ` is a non-breaking space
           (: j ((: (h k) (? (#s <= k) k
                             (s k = 92 && k + 1 < #s) (h (k + 2))
                             (s k = 32) k
                             (h (k + 1)))) i)
            (g j (snip s i j . acc))))) 0 ())
   (rfscrub s)
    (: defs {}
        (go l de nf d rs k acc)
        (atom? l ? (cats (rev acc) + rfshut nf rs)
           (: ln (rfdot <l) m (rfmac ln)
              ; a .de body runs to a lone .. only: a lone . or a blank name is an empty request
              (? de       (m = ".." ? (go >l () nf d rs k acc)
                             (pin defs de (peep defs de () + [<l]), go >l de nf d rs k acc))
                 (0 < d)  (go >l de nf (rfdepth ln d) rs k acc)         ; a conditional group
                 ; a comment, and a bare \ continuation with nothing on it
                 (rfcom? ln || ln = "\\") (go >l de nf d rs k acc)
                 (elem m rfdef)
                  (: nm (m = ".ig" ? " ig" ".\(rffst ln)")
                     (pin defs nm (m = ".de" || m = ".de1" ? () (peep defs nm ())), go >l nm nf d rs k acc))
                 ; the branch this device takes is read in the condition's place, so a macro
                 ; there is still a macro and the text is still text
                 (elem m rfcond)
                  (rfnro ln @ c
                     (? (c = 'no) (go >l de nf (rfdepth ln 0) rs k acc)
                        !#c       (go >l de nf d rs k acc)
                        (go (c . >l) de nf d rs k acc)))
                 (m = "." || elem m rfskip) (go >l de nf d rs k acc)
                 (: m2 (rfas m) rest (snip ln #m #ln)
                    ; .sp is a blank line inside a display and a paragraph break outside one
                    (? (m2 = ".sp") (go >l de nf d rs k ((nf ? "\n" ".PP\n") . acc))
                       (m2 = ".IP" && !nf) (go >l de nf d rs k (rfip ln . acc))
                       (elem m2 '(".nf" ".EX"))
                        (go >l de 1 d rs k (nf ? acc ("\(m2)\n" . acc)))
                       (elem m2 '(".fi" ".EE"))
                        (go >l de 0 d rs k (nf ? ("\(m2)\n" . acc) acc))
                       (m2 = ".RS") (go >l de nf d (rs + 1) k ("\(m2)\(rest)\n" . acc))
                       (m2 = ".RE") (rs ? (go >l de nf d (rs - 1) k ("\(m2)\n" . acc))
                                        (go >l de nf d rs k acc))
                       (peep defs m 'none != 'none)
                        (0 < k ? (go (map (b \ rfsub b (rargs rest)) (defs m) + >l) de nf d rs (k - 1) acc)
                           (go >l de nf d rs k (rfown ln . acc)))
                       (go >l de nf d rs k ("\(m2)\(rest)\n" . acc)))))))
       (go (splitnl s) () 0 0 0 4096 ())))

; ---------------------------------------------------------------- roff (man), read
; roff fills: input lines join with a space, a font macro's arguments with nothing (.BR and
; kin) or a space (.B/.I). a paragraph is a run of lines, each an inl, ended by a block macro.
(: rfesc? (!= 92)                                       ; ordinary inline text runs to the next \
   rclose    (alts [(lit "\\fR") (lit "\\fP")])                ; \fP is "previous font" -- same thing here
   rgl     (tag (p \ ['text (glyph (string <p + string <>p))])
                (seqs [(skip (lit "\\(")) (one chr?) (one chr?)]))
   ; the escapes with a quoted argument (device call, motion, rule) show nothing, argument too
   rdropq  (tag (const '(text ""))
                (alts (map (c \ seqs [(lit "\\\(c)") (lit "'") (span (!= 39)) (lit "'")])
                           '("X" "Z" "h" "v" "l" "L" "N" "o" "w" "A" "b" "D" "C" "R" "H" "S"))))
   ; a number register read: whatever it held, the .nr that set it is gone
   rreg    (tag (const '(text ""))
                (alts [(seqs [(lit "\\n(") (one chr?) (one chr?)])
                       (seqs [(lit "\\n[") (span (!= 93)) (lit "]")])
                       (seqs [(lit "\\n") (one chr?)])]))
   rpm     (one (c \ elem c '(43 45)))                     ; the sign a size change may carry
   rsize   (tag (const '(text ""))
                (alts [(seqs [(lit "\\s") (opt rpm) (lit "[") (span (!= 93)) (lit "]")])
                       (seqs [(lit "\\s") (opt rpm) (lit "(") (one dig?) (one dig?)])
                       (seqs [(lit "\\s") (opt rpm) (one dig?)])]))
   ; \*(XX and \*[name]: a string the page set for itself -- see rstrs. \[name] is the long
   ; spelling of \(xx and reaches the same table.
   rstrg   (tag (p \ ['text (rstr (string <p + string <>p))])
                (seqs [(skip (lit "\\*(")) (one chr?) (one chr?)]))
   rstrb   (tag (p \ ['text (rstr <p)]) (seqs [(skip (lit "\\*[")) (span (!= 93)) (skip (lit "]"))]))
   rstr1   (tag (p \ ['text (rstr (string <p))]) (seqs [(skip (lit "\\*")) (one chr?)]))
   rglb    (tag (p \ ['text (glyph <p)]) (seqs [(skip (lit "\\[")) (span (!= 93)) (skip (lit "]"))]))
   ; and the bare ones: a mark, a hyphenation point, a thin space -- all of them nothing here
   rnone   (tag (const '(text ""))
                (alts (map (c \ lit "\\\(c)") '("%" ":" "," "/" "|" "^" "{" "}" "c" "d" "u" "z" "p"))))
   resc    (alts [(tag (const '(text "\\")) (lit "\\e"))
                  (tag (const '(text "\\")) (lit "\\\\"))
                  (tag (const '(text "-")) (lit "\\-"))
                  (tag (const '(text "")) (lit "\\&"))      ; zero-width: mrg drops it
                  (tag (const '(text " ")) (lit "\\ "))
                  (tag (const '(text " ")) (lit "\\0"))
                  (tag (const '(text " ")) (lit "\\~"))
                  (tag (const '(text ".")) (lit "\\."))
                  (tag (const '(text "'")) (lit "\\'"))
                  (tag (const '(text "`")) (lit "\\`"))
                  ; a closer with no font open: roman already, so it says nothing. inside a
                  ; font body `rinls` tests rclose before it gets here, so this cannot steal one
                  (tag (const '(text "")) rclose)
                  rdropq rreg rsize rstrg rstrb rglb rstr1 rnone rgl])
   rtext  (tag (p \ ['text (cats p)]) (seq (one rfesc?) (span rfesc?)))
   ; ..a \ starting none of the above reads as literal text one char at a time, `mrg` gluing
   ; it back on. without it the reader stops dead at the first escape it does not model.
   rchar   (tag (p \ ['text (string <p)]) (one chr?))
   rcode   (tag (p \ ['code (plain <p)])
           (seqs [(skip (alts [(lit "\\f(CR") (lit "\\f(CW")]))   ; cw is groff-deprecated, still read
                  (pack (many (seq (notp rclose) (alts [resc rtext rchar])))) (skip rclose)]))
   ; the font cycle (span -> strong/em -> rfont -> rinls -> span) rides eta-expanded parsers.
   ; the closer is optional: a page may leave a font open to the end of the line
   (rfont o t) (tag (p \ [t <p]) (seqs [(skip (lit o)) (pack rinls) (skip (opt rclose))]))
   (rstrong s y n) (rfont "\\fB" 'strong s y n)
   (rem s y n)     (rfont "\\fI" 'em s y n)
   (rspan s y n)   (alts [resc rcode rstrong rem rtext rchar] s y n)
   (rinls s y n)   (pmap mrg (many (seq (notp rclose) rspan)) s y n)
   rfinl   (mrg * runp (many rspan))
   rplain  (plain * mrg * runp (many (alts [resc rtext rchar]))))   ; escapes only, no fonts

; the font macros: which fonts to cycle through, and whether the arguments take a space.
(: fontmacs '((".BR" (strong text) 0) (".RB" (text strong) 0) (".IR" (em text) 0)
              (".RI" (text em) 0) (".BI" (strong em) 0) (".IB" (em strong) 0)
              (".SB" (strong) 1) (".SM" (text) 1) (".B" (strong) 1) (".I" (em) 1))
   (macinfo m) ((: (g l) (? (atom? l) () (<<l = m) ><l (g >l))) fontmacs)
   (wrapf f l) (f @ ('strong || 'em) [[f l]] l)
   (allplain? l) (? (atom? l) 1 (<<l = 'text) (allplain? >l) 0)
   (argl a f)    (rfinl a @ l (allplain? l ? (wrapf f l) l))     ; an explicit \f inside the arg wins
   (argls as fs i sp) (two? as ?
                       (argl <as (fs (i % #fs)) @ h
                        (atom? >as ? h
                           (h + (? sp '((text " ")) ()) + argls >as fs (i + 1) sp))))
   (imacl line) (: a (rargs line) m (two? a ? <a "") info (macinfo m)
                 (atom? info ?  (rfinl line)
                  (mrg (argls (rargs (snip line #m #line)) <info <>info 0))))
   (linl line)  (#line && line 0 = 46 ? (imacl line) (rfinl line)))

; ---------------------------------------------------------------- roff (mdoc), as man
; an mdoc page (.Dd or .Sh ahead of any .TH) is laid as the man macros the reader knows: its
; blocks as .SH .TP .IP .RS .nf, its inline macros as fonts and words. a terminal's reading.
(: bsdcall '("Ac" "Ad" "An" "Ao" "Ap" "Aq" "Ar" "At" "Bc" "Bo" "Bq" "Brc" "Bro" "Brq" "Bsx" "Bx"
             "Cm" "Dc" "Do" "Dq" "Dv" "Dx" "Ec" "Em" "En" "Eo" "Er" "Es" "Ev" "Fa" "Fc" "Fl" "Fn"
             "Fr" "Ft" "Fx" "Ic" "Li" "Lk" "Ms" "Mt" "Nm" "No" "Ns" "Nx" "Oc" "Oo" "Op" "Ot" "Ox"
             "Pa" "Pc" "Pf" "Po" "Pq" "Qc" "Ql" "Qo" "Qq" "Sc" "So" "Sq" "St" "Sx" "Sy" "Ta" "Tn"
             "Ux" "Va" "Vt" "Xc" "Xo" "Xr")
   bsdbold '("Fl" "Cm" "Ic" "Nm" "Sy" "Cd")
   bsdital '("Ar" "Em" "Pa" "Va" "Fa" "Ft" "Ad" "Vt")
   bsdenc  '(("Op" "[" "]") ("Bq" "[" "]") ("Brq" "{" "}") ("Pq" "(" ")") ("Aq" "\\(la" "\\(ra")
             ("Dq" "\\(lq" "\\(rq") ("Sq" "\\(oq" "\\(cq") ("Ql" "\\(oq" "\\(cq") ("Qq" "\\(dq" "\\(dq"))
   ; the open and close halves, a line apart: 1 an opener, 0 a closer
   bsdhalf '(("Ao" "\\(la" 1) ("Ac" "\\(ra" 0) ("Bo" "[" 1) ("Bc" "]" 0) ("Bro" "{" 1) ("Brc" "}" 0)
             ("Do" "\\(lq" 1) ("Dc" "\\(rq" 0) ("Oo" "[" 1) ("Oc" "]" 0) ("Po" "(" 1) ("Pc" ")" 0)
             ("Qo" "\\(dq" 1) ("Qc" "\\(dq" 0) ("So" "\\(oq" 1) ("Sc" "\\(cq" 0))
   bsdos   '(("Bx" "BSD") ("Bsx" "BSD/OS") ("Fx" "FreeBSD") ("Nx" "NetBSD") ("Ox" "OpenBSD")
             ("Dx" "DragonFly"))
   bsdst   '(("-p1003.1" "IEEE Std 1003.1 (\\(lqPOSIX.1\\(rq)")
             ("-p1003.1-2001" "IEEE Std 1003.1-2001 (\\(lqPOSIX.1\\(rq)")
             ("-p1003.1-2004" "IEEE Std 1003.1-2004 (\\(lqPOSIX.1\\(rq)")
             ("-p1003.1-2008" "IEEE Std 1003.1-2008 (\\(lqPOSIX.1\\(rq)")
             ("-p1003.1-2017" "IEEE Std 1003.1-2017 (\\(lqPOSIX.1\\(rq)")
             ("-p1003.2" "IEEE Std 1003.2 (\\(lqPOSIX.2\\(rq)")
             ("-susv2" "Version\\~2 of the Single UNIX Specification (\\(lqSUSv2\\(rq)")
             ("-susv3" "Version\\~3 of the Single UNIX Specification (\\(lqSUSv3\\(rq)")
             ("-susv4" "Version\\~4 of the Single UNIX Specification (\\(lqSUSv4\\(rq)")
             ("-ansiC" "ANSI X3.159-1989 (\\(lqANSI\\~C89\\(rq)")
             ("-isoC" "ISO/IEC 9899:1990 (\\(lqISO\\~C90\\(rq)")
             ("-isoC-99" "ISO/IEC 9899:1999 (\\(lqISO\\~C99\\(rq)")
             ("-isoC-2011" "ISO/IEC 9899:2011 (\\(lqISO\\~C11\\(rq)")
             ("-xpg4" "X/Open Portability Guide Issue\\~4 (\\(lqXPG4\\(rq)")
             ("-ieee754" "IEEE Std 754-1985"))
   bsdlib  '(("libc" "Standard C Library (libc, \\-lc)") ("libm" "Math Library (libm, \\-lm)")
             ("libutil" "System Utilities Library (libutil, \\-lutil)")
             ("libpthread" "POSIX Threads Library (libpthread, \\-lpthread)"))
   bsdclose '("." "," ":" ";" ")" "]" "?" "!")
   (bsdkv l k) ((: (g l) (? (atom? l) () (<<l = k) ><l (g >l))) l)
   (bsdcall? t) (elem t bsdcall ? 1 0)
   (bsdcl? t) (elem t bsdclose ? 1 0)
   (bsdop? t) (t = "(" || t = "[" ? 1 0)
   (bsddel? t) (bsdcl? t || bsdop? t || t = "|")
   ; a piece is [text no-space-before no-space-after]; a delimiter leans as it reads
   (bsddp t) [t (bsdcl? t) (bsdop? t)]
   (bsdfont st f t) (? (st 'plain || f = 'r) t (f = 'b) "\\fB\(t)\\fR" "\\fI\(t)\\fR")
   ; a macro's words, up to the next callable macro: [words rest]
   (bsdupto l) ((: (g l acc) (? (atom? l || bsdcall? <l) [(rev acc) l] (g >l (<l . acc)))) l ())
   ; ..and an enclosure's body: all but the closing delimiters that end the line
   (bsdtrail l) (rev l @ r
                   ((: (g r t) (? (two? r && bsdcl? <r) (g >r (<r . t)) [(rev r) t])) r ()))
   (bsdsee? st) (st 'syn ? ";" "")
   ; one inline macro m over the tokens after it -> [pieces rest]
   (bsdmac st m r)
    (: f (? (elem m bsdbold) 'b (elem m bsdital) 'i 'r)
       e (bsdkv bsdenc m) h (bsdkv bsdhalf m) os (bsdkv bsdos m)
       ver (two? r && !(bsdcall? <r) && !(bsddel? <r))
       (? (two? e) (bsdtrail r @ [b t] [([<e 0 1] . bsdin st b + [[<>e 1 0]]) t])
          (two? h) [[(<>h ? [<h 0 1] [<h 1 0])] r]
          (two? os) [[[(ver ? (m = "Bx" ? (<r + <os) (<os + " " + <r)) <os) 0 0]] (ver ? >r r)]
          (m = "Ux") [[["UNIX" 0 0]] r]
          (m = "At") [[[(ver ? "Version\\~\(snip <r 1 #(<r)) AT&T UNIX" "AT&T UNIX") 0 0]] (ver ? >r r)]
          (m = "St") (two? r ? [[[(bsdkv bsdst <r @ s (s ? <s (snip <r 1 #(<r)))) 0 0]] >r] [() r])
          (m = "Xr") (: sec? (two? r && two? >r && !(bsdcall? <>r) && !(bsddel? <>r))
                        (two? r ? [[[(sec? ? "\(<r)(\(<>r))" <r) 0 0]] (sec? ? >>r >r)] [() r]))
          (m = "Ns") [[["" 1 1]] r]
          (m = "Ap") [[["'" 1 1]] r]
          (m = "Pf") (two? r ? [[[<r 0 1]] >r] [() r])
          (m = "Eo") (two? r && !(bsdcall? <r) ? [[[<r 0 1]] >r] [() r])
          (m = "Ec") (two? r && !(bsdcall? <r) ? [[[<r 1 0]] >r] [() r])
          (m = "Ta") [[[" " 0 0]] r]
          (elem m '("Xo" "Xc" "Bk" "Ek" "Fr" "En")) [() r]
          (m = "Es") [() (two? r ? (two? >r ? >>r ()) ())]
          (m = "Fn") (bsdupto r @ [ws rest]
                        (: ar (filter (w \ !(bsddel? w)) (two? ws ? >ws ()))
                           dl (filter bsddel? (two? ws ? >ws ()))
                           [([(bsdfont st 'b (two? ws ? <ws "")
                               + "(" + join ", " (map (a \ bsdfont st 'i a) ar) + ")" + bsdsee? st) 0 0]
                             . map bsddp dl) rest]))
          (m = "Fo") (two? r ? (pin st 'fa 0, [[[(bsdfont st 'b <r + "(") 0 1]] >r]) [() r])
          (m = "Fa" && charm? (st 'fa))
           (bsdupto r @ [ws rest]
              [(map (w \ (bsddel? w ? (bsddp w)
                          (: k (st 'fa) _ (pin st 'fa (k + 1))
                             [((0 < k ? ", " "") + bsdfont st 'i w) 1 0]))) ws) rest])
          (m = "Fc") (pin st 'fa (), [[[(")" + bsdsee? st) 1 0]] r])
          (m = "Lk") (bsdupto r @ [ws rest]
                        (atom? ws ? [() rest]
                         [(atom? >ws ? [[<ws 0 0]] (map (w \ [w 0 0]) >ws + [[": " 1 1] [<ws 0 0]])) rest]))
          (m = "An" && two? r && elem <r '("-split" "-nosplit")) [() >r]
          (bsdupto r @ [ws rest]
             (: dft (? (m = "Fl") "-" (m = "Ar") "file ..." (m = "Nm") (st 'name) "")
                word? (foldl (a \ w \ a || !(bsddel? w)) 0 ws)
                pre (m = "Fl" ? "-" "")
                ps (map (w \ (bsddel? w ? (bsddp w) [(bsdfont st f (pre + w)) 0 0])) ws)
                ; a bare Fl ahead of another macro joins it: Fl Fl create is --create
                lean (m = "Fl" && atom? ws && two? rest ? 1 0)
                [(!word? && #dft ? ([(bsdfont st f dft) 0 lean] . ps) ps) rest]))))
   ; a line's tokens -> pieces, words outside any macro as they stand
   (bsdin st l)
    (atom? l ? ()
       (: t <l
          (bsdcall? t ? (bsdmac st t >l @ [ps rest] (ps + bsdin st rest))
             ((bsddel? t ? (bsddp t) [t 0 0]) . bsdin st >l))))
   ; pieces -> text: a space between two unless either leans, none at all under .Sm off
   (bsdcat ps sm)
    ((: (g l prev acc)
        (atom? l ? (join "" (rev acc))
         (: p <l
            sep (? (atom? prev || !sm || <>>prev || <>p) "" " ")
            (g >l p (<p . sep . acc))))) ps () ())
   (bsdlead s) (#s && elem (s 0) '(46 39) ? "\\&\(s)" s)
   (bsdtext st l) (bsdlead (bsdcat (bsdin st l) (st 'sm)))
   bsdman '(("1" "General Commands Manual") ("2" "System Calls Manual")
            ("3" "Library Functions Manual") ("4" "Device Drivers Manual")
            ("5" "File Formats Manual") ("6" "Games Manual")
            ("7" "Miscellaneous Information Manual") ("8" "System Manager's Manual")
            ("9" "Kernel Developer's Manual"))
   ; `$Mdocdate: June 24 2025 $` is the date the vcs stamped
   (bsddate l) (join " " (filter (w \ w != "$" && w != "$Mdocdate:") l))
   (bsdand l) (? (atom? l) "" (atom? >l) <l (atom? >>l) "\(<l) and \(<>l)"
                 (join ", " (rev >(rev l)) + ", and " + <(rev l)))
   ; a reference, its %-fields in the order a reader wants them
   (bsdref st)
    (: rs (rev (st 'refs)) (v k) (bsdkv rs k)
       au (map (a \ bsdcat a 1) (filter (x \ <x = "%A") rs @ l (map (x \ <>x) l)))
       f1 (map (k \ (v k @ x (two? x ? (bsdcat <x 1)))) '("%T" "%B" "%J"))
       rest (map (k \ (v k @ x (two? x ? (bsdcat <x 1)))) '("%R" "%N" "%V" "%I" "%P" "%Q" "%C" "%D" "%O" "%U"))
       parts (filter (s \ string? s && #s)
                     ([(bsdand au) (<f1 @ t (string? t ? "\\(lq\(t)\\(rq"))
                       (<>f1 @ b (string? b ? "\\fI\(b)\\fR")) (<>>f1 @ j (string? j ? "\\fI\(j)\\fR"))]
                      + rest))
       (bsdlead (join ", " parts + ".")))
   ; the list a .It is in: [kind count rs]
   (bsdkind l) ((: (g l) (? (atom? l) "-tag"
                            (elem <l '("-tag" "-bullet" "-dash" "-hyphen" "-enum" "-item" "-column"
                                       "-hang" "-ohang" "-inset" "-diag")) <l
                            (g >l))) l)
   ; a column list's widths, its arguments that are not flags
   (bsdcols l) ((: (g l acc) (? (atom? l) (rev acc)
                                (<l = "-offset" || <l = "-width") (g (two? >l ? >>l ()) acc)
                                (#(<l) && <l 0 = 45) (g >l acc)
                                (g >l (#(<l) . acc)))) l ())
   (bsdpad s n) (s + rep " " (n - swidth s))
   ; split a column row at its Ta's
   (bsdcells l) ((: (g l cur acc) (? (atom? l) (rev (rev cur . acc))
                                     (<l = "Ta") (g >l () (rev cur . acc))
                                     (g >l (<l . cur) acc))) l () ())
   (bsdrow st toks)
    (: ws (st 'cols) _ (pin st 'plain 1)
       cs (map (c \ bsdcat (bsdin st c) 1) (bsdcells toks))
       _ (pin st 'plain (st 'nf))
       (go cs ws) (? (atom? cs) ""
                     (atom? >cs) <cs
                     (bsdpad <cs (max (two? ws ? <ws 0) (swidth <cs) + 2) + go >cs (two? ws ? >ws ())))
       (bsdlead (go cs ws)))
   ; one mdoc macro line -> the man lines it stands for
   (bsdblk st m toks)
    (: syn (st 'syn) top (st 'bl @ b (two? b ? <b ()))
       (txt _) (bsdtext st toks)
       (br l) (syn && st 'synl ? (".br" . l) (pin st 'synl 1, l))
       (? (m = "Dd") (pin st 'date (bsddate toks), ())
          (m = "Dt") (: (un s) (join "" (map (i \ s i @ c (? (c = 92 && i + 1 < #s && s (i + 1) = 38) ""
                                                             (i && s (i - 1) = 92 && c = 38) ""
                                                             (c = 92 && i + 1 < #s && s (i + 1) = 45) ""
                                                             (string c))) ^#s))
                        t (un (two? toks ? <toks "")) s (un (two? >toks ? <>toks ""))
                        ; a third word is the volume when it is words, not an architecture
                        v (two? >>toks && has? <>>toks " " ? <>>toks (bsdkv bsdman s @ x (two? x ? <x "")))
                        [".TH \"\(t)\" \"\(s)\" \"\(st 'date)\" \"\" \"\(v)\""])
          (elem m '("Os" "Bf" "Ef" "Bk" "Ek" "Db" "Xc")) ()
          (m = "Sh") (: n (bsdcat (bsdin st toks) 1)
                        (pins st 'syn (n = "SYNOPSIS" ? 1 ()) 'synl (), [".SH \(n)"]))
          (m = "Ss") [".SS \(bsdcat (bsdin st toks) 1)"]
          (m = "Pp" || m = "Lp") [".PP"]
          (m = "Sm") (pin st 'sm (two? toks && <toks = "off" ? 0 1), ())
          (m = "Nm") (: _ (!#(st 'name) && two? toks ? (pin st 'name <toks))
                        (bsdtext st (m . toks) @ l (syn ? (br [l]) [l])))
          (m = "Nd") ["\\- \(txt ())"]
          (m = "In") (br [(bsdlead (bsdfont st 'b "#include <\(two? toks ? <toks "")>"))])
          (m = "Fd") (br [(bsdlead (bsdfont st 'b (join " " toks)))])
          (m = "Ft") (syn ? (pin st 'synl (), [".PP" (txt ())]) [(txt ())])
          (m = "Fn" || m = "Fo") (: l (bsdtext st (m . toks)) (syn ? [".br" l] [l]))
          (m = "Lb") [(two? toks ? (bsdkv bsdlib <toks @ x (two? x ? <x "library \\(lq\(<toks)\\(rq")) "")]
          (m = "Ex") (: ns (filter (w \ w != "-std") toks) ns2 (two? ns ? ns [(st 'name)])
                        [(bsdlead ("The " + bsdand (map (n \ bsdfont st 'b n) ns2)
                                   + (atom? >ns2 ? " utility exits" " utilities exit")
                                   + "\\~0 on success, and\\~>0 if an error occurs."))])
          (m = "Rv") (: ns (filter (w \ w != "-std") toks) ns2 (two? ns ? ns [(st 'name)])
                        [(bsdlead ("The " + bsdand (map (n \ bsdfont st 'b n + "()") ns2)
                                   + (atom? >ns2 ? " function returns" " functions return")
                                   + " the value\\~0 if successful; otherwise the value\\~\\-1 is returned"
                                   + " and the global variable \(bsdfont st 'i "errno") is set to indicate the error."))])
          (m = "Ud") ["currently under development."]
          (m = "Bt") ["is currently in beta test."]
          (m = "Bl") (: k (bsdkind toks) rs (two? (st 'bl) || elem "-offset" toks ? 1 0)
                        _ (pin st 'bl ([k 0 rs] . st 'bl))
                        _ (k = "-column" ? (pins st 'cols (bsdcols toks) 'nf 1 'plain 1))
                        ((rs ? [".RS"] ()) + (k = "-column" ? [".nf"] ())))
          (m = "El") (two? top ? (: _ (pin st 'bl >(st 'bl))
                                    _ (<top = "-column" ? (pins st 'nf () 'plain ()))
                                    ((<top = "-column" ? [".fi"] ()) + (<>>top ? [".RE"] ()))) ())
          (m = "It") (: k (two? top ? <top "-tag")
                        (? (k = "-column") [(bsdrow st toks)]
                           (elem k '("-bullet" "-dash" "-hyphen")) [".IP \\(bu"]
                           (k = "-enum") (: n (<>top + 1) _ (pin st 'bl ([k n <>>top] . >(st 'bl)))
                                            [".IP \"\(show n).\""])
                           (k = "-item") [".PP"]
                           [".TP" (atom? toks ? "\\&" (txt ()))]))
          (m = "Bd") (: nf (elem "-literal" toks || elem "-unfilled" toks || elem "-centered" toks ? 1 0)
                        rs (elem "-offset" toks ? 1 0)
                        _ (pin st 'bd ([nf rs] . st 'bd))
                        _ (nf ? (pins st 'nf 1 'plain 1))
                        ((rs ? [".RS"] ()) + (nf ? [".nf"] ())))
          (m = "Ed") (st 'bd @ b (two? b ? (: x <b _ (pin st 'bd >b)
                                             _ (<x ? (pins st 'nf () 'plain ()))
                                             ((<x ? [".fi"] ()) + (<>x ? [".RE"] ()))) ()))
          (m = "D1") [".RS" (txt ()) ".RE"]
          (m = "Dl") (: _ (pin st 'plain 1) l (txt ()) _ (pin st 'plain (st 'nf)) [".RS" ".nf" l ".fi" ".RE"])
          (m = "Rs") (pin st 'refs (), ())
          (m = "Re") (: l (bsdref st) (pin st 'refs (), [l]))
          (m 0 = 37) (pin st 'refs ([m (bsdin st toks)] . st 'refs), ())
          (m = "An" && two? toks && elem <toks '("-split" "-nosplit")) ()
          [(bsdtext st (bsdcall? m ? (m . toks) toks))]))
   ; an mdoc macro line: a dot, a capital or a %, a short name, then a blank or the end
   (bsdname ln)
    (: n #ln
       (? (n < 3 || !(ln 0 = 46 || ln 0 = 39) || !(64 < ln 1 < 91 || ln 1 = 37)) ()
          ((: (g i) (? (n <= i || elem (ln i) '(32 9)) (i < 6 ? (snip ln 1 i) ()) (g (i + 1)))) 2)))
   ; a head extended across lines (Xo .. Xc), and Fo .. Fc, joined into one line first
   (bsdjoin ls)
    ((: (g ls acc)
        (atom? ls ? (rev acc)
         (: ln <ls nm (bsdname ln) ts (nm ? rargs (snip ln (#nm + 1) #ln) ())
            ; a line ending in Ns runs on into the next one, with no space between
            ns? (two? ts && <(rev ts) = "Ns" && !(elem "Xo" ts))
            (open? x) (elem "Xo" x || nm = "Fo" || ns?)
            (shut? l x) (? (nm = "Fo") (bsdname l = "Fc") ns? 1 (elem "Xc" x))
            (nm && open? ts && !(nm != "Fo" && elem "Xc" ts) ?
             ((: (h l j) (? (atom? l) (g () (j . acc))
                            (: s <l t (bsdname s @ k (k ? snip s 1 #s s))
                               (shut? s (rargs t) ? (g >l ("\(j) \(t)" . acc)) (h >l "\(j) \(t)")))))
              >ls ln)
             (g >ls (ln . acc)))))) ls ())
   (bsd? s)
    ((: (g l) (? (atom? l) 0
                 (rfdot <l @ x (? (rfmac x = ".TH") 0 (rfmac x = ".Dd" || rfmac x = ".Sh") 1 (g >l)))))
     (splitnl s))
   (bsd->man s)
    (: st (pins {} 'sm 1 'name "" 'date "" 'bl () 'bd () 'nf () 'plain ())
       (line ln) (bsdname ln @ m
                    (? !m [ln]
                       (0 < findsub ln "\\\"") (line (snip ln 0 (findsub ln "\\\"")))     ; a trailing comment
                       ; a macro that says nothing lays no line, which would end a paragraph
                       (filter (l \ 0 < #l)
                               (bsdblk st m (rargs (snip (m = "It" && col? () ? (tr ln) ln) (#m + 1) #ln))))))
       (col? _) (st 'bl @ b (two? b && <<b = "-column"))
       ; a column row may split at tabs as well as at Ta
       (tr ln) (cats (map (i \ ln i @ c (c = 9 ? " Ta " (string c))) ^#ln))
       (cats (map (l \ "\(l)\n") (catmap line (bsdjoin (splitnl s))))))
   (rfbsd s) (bsd? s ? (bsd->man s) s))

; the block layer: a run of fill lines is a paragraph, a block macro ends it.
(: blockmac (alts [(lit ".TH") (lit ".SH") (lit ".SS") (lit ".PP") (lit ".LP") (lit ".TP")
                   (lit ".RS") (lit ".RE") (lit ".EX") (lit ".EE") (lit ".IP") (lit ".br") (lit ".nf") (lit ".fi")])
   rfline    (seqs [(span nonl?) (skip (lit "\n"))])
   (rmacl m) (seqs [(skip (lit m)) (skip (span sp?)) (span nonl?) (skip (lit "\n"))])
   (r-fline s y n)  ((tag (linl * cats)
                          (seqs [(notp blockmac) (one nonl?) (span nonl?) (skip (lit "\n"))])) s y n)
   (joinfr (a . u)) (atom? u ? a (a + '((text " ")) + joinfr u))
   r-filled (tag (mrg * joinfr) (many1 r-fline))

   r-th   (tag (p \ ['meta (mnorm (zipm metakeys (rargs <p)))]) (rmacl ".TH"))
   r-sh   (tag (p \ ['head 1 (rfinl (join " " (rargs <p)))]) (rmacl ".SH"))
   r-ss   (tag (p \ ['head 2 (rfinl (join " " (rargs <p)))]) (rmacl ".SS"))
   ; a .pp with no filled run behind it spaces a display; `opt` gives it an empty payload,
   ; so it contributes no block.
   r-pp   (seqs [(skip (alts [(lit ".PP") (lit ".LP")])) (skip (span nonl?)) (skip (lit "\n"))
                 (opt (tag (p \ ['para <p]) r-filled))])
   r-para (tag (p \ ['para <p]) r-filled)      ; text with no .pp -- after a .SH
   r-tp   (tag (p \ [<p <>p])
               (seqs [(skip (lit ".TP")) (skip (span nonl?)) (skip (lit "\n")) r-fline r-filled]))
   r-dl   (tag (p \ ['deflist p]) (many1 r-tp))
   r-bu   (seqs [(skip (lit ".IP \\(bu")) (skip (span nonl?)) (skip (lit "\n")) r-filled])
   r-ul   (tag (p \ ['bullets p]) (many1 r-bu))
   r-no   (seqs [(skip (lit ".IP")) (skip (span nonl?)) (skip (lit "\n")) r-filled])
   r-ol   (tag (p \ ['numbers p]) (many1 r-no))
   r-ex   (tag (p \ ['fence "" (catmap (ln \ "\(rplain ln)\n") p)])
               (seqs [(skip (alts [(lit ".EX") (lit ".nf")])) (skip (span nonl?)) (skip (lit "\n"))
                      (many (seq (notp (alts [(lit ".EE") (lit ".fi")])) rfline))
                      (skip (alts [(lit ".EE") (lit ".fi")])) (skip (span nonl?)) (skip (lit "\n"))]))
   r-br    (skip (seqs [(lit ".br") (span nonl?) (lit "\n")]))   ; a break ends the run
   r-blank (skip (seqs [(span sp?) (lit "\n")]))
   ; the last resort: a macro line no block could place contributes nothing, else lenient
   ; `runp` drops the rest of the page. the closers are exempt: the block waiting for one
   ; runs this. it sits ahead of the lambdas, which see no later value binding
   r-close (alts [(lit ".RE") (lit ".EE") (lit ".fi")])
   r-lone  (skip (seqs [(notp r-close) (lit ".") (span nonl?) (lit "\n")]))
   ; .rs recurses into the block loop, so it sits with it and stays eta-expanded
   (r-rs s y n) (tag (p \ ['quote p])
                     (seqs [(skip (lit ".RS")) (skip (span nonl?)) (skip (lit "\n"))
                            (many r-block) (skip (lit ".RE")) (skip (span nonl?)) (skip (lit "\n"))]) s y n)
   (r-block s y n) (alts [r-blank r-br r-th r-sh r-ss r-pp r-ex r-rs r-ul r-ol r-dl r-para r-lone] s y n)
   rfread (bmrg * runp (many r-block) * rfscrub * rfbsd))   ; mdoc becomes man, then the scrub

; ---------------------------------------------------------------- a terminal, shown
; not a lens: no reader, no row in `surfaces`. it fills to a width, man's shape: a .SH flush
; left, body at 5, a .SS at 3, a definition 7 past its term, a quote 4 further in. a display
; is not filled. each word carries its own escapes, so no wrap cuts an attribute from its reset.
(: ttmk0  (string 1)                                          ; a mark's sentinel, never text
   ttmk1  (string 2)
   (tton a)  (#a ? "\e[\(a)m" "")
   ttoff  "\e[0m"
   (ttsp n)  (rep " " (n < 0 ? 0 n))
   (ttadd a b) (#a ? "\(a);\(b)" b)                        ; a nested attribute joins the outer
   ; an inl -> [text attribute] runs. code stays plain: roman is what a terminal shows for it
   (ttsegs l a)
    (atom? l ? ()
       (<l @ x
          (<x @ 'text   ([[<>x a]] + ttsegs >l a)
                'code   ([[<>x a]] + ttsegs >l a)
                'strong (ttsegs <>x (ttadd a "1") + ttsegs >l a)
                'em     (ttsegs <>x (ttadd a "4") + ttsegs >l a)
                ; the url trails the text it was on, the way a man page's \(la..\(ra does
                ; -- and an anchor, which has no url, is just its text
                'link   (ttsegs <>x a + (#<>>x ? [[" <\(<>>x)>" a]] ()) + ttsegs >l a)
                ; ttlinks' own node: a place, laid as a sentinel with no width that ttpage lifts
                'tmark  ([[(ttmk0 + <>x + ttmk1) 'mark]] + ttsegs >l a)
                'img    ((0 < #<>x ? [["[\(<>x)]" a]]) + ttsegs >l a)
                (ttsegs >l a))))
   ; a run's text at its whitespace, newlines too; the empty pieces at each end let a word
   ; carry on across a style change
   (ttsplit s)
    ((: (g i st acc) (? (#s <= i) (rev (snip s st i . acc))
                        (elem (s i) '(32 9 10 13)) (g (i + 1) (i + 1) (snip s st i . acc))
                        (g (i + 1) st acc))) 0 0 ())
   ; the runs -> words, each one [visible styled]: the visible half is what a fill measures.
   ; a mark rides the styled half only, onto the next word, or the last where none follows
   (ttwords segs)
    ((: (go l vis sty acc)
        (atom? l ? (#vis ? (rev ([vis sty] . acc))
                   (#sty && two? acc) (rev ([<<acc (<acc 1 + sty)] . >acc))
                   (rev acc))
         (: s <<l a <><l
            (pc p vis sty acc)
             (atom? p ? (go >l vis sty acc)
              (: h <p v2 (vis + h)
                 s2 (sty + (#h ? (#a ? (tton a + h + ttoff) h) ""))
               (atom? >p ? (pc >p v2 s2 acc)
                (pc >p "" (#v2 ? "" s2) (#v2 ? ([v2 s2] . acc) acc)))))
          (a = 'mark ? (go >l vis (sty + s) acc) (pc (ttsplit s) vis sty acc)))))
     segs "" "" ())
   ; greedy fill: the words onto lines of at most (w - ind) cells, each indented; n is the
   ; line's width so far, -1 before its first word
   (ttfill words w ind)
    (: pad (ttsp ind)
       room (w - ind @ r (r < 8 ? 8 r))
       (go l n sty acc)
        (atom? l ? (n < 0 ? (rev acc) (rev (pad + sty . acc)))
           (: v (swidth <<l) s <><l
              (? (n < 0) (go >l v s acc)
                 (n + 1 + v <= room) (go >l (n + 1 + v) "\(sty) \(s)" acc)
                 (go >l v s (pad + sty . acc)))))
       (go words -1 "" ()))
   (ttinl l w ind a) (ttfill (ttwords (ttsegs l a)) w ind)
   ; a marker replaces the head of the first line's indent, which is spaces
   (ttmark ls mk ind)
    (atom? ls ? ls
       (<ls @ h ((ttsp ind + mk + snip h (ind + swidth mk) #h) . >ls)))
   (ttitem l w ind mk) (ttmark (ttinl l w (ind + swidth mk) "") mk ind)
   ; the .TH line: title(section) either side of the manual, dropped to the title if too wide
   (ttmeta kvs w)
    (: t (mget kvs 'title) sec (mget kvs 'section) mn (mget kvs 'manual)
       l (#sec ? "\(t)(\(sec))" t)
       gap (w - 1 - 2 * swidth l - swidth mn)                          ; the last column stays empty
       lf (gap // 2)
       (!#t || gap < 2 ? (#t ? [l] ())
          [(l + ttsp lf + mn + ttsp (gap - lf) + l)]))
   (ttvis words) ((: (g l a) (atom? l ? a (g >l (#a ? "\(a) \(<<l)" <<l)))) words "")
   ; a term that fits the gap keeps its definition beside it, as .TP does; a longer one takes
   ; its own line. a blank line between items
   (ttdefs l w ind)
    (two? l ?
     (: it <l
        tw (ttwords (ttsegs <it ""))
        tv (ttvis tw)
        tl (ttfill tw w ind)
        bl (ttinl <>it w (ind + 7) "")
        tc (swidth tv)
        h  (#tv && tc < 7 && atom? >tl && two? bl ?
              (ttsp ind + snip <tl ind #<tl + ttsp (7 - tc)
                + snip <bl (ind + 7) #(<bl) . >bl)
              (tl + bl))
        r  (ttdefs >l w ind)
        (atom? r ? h (h + [""] + r))))
   (ttnums l w ind i)
    (two? l ? (ttitem <l w ind "\(i). " + ttnums >l w ind (i + 1)))
   (ttbuls l w ind)
    (two? l ? (ttitem <l w ind "• " + ttbuls >l w ind))
   (ttblk x w ind)
    (<x @ 'meta    (ttmeta <>x w)
          'head    (ttinl <>>x w (<>x < 2 ? 0 3) "1")
          'para    (ttinl <>x w ind "")
          'fence   (map (ln \ ttsp ind + ln) (splitnl <>>x))
          'quote   (ttdoc <>x w (ind + 4))
          'bullets (ttbuls <>x w ind)
          'numbers (ttnums <>x w ind 1)
          'deflist (ttdefs <>x w ind)
          'table   (tttable x w ind)
          'rule    [(ttsp ind + rep "-" (w - ind < 1 ? 1 (w - ind)))])
   ; a table the width holds is its columns; one it does not is each row as head: cell
   ; lines, a blank between rows, so no line overruns and nothing is cut
   (tttable x w ind)
    (tblines x @ ls
       (((: (g l) (? (atom? l) 1 (w < ind + tvw <l) 0 (g >l))) ls) ? (map (ln \ ttsp ind + ln) ls)
          (: hd (map tplain (x 2))
             (rw r) (catmap (hc \ ttinl [['text (0 < #<hc ? ("\(<hc): " + tplain <>hc) (tplain <>hc))]] w ind "")
                            (zipm hd r))
             ((: (g rs) (? (atom? rs) () (atom? >rs) (rw <rs) (rw <rs + [""] + g >rs))) (x 3)))))
   ; one blank line between blocks, none before the first, and none after a heading --
   ; a heading belongs to what follows it, and man sets it that way
   (ttdoc d w ind)
    (atom? d ? ()
       (: h (ttblk <d w ind) r (ttdoc >d w ind)
          (? (atom? h) r (atom? r) h
             (<<d = 'head) (h + r)
             (h + [""] + r))))
   ; a stateful map: f answers [y acc], threaded left to right
   (tlmap f l acc)
    (atom? l ? [() acc]
     (: r (f <l acc) s (tlmap f >l (r 1)) [(<r . <s) (s 1)]))
   ; an inl -> [inl acc]: a link with a url becomes [n] and its text, acc the urls newest
   ; first, so n is #acc, and a mark named byte 3 and n goes ahead of it for ttpage to find
   ; the line by. an anchor keeps its node -- no url, nothing to number
   (tlgo l acc)
    (atom? l ? [() acc]
     (: x <l
        r (<x @ 'link   (#(x 2) ? (: a ((x 2) . acc) i (tlspans <>x a)
                                     [(['tmark (string 3 + show #a)] . ['text "[\(#a)]"] . <i) (i 1)])
                                  (tlspans <>x acc @ i [[['link <i (x 2)]] (i 1)]))
                 'em     (tlspans <>x acc @ i [[['em <i]] (i 1)])
                 'strong (tlspans <>x acc @ i [[['strong <i]] (i 1)])
                 'mark   [[['tmark <>x]] acc]
                 ; an image: a mark " img SRC" for a viewer to draw at, then its [alt]
                 'img    [((0 < #(x 2) ? [['tmark " img \(x 2)"]] ())
                           + (0 < #<>x ? [['text "[\(<>x)]"]] ())) acc]
                 [[x] acc])
        s (tlgo >l (r 1))
        [(<r + <s) (s 1)]))
   (tlspans l acc) (tlgo l acc @ r [(mrg <r) (r 1)])     ; the marker joins its text: normal
   (tldef p acc) (: t (tlspans <p acc) b (tlspans <>p (t 1)) [[<t <b] (b 1)])
   (tlblk x acc)
    (<x @ 'head    (tlspans (x 2) acc @ i [['head <>x <i] (i 1)])
          'para    (tlspans <>x acc @ i [['para <i] (i 1)])
          'quote   (tlmap tlblk <>x acc @ d [['quote <d] (d 1)])
          'bullets (tlmap tlspans <>x acc @ r [['bullets <r] (r 1)])
          'numbers (tlmap tlspans <>x acc @ r [['numbers <r] (r 1)])
          'deflist (tlmap tldef <>x acc @ r [['deflist <r] (r 1)])
          'table   (: h (tlmap tlspans (x 2) acc) r (tlmap (tlmap tlspans) (x 3) (h 1))
                    [['table <>x <h <r] (r 1)])
          [x acc])
   ; a paragraph of marks alone lays no line to land on, so its marks move onto the next
   ; block that holds text; past the end of a doc there is none, and they go
   ; ..and so does one whose only text is blank, which is what a page's indenting leaves
   (tlblank? x) (<x = 'text && (: t <>x (g i) (? (#t <= i) 1 (elem (t i) '(32 9 10 13)) (g (i + 1)) 0) (g 0)))
   ; ..an image with no alt among them, which lays nothing but its mark
   (tlmk? x) (<x = 'mark || <x = 'img && 0 = #(x 1))
   (tlmarks? l)
    (: (g m k) (? (atom? m) k (tlmk? <m) (g >m 1) (tlblank? <m) (g >m k) 0)
       (g l 0))
   (tlonly l) (filter tlmk? l)
   (tlput x pend)
    (<x @ 'head    ['head <>x (pend + <>>x)]
          'para    ['para (pend + <>x)]
          'bullets (two? <>x ? ['bullets (pend + <<>x . ><>x)] ())
          'numbers (two? <>x ? ['numbers (pend + <<>x . ><>x)] ())
          'deflist (two? <>x ? ['deflist ([(pend + <<<>x) <><<>x] . ><>x)] ())
          'quote   ['quote (tlcarry (['para pend] . <>x))])
   (tlcarry d)
    ((: (go l pend)
        (two? l ?
         (<l @ x
          (<x = 'para && tlmarks? <>x ? (go >l (pend + tlonly <>x))
           (: y (atom? pend ? (<x = 'quote ? ['quote (tlcarry <>x)] x) (tlput x pend))
            (atom? y ? (x . go >l pend) (y . go >l ())))))))
     d ())
   ; a doc -> [doc urls]: the links numbered in reading order, urls 1-based by that number.
   ; a browser shows the doc and follows (urls (n - 1)); man keeps ttyshow's <url>
   (ttlinks d) (tlmap tlblk (tlcarry d) () @ r [<r (rev (r 1))])
   ; the laid text with each mark's sentinel lifted out -> [text anchors], an anchor being
   ; [name line] with the line counted from 0
   (ttlift t)
    (: n #t o (jug 0)
       (go i ln acc)
        (? (n <= i) [(slurp o) (rev acc)]
           (t i = 1) (: e ((: (g k) (n <= k || t k = 2 ? k (g (k + 1)))) (i + 1))
                        (go (e + 1) ln ([(snip t (i + 1) e) ln] . acc)))
           (t i @ c (put o c, go (i + 1) (c @ 10 (ln + 1) ln) acc)))
       (go 0 0 ()))
   ; [text urls anchors lines]: what a browser shows, follows, and lands on, and the line
   ; each link was laid on, by n
   (tldig s) ((: (g i v) (#s <= i ? v (g (i + 1) (v * 10 + (s i - 48))))) 1 0)
   (ttpage d w)
    (: r (ttlinks d) l (ttlift (ttyshow <r w))
       (lk? a) (0 < #<a && <a 0 = 3)
       t (foldl (t \ a \ pin t (tldig <a) <>a) {} (filter lk? <>l))
       [<l (r 1) (filter (a \ !(lk? a)) <>l) (map (i \ peep t (i + 1) -1) ^#(r 1))])
   ; [text anchors]: ttyshow's layout, links as they are, with the marks lifted as ttpage
   ; lifts them -- an image's " img SRC" among them, for a viewer to draw under its line
   (tpspans f l) (catmap (x \ <x @ 'em [['em (tpspans f <>x)]] 'strong [['strong (tpspans f <>x)]]
                                   'link [['link (tpspans f <>x) (x 2)]] (f x)) l)
   (tpblk f x)
    (<x @ 'head    ['head <>x (tpspans f (x 2))]
          'para    ['para (tpspans f <>x)]
          'quote   ['quote (map (tpblk f) <>x)]
          'bullets ['bullets (map (tpspans f) <>x)]
          'numbers ['numbers (map (tpspans f) <>x)]
          'deflist ['deflist (map (p \ [(tpspans f <p) (tpspans f <>p)]) <>x)]
          'table   ['table <>x (map (tpspans f) (x 2)) (map (map (tpspans f)) (x 3))]
          x)
   (ttpics d w)
    (: (img x) (<x @ 'img ((0 < #(x 2) ? [['mark " img \(x 2)"]] ())
                           + (0 < #<>x ? [['text "[\(<>x)]"]] ()))
                  [x])
       (mk x) (<x @ 'mark [['tmark <>x]] [x])
       (ttlift (ttyshow (map (tpblk mk) (tlcarry (map (tpblk img) d))) w)))
   (ttyshow d w) (catmap (ln \ "\(ln)\n") (ttdoc d (w < 20 ? 20 w) 5))
   (rf->tty s w) (ttyshow (rfread s) w)
   (md->tty s w) (ttyshow (mdread s) w)
   (ht->tty s w) (ttyshow (htread s) w))

; ---------------------------------------------------------------- the lens
; five surfaces under two hubs. the x86 rows reach the holo book when CALLED, so lapiz owes
; it nothing at bake.
(: surfaces [['md 'doc mdread mdshow] ['ht 'doc htread htshow] ['rf 'doc rfread rfshow]
             ['att 'x86 (s \ cite 'holo 'att-read s) (v \ cite 'holo 'att-show v)]
             ['intel 'x86 (s \ cite 'holo 'intel-read s) (v \ cite 'holo 'intel-show v)]]
   (srow k) ((: (g l) (? (atom? l) () (<<l = k) <l (g >l))) surfaces)
   (convert from to s) (: a (srow from) b (srow to)
                          (two? a && two? b && <>a = <>b ? (<>>>b (<>>a s)) 'nolens))
   (md->ht s) (htshow (mdread s))
   (ht->md s) (mdshow (htread s))
   (md->rf s) (rfshow (mdread s))
   (rf->md s) (mdshow (rfread s)))
) ; module lapiz

; a later surface joins the sealed module the runtime way: (borrow 'lapiz), then its own text.
