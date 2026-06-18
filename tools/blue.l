; blue.l -- generate blue.html from blue.md. a small markdown-subset converter
; written in ai, run on the host with the prel loaded:
;   out/host/ai -l ai/prel.l tools/blue.l blue.md > blue.html
; the supported subset is exactly what blue.md uses (no more): a leading "# " is
; the title, the next paragraph is the subtitle, "## t {#id}" / "### t {#id}" are
; anchored headings, a "> " line is a LAW BOX, "- "/"N. " are lists, "|...|" rows
; are a table (a |---| row splits header from body), a ``` fence is a code block,
; and "---" is a rule. inline: `code` (a `thm:name` span renders as a green chip),
; [text](url) links, **bold**, *italic*. the table of contents is built from the
; ## headings; the chrome (head, top nav, footer) is templated below. style lives
; in the single sheet blue.css. < > & are escaped; everything else is raw UTF-8.

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
              (= tag 'h2) (: _ (? tocdone 0 (: _ (o "<p class=\"toc\">\n") _ (emit-toc bs) _ (o "</p>\n") (o "<hr>\n")))
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

  ; the head splits around the stylesheet: blue.css is slurped and INLINED into a
  ; <style> block, so blue.html is a single self-contained file (blue.css stays the
  ; editable source the generator reads).
  htop (+ "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
          (+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n"
             "<title>ai \xe2\x80\x94 a blue paper</title>\n"))
  hrest (+ "</head>\n<body>\n"
           "<p class=\"topnav\"><a href=\"index.html\">\xe2\x86\x90 ai</a> \xc2\xb7 <a href=\"README.md\">readme</a> \xc2\xb7 <a href=\"CLAUDE.md\">the spec</a> \xc2\xb7 <a href=\"crew/index.html\">the crew</a></p>\n")
  foot "<footer>generated from <a href=\"blue.md\">blue.md</a> by <a href=\"tools/blue.l\">tools/blue.l</a>, an ai program \xc2\xb7 for bee</footer>\n</body>\n</html>\n"

  css (slurp (open "blue.css" "r"))
  md (slurp (open (cap (cup argv)) "r"))
  bs (parse (lines (s2cl md)))
  _ (o htop)
  _ (o "<style>\n") _ (o css) _ (o "</style>\n")
  _ (o hrest)
  _ (go bs 0 0)
  (o foot))
