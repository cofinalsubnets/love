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
 !(cite 'lapis))                           ; a missing module answers ()

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
    "* a star bullet
* and *em* in one"
    "| tool | kore | GNU |
| --- | :-: | --: |
| `a\\|b` | ✓ | |
| a \\| bar | **x** |
| short |"
    "a paragraph

| h |
| :-- |
| v |

and after"
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
   (t0? x) (? !(two? x) (0 = x) (t0? <x || t0? >x))
   _ (map (\ s
      (: d (mdread s)  m (nrm s)  h (md->ht s)
         (test
            (d = (mdread (mdshow d)))          ; law 1, the markdown surface
            (d = (htread (htshow d)))          ; law 1, the html surface
            (m = (ht->md (md->ht s)))          ; law 2: the lens closes, up to normalization
            (m = (nrm m))                      ; ..and a normalizer is idempotent
            (h = (md->ht (ht->md h)))
            (h = (hrm h))
            !(t0? d)                        ; no 0 tail anywhere in the middle
            !(t0? (htread h))))) corpus)

 ; --- the shapes, spelled out: the middle is plain love data -------------------
 _ (test
    ((mdread "# hi") = '((head 1 ((text "hi")))))
    ((mdread "*a*b") = '((para ((em ((text "a"))) (text "b")))))
    ((mdread "- x\n- y\n") = '((bullets (((text "x")) ((text "y"))))))
    ((mdread "> q\n") = '((quote ((para ((text "q")))))))
    ((mdread "```c\nx\n```\n") = '((fence "c" "x\n")))
    ((mdread "[t](u)") = '((para ((link ((text "t")) "u")))))
    ((mdread "---\n") = '((rule)))
    ((mdread "* x\n") = '((bullets (((text "x"))))))
    ; a table: aligns, the head, the rows laid to the head's width
    ((mdread "| a | b |\n| :-: | --- |\n| 1 |\n")
     = '((table (c n) (((text "a")) ((text "b"))) ((((text "1")) ())))))
    ; only a head over a delimiter row is a table; a line opening with a bar is prose
    ((mdread "| not | a table\n") = '((para ((text "| not | a table")))))
    ((mdread "a\n| b |\n| - |\n") = '((para ((text "a"))) (table (n) (((text "b"))) ())))
    ; html's table read off a page: no thead, the head is the first row
    ((htread "<table><tr><th>h</th></tr><tr><td class=\"x\">v</td></tr></table>")
     = '((table (n) (((text "h"))) ((((text "v")))))))
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
                           !(t0? (rfread (rfshow d)))))) rfcorpus)

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
                        !(t0? d))))
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
                     (test ('meta = <<d)    ; a .th, and it leads
                             !(elem 'rule (map cap d))))) ["doc/love.md" "doc/cook.md"])
      0)

 ; --- the html surface outside its own output ---------------------------------
 ; law 1 says htread reads what htshow writes. what `html2text` needs is the other half:
 ; that it also reads a page nobody wrote with htshow -- attributes, containers, a head,
 ; entities, and tags this middle has no node for. none of that is law 1 and none of it can
 ; be, so it is stated here as what the scrub promises.
 _ (test
    ; an attribute does not hide a block (an id is kept, as a mark), and the scrub drops
    ; what is not prose
    ((htread "<h1 id=\"x\">hi</h1>") = '((head 1 ((mark "x") (text "hi")))))
    ((htread "<h1 class=\"x\">hi</h1>") = '((head 1 ((text "hi")))))
    ((htread "<!doctype html>\n<html><body><p>hi</p></body></html>") = '((para ((text "hi")))))
    ((htread "<head><title>t</title></head><p>hi</p>") = '((para ((text "hi")))))
    ((htread "<script>var x = '<p>no</p>';</script><p>yes</p>") = '((para ((text "yes")))))
    ((htread "<!-- <p>no</p> --><p>yes</p>") = '((para ((text "yes")))))
    ; a container is unwrapped -- what it held is still there, one level out
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
 ; so the property that matters is the round trip through the shipped form: every heading
 ; the markdown has is still a heading after roff and the tty shower, at the column the
 ; shower puts one. it is not law 1 -- a terminal keeps nothing and there is no ttread --
 ; which is why 'tty is no row in `surfaces`: a row owes law 1 and this cannot pay it.
 _ (: (slurpf f) (: q (open f "r") (slurp q))
      ; an inl down to its text -- lapiz keeps its own `plain` off the export list
      (flat l) (one? l ? "" (: x <l
                     ((<x @ 'text <>x 'code <>x 'strong (flat <>x) 'em (flat <>x)
                             'link (flat <>x) "") + flat >l)))
      ; the line a heading should have become: a .SH flush left, a .SS indented three
      (heads d) (map (b \ (<>b < 2 ? "" "   ") + flat <>>b) (filter (b \ = <b 'head) d))
      (flush s) ((: (g i o) (? (#s <= i) (slurp o)
                               (i + 1 < #s && s i = 27 && s (i + 1) = 91)
                                ((: (h k) (? (#s <= k) (slurp o) (s k = 109) (g (k + 1) o)
                                             (h (k + 1)))) (i + 2))
                               (put o (s i), g (i + 1) o))) 0 (jug 0))
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
      ; a document of wide tables (the census) overruns neither straight to the terminal
      ; nor by way of roff, where a table too wide for a page is laid a row at a time
      _ (: d (mdread (slurpf "doc/misc/kore.md"))
           ; the width is characters: a check mark is three bytes and one column
           (cols l) (: f (flush l) (tally (filter (c \ !(128 <= c && c < 192)) (map (i \ f i) ^#f))))
           (test (foldl (\ a l (a && cols l <= 80)) 1 (lines (ttyshow d 80)))
                 (foldl (\ a l (a && cols l <= 80)) 1 (lines (ttyshow (rfread (rfshow d)) 80)))))
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
      ; is this device's branch, so its text is the page's; `.if t` belongs to the other one.
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
           (test !(elem "     .." ls) !(elem "     .. .." ls)
                   (elem "     kept by nroff t - a thing" ls)))
      ; the browser's view: every link with a url is [n] in reading order, through every
      ; block that holds an inl, and n picks its url; an anchor is a mark and no number.
      ; each [n] rides behind a mark named byte 3 and n, which ttpage lifts into the lines
      _ (: d (htread "<h2>see <a href=\"/h\">head</a></h2><p>a <a href=\"x/1\">one</a> and <em><a href=\"#f\">two <b>b</b></a></em>, <a name=\"n\">anchor</a></p><ul><li><a href=\"u3\">three</a></li></ul><blockquote><p><a href=\"q4\">four</a></p></blockquote><dl><dt><a href=\"d5\">term</a></dt><dd><a href=\"d6\">def</a></dd></dl><table><tr><th><a href=\"t7\">h</a></th></tr><tr><td><a href=\"t8\">c</a></td></tr></table>")
           r (ttlinks d)
           p (ttpage d 60)
           ls (lines (flush <p))
           (test (<>r = ["/h" "x/1" "#f" "u3" "q4" "d5" "d6" "t7" "t8"])
                 (<r = '((head 2 ((text "see ") (tmark "\x031") (text "[1]head")))
                         (para ((text "a ") (tmark "\x032") (text "[2]one and ")
                                (em ((tmark "\x033") (text "[3]two ") (strong ((text "b")))))
                                (text ", ") (tmark "n") (text "anchor")))
                         (bullets (((tmark "\x034") (text "[4]three"))))
                         (quote ((para ((tmark "\x035") (text "[5]four")))))
                         (deflist ((((tmark "\x036") (text "[6]term")) ((tmark "\x037") (text "[7]def")))))
                         (table (n) (((tmark "\x038") (text "[8]h"))) ((((tmark "\x039") (text "[9]c")))))))
                 (p 1 = <>r) (p 2 = [["n" 1]])
                 (p 3 = [0 1 1 3 5 7 8 10 12])
                 (elem "     a [2]one and [3]two b, anchor" ls)
                 ; a page with no links answers none, and the doc unchanged
                 (ttlinks (mdread "a *b* `c`\n") = [(mdread "a *b* `c`\n") ()])))
      ; what a page carries that is not prose, read anyway: a get form's text field is a
      ; link to form:ACTION?PAIRS -- every other control as it stands, the first submit
      ; button, then its own name=value last -- and a post form, a <select>, a hidden or
      ; unchecked control lay nothing. an image is its alt, a mark " img SRC" ahead of it
      ; where it has a src; a bare & is itself; an
      ; attribute may go unquoted, and a > inside a quoted one ends no tag
      _ (: f (htread "<form action=\"/w/i.php?old=1#f\"><input type=hidden name=t value=\"Special:S &amp; b\"><input name=q placeholder=\"Find\"><select name=k><option value=a>A<option selected>B b</select><input type=checkbox name=c checked><input type=checkbox name=d><input type=submit name=go value=Go><input type=submit name=no value=No><textarea name=n>x &lt; y</textarea></form><form method=POST><input name=p></form>")
           (test (f = '((para ((link ((text "[Find________]")) "form:/w/i.php?t=Special%3AS+%26+b&k=B+b&c=on&n=x+%3C+y&go=Go&q=")
                                (link ((text "[x < y_______]")) "form:/w/i.php?t=Special%3AS+%26+b&q=&k=B+b&c=on&go=Go&n=x+%3C+y")))))
                 (htread "<p>a <img src=x alt=\"the logo\"> b <img alt=\"\" src=y> c</p>"
                  = '((para ((text "a ") (mark " img x") (text "[the logo] b ") (mark " img y") (text " c")))))
                 (htread "<p>a <img alt=\"no src\"> b</p>" = '((para ((text "a [no src] b")))))
                 (htread "<p>fish & chips, <a href=\"q?a=1&b=2&amp;c=3\">q</a></p>"
                  = '((para ((text "fish & chips, ") (link ((text "q")) "q?a=1&b=2&c=3")))))
                 (htread "<p><a href=/u/v title=\"a > b\">u</a> <span id=s>s</span></p>"
                  = '((para ((link ((text "u")) "/u/v") (text " ") (mark "s") (text "s")))))))
      ; the places a link lands: every id a mark, inside a tag whose content is a line and
      ; ahead of any other, and an <a> with no href only its mark and its text. html keeps
      ; them (law 1); markdown and the terminal show nothing for them; ttpage answers each
      ; one's line -- a paragraph of marks alone on the next block, a mark at the end of
      ; one on its last word
      _ (: src "<div id=\"top\"></div><h2 id=\"History\">History</h2><p>see <a href=\"#cite_note-1\">[1]</a> and <a name=\"old\">old place</a> here</p><ol><li id=\"cite_note-1\"><span id=\"x\"></span>the note</li><li id=\"cite_note-2\">two</li></ol><section id=\"end\"><p>last</p></section><p>tail <a id=\"q&amp;a\"></a></p>"
           bare "<h2>History</h2><p>see <a href=\"#cite_note-1\">[1]</a> and old place here</p><ol><li>the note</li><li>two</li></ol><p>last</p><p>tail </p>"
           d (htread src)
           p (ttpage d 60)
           (test (d = '((para ((mark "top"))) (head 2 ((mark "History") (text "History")))
                        (para ((text "see ") (link ((text "[1]")) "#cite_note-1") (text " and ")
                               (mark "old") (text "old place here")))
                        (numbers (((mark "cite_note-1") (mark "x") (text "the note"))
                                  ((mark "cite_note-2") (text "two"))))
                        (para ((mark "end"))) (para ((text "last"))) (para ((text "tail ") (mark "q&a")))))
                 (htread (htshow d) = d)
                 (ht->tty src 60 = ht->tty bare 60)
                 (mdread (mdshow d) = mdread (mdshow (htread bare)))
                 !(elem 1 (map (i \ <p i) ^#(<p)))                ; no sentinel left behind
                 (p 2 = [["top" 0] ["History" 0] ["old" 1] ["cite_note-1" 3] ["x" 3]
                         ["cite_note-2" 4] ["end" 6] ["q&a" 8]])))
      ; where a page's own content starts: <main> or role=main is " main", an <article>
      ; " article" -- a space in the name, which no id has -- beside the tag's own id
      _ (: d (htread "<nav><p>menu</p></nav><main id=\"content\"><h1>t</h1></main>")
           (test (d = '((para ((text "menu"))) (para ((mark "content") (mark " main"))) (head 1 ((text "t")))))
                 (htread (htshow d) = d)
                 (ttpage d 60 2 = [["content" 2] [" main" 2]])
                 (htread "<div role=\"main\"><p>x</p></div>" = '((para ((mark " main"))) (para ((text "x")))))
                 (htread "<article><p>y</p></article>" = '((para ((mark " article"))) (para ((text "y")))))
                 ; a page's indenting leaves blank text beside the marks, and they still move on
                 (ttpage (htread "<nav><p>m</p></nav><main>\n    <p>x</p></main>") 60 2 = [[" main" 2]])))
      0)

 _ (test_fin ())
 _ (puts "apps/lapiz: ok -- the document lens (markdown/html/roff), laws 1 + 2 + the roff domain + the tty shower
")
 0)
