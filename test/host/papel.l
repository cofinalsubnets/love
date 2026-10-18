; test/host/papel.l -- what papel adds over lapiz and cook: anchors, slugs, relinks, titles, freshness.
; not in the corpus: it writes under /tmp. run: cat test/00-init.l test/host/papel.l | out/love

; --- the module seam: three modules, and papel adds nothing to the book
(elem 'parse (names ()) @ parse-before  ; the book before the load, for the leak delta
 ((borrow "src/apps/papel.l"),                ; the loader: papel wants lapiz + cook itself
  test (elem 'papel (cite ()))
       (elem 'lapiz (cite ()))
       (elem 'cook (cite ()))
       (elem 'build (keys (cite 'papel)))
       (lit? (cite 'papel 'papel-main))
       !(cite 'papyrus)
       ; `parse` may already be on the book via lapiz and cook, so the leak check is a delta
       (elem 'peg (cite ()))
       (lit? (cite 'peg 'seq))
       (parse-before = elem 'parse (names ()))))

(: dir "/tmp/papeltest"
   (put-file f s) (open (dir + "/" + f) "w" @ q (say q s, close q))
   (get-file f)   (open (dir + "/" + f) "r" @ q (hot? q ? (slurp q) ""))
   ; every attribute value after `pre`, up to its closing quote
   (finds s pre)  (: m #pre n #s
                     ((: (g i acc)
                         (i + m <= n ? (snip s i (i + m) = pre ? (((: (f k) (k < n && !(s k = 34) ? (f (k + 1)) k)) (i + m)) @ j
                                  (g j (snip s (i + m) j . acc))) (g (i + 1) acc)) (rev acc))) 0 ()))
   (has? l x)     (elem x l)
   (uniq? l)      ((: (g l) (? !(two? l) 1 (elem <l >l) 0 (g >l))) l)

   ; a clean slate: the freshness clauses count files written
   _ (hark ["rm" "-rf" dir])
   _ (mkdir dir 493)
   _ (mkdir (dir + "/src") 493)

   ; --- the fixture: small, and every clause below points at one line of it
   _ (put-file "src/one.md" "# One

The first page, whose opening paragraph becomes its line on the index.

## Shared Name

a

## Shared Name

b

See [two](two.md), [the archive](archive/old.md), [the web](https://example.com/x.md).

## Words

Apply
:   the verb. see [big](#big)

Big
:   a number

Big
:   again

Shared Name
:   spells a heading's slug
")
   _ (put-file "src/two.md" "---
title: Two From Meta
---

Only a paragraph, so the title has to come from the meta block.
")
   _ (put-file "src/three.md" "Neither a head-1 nor a meta block, so the file name is the title.
")

   conf ({} @ t
         (pin t 'out (dir + "/site"),
          pin t 'title "Fixture",
          pin t 'src [(dir + "/src")],
          pin t 'self "src/apps/papel.l",
          pin t 'quiet 1,
          t))

   ; --- the build, and freshness
   ; 3 pages + stylesheet + index; then nothing; then the touched page and the index
   n1 (build conf)
   n2 (build conf)
   ; rewrite a source as is to advance its mtime (read first: `open "w"` truncates); the rest lets
   ; the coarse file clock tick, or cook's strict-older compare reads it fresh
   _ (rest 5)
   _ (: s (get-file "src/one.md") q (open (dir + "/src/one.md") "w") (say q s, close q))
   n3 (build conf)
   _ (test (n1 = 5) (n2 = 0) (n3 = 2))

   ; --- and the dev-server gate over it
   ; `refresh`, per request: builds only when the source fingerprint moved, and never misses an edit
   box {}
   r1 (refresh conf box)
   r2 (refresh conf box)
   _ (rest 5)                                       ; coarse-clock care as above
   _ (: s (get-file "src/two.md") q (open (dir + "/src/two.md") "w") (say q s, close q))
   r3 (refresh conf box)
   r4 (refresh conf box)
   _ (test (0 = r1) (0 = r2) (2 = r3) (0 = r4))

   ; re-declaring recipes on every build must not grow the card
   cards (cite 'cook 'cards)
   (icount _) #<(cards (dir + "/site/index.html"))
   n0 (icount ())
   _ ((: (again k) (k < 6 ? (build conf, again (k + 1)) 0)) 0)
   _ (test (0 < n0) (n0 = icount ()))

   one (get-file "site/one.html")
   two (get-file "site/two.html")
   three (get-file "site/three.html")
   idx (get-file "site/index.html")

   ; --- anchors: every toc target exists as an id on the page
   (anchored? h) (: ids (finds h "id=\"")
                    tgts (finds h "href=\"#")
                    (!(two? tgts) ? 1 (filter (t \ !(has? ids t)) tgts @ bad !(two? bad))))
   _ (test
      (anchored? one) (anchored? two) (anchored? three)
      ; not vacuous: page one has a contents, its head-1 left out, duplicate headings deduped
      (has? (finds one "id=\"") "one")
      (has? (finds one "id=\"") "shared-name")
      (has? (finds one "id=\"") "shared-name-1")
      (uniq? (finds one "id=\""))
      ; the deflist: its terms anchored after the heads, deduped with them, the class its heading
      (has? (finds one "id=\"") "apply")
      (has? (finds one "id=\"") "big")
      (has? (finds one "id=\"") "big-1")
      (has? (finds one "id=\"") "shared-name-2")
      (has? (finds one "class=\"") "words")
      (#(finds one "href=\"#") = 4))                  ; 3 in the toc + the entry's link

   ; --- relink: rewritten inside the site, untouched outside
   hrefs (finds one "href=\"")
   _ (test
      (has? hrefs "two.html")
      (has? hrefs "archive/old.md")              ; not built -> left alone
      (has? hrefs "https://example.com/x.md")    ; absolute -> left alone
      !(has? hrefs "two.md"))

   ; --- title: the three sources, in order
   _ (test
      (0 < #(finds one "<h1 id=\""))
      (has? (finds two "content=\"") "Two From Meta")
      (cite 'papel 'ptitle (cite 'lapiz 'mdread (get-file "src/two.md")) "x") = "Two From Meta"
      (cite 'papel 'ptitle (cite 'lapiz 'mdread (get-file "src/three.md")) "three.md") = "three.md")

   ; --- the index lists every page, each with its blurb
   _ (: ih (finds idx "href=\"")
        _ (test (has? ih "one.html") (has? ih "two.html") (has? ih "three.html")
                  ; the blurb is the first paragraph, clipped on a word boundary
                  (0 < #(cite 'papel 'blurb (cite 'lapiz 'mdread (get-file "src/one.md"))))))

   ; --- the slug is a function of the text, and nothing else
   _ (cite 'papel 'slug @ slug
        (test (slug "Hello, World!" = "hello-world")
                (slug "  --- " = "section")            ; nothing left -> a name, never ""
                (slug "A" = slug "a")))

   ; --- the real thing: this tree's own docs
   ; the anchor property on every page; mdsof does not recurse, so subdirectories are named
   rconf ({} @ t
          (pin t 'out (dir + "/love"),
           pin t 'title "love",
           pin t 'src '("README.md" "doc" "doc/misc"),
           pin t 'self "src/apps/papel.l",
           pin t 'quiet 1,
           t))
   rn (build rconf)
   (test (10 < rn)
         (0 = build rconf),                     ; ..and is at once up to date
    (: (page f) (open (dir + "/love/" + f) "r" @ q (hot? q ? (slurp q) ""))
       (each (filter (f \ (cite 'papel 'ends? f ".html")) (readdir (dir + "/love")))
             (f \ (page f @ h
                     (test (0 < #h)
                             (cite 'papel 'ends? h "</html>\n")
                             (anchored? h)))),
        0)),

    test_fin (),
    puts "src/apps/papel: ok -- the static site (anchors, slugs, relink, titles, freshness)
",
    0))
