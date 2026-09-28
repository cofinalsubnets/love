; lapiz -- the document lens: surfaces over one middle. markdown, html and roff(man).
;
; there is no pairwise conversion code. one middle -- a plain love AST -- with a reader
; and a shower per surface, so md->ht is (htshow (mdread s)) and three surfaces make six
; conversions out of six functions. the `surfaces` table is the whole matrix: a row is
; (format hub reader shower), a conversion pairs a reader and a shower under ONE hub, and
; anything else meets the nom 'nolens. a fourth surface adds a row and touches nothing.
; the documents say hub 'doc; the two x86 assembler dialects (love/holo/dialect.l) say 'x86.
;
; --- the lens laws (test/host/lapiz.l proves them) ---
;   1. the AST is each surface's fixed point:  (mdread (mdshow a)) = a,  ht likewise
;   2. so each surface round-trips through the other up to normalization, both norms
;      idempotent:  (ht->md (md->ht s)) = s  for s already normal
; law 1 is the strong one -- neither shower loses what its reader wants -- and law 2 falls
; out of it. normal is what a shower emits: paragraphs on one line, `-` bullets, ``` fences,
; one blank line between blocks. a new surface owes law 1 and nothing more.
;
; --- the middle ---
; a doc is a list of blocks:
;   ('meta ((key value) ..))  ('head N inl)  ('para inl)  ('fence lang text)  ('quote doc)
;   ('bullets (inl ..))  ('numbers (inl ..))  ('deflist ((term-inl body-inl) ..))  ('rule)
;   ('table aligns head rows): aligns one of 'n 'l 'c 'r a column, head a row, a row a
;   list of inls, every row as wide as the head
; an inl is a list of spans:
;   ('text s)  ('em inl)  ('strong inl)  ('code s)  ('link inl url)  ('mark name)
; a mark is a place a link can land -- an html id. it is html's alone: markdown, roff and
; the terminal show nothing for it, which is the normalization the other surfaces owe it.
; two names have a space, which no id can: " main" and " article", where a page's own
; content starts past its menus (htscrub lays them).
; ('meta ..) is document-level and heads the doc; its keys are the canonical five, always
; all five, absent ones empty (`mnorm`). a doc is normal when no two texts are adjacent in
; an inl (`mrg`) and no two lists of one kind are adjacent in the doc (`bmrg`); every reader
; lands there, or law 1 fails on an AST that reads the same and is spelled two ways. every
; list ends in the unit -- `=` tells the two terminators apart, so a 0 tail fails law 1.
;
; --- reading what a shower did not write ---
; law 1 is about a surface's own output, and both readers now take a good deal more than
; that: rfread reads a hand-written man page and htread reads a web page. each has a scrub
; ahead of it (rfscrub, htscrub) for the same reason -- what such a file carries around its
; prose is not blocks, and is line-shaped in roff and container-shaped in html -- and each
; has a last-resort block rule, so a construct neither can place costs its own line and
; never the rest of the document. accepting more input cannot break law 1, which is why
; both were safe to add; what they owe instead is stated in test/host/lapiz.l.
; the html scrub also lays what a browser wants from a page's controls in the middle's own
; terms: an image is its [alt], and a GET form's text field is a link to form:ACTION?PAIRS
; (htscrub's `hform` says the shape), so no node is added for either.
;
; --- the terminal, which is not a surface ---
; `ttyshow` lays the middle out for a terminal at a width, and `kore man` is built on it.
; it is not a row in `surfaces` and never will be: a row owes law 1, and a terminal keeps
; nothing -- there is no ttread to be the other half of the pair, so there is no lens to
; state. what it owes instead is stated in test/host/lapiz.l: every heading the markdown has
; is still a heading after roff and the shower, and no line overruns the width.
; a link shows its <url> after its text, as man wants; a browser wants numbers instead, and
; `ttlinks` rewrites a doc so each link reads [n] and hands back the urls by n. `ttpage`
; lays that and lifts the marks out too, answering the line each one landed on, and the
; line each link did.
;
; --- the roff domain ---
; man macros are a smaller surface. law 1 holds on man-page-shaped docs: meta, head 1-2,
; para, fence with empty language, quote, bullets, numbers, deflist, and text/strong/em/code
; inline. outside that rfshow stays total and rfread normalizes four ways, each asserted by
; the gate: a head at 3+ lands at 2 (roff has .SH and .SS and no more), a fence language is
; dropped (.EX/.EE has no slot), a rule vanishes, and a link flattens to its text with the
; url trailing in \(la..\(ra.
;
; both readers are built from the parser combinators in love/boot/post.l -- a parser is
; (\ s y n), payloads are lists `seq` concatenates. lapiz adds what that set lacked: `notp`
; (negative lookahead, what a block grammar needs for "a line that starts no other block"),
; `nope`/`alts`, `many1`, and `pack`/`tag`, which build a node out of a flat payload.
;
; a consumer says (borrow 'lapiz), or hands the loader this file's path, and reads bare down
; the splice or reaches one member by accessor: (cite 'lapiz 'md->ht). the faces are the six
; surface pairs, plus rf->tty/md->tty, ttyshow and ttlinks/ttpage beside them. the head
; below names the exports and nothing else: unwrapped, lapiz puts all ~163 of its names on
; the session.

; no brackets here: the runtime supplies the layer. a consumer says (borrow 'lapiz)
; (the baked module) or hands the loader this file's path ((borrow "apps/lapiz.l")
; -- papel's want does), and reads bare down the splice, or reaches one member through
; the accessor: (cite 'lapiz 'md->ht). the six faces are
; mdread/mdshow/htread/htshow/md->ht/ht->md, and rfread/rfshow/ttyshow beside them;
; everything else is machinery, reachable for a probe ((keys (cite 'lapiz))) but not
; meant for the eye.

; the head names the exports: the ten faces, plus the four pieces papel's template
; reaches through the accessor. everything else is machinery and stays off the
; tablet -- catted, an unwrapped lapiz put all ~163 of its names on the session.
(module (lapiz mdread mdshow htread htshow rfread rfshow ttyshow ttlinks ttpage
         md->ht ht->md md->rf rf->md rf->tty md->tty ht->tty convert  htb hti hq mget)

; the combinators (love/boot/post.l) -- lapiz wants only the lenient `runp`. inside the
; module, so peg splices for this compile alone.
(borrow 'peg)

; --- little utils ---
(: (rep s n)    (? (n < 1) "" (s + rep s (n - 1)))
   (splitnl s)  ((: (g i st acc) (? (i < #s) (? (s i = 10) (g (i + 1) (i + 1) (snip s st i . acc))
                                                      (g (i + 1) st acc))
                                    (st < i) (rev (snip s st i . acc))
                                    (rev acc)))
                 0 0 ())
   (endnl s)    (tally s && s (tally s - 1) = 10 ? s (s + "\n"))     ; one trailing newline, always
   ; a parser whose payload must also pass ok, or it fails where it began
   (pwhen ok a s y n) (a s (\ s1 x (? (ok x) (y s1 x) (n s))) n)
   ; a row laid to n cells: the cells past its end empty, the ones past n gone
   (tfit n l) (? (n < 1) () ((? (two? l) <l ()) . (tfit (n - 1) (? (two? l) >l ())))))


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
; the key is INTERNED, never `nom`ed: `nom` mints a fresh symbol neither `==` nor `=` to the
; literal of the same spelling, so law 1 would fail on the key rather than the value.
; values are single-line; a shower emits only the filled fields and the reader fills the
; rest back with "".
(: metakeys '(title section date source manual)
   (mget kvs k) (atom? kvs ? "" (<kvs @ [^k v] v (mget >kvs k)))
   (mnorm kvs)  (map (\ k [k (mget kvs k)]) metakeys)
   mfilled (filter (tally * caup)))

; --- the roff glyph table, read both ways, so it must be a BIJECTION: no two names may
; share a character, which is why \(aq \(oq \(cq (all an apostrophe) are absent. groff reads
; latin-1 unless preconv ran, so a raw UTF-8 character in the source renders as mojibake.
(: rglyphs '(("em" "—") ("en" "–") ("bu" "•") ("la" "⟨") ("ra" "⟩") ("mi" "−"))
   ; ..and the glyphs the reader alone knows. rfshow emits none of them, so they sit outside
   ; the bijection and only `glyph` consults them: rq still encodes from the six above, and
   ; law 1 never sees this table. a page in the wild is mostly quotes and dashes.
   rglyphr '(("aq" "'") ("cq" "'") ("oq" "'") ("dq" "\"") ("lq" "“") ("rq" "”")
             ("ga" "`") ("rs" "\\") ("hy" "-") ("ti" "~") ("ha" "^") ("ul" "_")
             ("ru" "_") ("sl" "/") ("co" "©") ("rg" "®") ("tm" "™") ("at" "@")
             ("br" "|") ("bv" "|") ("de" "°") ("dg" "†") ("dd" "‡") ("ct" "¢")
             ("mu" "×") ("di" "÷") ("+-" "±") ("is" "∫") ("if" "∞") ("pd" "∂")
             ("->" "→") ("<-" "←") ("ua" "↑") ("da" "↓") ("na" "∇") ("ap" "~")
             ("==" "≡") ("!=" "≠") ("<=" "≤") (">=" "≥") ("sr" "√") ("fm" "′"))
   (glyph n)   ((: (g l) (? (one? l) ((: (h m) (? (one? m) ("\\(" + n) (<<m = n) <><m (h >m))) rglyphr)
                            (<<l = n) <><l (g >l))) rglyphs)
   (rqat s i)  ((: (g l) (? (one? l) ()                       ; does a glyph start at i? -> (name len)
                            (: gl <><l n #gl
                             (i + n <= #s && gl = snip s i (i + n) ? [<<l n] (g >l)))))
                rglyphs)
   ; \*(XX and \*[name]: a page's own strings. the ones a generator defines and then uses are
   ; quote and dash spellings; anything else it set we dropped with its .ds, and an unset
   ; string is empty in groff too, so that is the fallback.
   rstrs '(("Aq" "'") ("C`" "") ("C'" "") ("\"" "\"") ("``" "“") ("''" "”") ("lq" "“") ("rq" "”")
           ("L\"" "“") ("R\"" "”") ("Em" "—") ("En" "–") ("Tr" "") ("(A" "") ("(B" ""))
   (rstr n) ((: (g l) (? (one? l) "" (<<l = n) <><l (g >l))) rstrs))

; --- normalizing an inl: adjacent texts are one text (the AST is the fixed point, so this matters) ---
(: (mrg l) (? (one? l) () (: h <l (= <h 'text && 0 = #<>h)) (mrg >l)     ; a \& contributes an empty text: drop it
              (one? >l) (<l . ())
              (: a <l b <>l
               (= <a 'text && (= <b 'text) ? (mrg (['text (<>a + <>b)] . >>l))
                (a . mrg >l))))
   ; ..and the same at block level: two adjacent lists of one kind are one list. roff cannot
   ; separate two `.TP` runs at all, so without this it merges a pair markdown kept apart and
   ; law 1 fails on a document that looks right in all three surfaces.
   (bmrg l) (? (one? l) ()
               (one? >l) (<l . ())
               (: a <l b <>l
                  (? (= <a <b && elem <a '(bullets numbers deflist))
                     (bmrg ([<a (<>a + <>b)] . >>l))
                     (a . bmrg >l))))
   plain (cats * map caup)                        ; an inl of pure texts back to a string
   (dpair (a . b . c)) ([a b] . dpair c)             ; a flat t/b payload into pairs
   (zipm (a . b) (c . d)) ([a c] . zipm b d))

; ---------------------------------------------------------------- markdown, read
; inline. the text leaf stops at every sigil, so a construct is never swallowed; a sigil
; starting nothing falls through to `mdchar` as one-char text and `mrg` glues it back on.
(: mdesc    (tag (\ p ['text (string <>p)]) (seq (lit "\\") (one chr?)))
   mdcode   (tag (\ p ['code <>p]) (seqs [(lit "`") (span (!= 96)) (lit "`")]))
   mdtext   (tag (\ p ['text (cats p)]) (seq (one ord?) (span ord?)))
   mdchar   (tag (\ p ['text (string <p)]) (one chr?))
   ; the leaves are values; the cycle (span -> strong/em/link -> inls -> span) rides
   ; eta-expanded parsers, so a member is reached at call time and not while the layer builds.
   (mdstrong s y n) ((tag (\ p ['strong <p]) (seqs [(skip (lit "**")) (pack (mdinls "**")) (skip (lit "**"))])) s y n)
   (mdem s y n)     ((tag (\ p ['em <p]) (seqs [(skip (lit "*")) (pack (mdinls "*")) (skip (lit "*"))])) s y n)
   (mdlink s y n)   ((tag (\ p ['link <p <>p])
                          (seqs [(skip (lit "[")) (pack (mdinls "]")) (skip (lit "]"))
                                 (skip (lit "(")) (span (!= 41)) (skip (lit ")"))])) s y n)
   (mdspan s y n)   ((alts [mdesc mdcode mdstrong mdem mdlink mdtext mdchar]) s y n)
   (mdinls stop) (pmap mrg (many (seq (notp (lit stop)) mdspan)))   ; spans up to a closer
   mdinl        (runp (pmap mrg (many mdspan))))

; blocks. every one of these is entered at the start of a line and eats its own newline.
(: eol       (skip (opt (lit "\n")))
   blankline (skip (seqs [(span sp?) (lit "\n")]))
   headmark  (seqs [(lit "#") (span hash?) (lit " ")])
   nummark   (seqs [(one dig?) (span dig?) (lit ". ")])
   defmark   (lit ":   ")                                                        ; the definition-list body marker
   starter   (alts [headmark nummark defmark (lit "```") (lit ">") (lit "- ") (lit "* ") (lit "---")])   ; what a paragraph must not be

   ; a table, GFM's piped form: a head row, a row of --- :-- :-: --: cells, the body rows.
   ; a cell ends at a bar no backslash escapes (the escape comes off, so a code span keeps
   ; its bar) and is one inl. only a head over a delimiter row starts one, so a line that
   ; merely opens with a bar stays prose
   (tbtrim s) (: n #s (l i) (? (i < n && sp? (s i)) (l (i + 1)) i)
                 (r j) (? (0 < j && sp? (s (j - 1))) (r (j - 1)) j)
                 a (l 0) b (r n) (? (a < b) (snip s a b) ""))
   (tcells s)
    (: n #s
       (go i cur acc)
        (? (n <= i) (rev (? (0 < #(tbtrim cur)) (tbtrim cur . acc) acc))
           (s i = 92 && i + 1 < n && s (i + 1) = 124) (go (i + 2) (cur + "|") acc)
           (s i = 92 && i + 1 < n) (go (i + 2) (cur + snip s i (i + 2)) acc)
           (s i = 124) (go (i + 1) "" (tbtrim cur . acc))
           (go (i + 1) (cur + string (s i)) acc))
       (go 0 "" ()))
   (tdel c)                        ; a delimiter cell -> its alignment, () for any other text
    (: n #c lc (0 < n && c 0 = 58) rc (1 < n && c (n - 1) = 58)
       mid (snip c (? lc 1 0) (? rc (n - 1) n))
       dash ((: (g i) (? (#mid <= i) 1 (mid i = 45) (g (i + 1)) 0)) 0)
       (? (0 < #mid && dash) (? (lc && rc) 'c rc 'r lc 'l 'n) ()))
   (tdels? l) (? (one? l) 1 (nil? (tdel <l)) 0 (tdels? >l))
   t-row   (tag (p \ tcells (cats p)) (seqs [(skip (lit "|")) (span nonl?) eol]))
   t-del   (pwhen (p \ two? <p && tdels? <p) t-row)
   t-start (pwhen (p \ #<p = #<>p) (seq t-row t-del))
   b-table (tag (\ p (: w #<p ['table (map tdel <>p) (map mdinl <p) (map (r \ tfit w (map mdinl r)) >>p)]))
                (pwhen (p \ #<p = #<>p) (seqs [t-row t-del (many t-row)])))
   b-rule  (tag (\ _ '(rule)) (seqs [(lit "---") (skip (span sp?)) (lit "\n")]))
   b-head  (tag (\ p ['head (1 + #<>p) (mdinl <>>>p)])
                     (seqs [(lit "#") (span hash?) (lit " ") (span nonl?) eol]))
   f-line  (seqs [(notp (lit "```")) (span nonl?) (lit "\n")])       ; ..a fenced line keeps its newline
   b-fence (tag (\ p ['fence <p (cats <>p)])
                     (seqs [(skip (lit "```")) (span nonl?) eol (pack (many f-line))
                            (skip (lit "```")) (skip (span nonl?)) eol]))
   q-line  (seqs [(skip (lit ">")) (skip (opt (lit " "))) (span nonl?) (lit "\n")])
   ; a wrapped item is one item: a line neither blank nor a block opener belongs to the
   ; item above it. `p-line` is already that exact test, so the two readings of "what
   ; continues a block" cannot drift. law 1 is untouched -- a shower writes an item on one
   ; line and a blank line between blocks, so nothing it emits reads as a continuation.
   (litrim s) ((: (g i) (i < #s && sp? (s i) ? (g (i + 1)) (snip s i #s))) 0)
   (lazyj p)  (join " " (map litrim p))
   ; a paragraph line must be neither blank nor a block opener -- and must eat a character
   ; (`one nonl?` before the span), else `many` spins forever on the empty tail.
   (p-line s y n)  ((tag cats                      ; ..`tag` does the wrapping; f yields the element
                         (seqs [(notp blankline) (notp starter) (notp t-start) (one nonl?) (span nonl?) eol])) s y n)
   u-item  (tag lazyj (seqs [(skip (alts [(lit "- ") (lit "* ")])) (span nonl?) eol (many p-line)]))
   o-item  (tag lazyj (seqs [(skip (one dig?)) (skip (span dig?)) (skip (lit ". "))
                             (span nonl?) eol (many p-line)]))
   b-bullets (tag (\ p ['bullets (map mdinl p)]) (many1 u-item))
   b-numbers (tag (\ p ['numbers (map mdinl p)]) (many1 o-item))
   ; a definition-list item: a TERM line (itself no block opener), then its `:   ` body line.
   ; tried before b-para -- a term line reads as a paragraph line until the body line proves
   ; otherwise, and the failure backtracks, so b-para picks up an ordinary paragraph. blocks
   ; are always blank-line separated by every shower, so a paragraph never swallows a term.
   d-term    (tag cats (seqs [(notp blankline) (notp starter) (one nonl?) (span nonl?) eol]))
   d-body    (seqs [(skip defmark) (span nonl?) eol])
   d-item    (tag (\ p [(mdinl <p) (mdinl <>p)]) (seq d-term d-body))
   b-deflist (tag (\ p ['deflist p]) (many1 d-item))
   (b-para s y n)  ((tag (\ p ['para (mdinl (join " " p))]) (many1 p-line)) s y n)
   ; the last resort, and what makes mdread TOTAL: `starter` claims more lines than the
   ; blocks it names can parse (a `--- text ---` that is not a rule, a `:   ` body with no
   ; term over it) and `p-line` refuses them too, so without this the block loop stops and
   ; the rest of the document vanishes in silence. taking one line as a paragraph lets the
   ; loop go on. it cannot fire on what a shower writes, so law 1 does not feel it.
   b-line  (tag (\ p ['para (mdinl (cats p))]) (seqs [(one nonl?) (span nonl?) eol]))
   ; yaml-ish front matter, the markdown face of the meta block: head-only (a `---` fence
   ; anywhere else is a rule), so it is read before the block loop and shown before it.
   kvline (tag (\ p [(name <p) <>p])
               (seqs [(span (c \ nonl? c && c != 58)) (skip (lit ": ")) (span nonl?) eol]))
   b-meta (tag (\ p ['meta (mnorm p)])
                    (seqs [(skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))
                           (many kvline) (skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))]))
   ; quote recurses into the block loop, so it sits with it and stays eta-expanded -- and
   ; both sit after every value binding above, because a value binding written after a
   ; lambda is not one the lambda can see. this one re-reads its own text where the html
   ; quote recurses in place, the `> ` having to come off first; what it re-reads with is
   ; the BLOCK LOOP and not mdread, which is the difference between a quote that reads and
   ; a quote that comes back empty.
   (b-quote s y n) ((tag (\ p ['quote (bmrg (runp (many mdblock) (cats <p)))])
                         (pack (many1 q-line))) s y n)
   (mdblock s y n)
    ((seqs [(skip (many blankline))
            (alts [b-rule b-head b-fence b-quote b-table b-bullets b-numbers b-deflist b-para b-line])]) s y n)
   (mdread t) (bmrg (runp (seqs [(opt b-meta) (many mdblock) (skip (many blankline))]) (endnl t))))

; ---------------------------------------------------------------- markdown, show
(: (mq s) (:- (g 0 "") (g i acc) (i >= #s ? acc (s i @ c (g (i + 1) (acc + (spec? c ? "\\" "") + string c)))))
   (mdi l)  (catmap mdi1 l)
   (mdi1 x) (<x @ 'text (mq <>x)
                  'code ("`" + <>x + "`")
                  'strong ("**" + mdi <>x + "**")
                  'em ("*" + mdi <>x + "*")
                  'link ("[" + mdi <>x + "](" + <>>x + ")")
                  "")
   ; a paragraph whose first characters would re-read as another block wears one backslash --
   ; the escape leaf takes it back off, so law 1 survives a paragraph that starts "- " or "# ".
   (shield s) (two? (runp starter (endnl s)) ? ("\\" + s) s)
   (qpre s)   (catmap (ln \ #ln ? ("> " + ln + "\n") ">\n") (splitnl s))
   (nlist l i) (atom? l ? "" (show i + ". " + mdi <l + "\n" + nlist >l (i + 1)))
   (mfront kvs) ("---\n" + cats (map (p \ string <p + ": " + <>p + "\n") (mfilled kvs)) + "---\n")
   (mdefs l)    (catmap (it \ mdi <it + "\n:   " + mdi <>it + "\n") l)
   ; a table row, a cell's bars escaped so the row splits where it should
   (tbar l)     ("| " + join " | " l + " |")
   (tmcell i)   (: s (mdi i) (cats (map (k \ (? (s k = 124) "\\|" (string (s k)))) ^#s)))
   (tmal a)     (a @ 'l ":--" 'c ":-:" 'r "--:" "---")
   (mtable x)   (tbar (map tmcell (x 2)) + "\n" + tbar (map tmal (x 1)) + "\n"
                 + catmap (r \ tbar (map tmcell r) + "\n") (x 3))
   (mdb x) (<x @ 'head    (rep "#" <>x + " " + mdi <>>x + "\n")
                 'para    (shield (mdi <>x) + "\n")
                 'fence   ("```" + <>x + "\n" + <>>x + "```\n")
                 'quote   (qpre (mdshow <>x))
                 'bullets (catmap (i \ "- " + mdi i + "\n") <>x)
                 'numbers (nlist <>x 1)
                 'deflist (mdefs <>x)
                 'table   (mtable x)
                 'meta    (mfront <>x)
                 'rule    "---\n"
                 "")
   (mdshow d) (join "\n" (map mdb d)))                        ; each block ends in \n, so \n between = a blank line

; ---------------------------------------------------------------- html, show
(: (hq s) (:- (g 0 "") (g i acc) (i >= #s ? acc (: c (s i) (g (i + 1)
           (acc + (c @ 38 "&amp;" 60 "&lt;" 62 "&gt;" (string c)))))))
   (hti l)  (catmap hti1 l)
   (hti1 x) (<x @ 'text   (hq <>x)
                  'code   ("<code>" + hq <>x + "</code>")
                  'strong ("<strong>" + hti <>x + "</strong>")
                  'em     ("<em>" + hti <>x + "</em>")
                  'link   ("<a href=\"" + hq <>>x + "\">" + hti <>x + "</a>")
                  'mark   ("<a id=\"" + hq <>x + "\"></a>")
                  "")
   (hitems l t) (join "\n" (map (i \ "<li>" + hti i + "</li>") l) + "\n</" + t + ">")
   (hmeta kvs)  (join "\n" (map (p \ "<meta name=\"" + string <p + "\" content=\"" + hq <>p + "\">") (mfilled kvs)))
   (hdefs l)    ("<dl>\n" + join "\n" (map (it \ "<dt>" + hti <it + "</dt>\n<dd>" + hti <>it + "</dd>") l) + "\n</dl>")
   (hal a)      (a @ 'l " align=\"left\"" 'c " align=\"center\"" 'r " align=\"right\"" "")
   (hcells t al cs) (? (two? cs) ("<" + t + hal <al + ">" + hti <cs + "</" + t + ">" + hcells t >al >cs) "")
   (hrow t al cs) ("<tr>" + hcells t al cs + "</tr>")
   (htable x)   ("<table>\n<thead>\n" + hrow "th" (x 1) (x 2) + "\n</thead>\n<tbody>\n"
                 + cats (map (r \ hrow "td" (x 1) r + "\n") (x 3)) + "</tbody>\n</table>")
   (htb x) (<x @ 'head    (: h ("h" + show <>x) ("<" + h + ">" + hti <>>x + "</" + h + ">"))
                 'para    ("<p>" + hti <>x + "</p>")
                 'fence   ("<pre><code" + (? (0 < #<>x) (" class=\"language-" + <>x + "\"") "")
                                  + ">" + hq <>>x + "</code></pre>")
                 'quote   ("<blockquote>\n" + htshow <>x + "\n</blockquote>")
                 'bullets ("<ul>\n" + hitems <>x "ul")
                 'numbers ("<ol>\n" + hitems <>x "ol")
                 'deflist (hdefs <>x)
                 'table   (htable x)
                 'meta    (hmeta <>x)
                 'rule    "<hr>"
                 "")
   (htshow d) (join "\n" (map htb d)))

; ---------------------------------------------------------------- html entities
; the named entities a document actually spells, and the numeric forms. an unknown name
; rides through as it was written, which is what the markdown surface does with a sigil
; it cannot claim -- better a literal `&foo;` on the page than a silently eaten word.
; the reader decodes text with these, and the scrub an attribute's value (`hdec`).
(: hents '(("amp" "&") ("lt" "<") ("gt" ">") ("quot" "\"") ("apos" "'") ("nbsp" " ")
           ("middot" "·") ("mdash" "—") ("ndash" "–") ("hellip" "…") ("bull" "•")
           ("lsquo" "‘") ("rsquo" "’") ("ldquo" "“") ("rdquo" "”") ("copy" "©")
           ("reg" "®") ("trade" "™") ("deg" "°") ("times" "×") ("divide" "÷")
           ("laquo" "«") ("raquo" "»") ("dagger" "†") ("para" "¶") ("sect" "§")
           ("larr" "←") ("rarr" "→") ("harr" "↔") ("le" "≤") ("ge" "≥") ("ne" "≠"))
   (hnum nm)                                     ; &#NN; and &#xHH; -> the character
    (: n #nm
       (go i b v) (? (n <= i) (? (v < 0) () (utf8 v))
                     (: d (hexv (nm i))
                        (? (d < 0 || b <= d) () (go (i + 1) b ((? (v < 0) 0 v) * b + d)))))
       (? (n < 2 || nm 0 != 35) ()
          (elem (nm 1) '(120 88)) (go 2 16 -1) (go 1 10 -1)))
   (entof nm) ((: (g l) (? (one? l) (: u (hnum nm) (? (string? u) u ("&" + nm + ";")))
                           (<<l = nm) <><l (g >l))) hents)
   (hdec s)
    (: n #s o (jug 0)
       (semi i) ((: (g k) (? (n <= k || i + 12 < k) -1 (s k = 59) k (g (k + 1)))) (i + 1))
       (go i) (? (n <= i) (slurp o)
                 (s i = 38) (: e (semi i)
                               (? (e < 0) (: _ (put o 38) (go (i + 1)))
                                  (: _ (say o (entof (snip s (i + 1) e))) (go (e + 1)))))
                 (: _ (put o (s i)) (go (i + 1))))
       (go 0)))

; ---------------------------------------------------------------- html, scrubbed
; the roff surface learned this first, and html wants it for the same reason: a page in the
; wild is mostly not prose. a doctype, a comment, a <head> and everything under it, and the
; <script>/<style> bodies are not blocks; and a container -- div, nav, section, span -- is
; not one either, since it wraps blocks rather than being one. so the scrub deletes the
; first kind whole, opening tag to matching close, and UNWRAPS the second, dropping the tag
; and keeping what it held. the aliases go here too: <b> is <strong> to a reader with one
; font, and <br> ends a line the only way this middle can say it.
(: hkill '("script" "style" "head" "svg" "noscript" "template" "iframe" "object" "select" "datalist")
   hbare '("div" "nav" "section" "article" "main" "header" "footer" "aside" "span" "body"
           "html" "figure" "figcaption" "form" "label" "picture" "video" "audio" "canvas"
           "caption" "colgroup" "col" "button"
           "font" "center" "small" "big" "abbr" "cite" "time" "mark" "ins" "del" "sup" "sub")
   halias '(("b" "strong") ("i" "em") ("u" "em") ("strike" "em") ("s" "em") ("q" "em")
            ("tt" "code") ("kbd" "code") ("samp" "code") ("var" "code") ("dfn" "em")
            ("h7" "h6") ("h8" "h6") ("menu" "ul") ("dir" "ul"))
   (hlow t) (:- (go 0) n #t o (jug 0) (go i)
             (n <= i ? (slurp o) (t i @ c (put o (64 < c < 91 ? (c + 32) c), go (i + 1)))))
   ; the tag starting at i: [name end-index open?], or () where none does
   (htag s i)
    (: n #s
       (? !(i < n && s i = 60) ()
          (: c? (i + 1 < n && s (i + 1) = 47)
             b (? c? (i + 2) (i + 1))
             (nm k) (? (n <= k) k (elem (s k) '(32 9 10 13 47 62)) k (nm (k + 1)))
             e (nm b)
             ; a > inside a quoted value does not end the tag
             (go k q) (? (n <= k) k
                         (0 < q) (go (k + 1) (? (s k = q) 0 q))
                         (s k = 62) (k + 1)
                         (elem (s k) '(34 39) && s (k - 1) = 61) (go (k + 1) (s k))
                         (go (k + 1) 0))
             (? (n <= b || e = b) () [(hlow (snip s b e)) (go e 0) !c?]))))
   (halias? t) ((: (g l) (? (one? l) t (<<l = t) <><l (g >l))) halias)
   ; from i, past the matching close of t -- nesting counted, so a <div> inside a killed
   ; <div> does not end it early. an unclosed one runs to the end, as it does in a browser.
   (hpast s i t)
    (:- (go i 1) n #s (go k d)
     (n <= k ? k
      (: h (htag s k) (?
       (one? h) (go (k + 1) d)
       (<h != t) (go <>h d)
       <>>h (go <>h (d + 1))
       (d <= 1) <>h
       (go <>h (d - 1))))))
   ; an attribute's value by name, where the name starts a word -- so id= is not data-id= --
   ; quoted either way, or bare to the next space
   ; every open tag asks, so it compares in place and allocates only the answer
   (hattr s k e nm)
    (: n #nm m (n + 1)
       (at? i) (: (g j) (? (n <= j) (s (i + n) = 61) (s (i + j) != nm j) 0 (g (j + 1))) (g 0))
       ((: (go i) (? (e <= i + m) ()
                     !(s i = nm 0 && elem (s (i - 1)) '(32 9 10 13) && at? i) (go (i + 1))
                     (s (i + m) @ ((34 || 39) @ c)
                      ((: (h j) (? (e <= j) () (s j = c) (snip s (i + m + 1) j) (h (j + 1))))
                       (i + m + 1))
                      ((: (h j) (? (e <= j || elem (s j) '(32 9 10 13)) (snip s (i + m) j) (h (j + 1))))
                       (i + m)))))
        k))
   ; a place a link can land, in the one shape the reader knows. a name with a quote in it
   ; cannot be spelled there, and is no place
   (hmk v)
    (? (string? v && 0 < #v && (: (g i) (? (#v <= i) 1 (v i = 34) 0 (g (i + 1))) (g 0)))
       ("<a id=\"" + v + "\"></a>") "")
   ; the tags whose content is a line of text: a mark goes inside, where the text is; any
   ; other tag holds blocks or is dropped, and its mark goes ahead of it
   hinside '("p" "h1" "h2" "h3" "h4" "h5" "h6" "li" "dt" "dd" "td" "th")
   ; where the page's own content starts, past its menus: a mark whose name has a space,
   ; which no id can, so it never meets one. <main> or role=main, else an <article>
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
       (go i) (? (#s <= i) (slurp o)
                 (: c (s i)
                    _ (? ((96 < c < 123) || (64 < c < 91) || (47 < c < 58) || elem c '(45 46 95 126)) (put o c)
                         (c = 32) (put o 43)
                         (: _ (put o 37) _ (put o (hx (c // 16))) (put o (hx (c % 16)))))
                    (go (i + 1))))
       (go 0))
   ; an attribute's value decoded, or "" where there is none
   (hval s k e nm) (: v (hattr s k e nm) (? (string? v) (hdec v) ""))
   ; the option a <select> sends: the selected one, else the first; its value, else its text
   (hopt s i z)
    (: (val k e e2) (: v (hattr s k e "value")
                       (? (string? v) (hdec v)
                          (hdec ((: (g j) (? (z <= j || s j = 60) (snip s e2 j) (g (j + 1)))) e2))))
       (go i first)
        (? (z <= i) (? (string? first) first "")
           (: h (htag s i)
              (? (one? h) (go (i + 1) first)
                 !(<h = "option" && <>>h) (go <>h first)
                 (: k (i + 7) e (<>h - 1) v (val k e <>h)
                    (? (hflag s k e "selected") v (go <>h (? (string? first) first v)))))))
       (go i ()))
   ; a form's controls from i to z, in order: [at kind name value label], kind 'text for what
   ; a person types, 'fix for what goes as it stands, 'sub for a submit button
   (hctls s i z)
    (: (go i acc)
        (? (z <= i) (rev acc)
           (: h (htag s i)
              (? (one? h) (go (i + 1) acc)
                 (: t <h e2 <>h k (i + 1 + #t) e (e2 - 1)
                    nm (hattr s k e "name") v (hval s k e "value")
                    (? !(<>>h && string? nm) (go e2 acc)
                       (t = "input")
                        (: y (hattr s k e "type") ty (? (string? y) (hlow y) "text")
                           (go e2 (? (ty = "hidden") ([i 'fix nm v ""] . acc)
                                     (elem ty '("checkbox" "radio"))
                                      (? (hflag s k e "checked") ([i 'fix nm (? #v v "on") ""] . acc) acc)
                                     (ty = "submit") ([i 'sub nm v ""] . acc)
                                     (elem ty '("image" "reset" "button" "file")) acc
                                     ([i 'text nm v (? #v v (: p (hval s k e "placeholder") (? #p p nm)))] . acc))))
                       (t = "textarea")
                        (: z2 (hpast s e2 t)
                           c (hdec (snip s e2 ((: (g j) (? (j <= e2) e2 (s j = 60) j (g (j - 1)))) (z2 - 1))))
                           (go z2 ([i 'text nm c (? #c c nm)] . acc)))
                       (t = "select") (: z2 (hpast s e2 t) (go z2 ([i 'fix nm (hopt s e2 z2) ""] . acc)))
                       (t = "button")
                        (: y (hattr s k e "type")
                           (go e2 (? (!(string? y) || hlow y = "submit") ([i 'sub nm v ""] . acc) acc)))
                       (go e2 acc))))))
       (go i ()))
   ; a get form -> a tablet of its text fields' links by where each tag starts. a field is a
   ; link to form: + the action + ? + every other control's pair + its own name=value, so a
   ; browser sends what was typed by putting it in place of what follows that last =. the
   ; first submit button goes too, as return in a field sends it. a post form lays no field
   (hform s k e0 e)
    (: m (hattr s k e0 "method") t (tablet 0)
       (? (string? m && hlow m != "get") t
          (: a (hval s k e0 "action")
             act (: j ((: (g j) (? (#a <= j || elem (a j) '(35 63)) j (g (j + 1)))) 0)
                    (hesc [[34 "%22"] [38 "%26"] [60 "%3C"]] (snip a 0 j)))
             cs (hctls s e (hpast s e "form"))
             sub (: l (filter (c \ c 1 = 'sub) cs) (? (two? l) [<l] ()))
             kept (filter (c \ c 1 != 'sub) cs)
             (pair c) (hpe (c 2) + "=" + hpe (c 3))
             (link c) (: ot (map pair (filter (d \ <d != <c) kept + sub))
                         lb (c 4)
                         ("<a href=\"form:" + act + "?" + cats (map (x \ x + "&") ot) + pair c + "\">["
                          + hq lb + rep "_" (12 - #lb) + "]</a>"))
             _ (map (c \ pin t <c (link c)) (filter (c \ c 1 = 'text) kept))
             t)))
   ; an image is its alt text, bracketed, as lynx shows it; one with none is not there
   (halt s k e)
    (: v (hattr s k e "alt")
       (? (string? v && 0 < #v) ("[" + hesc [[60 "&lt;"]] v + "]") ""))
   ; ..and a mark " img SRC" ahead of it, on the line a viewer can draw it under
   (himg s k e) (: v (hval s k e "src") ((? (0 < #v) (hmk (" img " + v)) "") + halt s k e))
   ; s with each byte the table names spelled its way
   (hesc tb s)
    (: o (jug 0)
       (go i) (? (#s <= i) (slurp o)
                 (: c (s i) r ((: (g l) (? (one? l) () (<(<l) = c) <>(<l) (g >l))) tb)
                    _ (? r (say o r) (put o c))
                    (go (i + 1))))
       (go 0))
   ; an id is the other attribute the middle keeps: it becomes a mark, inside a tag whose
   ; content is a line and ahead of any other. `ba` is 1 while an <a> with no href is open:
   ; that is an anchor, not a link, so its tags go and only its mark and its text stay.
   (htscrub s)
    (:- (go 0 0) n #s o (jug 0) fs (pin (tablet 0) 'f (tablet 0))
     (field i) (peep (fs 'f) i "")
     (go i ba)
      (? (n <= i) (slurp o)
         (i + 3 < n && s i = 60 && s (i + 1) = 33 && s (i + 2) = 45 && s (i + 3) = 45)
          (go (hfind s (i + 4) "-->") ba)
         (i + 1 < n && s i = 60 && s (i + 1) = 33)                       ; <!doctype ..>
          (go ((: (g k) (? (n <= k) k (s k = 62) (k + 1) (g (k + 1)))) (i + 1)) ba)
         (: h (htag s i)
            (? (one? h) (put o (s i), go (i + 1) ba)
               (: t <h e <>h op? <>>h
                  k (i + 1 + #t)
                  mk (? op? (hmk (hattr s k (e - 1) "id") + hmain s t k (e - 1)) "")
                  (? (t = "form") (: _ (pin fs 'f (? op? (hform s k (e - 1) e) (tablet 0))) (say o mk, go e ba))
                     (t = "input") (say o (mk + field i), go e ba)
                     (t = "textarea") (say o (mk + field i), go (? op? (hpast s e t) e) ba)
                     (t = "img") (say o (mk + (? op? (himg s k (e - 1)) "")), go e ba)
                     (elem t hkill) (go (? op? (hpast s e t) e) ba)
                     (elem t hbare) (say o mk, go e ba)
                     (t = "br") (say o "</p><p>", go e ba)
                     ; a link is the one tag whose attribute the middle keeps, so it is
                     ; normalized to the shape the reader knows: href alone, and first
                     (t = "a") (: v (op? && hattr s k (e - 1) "href")
                                  m2 (? #mk mk op? (hmk (hattr s k (e - 1) "name")) "")
                                (? !op? (say o (ba ? "" "</a>"), go e 0)
                                   (string? v) (say o (m2 + "<a href=\"" + v + "\">"), go e 0)
                                   (say o m2, go e 1)))
                     (: a (halias? t)
                      (say o $ op? ? (: tg ("<" + a + snip s k (e - 1) + ">")
                                        (elem a hinside ? (tg + mk) (mk + tg)))
                                     ("</" + a + ">"),
                       go e ba)))))))))

; ---------------------------------------------------------------- html, read
; an open tag may carry attributes -- `<h1 id="x">` is the same head as `<h1>`, and a page
; not written by htshow always carries some. accepting them costs law 1 nothing: htshow
; emits none, so its own output always takes the bare branch.
(: (otag t)    (alts [(lit ("<" + t + ">"))
                      (seqs [(lit ("<" + t)) (one ws?) (span (!= 62)) (lit ">")])])
   (ctag t)    (lit ("</" + t + ">"))
   hws         (skip (span ws?))
   (wrapt t a) (seqs [(skip (otag t)) a hws (skip (ctag t))])
   (hraw? c)   (c != 60 && c != 38)                        ; ordinary text runs to the next < or &

   (hname? c)  ((96 < c < 123) || (64 < c < 91) || (47 < c < 58) || c = 35)
   ; an & that starts no entity is itself -- a query's a=1&b=2, or "fish & chips"
   hent    (alts [(tag (\ p ['text (entof <p)]) (seqs [(skip (lit "&")) (span hname?) (skip (lit ";"))]))
                  (tag (const '(text "&")) (lit "&"))])
   htext   (tag (\ p ['text (cats p)]) (seq (one hraw?) (span hraw?)))
   hcode   (tag (\ p ['code (plain <p)]) (wrapt "code" (pack (many (alts [hent htext])))))
   hmark   (tag (\ p ['mark (plain (runp (many (alts [hent htext])) <p))])
                (seqs [(skip (lit "<a id=\"")) (span (!= 34)) (skip (lit "\"></a>"))]))
   ; the inline cycle (htinl -> strong/em/link -> htinl) rides eta-expanded parsers
   (hstrong s y n) ((tag (\ p ['strong <p]) (wrapt "strong" (pack htinl))) s y n)
   (hem s y n)     ((tag (\ p ['em <p]) (wrapt "em" (pack htinl))) s y n)
   ; ..the href is entity-decoded by running the same two text leaves over it
   (hlink s y n)   ((tag (\ p ['link <>p (plain (runp (many (alts [hent htext])) <p))])
                         (seqs [(skip (lit "<a href=\"")) (span (!= 34)) (skip (lit "\">"))
                                (pack htinl) (skip (lit "</a>"))])) s y n)
   (htinl s y n)   ((pmap mrg (many (alts [hent hcode hstrong hem hmark hlink htext]))) s y n)

   (hlev n)  (tag (\ p ['head n <p]) (wrapt ("h" + show n) (pack htinl)))
   hlang     (seqs [(skip (lit " class=\"language-")) (span (!= 34)) (skip (lit "\""))])
   h-rule  (tag (const '(rule)) (lit "<hr>"))
   h-head  (alts (map hlev '(1 2 3 4 5 6)))
   h-para  (tag (\ p ['para <p]) (wrapt "p" (pack htinl)))
   h-fence (tag (\ p ['fence <p (plain <>p)])
                (seqs [(skip (lit "<pre><code")) (dflt hlang "") (skip (lit ">"))
                       (pack (many (alts [hent htext]))) (skip (lit "</code></pre>"))]))
   h-li    (seqs [hws (wrapt "li" (pack htinl))])
   h-ul    (tag (\ p ['bullets p]) (wrapt "ul" (many h-li)))
   h-ol    (tag (\ p ['numbers p]) (wrapt "ol" (many h-li)))
   h-meta1 (tag (\ p [(name <p) (plain (runp (many (alts [hent htext])) <>p))])
                (seqs [hws (skip (lit "<meta name=\"")) (span (!= 34))
                       (skip (lit "\" content=\"")) (span (!= 34)) (skip (lit "\">"))]))
   h-meta  (tag (\ p ['meta (mnorm p)]) (many1 h-meta1))
   h-dt    (seqs [hws (wrapt "dt" (pack htinl)) hws (wrapt "dd" (pack htinl))])
   h-dl    (tag (\ p ['deflist (dpair p)]) (wrapt "dl" (many h-dt)))
   ; a table: the cells inline, th or td alike, an alignment off htshow's own attribute
   ; and none off any other; the head is the first row, whichever section held it
   (hcellp t) (alts ((map (a \ tag (c \ [a <c]) (seqs [hws (skip (lit ("<" + t + hal a + ">"))) (pack htinl) (skip (ctag t))]))
                         '(l c r))
                     + [(tag (c \ ['n <c]) (seqs [hws (skip (otag t)) (pack htinl) (skip (ctag t))]))]))
   h-tr    (pack (seqs [hws (skip (otag "tr")) (many (alts [(hcellp "th") (hcellp "td")])) hws (skip (ctag "tr"))]))
   (h-tsec t) (seqs [hws (skip (otag t)) (many h-tr) hws (skip (ctag t))])
   h-table (tag (\ p (: hd <p w #hd
                         ['table (map cap hd) (map (c \ <>c) hd) (map (r \ tfit w (map (c \ <>c) r)) >p)]))
                (pwhen (p \ two? p && two? <p)
                       (wrapt "table" (many (alts [(h-tsec "thead") (h-tsec "tbody") (h-tsec "tfoot") h-tr])))))
   ; the last resort, and the reason `many h-block` never stalls: a tag no block above could
   ; place is dropped, and what it wrapped is left to be read on its own. without it `runp`
   ; -- which is lenient -- keeps what it parsed and drops the rest of the page in silence,
   ; so a page that opened with anything unexpected parsed to NOTHING at all. it cannot fire
   ; on what htshow writes, so law 1 does not feel it; and it sits ahead of h-quote because
   ; a value binding after that lambda is not one h-block can see.
   ; one closer is exempt, for the reason the roff reader exempts three: `many h-block`
   ; runs inside the block waiting for it, and eating </blockquote> there starves the quote
   ; and loses the whole of it. h-quote is the ONLY place `many h-block` appears, so it is
   ; the only closer that needs this -- every other one is consumed by the inline or item
   ; parser that opened it, and a </a> arriving HERE is an orphan whose opener never
   ; matched. exempting those too is what made a page of <a accesskey=..> tags stall.
   h-close (lit "</blockquote>")
   h-lone  (skip (seqs [(notp h-close) (lit "<") (span (!= 62)) (lit ">")]))
   ; ..and text with no <p> around it is still a paragraph. unwrapping a container leaves
   ; its inline content bare at block level, which is where most of a real page's prose
   ; turns out to live; `many1` is what keeps it from matching nothing and looping.
   h-loose (tag (\ p ['para <p])
                (pack (pmap mrg (many1 (alts [hent hcode hstrong hem hmark hlink htext])))))
   ; quote recurses into the block loop, so it sits with it and stays eta-expanded
   (h-quote s y n) ((tag (\ p ['quote <p]) (wrapt "blockquote" (pack (many h-block)))) s y n)
   (h-block s y n)
    ((seqs [hws (alts [h-rule h-head h-fence h-quote h-ul h-ol h-dl h-table h-meta h-para h-loose h-lone])]) s y n)
   (htread t) (bmrg (runp (seqs [(many h-block) hws]) (htscrub t))))

; ---------------------------------------------------------------- a table, laid out
; roff and the terminal both show a table as its columns in plain text: a cell's words, the
; columns padded to their widest by the alignment, two spaces between, a dashed rule under
; the head. a width is counted in characters, not bytes -- a mark like a check is three --
; and a place ttlinks marked rides in its sentinels (bytes 1 and 2), which have none.
(: (tplain l) (catmap (x \ <x @ 'text <>x 'code <>x 'strong (tplain <>x) 'em (tplain <>x)
                            'link (tplain <>x) 'tmark (string 1 + <>x + string 2) "") l)
   (tvw s) ((: (g i n) (? (#s <= i) n
                          (s i = 1) (g ((: (h k) (? (#s <= k || s k = 2) (k + 1) (h (k + 1)))) i) n)
                          (g (i + 1) (? (128 <= s i && s i < 192) n (n + 1))))) 0 0)
   (tpad a w s) (: k (w - tvw s)
                   (? (k < 1) s (a = 'r) (rep " " k + s)
                      (a = 'c) (rep " " (k // 2) + s + rep " " (k - k // 2)) (s + rep " " k)))
   (tblines x)
    (: al (x 1) rows ((map tplain (x 2)) . (map (r \ map tplain r) (x 3)))
       ws (foldl (\ a r (map (p \ max <p <>p) (zipm a (map tvw r)))) (map (_ \ 0) (x 1)) rows)
       (line r) (: (g as wz cs) (? (one? cs) "" (: c (tpad <as <wz <cs)
                                                   (? (one? >cs) c (c + "  " + g >as >wz >cs))))
                   (g al ws r))
       (strip s) (: (b j) (? (0 < j && s (j - 1) = 32) (b (j - 1)) j) (snip s 0 (b #s)))
       ([(strip (line <rows)) (join "  " (map (n \ rep "-" n) ws))] + map (r \ strip (line r)) >rows)))

; ---------------------------------------------------------------- roff (man), show
; man macros carry sections two deep, literal blocks with no language, and no rule or
; hyperlink at all -- the domain law 1 holds on, and the four normalizations outside it,
; are in the header.
(: (rq s) ((: (g i acc)
              (? !(i < #s) acc
                 (: hit (rqat s i)
                    (? (two? hit) (g (i + <>hit) (acc + "\\(" + <hit))
                       (: c (s i) (g (i + 1) (acc + (c @ 92 "\\e" 45 "\\-" (string c)))))))))
           0 "")
   (rline s) (#s && (s 0 = 46 || s 0 = 39) ? ("\\&" + s) s)       ; a leading . or ' is text
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
                  'code   ("\\f(CR" + rq <>x + "\\fR")     ; cr, not the deprecated cw: groff warns on that
                  'strong ("\\fB" + rfi <>x + "\\fR")
                  'em     ("\\fI" + rfi <>x + "\\fR")
                  'link   (rfi <>x + " \\(la" + rq <>>x + "\\(ra")
                  "")
   (rth kvs)   (".TH" + cats (map (k \ " \"" + mget kvs k + "\"") metakeys) + "\n")
   (rnums l i) (atom? l ? "" (".IP \"" + show i + ".\" 4\n" + rline (rfi <l) + "\n" + rnums >l (i + 1)))
   (rdefs l)   (catmap (it \ ".TP\n" + rline (rfi <it) + "\n" + rfill (rfi <>it)) l)
   ; roff has no cells here: a table that fits a page is its laid columns as a display,
   ; and a wider one each row a paragraph of head: cell lines, which the page can fill
   (rcell hc) (? (0 < #<hc) (<hc + ": " + tplain <>hc) (tplain <>hc))
   (rrow hd r) (".PP\n" + join "\n.br\n" (map (hc \ rline (rq (rcell hc))) (zipm hd r)) + "\n")
   (rtable x)
    (: ls (tblines x)
       (? (foldl (\ a l (a && tvw l <= 78)) 1 ls) (rfb ['fence "" (catmap (ln \ ln + "\n") ls)])
          (: hd (map tplain (x 2)) (catmap (r \ rrow hd r) (x 3)))))
   (rfb x) (<x @ 'meta    (rth <>x)
                 'head    ((<>x < 2 ? ".SH " ".SS ") + rfi <>>x + "\n")
                 'para    (".PP\n" + rfill (rfi <>x))
                 'fence   (".EX\n" + cats (map (ln \ rline (rq ln) + "\n") (splitnl <>>x)) + ".EE\n")
                 'quote   (".PP\n.RS\n" + rfshow <>x + ".RE\n")   ; the .pp spaces the display
                 'bullets (catmap (i \ ".IP \\(bu 2\n" + rline (rfi i) + "\n") <>x)
                 'numbers (rnums <>x 1)
                 'deflist (rdefs <>x)
                 'table   (rtable x)
                 "")                                        ; a rule has no roff form: it vanishes
   (rfshow d) (catmap rfb d))

; ---------------------------------------------------------------- roff (man), scrubbed
; a page in the wild opens with a preamble the reader has no use for: pod2man and sphinx
; define their own macros, guard them with conditionals, and leave comments and index calls
; all through the body. none of that is a block, so the parser would read it as paragraph
; text. the scrub is line-oriented because what it removes is: a .de runs to a lone `..`,
; a conditional group runs to the \} that closes it, and a request is one line -- none of
; them a shape a combinator sees without carrying state the rest of the reader does not want.
; what it cannot do is honour a condition: `.if n` and `.if t` both go, so a page that spells
; one passage twice loses both. no page in the corpus does that outside its preamble.
(: rfskip '(".IX" ".PD" ".ds" ".as" ".nr" ".rr" ".tm" ".ad" ".na" ".hy" ".nh" ".ne" ".ft"
            ".fam" ".ll" ".ps" ".vs" ".lf" ".hw" ".in" ".ti" ".rm" ".rn" ".cc" ".c2" ".eo"
            ".ec" ".sy" ".do" ".it" ".pl" ".po" ".mk" ".rt" ".ns" ".rs" ".UC" ".DT" ".tr"
            ".char" ".fc" ".so" ".nop" ".ev" ".di" ".wh" ".pso" ".blm" ".shift" ".return")
   ; the macros a generator defines for itself, read as the stock ones they stand for
   rfsame '((".Sp" ".sp") (".Vb" ".nf") (".Ve" ".fi") (".P" ".PP") (".HP" ".PP")
            (".Pp" ".PP") (".INDENT" ".RS") (".UNINDENT" ".RE") (".Ip" ".IP") (".IPs" ".IP"))
   rfdef  '(".de" ".de1" ".am" ".am1")
   rfcond '(".if" ".ie" ".el")
   ; the macro name: up to the first blank or \, so `.el\{\` names .el the way groff reads it
   (rfmac ln) ((: (g i) (? (#ln <= i) (snip ln 0 i)
                           (elem (ln i) '(32 9 92)) (snip ln 0 i)
                           (g (i + 1)))) 0)
   (rfas m)   ((: (g l) (? (one? l) m (<<l = m) <><l (g >l))) rfsame)
   ; the \{ groups one line opens, less the ones it closes; a lone \} floors at none open
   (rfdepth ln d)
    ((: (g i k) (? (#ln <= i) (? (k < 0) 0 k)
                   (ln i = 92 && i + 1 < #ln && ln (i + 1) = 123) (g (i + 2) (k + 1))
                   (ln i = 92 && i + 1 < #ln && ln (i + 1) = 125) (g (i + 2) (k - 1))
                   (g (i + 1) k))) 0 d)
   ; a no-break control character is the same macro, so ' normalizes to .
   (rfdot ln) (#ln && ln 0 = 39 ? ("." + snip ln 1 #ln) ln)
   ; nroff is what a terminal is, so `.if n` is OUR branch and its text is the page's;
   ; `.if t` is the typesetter's and goes. the answer is the text to read in this line's
   ; place, "" for the branch not taken, or 'no for a condition this cannot decide -- an
   ; expression, or one opening a \{ group, where the branch is a block and not a line's
   ; tail. an .el is always 'no: the .ie it answers is not remembered, so a page that
   ; spells the terminal branch second still loses it, as it did before any of this.
   (rfnro ln)
    (: r (snip ln #(rfmac ln) #ln)
       n #r
       i ((: (g k) (? (n <= k) k !(elem (r k) '(32 9)) k (g (k + 1)))) 0)
       (? (rfmac ln = ".el") 'no                         ; an .el carries no condition at all
          (rfdepth ln 0) 'no
          !((i + 1 < n) && elem (r (i + 1)) '(32 9)) 'no
          (r i = 110) (snip r (i + 2) n)
          (r i = 116) ""
          'no))
   (rfcom? ln) (2 < #ln && ln 0 = 46 && ln 1 = 92 && ln 2 = 34)
   ; a macro line's first argument, bare or "quoted"
   (rffst ln)
    (: n #ln
       (go i) (? (n <= i) ""
                 (elem (ln i) '(32 9)) (go (i + 1))
                 (ln i = 34) ((: (h k) (? (n <= k || ln k = 34) (snip ln (i + 1) k) (h (k + 1)))) (i + 1))
                 ((: (h k) (? (n <= k || elem (ln k) '(32 9)) (snip ln i k) (h (k + 1)))) i))
       (go #(rfmac ln)))
   (rfdigs? a) (#a && ((: (g i) (? (#a <= i) 1 (dig? (a i)) (g (i + 1)) 0)) 0))
   (rfbul? a)  (elem a '("\\(bu" "\\(em" "\\-" "•" "-" "*" "o"))
   (rfnum? a)  (: n #a (1 < n && elem (a (n - 1)) '(46 41) && rfdigs? (snip a 0 (n - 1))))
   ; .IP is three blocks under one macro: a bullet, a numbered item, or a tagged paragraph.
   ; a tagged paragraph is what .TP already spells, so it becomes one and the reader needs no
   ; new block for it -- and without this the tag is skipped with the rest of the .IP line,
   ; which on a pod2man page is every option name in the file. a bare .IP, or one carrying
   ; only the indent it wants, tags nothing and is a paragraph.
   (rfip ln)
    (: a (rffst ln)
       (? (!#a || rfdigs? a) ".PP\n"
          (rfbul? a) ".IP \\(bu\n"
          (rfnum? a) (".IP \"" + a + "\"\n")
          (".TP\n" + (#a && a 0 = 46 ? ("\\&" + a) a) + "\n")))
   ; what a page opened and did not close, closed for it. the reader's block loop leaves a
   ; display and a quote closer alone -- the block waiting for one would starve otherwise --
   ; so an unmatched one has nothing that can consume it and the page truncates there. that
   ; makes balance the scrub's job: a second .nf is the no-op groff reads it as, a .RE with
   ; no .RS goes, and whatever is still open at the end is shut here.
   (rfshut nf rs) ((nf ? ".fi\n" "") + rep ".RE\n" rs)
   ; a macro the page defined for itself: we dropped the .de that says what it does, but its
   ; arguments are still its content, and they are the difference between a word rendered
   ; without its quotes and a line that is not in the page at all
   (rfown ln) (: r (rffst ln) (!#r ? "" ((r 0 = 46 ? ("\\&" + r) r) + "\n")))
   (rfscrub s)
    ((: (go l de nf d rs defs acc)
        (one? l ? (cats (rev acc) + rfshut nf rs)
           (: ln (rfdot <l) m (rfmac ln)
              ; a .de body runs to a lone .. -- and ONLY to that. a lone . is an empty
              ; request, and so is any line whose name is blank (`.  if t ..`, which roff
              ; indents inside a definition), so ending the body on one leaks the rest of
              ; the definition into the page, .. included
              (? de       (go >l !(m = "..") nf d rs defs acc)
                 (0 < d)  (go >l de nf (rfdepth ln d) rs defs acc)         ; a conditional group
                 ; a comment, and a bare \ -- a continuation with nothing on it, which some
                 ; generators leave at the head of a page and which shows as text otherwise
                 (rfcom? ln || ln = "\\") (go >l de nf d rs defs acc)
                 (elem m rfdef) (go >l 1 nf d rs ("." + rffst ln . defs) acc)
                 ; the branch this device takes is read in the condition's place, so a macro
                 ; there is still a macro and the text is still text
                 (elem m rfcond)
                  (: k (rfnro ln)
                     (? (= k 'no) (go >l de nf (rfdepth ln 0) rs defs acc)
                        !#k       (go >l de nf d rs defs acc)
                        (go (k . >l) de nf d rs defs acc)))
                 (m = "." || elem m rfskip) (go >l de nf d rs defs acc)
                 (: m2 (rfas m) rest (snip ln #m #ln)
                    ; .sp is a blank line inside a display and a paragraph break outside one
                    (? (m2 = ".sp") (go >l de nf d rs defs ((nf ? "\n" ".PP\n") . acc))
                       (m2 = ".IP" && !nf) (go >l de nf d rs defs (rfip ln . acc))
                       (elem m2 '(".nf" ".EX"))
                        (go >l de 1 d rs defs (nf ? acc ((m2 + "\n") . acc)))
                       (elem m2 '(".fi" ".EE"))
                        (go >l de 0 d rs defs (nf ? ((m2 + "\n") . acc) acc))
                       (m2 = ".RS") (go >l de nf d (rs + 1) defs ((m2 + rest + "\n") . acc))
                       (m2 = ".RE") (? rs (go >l de nf d (rs - 1) defs ((m2 + "\n") . acc))
                                        (go >l de nf d rs defs acc))
                       (elem m defs) (go >l de nf d rs defs (rfown ln . acc))
                       (go >l de nf d rs defs ((m2 + rest + "\n") . acc))))))))
     (splitnl s) 0 0 0 0 () ()))

; ---------------------------------------------------------------- roff (man), read
; roff FILLS, which is why this reader is line-oriented where the html one is tag-oriented:
; consecutive input lines join with a space, a font macro's arguments with nothing (the
; alternating .BR/.RB/.IR/.RI) or with a space (.B/.I) -- all three probed under groff. a
; paragraph is a run of lines, each an inl fragment, and a block macro ends the run. the
; macros a hand-written page uses are read, not just the escapes rfshow emits.
(: rfesc? (!= 92)                                       ; ordinary inline text runs to the next \
   rclose    (alts [(lit "\\fR") (lit "\\fP")])                ; \fP is "previous font" -- same thing here
   rgl     (tag (\ p ['text (glyph (string <p + string <>p))])
                (seqs [(skip (lit "\\(")) (one chr?) (one chr?)]))
   ; the escapes that carry an argument in quotes -- a device call, a motion, a rule. none
   ; of them has a terminal form, so each contributes nothing and takes its argument with
   ; it; without that the argument reads as text and a link's url lands in the page.
   rdropq  (tag (const '(text ""))
                (alts (map (c \ seqs [(lit ("\\" + c)) (lit "'") (span (!= 39)) (lit "'")])
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
   rstrg   (tag (\ p ['text (rstr (string <p + string <>p))])
                (seqs [(skip (lit "\\*(")) (one chr?) (one chr?)]))
   rstrb   (tag (\ p ['text (rstr <p)]) (seqs [(skip (lit "\\*[")) (span (!= 93)) (skip (lit "]"))]))
   rstr1   (tag (\ p ['text (rstr (string <p))]) (seqs [(skip (lit "\\*")) (one chr?)]))
   rglb    (tag (\ p ['text (glyph <p)]) (seqs [(skip (lit "\\[")) (span (!= 93)) (skip (lit "]"))]))
   ; and the bare ones: a mark, a hyphenation point, a thin space -- all of them nothing here
   rnone   (tag (const '(text ""))
                (alts (map (c \ lit ("\\" + c)) '("%" ":" "," "/" "|" "^" "{" "}" "c" "d" "u" "z" "p"))))
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
   rtext  (tag (\ p ['text (cats p)]) (seq (one rfesc?) (span rfesc?)))
   ; ..a \ starting none of the above reads as literal text one char at a time, `mrg` gluing
   ; it back on. without it the reader stops dead at the first escape it does not model.
   rchar   (tag (\ p ['text (string <p)]) (one chr?))
   rcode   (tag (\ p ['code (plain <p)])
           (seqs [(skip (alts [(lit "\\f(CR") (lit "\\f(CW")]))   ; cw is groff-deprecated, still read
                  (pack (many (seq (notp rclose) (alts [resc rtext rchar])))) (skip rclose)]))
   ; the font cycle (span -> strong/em -> rfont -> rinls -> span) rides eta-expanded parsers.
   ; the closer is optional because a font runs to one in roff and a page may leave it to the
   ; end of the line; `rinls` stops at either, so `opt` is the whole of the difference.
   (rfont o t) (tag (\ p [t <p]) (seqs [(skip (lit o)) (pack rinls) (skip (opt rclose))]))
   (rstrong s y n) ((rfont "\\fB" 'strong) s y n)
   (rem s y n)     ((rfont "\\fI" 'em) s y n)
   (rspan s y n)   ((alts [resc rcode rstrong rem rtext rchar]) s y n)
   (rinls s y n)   ((pmap mrg (many (seq (notp rclose) rspan))) s y n)
   rfinl   (mrg * runp (many rspan))
   rplain  (plain * mrg * runp (many (alts [resc rtext rchar]))))   ; escapes only, no fonts

; the font macros: which fonts to cycle through, and whether the arguments take a space.
(: (rargs s)                                                  ; a macro's arguments, bare or "quoted"
   ((: (g i acc)
       (? (i >= #s) (rev acc)
          (s i = 32) (g (i + 1) acc)
          (s i = 34) (: j ((: (h k) (k < #s && s k != 34 ? (h (k + 1)) k)) (i + 1))
                      (g (j + 1) (snip s (i + 1) j . acc)))
          ; an escape is two characters and neither of them splits the argument -- `\ ` is a
          ; non-breaking space, and splitting there leaves a lone \ at the end of one
          ; argument and the word it was joining at the head of the next
          (: j ((: (h k) (? (#s <= k) k
                            (s k = 92 && k + 1 < #s) (h (k + 2))
                            (s k = 32) k
                            (h (k + 1)))) i)
           (g j (snip s i j . acc))))) 0 ())
   fontmacs '((".BR" (strong text) 0) (".RB" (text strong) 0) (".IR" (em text) 0)
              (".RI" (text em) 0) (".BI" (strong em) 0) (".IB" (em strong) 0)
              (".SB" (strong) 1) (".SM" (text) 1) (".B" (strong) 1) (".I" (em) 1))
   (macinfo m) ((: (g l) (? (one? l) () (<<l = m) ><l (g >l))) fontmacs)
   (wrapf f l) (f @ ('strong || 'em) [[f l]] l)
   (allplain? l) (? (one? l) 1 (<<l = 'text) (allplain? >l) 0)
   (argl a f)    (rfinl a @ l (allplain? l ? (wrapf f l) l))     ; an explicit \f inside the arg wins
   (argls as fs i sp) (two? as ?
                       (: h (argl <as (fs (i % #fs)))
                        (one? >as ? h
                           (h + (? sp '((text " ")) ()) + argls >as fs (i + 1) sp))))
   (imacl line) (: a (rargs line) m (? (two? a) <a "") info (macinfo m)
                 (one? info ?  (rfinl line)
                  (mrg (argls (rargs (snip line #m #line)) <info <>info 0))))
   (linl line)  (#line && line 0 = 46 ? (imacl line) (rfinl line)))

; the block layer: a run of fill lines is a paragraph, a block macro ends it.
(: blockmac (alts [(lit ".TH") (lit ".SH") (lit ".SS") (lit ".PP") (lit ".LP") (lit ".TP")
                   (lit ".RS") (lit ".RE") (lit ".EX") (lit ".EE") (lit ".IP") (lit ".br") (lit ".nf") (lit ".fi")])
   rfline    (seqs [(span nonl?) (skip (lit "\n"))])
   (rmacl m) (seqs [(skip (lit m)) (skip (span sp?)) (span nonl?) (skip (lit "\n"))])
   (r-fline s y n)  ((tag (linl * cats)
                          (seqs [(notp blockmac) (one nonl?) (span nonl?) (skip (lit "\n"))])) s y n)
   (joinfr (a . u)) (one? u ? a (a + '((text " ")) + (joinfr u)))
   r-filled (tag (mrg * joinfr) (many1 r-fline))

   r-th   (tag (\ p ['meta (mnorm (zipm metakeys (rargs <p)))]) (rmacl ".TH"))
   r-sh   (tag (\ p ['head 1 (rfinl (join " " (rargs <p)))]) (rmacl ".SH"))
   r-ss   (tag (\ p ['head 2 (rfinl (join " " (rargs <p)))]) (rmacl ".SS"))
   ; a .pp with no filled run behind it spaces a display; `opt` gives it an empty payload,
   ; so it contributes no block.
   r-pp   (seqs [(skip (alts [(lit ".PP") (lit ".LP")])) (skip (span nonl?)) (skip (lit "\n"))
                 (opt (tag (\ p ['para <p]) r-filled))])
   r-para (tag (\ p ['para <p]) r-filled)      ; text with no .pp -- after a .SH
   r-tp   (tag (\ p [<p <>p])
               (seqs [(skip (lit ".TP")) (skip (span nonl?)) (skip (lit "\n")) r-fline r-filled]))
   r-dl   (tag (\ p ['deflist p]) (many1 r-tp))
   r-bu   (seqs [(skip (lit ".IP \\(bu")) (skip (span nonl?)) (skip (lit "\n")) r-filled])
   r-ul   (tag (\ p ['bullets p]) (many1 r-bu))
   r-no   (seqs [(skip (lit ".IP")) (skip (span nonl?)) (skip (lit "\n")) r-filled])
   r-ol   (tag (\ p ['numbers p]) (many1 r-no))
   r-ex   (tag (\ p ['fence "" (catmap (ln \ rplain ln + "\n") p)])
               (seqs [(skip (alts [(lit ".EX") (lit ".nf")])) (skip (span nonl?)) (skip (lit "\n"))
                      (many (seq (notp (alts [(lit ".EE") (lit ".fi")])) rfline))
                      (skip (alts [(lit ".EE") (lit ".fi")])) (skip (span nonl?)) (skip (lit "\n"))]))
   r-br    (skip (seqs [(lit ".br") (span nonl?) (lit "\n")]))   ; a break ends the run
   r-blank (skip (seqs [(span sp?) (lit "\n")]))
   ; the last resort, and the reason `many r-block` never stalls: a macro line no block above
   ; could place contributes nothing. without it `runp` -- which is lenient -- keeps what it
   ; parsed and drops the whole rest of the page in silence, so one unplaced .RE truncates it.
   ; the closers are exempt: this runs inside the `many` of the block that is waiting for one,
   ; so eating .RE there would starve the quote and lose the whole of it. it cannot fire on
   ; what rfshow writes, so law 1 does not feel it -- and it sits ahead of r-rs because a
   ; value binding after that lambda is not one r-block can see.
   r-close (alts [(lit ".RE") (lit ".EE") (lit ".fi")])
   r-lone  (skip (seqs [(notp r-close) (lit ".") (span nonl?) (lit "\n")]))
   ; .rs recurses into the block loop, so it sits with it and stays eta-expanded
   (r-rs s y n) ((tag (\ p ['quote p])
                      (seqs [(skip (lit ".RS")) (skip (span nonl?)) (skip (lit "\n"))
                             (many r-block) (skip (lit ".RE")) (skip (span nonl?)) (skip (lit "\n"))])) s y n)
   (r-block s y n) ((alts [r-blank r-br r-th r-sh r-ss r-pp r-ex r-rs r-ul r-ol r-dl r-para r-lone]) s y n)
   rfread (bmrg * runp (many r-block) * rfscrub))   ; the scrub runs first: see above

; ---------------------------------------------------------------- a terminal, shown
; the fourth surface, and the one that is not a lens: a terminal is where a document is
; read, never where one is kept, so there is no ttread and law 1 has nothing to say. that
; is why it is not a row in `surfaces` -- a row owes law 1 and this cannot pay it. it takes
; the width because filling is the whole of the job, and answers one string of lines.
;
; the shape is man's, measured against man-db 2.13 rather than remembered: a .SH flush left,
; body at 5, a .SS at 3, a tagged term at the body indent with its definition 7 further in,
; and a quote 4 further in again. a display is not filled -- it is already laid out, and a
; pager scrolls sideways better than a shower guesses.
;
; a word carries its own escapes: bold opens and closes inside the word, never across the
; space between two. that costs a few bytes on a run of bold words and buys the thing that
; matters -- no wrap, here or in a pager that wraps again at its own width, can ever cut an
; attribute away from the reset that ends it.
(: ttesc  (string 27)
   ttmk0  (string 1)                                          ; a mark's sentinel, never text
   ttmk1  (string 2)
   (tton a)  (#a ? (ttesc + "[" + a + "m") "")
   ttoff  (ttesc + "[0m")
   (ttsp n)  (rep " " (n < 0 ? 0 n))
   (ttadd a b) (#a ? (a + ";" + b) b)                        ; a nested attribute joins the outer
   ; an inl -> [text attribute] runs. code stays plain: roman is what a terminal shows for it
   (ttsegs l a)
    (? (one? l) ()
       (: x <l
          (<x @ 'text   ([[<>x a]] + ttsegs >l a)
                'code   ([[<>x a]] + ttsegs >l a)
                'strong ((ttsegs <>x (ttadd a "1")) + ttsegs >l a)
                'em     ((ttsegs <>x (ttadd a "4")) + ttsegs >l a)
                ; the url trails the text it was on, the way a man page's \(la..\(ra does
                ; -- and an anchor, which has no url, is just its text
                'link   ((ttsegs <>x a) + (#<>>x ? [[(" <" + <>>x + ">") a]] ()) + ttsegs >l a)
                ; ttlinks' own node: a place, laid as a sentinel with no width that ttpage lifts
                'tmark  ([[(ttmk0 + <>x + ttmk1) 'mark]] + ttsegs >l a)
                (ttsegs >l a))))
   ; a run's text at its space breaks; the empty pieces at each end are what lets a word
   ; carry on across a style change with no space between the halves. a newline is a break
   ; like any other -- this fills, and a surface that keeps its own line structure (a fence)
   ; never comes through here. without that a run of whitespace is one enormous WORD, which
   ; wraps to a line of its own and reads as a blank paragraph nobody wrote.
   (ttsplit s)
    ((: (g i st acc) (? (#s <= i) (rev (snip s st i . acc))
                        (elem (s i) '(32 9 10 13)) (g (i + 1) (i + 1) (snip s st i . acc))
                        (g (i + 1) st acc))) 0 0 ())
   ; the runs -> words, each one [visible styled]: the visible half is what a fill measures.
   ; a mark rides the styled half only, onto the next word, or the last where none follows
   (ttwords segs)
    ((: (go l vis sty acc)
        (one? l ? (#vis ? (rev ([vis sty] . acc))
                   (#sty && two? acc) (rev ([<(<acc) (<acc 1 + sty)] . >acc))
                   (rev acc))
         (: s <<l a <><l
            (pc p vis sty acc)
             (one? p ? (go >l vis sty acc)
              (: h <p v2 (vis + h)
                 s2 (sty + (#h ? (#a ? (tton a + h + ttoff) h) ""))
               (one? >p ? (pc >p v2 s2 acc)
                (pc >p "" (#v2 ? "" s2) (#v2 ? ([v2 s2] . acc) acc)))))
          (? (a = 'mark) (go >l vis (sty + s) acc) (pc (ttsplit s) vis sty acc)))))
     segs "" "" ())
   ; greedy fill: the words onto lines of at most (w - ind) visible columns, each indented
   (ttfill words w ind)
    (: pad (ttsp ind)
       room (w - ind @ r (r < 8 ? 8 r))
       (go l vis sty acc)
        (? (one? l) (#vis ? (rev ((pad + sty) . acc)) (rev acc))
           (: v <<l s <><l
              (? !#vis (go >l v s acc)
                 (#vis + 1 + #v <= room) (go >l (vis + " " + v) (sty + " " + s) acc)
                 (go >l v s ((pad + sty) . acc)))))
       (go words "" "" ()))
   (ttinl l w ind a) (ttfill (ttwords (ttsegs l a)) w ind)
   ; a marker replaces the head of the first line's indent -- which is spaces, so the byte
   ; arithmetic is the column arithmetic even where the marker itself is not one byte
   (ttmark ls mk ind)
    (? (one? ls) ls
       (: h <ls (((ttsp ind + mk) + snip h (ind + #mk) #h) . >ls)))
   (ttitem l w ind mk) (ttmark (ttinl l w (ind + #mk) "") mk ind)
   ; the .th line: the page either side of its manual, which is what a terminal reader
   ; looks at to know what they opened. it is dropped whole if the width cannot hold it.
   (ttmeta kvs w)
    (: t (mget kvs 'title) sec (mget kvs 'section) mn (mget kvs 'manual)
       l (#sec ? (t + "(" + sec + ")") t)
       gap (w - 1 - 2 * #l - #mn)                          ; the last column stays empty
       lf (gap // 2)
       (? (!#t || gap < 2) (#t ? [l] ())
          [(l + ttsp lf + mn + ttsp (gap - lf) + l)]))
   (ttvis words) ((: (g l a) (one? l ? a (g >l (#a ? (a + " " + <(<l)) <(<l))))) words "")
   ; the term carries whatever fonts the page gave it, so nothing is forced on it here.
   ; a term that fits the gap keeps its definition beside it, which is what .TP does and
   ; what a page of one-letter flags wants; a longer one takes the line to itself. and a
   ; blank between items, without which a long definition runs into the next term.
   (ttdefs l w ind)
    (two? l ?
     (: it <l
        tw (ttwords (ttsegs <it ""))
        tv (ttvis tw)
        tl (ttfill tw w ind)
        bl (ttinl <>it w (ind + 7) "")
        h  (? (#tv && #tv < 7 && one? >tl && two? bl)
              (((ttsp ind + snip <tl ind #(<tl) + ttsp (7 - #tv))
                + snip <bl (ind + 7) #(<bl)) . >bl)
              (tl + bl))
        r  (ttdefs >l w ind)
        (one? r ? h (h + [""] + r))))
   (ttnums l w ind i)
    (two? l ? (ttitem <l w ind (show i + ". ") + ttnums >l w ind (i + 1)))
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
          'rule    [(ttsp ind + rep "-" (? (w - ind < 1) 1 (w - ind)))])
   ; a table the width holds is its columns; one it does not is each row as head: cell
   ; lines, a blank between rows, so no line overruns and nothing is cut
   (tttable x w ind)
    (: ls (tblines x)
       (? ((: (g l) (? (one? l) 1 (w < ind + tvw <l) 0 (g >l))) ls) (map (ln \ ttsp ind + ln) ls)
          (: hd (map tplain (x 2))
             (rw r) (catmap (hc \ ttinl [['text (? (0 < #<hc) (<hc + ": " + tplain <>hc) (tplain <>hc))]] w ind "")
                            (zipm hd r))
             ((: (g rs) (? (one? rs) () (one? >rs) (rw <rs) (rw <rs + [""] + g >rs))) (x 3)))))
   ; one blank line between blocks, none before the first, and none after a heading --
   ; a heading belongs to what follows it, and man sets it that way
   (ttdoc d w ind)
    (? (one? d) ()
       (: h (ttblk <d w ind) r (ttdoc >d w ind)
          (? (one? h) r (one? r) h
             (= <(<d) 'head) (h + r)
             (h + [""] + r))))
   ; a stateful map: f answers [y acc], threaded left to right
   (tlmap f l acc)
    (one? l ? [() acc]
     (: r (f <l acc) s (tlmap f >l (r 1)) [(<r . <s) (s 1)]))
   ; an inl -> [inl acc]: a link with a url becomes [n] and its text, acc the urls newest
   ; first, so n is #acc, and a mark named byte 3 and n goes ahead of it for ttpage to find
   ; the line by. an anchor keeps its node -- no url, nothing to number
   (tlgo l acc)
    (one? l ? [() acc]
     (: x <l
        r (<x @ 'link   (#(x 2) ? (: a ((x 2) . acc) i (tlspans <>x a)
                                     [(['tmark (string 3 + show #a)] . ['text ("[" + show #a + "]")] . <i) (i 1)])
                                  (: i (tlspans <>x acc) [[['link <i (x 2)]] (i 1)]))
                 'em     (: i (tlspans <>x acc) [[['em <i]] (i 1)])
                 'strong (: i (tlspans <>x acc) [[['strong <i]] (i 1)])
                 'mark   [[['tmark <>x]] acc]
                 [[x] acc])
        s (tlgo >l (r 1))
        [(<r + <s) (s 1)]))
   (tlspans l acc) (: r (tlgo l acc) [(mrg <r) (r 1)])     ; the marker joins its text: normal
   (tldef p acc) (: t (tlspans <p acc) b (tlspans <>p (t 1)) [[<t <b] (b 1)])
   (tlblk x acc)
    (<x @ 'head    (: i (tlspans (x 2) acc) [['head <>x <i] (i 1)])
          'para    (: i (tlspans <>x acc) [['para <i] (i 1)])
          'quote   (: d (tlmap tlblk <>x acc) [['quote <d] (d 1)])
          'bullets (: r (tlmap tlspans <>x acc) [['bullets <r] (r 1)])
          'numbers (: r (tlmap tlspans <>x acc) [['numbers <r] (r 1)])
          'deflist (: r (tlmap tldef <>x acc) [['deflist <r] (r 1)])
          'table   (: h (tlmap tlspans (x 2) acc) r (tlmap (tlmap tlspans) (x 3) (h 1))
                      [['table <>x <h <r] (r 1)])
          [x acc])
   ; a paragraph of marks alone lays no line to land on, so its marks move onto the next
   ; block that holds text; past the end of a doc there is none, and they go
   ; ..and so does one whose only text is blank, which is what a page's indenting leaves
   (tlblank? x) (<x = 'text && (: t <>x (g i) (? (#t <= i) 1 (elem (t i) '(32 9 10 13)) (g (i + 1)) 0) (g 0)))
   (tlmarks? l)
    (: (g m k) (? (one? m) k (<(<m) = 'mark) (g >m 1) (tlblank? <m) (g >m k) 0)
       (g l 0))
   (tlonly l) (filter (x \ <x = 'mark) l)
   (tlput x pend)
    (<x @ 'head    ['head <>x (pend + <>>x)]
          'para    ['para (pend + <>x)]
          'bullets (two? <>x ? ['bullets ((pend + <(<>x)) . >(<>x))] ())
          'numbers (two? <>x ? ['numbers ((pend + <(<>x)) . >(<>x))] ())
          'deflist (two? <>x ? ['deflist ([(pend + <(<(<>x))) <>(<(<>x))] . >(<>x))] ())
          'quote   ['quote (tlcarry (['para pend] . <>x))]
          ())
   (tlcarry d)
    ((: (go l pend)
        (? (one? l) ()
           (: x <l
              (? (<x = 'para && tlmarks? <>x) (go >l (pend + tlonly <>x))
                 (: y (? (one? pend) (<x = 'quote ? ['quote (tlcarry <>x)] x) (tlput x pend))
                    (? (one? y) (x . (go >l pend)) (y . (go >l ()))))))))
     d ())
   ; a doc -> [doc urls]: the links numbered in reading order, urls 1-based by that number.
   ; a browser shows the doc and follows (urls (n - 1)); man keeps ttyshow's <url>
   (ttlinks d) (: r (tlmap tlblk (tlcarry d) ()) [<r (rev (r 1))])
   ; the laid text with each mark's sentinel lifted out -> [text anchors], an anchor being
   ; [name line] with the line counted from 0
   (ttlift t)
    (: n #t o (jug 0)
       (go i ln acc)
        (? (n <= i) [(slurp o) (rev acc)]
           (t i = 1) (: e ((: (g k) (? (n <= k || t k = 2) k (g (k + 1)))) (i + 1))
                        (go (e + 1) ln ([(snip t (i + 1) e) ln] . acc)))
           (: c (t i) _ (put o c) (go (i + 1) (c = 10 ? (ln + 1) ln) acc)))
       (go 0 0 ()))
   ; [text urls anchors lines]: what a browser shows, follows, and lands on, and the line
   ; each link was laid on, by n
   (tldig s) ((: (g i v) (? (#s <= i) v (g (i + 1) ((v * 10) + (s i - 48))))) 1 0)
   (ttpage d w)
    (: r (ttlinks d) l (ttlift (ttyshow <r w))
       (lk? a) (0 < #<a && <a 0 = 3)
       t (foldl (\ t a (pin t (tldig <a) <>a)) (tablet 0) (filter lk? <>l))
       [<l (r 1) (filter (a \ !(lk? a)) <>l) (map (i \ peep t (i + 1) -1) ^#(r 1))])
   (ttyshow d w) (catmap (ln \ ln + "\n") (ttdoc d (w < 20 ? 20 w) 5))
   (rf->tty s w) (ttyshow (rfread s) w)
   (md->tty s w) (ttyshow (mdread s) w)
   (ht->tty s w) (ttyshow (htread s) w))

; ---------------------------------------------------------------- the lens
; five surfaces under two hubs. the x86 rows reach the holo book when CALLED, so lapiz owes
; it nothing at bake.
(: surfaces [['md 'doc mdread mdshow] ['ht 'doc htread htshow] ['rf 'doc rfread rfshow]
             ['att 'x86 (s \ cite 'holo 'att-read s) (v \ cite 'holo 'att-show v)]
             ['intel 'x86 (s \ cite 'holo 'intel-read s) (v \ cite 'holo 'intel-show v)]]
   (srow k) ((: (g l) (? (one? l) () (<<l = k) <l (g >l))) surfaces)
   (convert from to s) (: a (srow from) b (srow to)
                          (two? a && two? b && <>a = <>b ? (<>>>b (<>>a s)) 'nolens))
   (md->ht s) (htshow (mdread s))
   (ht->md s) (mdshow (htread s))
   (md->rf s) (rfshow (mdread s))
   (rf->md s) (mdshow (rfread s)))
) ; module lapiz

; a later surface joins the sealed module the runtime way: (borrow 'lapiz), then its own text.
