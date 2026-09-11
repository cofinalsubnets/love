; lapiz -- the document lens: surfaces over one middle. markdown, html and roff(man).
;
; there is no pairwise conversion code. one middle -- a plain love AST -- with a reader
; and a shower per surface, so md->ht is (htshow (mdread s)) and three surfaces make six
; conversions out of six functions. the `surfaces` table is the whole matrix: a row is
; (format hub reader shower), a conversion pairs a reader and a shower under ONE hub, and
; anything else meets the nom 'nolens. a fourth surface adds a row and touches nothing.
; the documents say hub 'doc; the two x86 assembler dialects (l/holo/dialect.l) say 'x86.
;
; --- the lens laws (t/host/lapiz.l proves them) ---
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
; an inl is a list of spans:
;   ('text s)  ('em inl)  ('strong inl)  ('code s)  ('link inl url)
; ('meta ..) is document-level and heads the doc; its keys are the canonical five, always
; all five, absent ones empty (`mnorm`). a doc is normal when no two texts are adjacent in
; an inl (`mrg`) and no two lists of one kind are adjacent in the doc (`bmrg`); every reader
; lands there, or law 1 fails on an AST that reads the same and is spelled two ways. every
; list ends in the unit -- `=` tells the two terminators apart, so a 0 tail fails law 1.
;
; --- the roff domain ---
; man macros are a smaller surface. law 1 holds on man-page-shaped docs: meta, head 1-2,
; para, fence with empty language, quote, bullets, numbers, deflist, and text/strong/em/code
; inline. outside that rfshow stays total and rfread normalizes four ways, each asserted by
; the gate: a head at 3+ lands at 2 (roff has .SH and .SS and no more), a fence language is
; dropped (.EX/.EE has no slot), a rule vanishes, and a link flattens to its text with the
; url trailing in \(la..\(ra.
;
; both readers are built from the parser combinators in l/boot/post.l -- a parser is
; (\ s y n), payloads are lists `seq` concatenates. lapiz adds what that set lacked: `notp`
; (negative lookahead, what a block grammar needs for "a line that starts no other block"),
; `nope`/`alts`, `many1`, and `pack`/`tag`, which build a node out of a flat payload.
;
; a consumer says (borrow 'lapiz), or hands the loader this file's path, and reads bare down
; the splice or reaches one member by accessor: (cite 'lapiz 'md->ht). the six faces are
; mdread/mdshow/htread/htshow/md->ht/ht->md. the head below names the exports and nothing
; else: unwrapped, lapiz puts all ~163 of its names on the session.

(module (lapiz mdread mdshow htread htshow rfread rfshow
         md->ht ht->md md->rf rf->md convert  htb hti hq mget)

; the combinators (l/boot/post.l) -- lapiz wants only the lenient `runp`. inside the
; module, so peg splices for this compile alone.
(borrow 'peg)

; --- little utils ---
(: (joins l sp) (? !(two? l) "" !(two? >l) <l (<l + sp + joins >l sp))
   (rep s n)    (? (n < 1) "" (s + rep s (n - 1)))
   (splitnl s)  ((: (g i st acc) (? (i < #s) (? (s i = 10) (g (i + 1) (i + 1) (snip s st i . acc))
                                                      (g (i + 1) st acc))
                                    (st < i) (rev (snip s st i . acc))
                                    (rev acc)))
                 0 0 ())
   (endnl s)    (tally s && s (tally s - 1) = 10 ? s (s + "\n")))     ; one trailing newline, always


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
   (glyph n)   ((: (g l) (? (one? l) ("\\(" + n) (<<l = n) <><l (g >l))) rglyphs)
   (rqat s i)  ((: (g l) (? (one? l) ()                       ; does a glyph start at i? -> (name len)
                            (: gl <><l n #gl
                             (i + n <= #s && gl = snip s i (i + n) ? [<<l n] (g >l)))))
                rglyphs))

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
   starter   (alts [headmark nummark defmark (lit "```") (lit ">") (lit "- ") (lit "---")])   ; what a paragraph must not be

   b-rule  (tag (\ _ '(rule)) (seqs [(lit "---") (skip (span sp?)) (lit "\n")]))
   b-head  (tag (\ p ['head (1 + #<>p) (mdinl <>>>p)])
                     (seqs [(lit "#") (span hash?) (lit " ") (span nonl?) eol]))
   f-line  (seqs [(notp (lit "```")) (span nonl?) (lit "\n")])       ; ..a fenced line keeps its newline
   b-fence (tag (\ p ['fence <p (cats <>p)])
                     (seqs [(skip (lit "```")) (span nonl?) eol (pack (many f-line))
                            (skip (lit "```")) (skip (span nonl?)) eol]))
   q-line  (seqs [(skip (lit ">")) (skip (opt (lit " "))) (span nonl?) (lit "\n")])
   b-quote (tag (\ p ['quote (mdread (cats <p))]) (pack (many1 q-line)))   ; the doc reads itself
   ; a wrapped item is one item: a line neither blank nor a block opener belongs to the
   ; item above it. `p-line` is already that exact test, so the two readings of "what
   ; continues a block" cannot drift. law 1 is untouched -- a shower writes an item on one
   ; line and a blank line between blocks, so nothing it emits reads as a continuation.
   (litrim s) ((: (g i) (i < #s && sp? (s i) ? (g (i + 1)) (snip s i #s))) 0)
   (lazyj p)  (joins (map litrim p) " ")
   ; a paragraph line must be neither blank nor a block opener -- and must eat a character
   ; (`one nonl?` before the span), else `many` spins forever on the empty tail.
   (p-line s y n)  ((tag cats                      ; ..`tag` does the wrapping; f yields the element
                         (seqs [(notp blankline) (notp starter) (one nonl?) (span nonl?) eol])) s y n)
   u-item  (tag lazyj (seqs [(skip (lit "- ")) (span nonl?) eol (many p-line)]))
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
   (b-para s y n)  ((tag (\ p ['para (mdinl (joins p " "))]) (many1 p-line)) s y n)
   ; the last resort, and what makes mdread TOTAL: `starter` claims more lines than the
   ; blocks it names can parse (a `--- text ---` that is not a rule, a `:   ` body with no
   ; term over it) and `p-line` refuses them too, so without this the block loop stops and
   ; the rest of the document vanishes in silence. taking one line as a paragraph lets the
   ; loop go on. it cannot fire on what a shower writes, so law 1 does not feel it.
   b-line  (tag (\ p ['para (mdinl (cats p))]) (seqs [(one nonl?) (span nonl?) eol]))
   mdblock (seqs [(skip (many blankline))
                  (alts [b-rule b-head b-fence b-quote b-bullets b-numbers b-deflist b-para b-line])])
   ; yaml-ish front matter, the markdown face of the meta block: head-only (a `---` fence
   ; anywhere else is a rule), so it is read before the block loop and shown before it.
   kvline (tag (\ p [(name <p) <>p])
               (seqs [(span (c \ nonl? c && c != 58)) (skip (lit ": ")) (span nonl?) eol]))
   b-meta (tag (\ p ['meta (mnorm p)])
                    (seqs [(skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))
                           (many kvline) (skip (lit "---")) (skip (span sp?)) (skip (lit "\n"))]))
   (mdread t) (bmrg (runp (seqs [(opt b-meta) (many mdblock) (skip (many blankline))]) (endnl t))))

; ---------------------------------------------------------------- markdown, show
(: (mq s) (:- (g 0 "") (g i acc) (i >= #s ? acc (s i @ c (g (i + 1) (acc + (spec? c ? "\\" "") + string c)))))
   (mdi l)  (cats (map mdi1 l))
   (mdi1 x) (<x @ 'text (mq <>x)
                  'code ("`" + <>x + "`")
                  'strong ("**" + mdi <>x + "**")
                  'em ("*" + mdi <>x + "*")
                  'link ("[" + mdi <>x + "](" + <>>x + ")")
                  "")
   ; a paragraph whose first characters would re-read as another block wears one backslash --
   ; the escape leaf takes it back off, so law 1 survives a paragraph that starts "- " or "# ".
   (shield s) (two? (runp starter (endnl s)) ? ("\\" + s) s)
   (qpre s)   (cats (map (ln \ #ln ? ("> " + ln + "\n") ">\n") (splitnl s)))
   (nlist l i) (atom? l ? "" (show i + ". " + mdi <l + "\n" + nlist >l (i + 1)))
   (mfront kvs) ("---\n" + cats (map (p \ string <p + ": " + <>p + "\n") (mfilled kvs)) + "---\n")
   (mdefs l)    (cats (map (it \ mdi <it + "\n:   " + mdi <>it + "\n") l))
   (mdb x) (<x @ 'head    (rep "#" <>x + " " + mdi <>>x + "\n")
                 'para    (shield (mdi <>x) + "\n")
                 'fence   ("```" + <>x + "\n" + <>>x + "```\n")
                 'quote   (qpre (mdshow <>x))
                 'bullets (cats (map (i \ "- " + mdi i + "\n") <>x))
                 'numbers (nlist <>x 1)
                 'deflist (mdefs <>x)
                 'meta    (mfront <>x)
                 'rule    "---\n"
                 "")
   (mdshow d) (joins (map mdb d) "\n"))                        ; each block ends in \n, so \n between = a blank line

; ---------------------------------------------------------------- html, show
(: (hq s) (:- (g 0 "") (g i acc) (i >= #s ? acc
           (: c (s i) (g (i + 1)
            (acc + (c @ 38 "&amp;" 60 "&lt;" 62 "&gt;" (string c)))))))
   (hti l)  (cats (map hti1 l))
   (hti1 x) (<x @ 'text   (hq <>x)
                  'code   ("<code>" + hq <>x + "</code>")
                  'strong ("<strong>" + hti <>x + "</strong>")
                  'em     ("<em>" + hti <>x + "</em>")
                  'link   ("<a href=\"" + hq <>>x + "\">" + hti <>x + "</a>")
                  "")
   (hitems l t) (joins (map (i \ "<li>" + hti i + "</li>") l) "\n" + "\n</" + t + ">")
   (hmeta kvs)  (joins (map (p \ "<meta name=\"" + string <p + "\" content=\"" + hq <>p + "\">") (mfilled kvs)) "\n")
   (hdefs l)    ("<dl>\n" + joins (map (\ it ("<dt>" + hti <it + "</dt>\n<dd>" + hti <>it + "</dd>")) l) "\n" + "\n</dl>")
   (htb x) (<x @ 'head    (: h ("h" + show <>x) ("<" + h + ">" + hti <>>x + "</" + h + ">"))
                 'para    ("<p>" + hti <>x + "</p>")
                 'fence   ("<pre><code" + (? (0 < #<>x) (" class=\"language-" + <>x + "\"") "")
                                  + ">" + hq <>>x + "</code></pre>")
                 'quote   ("<blockquote>\n" + htshow <>x + "\n</blockquote>")
                 'bullets ("<ul>\n" + hitems <>x "ul")
                 'numbers ("<ol>\n" + hitems <>x "ol")
                 'deflist (hdefs <>x)
                 'meta    (hmeta <>x)
                 'rule    "<hr>"
                 "")
   (htshow d) (joins (map htb d) "\n"))

; ---------------------------------------------------------------- html, read
(: (otag t)    (lit ("<" + t + ">"))
   (ctag t)    (lit ("</" + t + ">"))
   hws         (skip (span ws?))
   (wrapt t a) (seqs [(skip (otag t)) a hws (skip (ctag t))])
   (entof nm) (nm @ "amp" "&" "lt" "<" "gt" ">" "quot" "\"" ("&" + nm + ";"))

   (hraw? c)   (c != 60 && c != 38)                        ; ordinary text runs to the next < or &

   hent    (tag (\ p ['text (entof <p)]) (seqs [(skip (lit "&")) (span (!= 59)) (skip (lit ";"))]))
   htext   (tag (\ p ['text (cats p)]) (seq (one hraw?) (span hraw?)))
   hcode   (tag (\ p ['code (plain <p)]) (wrapt "code" (pack (many (alts [hent htext])))))
   ; the inline cycle (htinl -> strong/em/link -> htinl) rides eta-expanded parsers
   (hstrong s y n) ((tag (\ p ['strong <p]) (wrapt "strong" (pack htinl))) s y n)
   (hem s y n)     ((tag (\ p ['em <p]) (wrapt "em" (pack htinl))) s y n)
   ; ..the href is entity-decoded by running the same two text leaves over it
   (hlink s y n)   ((tag (\ p ['link <>p (plain (runp (many (alts [hent htext])) <p))])
                         (seqs [(skip (lit "<a href=\"")) (span (!= 34)) (skip (lit "\">"))
                                (pack htinl) (skip (lit "</a>"))])) s y n)
   (htinl s y n)   ((pmap mrg (many (alts [hent hcode hstrong hem hlink htext]))) s y n)

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
   ; quote recurses into the block loop, so it sits with it and stays eta-expanded
   (h-quote s y n) ((tag (\ p ['quote <p]) (wrapt "blockquote" (pack (many h-block)))) s y n)
   (h-block s y n) ((seqs [hws (alts [h-rule h-head h-fence h-quote h-ul h-ol h-dl h-meta h-para])]) s y n)
   (htread t) (bmrg (runp (seqs [(many h-block) hws]) t)))

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
   (rfill s) (cats (map (ln \ ln + "\n") (rsent s)))
   (rfi l)  (cats (map rfi1 l))
   (rfi1 x) (<x @ 'text   (rq <>x)
                  'code   ("\\f(CR" + rq <>x + "\\fR")     ; cr, not the deprecated cw: groff warns on that
                  'strong ("\\fB" + rfi <>x + "\\fR")
                  'em     ("\\fI" + rfi <>x + "\\fR")
                  'link   (rfi <>x + " \\(la" + rq <>>x + "\\(ra")
                  "")
   (rth kvs)   (".TH" + cats (map (k \ " \"" + mget kvs k + "\"") metakeys) + "\n")
   (rnums l i) (atom? l ? "" (".IP \"" + show i + ".\" 4\n" + rline (rfi <l) + "\n" + rnums >l (i + 1)))
   (rdefs l)   (cats (map (it \ ".TP\n" + rline (rfi <it) + "\n" + rfill (rfi <>it)) l))
   (rfb x) (<x @ 'meta    (rth <>x)
                 'head    ((<>x < 2 ? ".SH " ".SS ") + rfi <>>x + "\n")
                 'para    (".PP\n" + rfill (rfi <>x))
                 'fence   (".EX\n" + cats (map (ln \ rline (rq ln) + "\n") (splitnl <>>x)) + ".EE\n")
                 'quote   (".PP\n.RS\n" + rfshow <>x + ".RE\n")   ; the .pp spaces the display
                 'bullets (cats (map (i \ ".IP \\(bu 2\n" + rline (rfi i) + "\n") <>x))
                 'numbers (rnums <>x 1)
                 'deflist (rdefs <>x)
                 "")                                        ; a rule has no roff form: it vanishes
   (rfshow d) (cats (map rfb d)))

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
   resc    (alts [(tag (const '(text "\\")) (lit "\\e"))
                  (tag (const '(text "-")) (lit "\\-"))
                  (tag (const '(text "")) (lit "\\&"))      ; zero-width: mrg drops it
                  (tag (const '(text " ")) (lit "\\ "))
                  rgl])
   rtext  (tag (\ p ['text (cats p)]) (seq (one rfesc?) (span rfesc?)))
   ; ..a \ starting none of the above reads as literal text one char at a time, `mrg` gluing
   ; it back on. without it the reader stops dead at the first escape it does not model.
   rchar   (tag (\ p ['text (string <p)]) (one chr?))
   rcode   (tag (\ p ['code (plain <p)])
           (seqs [(skip (alts [(lit "\\f(CR") (lit "\\f(CW")]))   ; cw is groff-deprecated, still read
                  (pack (many (seq (notp rclose) (alts [resc rtext rchar])))) (skip rclose)]))
   ; the font cycle (span -> strong/em -> rfont -> rinls -> span) rides eta-expanded parsers
   (rfont o t) (tag (\ p [t <p]) (seqs [(skip (lit o)) (pack rinls) (skip rclose)]))
   (rstrong s y n) ((rfont "\\fB" 'strong) s y n)
   (rem s y n)     ((rfont "\\fI" 'em) s y n)
   (rspan s y n)   ((alts [resc rcode rstrong rem rtext rchar]) s y n)
   (rinls s y n)   ((pmap mrg (many (seq (notp rclose) rspan))) s y n)
   rfinl       (mrg * (runp (many rspan)))
   rplain      (plain * mrg * runp (many (alts [resc rtext rchar]))))   ; escapes only, no fonts

; the font macros: which fonts to cycle through, and whether the arguments take a space.
(: (rargs s)                                                  ; a macro's arguments, bare or "quoted"
   ((: (g i acc)
       (? (i >= #s) (rev acc)
          (s i = 32) (g (i + 1) acc)
          (s i = 34) (: j ((: (h k) (k < #s && s k != 34 ? (h (k + 1)) k)) (i + 1))
                      (g (j + 1) (snip s (i + 1) j . acc)))
          (: j ((: (h k) (k < #s && s k != 32 ? (h (k + 1)) k)) i)
           (g j (snip s i j . acc))))) 0 ())
   fontmacs '((".BR" (strong text) 0) (".RB" (text strong) 0) (".IR" (em text) 0)
              (".RI" (text em) 0) (".SB" (strong) 1) (".SM" (text) 1) (".B" (strong) 1) (".I" (em) 1))
   (macinfo m) ((: (g l) (? (one? l) () (<<l = m) (>(<l)) (g >l))) fontmacs)
   (wrapf f l) (f @ ('strong || 'em) [[f l]] l)
   (allplain? l) (? (one? l) 1 (= <<l 'text) (allplain? >l) 0)
   (argl a f)    (: l (rfinl a) (? (allplain? l) (wrapf f l) l))     ; an explicit \f inside the arg wins
   (argls as fs i sp) (? (one? as) ()
                         (: h (argl <as (fs (i % #fs)))
                            (? (one? >as) h
                               (h + (? sp '((text " ")) ()) + (argls >as fs (i + 1) sp)))))
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
   r-sh   (tag (\ p ['head 1 (rfinl (joins (rargs <p) " "))]) (rmacl ".SH"))
   r-ss   (tag (\ p ['head 2 (rfinl (joins (rargs <p) " "))]) (rmacl ".SS"))
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
   r-ex   (tag (\ p ['fence "" (cats (map (ln \ rplain ln + "\n") p))])
               (seqs [(skip (alts [(lit ".EX") (lit ".nf")])) (skip (span nonl?)) (skip (lit "\n"))
                      (many (seq (notp (alts [(lit ".EE") (lit ".fi")])) rfline))
                      (skip (alts [(lit ".EE") (lit ".fi")])) (skip (span nonl?)) (skip (lit "\n"))]))
   r-br    (skip (seqs [(lit ".br") (span nonl?) (lit "\n")]))   ; a break ends the run
   r-blank (skip (seqs [(span sp?) (lit "\n")]))
   ; .rs recurses into the block loop, so it sits with it and stays eta-expanded
   (r-rs s y n) ((tag (\ p ['quote p])
                      (seqs [(skip (lit ".RS")) (skip (span nonl?)) (skip (lit "\n"))
                             (many r-block) (skip (lit ".RE")) (skip (span nonl?)) (skip (lit "\n"))])) s y n)
   (r-block s y n) ((alts [r-blank r-br r-th r-sh r-ss r-pp r-ex r-rs r-ul r-ol r-dl r-para]) s y n)
   rfread (bmrg * runp (many r-block)))

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
