; site.l -- generate the kship site (index/repl/blue) from content + one template.
; a small markdown-subset converter written in ai, run on the HOST (the egg already
; carries the prel -- DO NOT pass `-l ai/prel.l`, that loads it twice and scares):
;   out/host/ai tools/site.l <page-id> <content.md> > <page>.html
; page-id is home | kship | repl | blue; it picks the <title>, the active top-nav item,
; whether a table of contents is emitted (home + blue), and an optional tail file
; (content/repl.tail.html, the repl's wasm shim -- home injects the same shim above the
; toc as the bao shell). one site.css is inlined into each page, so every page is
; self-contained, and the top nav links them.
; the supported markdown subset (same as blue.md): a leading "# " is the title, the
; next paragraph is the subtitle, "## t {#id}" / "### t {#id}" are anchored headings,
; a "> " line is a LAW BOX, "- "/"N. " are lists, "|...|" rows are a table (a |---|
; row splits header from body), a ``` fence is a code block, and "---" is a rule.
; inline: `code` (a `thm:name` span renders as a green chip), [text](url) links,
; **bold**, *italic*. < > & are escaped; everything else is raw UTF-8.

(:
  ; --- charlist basics ---
  (s2cl s) ((: (g i) (? (< i (tally s)) (link (peep s i 0) (g (+ 1 i))))) 0)
  (lines cl) ((: (go cl acc) (? (two? cl)
                                (: c (cap cl) (? (= c 10) (link (rev acc) (go (cup cl) 0))
                                                         (go (cup cl) (link c acc))))
                                (L (rev acc)))) cl 0)
  (starts? ln s) ((: (g ln i) (? (< i (tally s))
                                 (&& (two? ln) (= (cap ln) (peep s i 0)) (g (cup ln) (+ i 1)))
                                 1)) ln 0)
  (hasb cl c) (? (two? cl) (? (= (cap cl) c) 1 (hasb (cup cl) c)) 0)
  (upto cl c) (? (two? cl) (? (= (cap cl) c) 0 (link (cap cl) (upto (cup cl) c))) 0)
  (past cl c) (? (two? cl) (? (= (cap cl) c) (cup cl) (past (cup cl) c)) 0)
  (has2 cl) (? (&& (two? cl) (two? (cup cl))) (? (&& (= (cap cl) 42) (= (cap (cup cl)) 42)) 1 (has2 (cup cl))) 0)
  (upto2 cl) (? (&& (two? cl) (two? (cup cl)) (= (cap cl) 42) (= (cap (cup cl)) 42)) 0
                (? (two? cl) (link (cap cl) (upto2 (cup cl))) 0))
  (past2 cl) (? (&& (two? cl) (two? (cup cl)) (= (cap cl) 42) (= (cap (cup cl)) 42)) (cup (cup cl))
                (? (two? cl) (past2 (cup cl)) 0))
  (lstrip cl) (? (&& (two? cl) (= (cap cl) 32)) (lstrip (cup cl)) cl)
  (rstrip cl) (rev (lstrip (rev cl)))
  (trim cl) (rstrip (lstrip cl))
  (keepne lst) (? (two? lst) (? (two? (cap lst)) (link (cap lst) (keepne (cup lst))) (keepne (cup lst))) 0)
  (splitb cl c) ((: (g cl cur) (? (two? cl)
                                  (: x (cap cl) (? (= x c) (link (rev cur) (g (cup cl) 0)) (g (cup cl) (link x cur))))
                                  (L (rev cur)))) cl 0)
  (joinsp lst) (? (two? lst)
                  (? (two? (cup lst)) (+ (cap lst) (link 32 (joinsp (cup lst)))) (cap lst))
                  0)
  (skipdig ln) (? (&& (two? ln) (<= 48 (cap ln)) (<= (cap ln) 57)) (skipdig (cup ln)) ln)
  (ol? ln) (: r (skipdig ln) (&& (! (id? r ln)) (two? r) (= (cap r) 46) (two? (cup r)) (= (cap (cup r)) 32)))
  (ol-text ln) (drop 2 (skipdig ln))

  ; --- escaping + inline ---
  (esc1 c) (? (= c 60) "&lt;" (= c 62) "&gt;" (= c 38) "&amp;" (+ "" c))
  (escs cl) (? (two? cl) (+ (esc1 (cap cl)) (escs (cup cl))) "")
  (codeChip inner) (? (starts? inner "thm:")
                      (+ (+ "<span class=\"thm\">" (escs (drop 4 inner))) "</span>")
                      (+ (+ "<code>" (escs inner)) "</code>"))
  (inl cl) (? (two? cl)
              (: c (cap cl)
                 (? (= c 96) (: inner (upto (cup cl) 96) rest (past (cup cl) 96)
                                (+ (codeChip inner) (inl rest)))
                    (= c 91) (: txt (upto (cup cl) 93) aft (past (cup cl) 93)
                                (? (&& (two? aft) (= (cap aft) 40))
                                   (: url (upto (cup aft) 41) rest (past (cup aft) 41)
                                      (+ (+ (+ (+ "<a href=\"" (string url)) "\">") (inl txt)) (+ "</a>" (inl rest))))
                                   (+ "[" (inl (cup cl)))))
                    (&& (= c 42) (two? (cup cl)) (= (cap (cup cl)) 42) (has2 (cup (cup cl))))
                       (: body (cup (cup cl)) inner (upto2 body) rest (past2 body)
                          (+ (+ "<strong>" (inl inner)) (+ "</strong>" (inl rest))))
                    (&& (= c 42) (hasb (cup cl) 42)) (: inner (upto (cup cl) 42) rest (past (cup cl) 42)
                                (+ (+ "<em>" (inl inner)) (+ "</em>" (inl rest))))
                    (+ (esc1 c) (inl (cup cl)))))
              "")

  ; --- heading id split: "text {#id}" -> (text . id) ---
  (splitid raw) (? (hasb raw 123)
                   (: t (rstrip (upto raw 123)) id (upto (cup (past raw 123)) 125) (link t id))
                   (link raw 0))

  ; --- block parse: lines -> list of (tag payload) ---
  (starter? x) (? (starts? x "#") 1 (starts? x "> ") 1 (starts? x "- ") 1 (starts? x "|") 1
                  (starts? x "```") 1 (&& (starts? x "---") (= (tally x) 3)) 1 (ol? x) 1 0)
  (span p ls) (? (&& (two? ls) (p (cap ls)))
                 (: r (span p (cup ls)) (link (link (cap ls) (cap r)) (cup r)))
                 (link 0 ls))
  (parse ls) (? (! (two? ls)) 0
                (: ln (cap ls)
                   (? (! (two? ln)) (parse (cup ls))
                      (starts? ln "### ") (link (L 'h3 (drop 4 ln)) (parse (cup ls)))
                      (starts? ln "## ")  (link (L 'h2 (drop 3 ln)) (parse (cup ls)))
                      (starts? ln "# ")   (link (L 'h1 (drop 2 ln)) (parse (cup ls)))
                      (starts? ln "```")  (: sp (span (\ x (! (starts? x "```"))) (cup ls))
                                              more (? (two? (cup sp)) (cup (cup sp)) 0)
                                              (link (L 'pre (cap sp)) (parse more)))
                      (starts? ln "> ")   (link (L 'law (drop 2 ln)) (parse (cup ls)))
                      (starts? ln "- ")   (: sp (span (\ x (starts? x "- ")) ls)
                                              (link (L 'ul (map (\ x (drop 2 x)) (cap sp))) (parse (cup sp))))
                      (starts? ln "|")    (: sp (span (\ x (starts? x "|")) ls)
                                              (link (L 'table (cap sp)) (parse (cup sp))))
                      (&& (starts? ln "---") (= (tally ln) 3)) (link (L 'hr 0) (parse (cup ls)))
                      (ol? ln)            (: sp (span ol? ls)
                                              (link (L 'ol (map ol-text (cap sp))) (parse (cup sp))))
                      (: sp (span (\ x (&& (two? x) (! (starter? x)))) ls)
                         (link (L 'p (joinsp (cap sp))) (parse (cup sp)))))))

  ; --- emit ---
  (o s) (say out s)
  (emit-toc bs) (? (two? bs)
                   (: b (cap bs)
                      (? (= (cap b) 'h2)
                         (: sp (splitid (cap (cup b))) id (string (cup sp))
                            _ (o "<a href=\"#") _ (o id) _ (o "\">") _ (o (inl (cap sp))) _ (o "</a><br>\n")
                            (emit-toc (cup bs)))
                         (emit-toc (cup bs))))
                   0)
  (emit-law pl) (: _ (o "<div class=\"law\">")
                   _ (? (starts? pl "**")
                        (: body (cup (cup pl)) inner (upto2 body) rest (past2 body)
                           _ (o "<span class=\"n\">") _ (o (inl inner)) _ (o "</span>") (o (inl rest)))
                        (o (inl pl)))
                   (o "</div>\n"))
  (emit-list t items) (: _ (o "<") _ (o t) _ (o ">\n")
                         _ ((: (w xs) (? (two? xs) (: _ (o "<li>") _ (o (inl (cap xs))) _ (o "</li>\n") (w (cup xs))) 0)) items)
                         _ (o "</") _ (o t) (o ">\n"))
  (emit-pre body) (: _ (o "<pre><code>")
                     _ ((: (w xs) (? (two? xs) (: _ (o (escs (cap xs))) _ (o "\n") (w (cup xs))) 0)) body)
                     (o "</code></pre>\n"))
  (sepb? c) (|| (= c 45) (|| (= c 124) (|| (= c 32) (= c 58))))
  (allsep r) (? (two? r) (&& (sepb? (cap r)) (allsep (cup r))) 1)
  (seprow? r) (&& (hasb r 45) (allsep r))
  (emit-cells cells t) (? (two? cells)
                          (: _ (o "<") _ (o t) _ (o ">") _ (o (inl (cap cells))) _ (o "</") _ (o t) _ (o ">")
                             (emit-cells (cup cells) t))
                          0)
  (emit-row r t) (: _ (o "<tr>") _ (emit-cells (keepne (map trim (splitb r 124))) t) (o "</tr>\n"))
  (emit-table rows) (: _ (o "<table>\n")
                       _ ((: (w rs first) (? (two? rs)
                                             (? (seprow? (cap rs)) (w (cup rs) first)
                                                (: _ (emit-row (cap rs) (? first "th" "td")) (w (cup rs) 0)))
                                             0)) rows 1)
                       (o "</table>\n"))
  (go bs subdone tocdone)
     (? (! (two? bs)) 0
        (: b (cap bs) tag (cap b) pl (cap (cup b))
           (? (= tag 'h1) (: _ (o "<h1>") _ (o (inl pl)) _ (o "</h1>\n") (go (cup bs) subdone tocdone))
              (= tag 'p) (: _ (? subdone (o "<p>") (o "<p class=\"sub\">")) _ (o (inl pl)) _ (o "</p>\n") (go (cup bs) 1 tocdone))
              (= tag 'h2) (: _ (? tocdone 0 (: _ (o shellh) _ (o "<p class=\"toc\">\n") _ (emit-toc bs) _ (o "</p>\n") (o "<hr>\n")))
                             sp (splitid pl) id (string (cup sp))
                             _ (o "<h2 id=\"") _ (o id) _ (o "\"><a href=\"#") _ (o id) _ (o "\">")
                             _ (o (inl (cap sp))) _ (o "</a></h2>\n")
                             (go (cup bs) subdone 1))
              (= tag 'h3) (: sp (splitid pl) id (string (cup sp))
                             _ (o "<h3 id=\"") _ (o id) _ (o "\"><a href=\"#") _ (o id) _ (o "\">")
                             _ (o (inl (cap sp))) _ (o "</a></h3>\n")
                             (go (cup bs) subdone tocdone))
              (= tag 'law) (: _ (emit-law pl) (go (cup bs) subdone tocdone))
              (= tag 'ul) (: _ (emit-list "ul" pl) (go (cup bs) subdone tocdone))
              (= tag 'ol) (: _ (emit-list "ol" pl) (go (cup bs) subdone tocdone))
              (= tag 'pre) (: _ (emit-pre pl) (go (cup bs) subdone tocdone))
              (= tag 'table) (: _ (emit-table pl) (go (cup bs) subdone tocdone))
              (= tag 'hr) (: _ (o "<hr>\n") (go (cup bs) subdone tocdone))
              (go (cup bs) subdone tocdone))))

  (go-crew bs first1?)
     (? (! (two? bs)) 0
        (: b (cap bs) tag (cap b) pl (cap (cup b))
           (? (= tag 'h2) 0
              (= tag 'h1) (: sp (emdash pl) nm (trim (cap sp)) rest (trim (cup sp))
                             _ (o "<h1>") _ (o (inl nm)) _ (o " <span class=\"what\">\xc2\xb7 ")
                             _ (o (inl rest)) _ (o "</span></h1>\n")
                             (go-crew (cup bs) first1?))
              (= tag 'p) (? (&& first1? (bold-lead? pl))
                            (: _ (o "<p class=\"creed\">") _ (o (inl (lead-creed pl))) _ (o "</p>\n")
                               rest (lead-rest pl)
                               _ (? (two? rest) (: _ (o "<p>") _ (o (inl rest)) (o "</p>\n")) 0)
                               (go-crew (cup bs) 0))
                            (: _ (o "<p>") _ (o (inl pl)) _ (o "</p>\n") (go-crew (cup bs) 0)))
              (= tag 'ul) (: _ (emit-list "ul" pl) (go-crew (cup bs) first1?))
              (= tag 'ol) (: _ (emit-list "ol" pl) (go-crew (cup bs) first1?))
              (= tag 'pre) (: _ (emit-pre pl) (go-crew (cup bs) first1?))
              (= tag 'table) (: _ (emit-table pl) (go-crew (cup bs) first1?))
              (= tag 'law) (: _ (emit-law pl) (go-crew (cup bs) first1?))
              (= tag 'hr) (: _ (o "<hr>\n") (go-crew (cup bs) first1?))
              (= tag 'h3) (: _ (o "<h3>") _ (o (inl pl)) _ (o "</h3>\n") (go-crew (cup bs) first1?))
              (go-crew (cup bs) first1?))))

  ; --- crew-mode helpers (the crew bio pages) ---
  ; split a charlist on the first occurrence of the 3-byte em-dash "\xe2\x80\x94":
  ; (link before after); no dash -> (link cl 0).
  (dash3? cl) (&& (two? cl) (= (cap cl) 226)
                  (two? (cup cl)) (= (cap (cup cl)) 128)
                  (two? (cup (cup cl))) (= (cap (cup (cup cl))) 148))
  (emdash cl) ((: (g cl pre) (? (dash3? cl) (link (rev pre) (drop 3 cl))
                                (? (two? cl) (g (cup cl) (link (cap cl) pre))
                                   (link (rev pre) 0)))) cl 0)
  ; the middle dot " \xc2\xb7 " separates role from sign in the rest; take what's before.
  (mdot? cl) (&& (two? cl) (= (cap cl) 194) (two? (cup cl)) (= (cap (cup cl)) 183))
  (beforedot cl) ((: (g cl pre) (? (mdot? cl) (rev pre)
                                   (? (two? cl) (g (cup cl) (link (cap cl) pre)) (rev pre)))) cl 0)
  ; the member name from the md path "crew/<name>.md" -> "<name>".
  (basename p) ((: cl (s2cl p) (? (hasb cl 47) (rev (upto (rev cl) 47)) cl)))
  (stem cl) (? (hasb cl 46) (upto cl 46) cl)
  ; the bold LEAD of the first paragraph is the creed: a paragraph that opens with a
  ; "**...**" span splits into (creed-text . rest) -- the lead bold span (unwrapped)
  ; and the prose after it (trimmed). a paragraph not opening with "**" has no creed:
  ; (link 0 cl). (upto2/past2 carve the first "**...**" pair.)
  (bold-lead? cl) (: t (lstrip cl) (&& (two? t) (= (cap t) 42) (two? (cup t)) (= (cap (cup t)) 42)
                                       (has2 (drop 2 t))))
  (lead-creed cl) (: t (lstrip cl) (upto2 (drop 2 t)))    ; the lead span's text
  (lead-rest cl)  (: t (lstrip cl) (trim (past2 (drop 2 t))))  ; the prose after it

  ; --- per-page chrome: one template, four pages, one css inlined ---
  ; invoked `out/host/ai -l ai/prel.l tools/site.l <page-id> <content.md> > <page>.html`.
  ; the page-id (kship | repl | blue | crew) picks the title, the active nav item,
  ; whether a table of contents is emitted, an optional tail file (the repl's wasm
  ; shim), and -- for crew -- a wholly different bio chrome rendered from the md.
  (cc xs) (? (two? xs) (+ (cap xs) (cc (cup xs))) "")    ; concat a list of strings
  pageid (cap (cup argv))
  mdfile (cap (cup (cup argv)))
  crew? (= pageid "crew")
  toc?  (|| (= pageid "blue") (= pageid "home"))         ; the paper + the home page get a toc
  ; the per-page h1::before emoji (the telescope ::after is shared in site.css):
  ; kship -> rocket, repl(bao) -> dog, home/blue -> blue heart. crew pages: none.
  preji (? (= pageid "kship") "\xf0\x9f\x9a\x80" (= pageid "repl") "\xf0\x9f\x90\x95" "\xf0\x9f\x92\x99")
  shellh (? (= pageid "home") (slurp (open "content/repl.tail.html" "r")) "")  ; the bao shell, home only
  tailf (? (= pageid "repl") "content/repl.tail.html" "")  ; the repl injects the wasm shim
  sep " \xc2\xb7 "
  nav1 (\ id href label (? (= id pageid)
                           (cc (L "<span class=\"here\">" label "</span>"))
                           (cc (L "<a href=\"" href "\">" label "</a>"))))
  ; the crew topnav is a fixed bar of relative links (crew pages live in crew/).
  crewnav (+ "<p class=\"topnav\"><a href=\"../index.html\">\xe2\x86\x90 ai</a> \xc2\xb7 "
             (+ "<a href=\"index.html\">the crew</a> \xc2\xb7 "
                (+ "<a href=\"../blue.html\">blue paper</a> \xc2\xb7 "
                   "<a href=\"../README.md\">readme</a></p>\n")))
  topnav (? crew? crewnav
            (cc (L "<p class=\"topnav\">"
                   (nav1 "kship" "kship.html" "kship") sep
                   (nav1 "repl"  "repl.html"  "bao")  sep
                   (nav1 "blue"  "blue.html"  "blue paper") sep
                   "<a href=\"CLAUDE.md\">the spec</a>" sep
                   "<a href=\"crew/index.html\">the crew</a></p>\n")))

  css (slurp (open (? crew? "crew/crew.css" "site.css") "r"))
  md (slurp (open mdfile "r"))
  bs (parse (lines (s2cl md)))

  ; for crew: derive the member name + title from the parsed h1 line.
  h1pl (? (&& (two? bs) (= (cap (cap bs)) 'h1)) (cap (cup (cap bs))) "")
  h1sp (emdash h1pl)
  cname (trim (cap h1sp))                       ; "<name>"
  crole (trim (beforedot (trim (cup h1sp))))    ; "<role>" (the rest, sign tail dropped)
  mname (string (stem (basename mdfile)))       ; the .md filename stem, for the .md link
  ; the per-member crew h1::before animal: bellberry rabbit, aineko cat, gwen dove,
  ; bao dog, mow cow; every other member none. (bound after mname, which it reads.)
  crewji (? (= mname "bellberry") "\xf0\x9f\x90\xb0" (= mname "aineko") "\xf0\x9f\x90\xb1"
            (= mname "gwen") "\xf0\x9f\x95\x8a\xef\xb8\x8f" (= mname "bao") "\xf0\x9f\x90\x95"
            (= mname "mow") "\xf0\x9f\x90\x84" "")
  title (? crew? (cc (L (string cname) " \xe2\x80\x94 " (string crole)))
            (= pageid "home") "ai"
            (= pageid "blue") "ai blue paper" (= pageid "repl") "bao \xc2\xb7 the shell" "kship")
  htop (cc (L "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
              "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
              "<title>" title "</title>\n"))
  foot (? crew? "<footer>for p., b. and e.</footer>\n</body>\n</html>\n"
            (cc (L "<footer>generated from <a href=\"" mdfile "\">" mdfile "</a> by "
                   "<a href=\"tools/site.l\">tools/site.l</a>, an ai program \xc2\xb7 for p., b. and e."
                   "</footer>\n</body>\n</html>\n")))
  ; the .lives brief link (crew only), before the footer.
  lives (cc (L "<p class=\"lives\">lives in the crew \xc2\xb7 the full brief is "
               "<a href=\"" mname ".md\">crew/" mname ".md</a></p>\n"))

  _ (o htop)
  _ (o "<style>\n") _ (o css)
  _ (? crew? (? (= crewji "") 0 (: _ (o "h1::before { content: \"") _ (o crewji) (o " \"; }\n")))
       (: _ (o "h1::before { content: \"") _ (o preji) (o " \"; }\n")))
  _ (o "</style>\n")
  _ (o "</head>\n<body>\n")
  _ (? crew? (o "\n") 0)
  _ (o topnav)
  _ (? crew? (o "\n") 0)
  _ (? crew? (: _ (go-crew bs 1) (o lives))
       (go bs 0 (? toc? 0 1)))
  _ (? (! (= tailf "")) (o (slurp (open tailf "r"))) 0)
  (o foot))
