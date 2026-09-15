; --- test/host/lapiz.l: the document lens, exactly ---
; not in the test/*.l corpus (it loads a crew file and splices its module).
; the corpus is the lens laws over a markdown corpus wide enough to touch every
; block and every span:
;   law 1  the AST is the fixed point of each surface -- (mdread (mdshow a)) = a
;          and (htread (htshow a)) = a. the strong one: neither shower loses
;          anything its reader wants, so the two surfaces are views of one value.
;   law 2  falls out -- each surface round-trips through the other up to
;          normalization, and both normalizers are idempotent. reading is a
;          retraction (many markdowns, one AST), showing its section.
; a new surface owes law 1 and nothing more; that is what keeps its arrival from
; touching any other. run:
;   cat test/00-init.l test/host/lapiz.l | out/love

(borrow 'lapiz)                                ; the baked module, spliced

; --- the module seam: lapiz registered, the splice + accessor both reach -------
(test
 (elem 'lapiz (cite ()))                   ; the registry lists it
 (elem 'md->ht (keys (cite 'lapiz)))        ; keys introspects the layer
 ("<h1>hi</h1>" = ((cite 'lapiz 'md->ht) "# hi"))   ; the opaque accessor reaches a face
 (lit? (cite 'lapiz))                         ; presence: the accessor is a closure
 (! (cite 'lapis)))                           ; a missing module answers ()

; --- the corpus: every block, every span, and the edges around them ------------
(: corpus
   ["" "# a title" "###### deep" "just a paragraph"
    "a wrapped paragraph
continued on a second line"
    "hello *world* and `code` and **bold** here"
    "**bold with *em* inside** and [a *link*](http://x.y/p?q=1&r=2)"
    "sigils that start nothing: a - b, 2 * 3, x[1], a \\* literal star"
    "\\- not a bullet"  "\\# not a head"  "\\--- not a rule"
    "5 < 6 & 7 > 2 -- the html escapes"
    "- one
- two **bold**"
    "1. first
2. second
3. third"
    "> quoted *text*
> and more
>
> a second quoted block"
    "```love
(+ 1 2)
```"
    "```
no language tag
```"
    "---"
    "---
title: LOVE
section: 1
manual: love manual
---

# NAME

love \\- a curried lisp"
    "-l *lib*
:   load **lib** first

--emit
:   transpile it"
    "# everything

a paragraph, then a list:

- alpha
- beta

> a quote with `code`

```c
int main(void) { return 0; }
```

---

the [end](e)."]

   (nrm s) (mdshow (mdread s))                 ; the markdown normalizer: read then show
   (hrm s) (htshow (htread s))                 ; ..and the html one
   ; the 0 nil-tail fossil would fail law 1 on nothing but the terminator, and
   ; `show` prints the two alike -- so probe the tail itself, everywhere in the AST.
   (t0? x) (? (! (two? x)) (0 = x) (|| (t0? <x) (t0? >x)))
   _ (map (\ s
      (: d (mdread s)  m (nrm s)  h (md->ht s)
         (test
            (d = (mdread (mdshow d)))          ; law 1, the markdown surface
            (d = (htread (htshow d)))          ; law 1, the html surface
            (m = (ht->md (md->ht s)))          ; law 2: the lens closes, up to normalization
            (m = (nrm m))                      ; ..and a normalizer is idempotent
            (h = (md->ht (ht->md h)))
            (h = (hrm h))
            (! (t0? d))                        ; no 0 tail anywhere in the middle
            (! (t0? (htread h)))))) corpus)

 ; --- the shapes, spelled out: the middle is plain love data -------------------
 _ (test
    ((mdread "# hi") = '((head 1 ((text "hi")))))
    ((mdread "*a*b") = '((para ((em ((text "a"))) (text "b")))))
    ((mdread "- x\n- y\n") = '((bullets (((text "x")) ((text "y"))))))
    ((mdread "> q\n") = '((quote ((para ((text "q")))))))
    ((mdread "```c\nx\n```\n") = '((fence "c" "x\n")))
    ((mdread "[t](u)") = '((para ((link ((text "t")) "u")))))
    ((mdread "---\n") = '((rule)))
    ((mdread "t\n:   b\n") = '((deflist ((((text "t")) ((text "b")))))))
    ((mdread "---\ntitle: L\n---\n") = '((meta ((title "L") (section "") (date "") (source "") (manual "")))))
    ; two blank-separated lists of one kind are one list (markdown's loose-list rule,
    ; and the only spelling roff has) -- `bmrg`, the block twin of `mrg`
    ((mdread "- a\n\n- b\n") = '((bullets (((text "a")) ((text "b"))))))
    ; a wrapped item is one item: a line that is neither blank nor a block opener
    ; continues the item above it, and the wrap's indentation is not the text's.
    ((mdread "- a\n  wrapped\n- b\n") = '((bullets (((text "a wrapped")) ((text "b"))))))
    ((mdread "1. a\n   wrapped\n") = '((numbers (((text "a wrapped"))))))
    ; ..and what does not continue one: a blank line, and every block opener
    ((mdread "- a\n\nb\n") = '((bullets (((text "a")))) (para ((text "b")))))
    ((mdread "- a\n- b\n") = '((bullets (((text "a")) ((text "b"))))))
    ((mdread "- a\n# b\n") = '((bullets (((text "a")))) (head 1 ((text "b")))))
    ((mdread "- a\n```\nx\n```\n") = '((bullets (((text "a")))) (fence "" "x\n")))
    ; the reader is total: a line `starter` claims but no block can parse -- a
    ; `---` rule that is not one, a `:   ` body with no term over it -- is taken as
    ; a paragraph of its own rather than stopping the block loop, which used to drop
    ; the whole rest of the document in silence.
    ((mdread ":   orphan\n") = '((para ((text ":   orphan")))))
    ((mdread "--- the table ---\nbody\n")
     = '((para ((text "--- the table ---"))) (para ((text "body")))))
    ((mdread "- a\n:   b\n") = '((bullets (((text "a")))) (para ((text ":   b")))))
    ; ..and it never fires on what a shower writes, which is why law 1 does not feel
    ; it: a real rule, a real deflist and a shielded paragraph all still read as they
    ; are shown.
    ((mdread "---\n") = '((rule)))
    ((mdread "t\n:   b\n") = '((deflist ((((text "t")) ((text "b")))))))
    ; a paragraph that would re-read as a block wears one backslash; the escape leaf takes it off
    ((nrm "- a") = "- a\n")
    ((nrm "\\- a") = "\\- a\n")
    ((mdread "\\- a") = '((para ((text "- a")))))
    ; the two faces of one middle
    ((md->ht "# hi") = "<h1>hi</h1>")
    ((md->ht "a *b* `c`") = "<p>a <em>b</em> <code>c</code></p>")
    ((ht->md "<p><em>x</em></p>") = "*x*\n")
    ((ht->md "<ul>\n<li>a</li>\n<li>b</li>\n</ul>") = "- a\n- b\n")
    ((ht->md "<h2>t</h2>\n<hr>") = "## t\n\n---\n")
    ; entities decode on the way in and re-encode on the way out
    ((ht->md "<p>5 &lt; 6 &amp; 7</p>") = "5 < 6 & 7\n")
    ((md->ht "5 < 6 & 7") = "<p>5 &lt; 6 &amp; 7</p>"))

 ; --- the roff surface: law 1 on the man-page-shaped docs ---------------------
 ; roff is a smaller surface, so its law is stated over its domain -- meta, head 1-2,
 ; para, fence with no language, quote, bullets, numbers, deflist, and text/strong/
 ; em/code inline. every one of those appears below.
 _ (: rfcorpus
    ["# NAME" "## OPTIONS" "plain paragraph text" "a *b* **c** `d`"
     "- one
- two"
     "- an item that wraps onto
  a second line
- and one that does not"
     "1. first
2. second"
     "-l *lib*
:   load **lib** first
--emit
:   transpile it"
     "> an indented note with `code`"
     "```
literal
block
```"
     "---
title: LOVE
section: 1
manual: love manual
---

# NAME

love \\- a curried lisp

## OPTIONS

-l *lib*
:   load **lib** before the file

- a bullet
- another

> a note

```
some literal
```"]
    _ (map (\ s (: d (mdread s)
                   (test (d = (rfread (rfshow d)))        ; law 1, the roff surface
                           (! (t0? (rfread (rfshow d))))))) rfcorpus)

    ; ..and outside the domain rfshow stays total while rfread normalizes. each loss is
    ; pinned here, so it is a stated property of the surface and not a surprise.
    (rfrt s) (rfread (rfshow (mdread s)))
    _ (test
       ((rfrt "### deep") = '((head 2 ((text "deep")))))              ; .SH/.SS and no more
       ((rfrt "```c\nx\n```\n") = '((fence "" "x\n")))                ; .EX/.EE has no language slot
       ((rfrt "---\n") = ())                                          ; a man page has no rule
       ((rfrt "[t](u)") = '((para ((text "t ⟨u⟩")))))                 ; a link flattens to the man idiom
       ; ..and the domain-shaped neighbours of each are untouched
       ((rfrt "## deep") = '((head 2 ((text "deep")))))
       ((rfrt "```\nx\n```\n") = '((fence "" "x\n"))))

    ; the surface table is the whole of conversion: six pairings, no pairwise code
    _ (test
       ((convert 'md 'ht "# hi") = "<h1>hi</h1>")
       ((convert 'md 'rf "# hi") = ".SH hi\n")
       ((convert 'rf 'md ".SH hi\n") = "# hi\n")
       ((convert 'ht 'rf "<h1>hi</h1>") = ".SH hi\n")
       ((convert 'md 'ht "# hi") = (md->ht "# hi"))
       ((md->rf "# NAME") = ".SH NAME\n")
       ; ..and the one undefined spot: no row for a format, on either side
       ((convert 'md 'png "# hi") = 'nolens)
       ((convert 'png 'md "# hi") = 'nolens)
       (nom? (convert 'md 'png "# hi"))
       ; the second hub: the two x86 dialects convert into each other, and not into a document
       ((convert 'att 'intel "\tmovl\t$5, -12(%rbp)\n") = "\t.intel_syntax noprefix\n\tmov\tDWORD PTR [rbp-12], 5\n")
       ((convert 'intel 'att "\tmov\tDWORD PTR [rbp-12], 5\n") = "\tmovl\t$5, -12(%rbp)\n")
       ((convert 'md 'att "# hi") = 'nolens))
    0)

 ; --- real documents through the lens, laws and all ---------------------------
 ; readme.md, and the two man pages -- which are written in markdown and generated
 ; into roff by this module (tools/mkman.l), so their law 1 is load-bearing: it is
 ; what keeps doc/*.md and the shipped doc/*.1 from being able to disagree.
 _ (: (slurpf f) (: q (open f "r") (slurp q))
      _ (map (\ f (: d (mdread (slurpf f))
                     (test
                        (0 < tally d)                    ; it parsed
                        (d = (mdread (mdshow d)))        ; law 1 on real markdown
                        (d = (htread (htshow d)))
                        (! (t0? d)))))
             ["README.md" "doc/love.md" "doc/cook.md"])
      ; ..and the roff law only on the man pages: readme.md is deliberately outside the
      ; roff domain (deep headings, fence languages, links, rules), which is the domain
      ; doing its job rather than a failure.
      _ (map (\ f (: d (mdread (slurpf f))
                     (test (d = (rfread (rfshow d))))))   ; law 1 on the roff the build ships
             ["doc/love.md" "doc/cook.md"])
      ; the man pages are man-page-shaped: every block is in the roff domain, so the
      ; generated page loses nothing (verified against groff by hand, byte-identical
      ; to the hand-written pages these replaced).
      _ (map (\ f (: d (mdread (slurpf f))
                     (test ('meta = (cap (cap d)))    ; a .th, and it leads
                             (! (elem 'rule (map cap d)))))) ["doc/love.md" "doc/cook.md"])
      0)

 ; --- the html surface outside its own output ---------------------------------
 ; law 1 says htread reads what htshow writes. what `html2text` needs is the other half:
 ; that it also reads a page NOBODY wrote with htshow -- attributes, containers, a head,
 ; entities, and tags this middle has no node for. none of that is law 1 and none of it can
 ; be, so it is stated here as what the scrub promises.
 _ (test
    ; an attribute does not hide a block, and the scrub drops what is not prose
    ((htread "<h1 id=\"x\">hi</h1>") = '((head 1 ((text "hi")))))
    ((htread "<!doctype html>\n<html><body><p>hi</p></body></html>") = '((para ((text "hi")))))
    ((htread "<head><title>t</title></head><p>hi</p>") = '((para ((text "hi")))))
    ((htread "<script>var x = '<p>no</p>';</script><p>yes</p>") = '((para ((text "yes")))))
    ((htread "<!-- <p>no</p> --><p>yes</p>") = '((para ((text "yes")))))
    ; a container is UNWRAPPED -- what it held is still there, one level out
    ((htread "<div class=\"a\"><p>hi</p></div>") = '((para ((text "hi")))))
    ((htread "<div><div><p>hi</p></div></div>") = '((para ((text "hi")))))
    ; ..and a nested kill does not end its parent early
    ((htread "<script><script></script>x</script><p>y</p>") = '((para ((text "y")))))
    ; the aliases: one font, so <b> is <strong> and <tt> is <code>
    ((htread "<p><b>a</b> <i>c</i> <tt>d</tt></p>")
     = '((para ((strong ((text "a"))) (text " ") (em ((text "c"))) (text " ") (code "d")))))
    ; text with no <p> around it is still a paragraph -- which is where a page's prose
    ; lives once its containers are gone
    ((htread "<div>bare text</div>") = '((para ((text "bare text")))))
    ; the entities a document spells, named and numeric
    ((htread "<p>a&nbsp;b &amp; c&#65;d&#x42;e</p>") = '((para ((text "a b & cAdBe")))))
    ((htread "<p>&mdash;&hellip;</p>") = '((para ((text "—…")))))
    ((htread "<p>&nosuchentity;</p>") = '((para ((text "&nosuchentity;")))))   ; unknown rides through
    ; a tag with no node here is dropped and its content kept, so nothing truncates
    ((htread "<p>a</p><button>b</button><p>c</p>")
     = '((para ((text "a"))) (para ((text "b"))) (para ((text "c")))))
    ; ..and the closers stay with the block waiting for them: a quote survives a stray tag
    ((htread "<blockquote><p>q</p></blockquote>") = '((quote ((para ((text "q")))))))
    ((htread "<blockquote><wat><p>q</p></blockquote>") = '((quote ((para ((text "q")))))))
    ; a page of nothing but furniture is empty, not garbage
    ((htread "<!doctype html><html><head></head><body></body></html>") = ()))

 ; --- the terminal surface: the circle the man pages travel ---------------------
 ; the build writes doc/*.md, shows it as roff, ships that, and `kore man` reads it back.
 ; so the property that matters is the round trip through the SHIPPED form: every heading
 ; the markdown has is still a heading after roff and the tty shower, at the column the
 ; shower puts one. it is not law 1 -- a terminal keeps nothing and there is no ttread --
 ; which is why 'tty is no row in `surfaces`: a row owes law 1 and this cannot pay it.
 _ (: (slurpf f) (: q (open f "r") (slurp q))
      ; an inl down to its text -- lapiz keeps its own `plain` off the export list
      (flat l) (? (one? l) ""
                  (: x <l
                     ((<x @ 'text <>x 'code <>x 'strong (flat <>x) 'em (flat <>x)
                             'link (flat <>x) "") + flat >l)))
      ; the line a heading should have become: a .SH flush left, a .SS indented three
      (heads d) (map (b \ (<>b < 2 ? "" "   ") + flat <>>b) (filter (b \ = <b 'head) d))
      (flush s) ((: (g i o) (? (#s <= i) (slurp o)
                               (i + 1 < #s && s i = 27 && s (i + 1) = 91)
                                ((: (h k) (? (#s <= k) (slurp o) (s k = 109) (g (k + 1) o)
                                             (h (k + 1)))) (i + 2))
                               (: _ (put o (s i)) (g (i + 1) o)))) 0 (jug 0))
      (lines s) (: (g i st a) (? (#s <= i) (rev a)
                                 (s i = 10) (g (i + 1) (i + 1) (snip s st i . a))
                                 (g (i + 1) st a))
                   (g 0 0 ()))
      _ (map (\ f (: d (mdread (slurpf f))
                     t (flush (ttyshow (rfread (rfshow d)) 80))
                     ls (lines t)
                     (test
                        ; every heading survives the trip, and lands flush left the way
                        ; a .SH does -- so a missing one is a missing section, not a wrap
                        (foldl (\ a h (a && elem h ls)) 1 (heads d))
                        ; nothing overruns the width it was given
                        (foldl (\ a l (a && #l <= 80)) 1 ls)
                        ; the .th became the header line, with the page either side of it
                        (: h0 <ls (0 < #h0 && (h0 0) != 32)))))
             ["doc/love.md" "doc/cook.md"])
      ; a roff page the tree did not write still lays out: the shower is total over the
      ; middle, so every block kind renders and none of them widens past the width
      _ (: d (rfread ".TH \"T\" \"1\" \"\" \"s\" \"m\"
.SH NAME
t \\- a thing
.SH OPTIONS
.TP
\\fB\\-v\\fR
be loud
.IP \\(bu 2
a bullet
.PP
.RS
.EX
a display
.EE
.RE
")
           ls (lines (flush (ttyshow d 40)))
           (test (0 < #ls)
                   (foldl (\ a l (a && #l <= 40)) 1 ls)
                   (elem "NAME" ls) (elem "OPTIONS" ls)
                   (elem "     t - a thing" ls)
                   (elem "     -v     be loud" ls)       ; a short term keeps its definition
                   (elem "     • a bullet" ls)
                   (elem "         a display" ls)))      ; a display sits inside the quote
      ; the two ways a page's own furniture leaks into it. a .de body runs to a lone `..`
      ; and to nothing else -- an indented request inside one names no macro, and ending
      ; the body there spills the rest of the definition, terminator included. and `.if n`
      ; is THIS device's branch, so its text is the page's; `.if t` belongs to the other one.
      _ (: d (rfread ".TH \"T\" \"1\" \"\" \"s\" \"m\"
.de Q
.ie \\n(.g \\(lq\\\\$1\\(rq
.el \\{\\
.  if t ``\\\\$1''
.  if n \"\\\\$1\"
.\\}
..
.SH NAME
.if n kept by nroff
.if t dropped by nroff
t \\- a thing
")
           ls (lines (flush (ttyshow d 40)))
           (test (! (elem "     .." ls)) (! (elem "     .. .." ls))
                   (elem "     kept by nroff t - a thing" ls)))
      0)

 _ (test_fin ())
 _ (puts "apps/lapiz: ok -- the document lens (markdown/html/roff), laws 1 + 2 + the roff domain + the tty shower
")
 0)
