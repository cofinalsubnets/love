; src/apps/caja/build.l -- caja's lists: box display (tex.web part 12), the semantic nest (16),
; the packager's reports (33), the page builder (45) and the building of boxes and lists
; (46-47). the second part of the module caja-tex, between mouth.l and exec.l. line_break and
; the ligature loop are par.l's, vert_break page.l's, packing and shipping box.l's; eqtb
; reaches them through J 'params.
(module 'caja-tex
(borrow 'posix)
(borrow 'tfm)
(borrow 'caja-box)
(borrow 'caja-par)
(borrow 'caja-page)
(:
   acc-kern 2 non-char 256 nest-size 500
   box-flag 1073741824 ship-out-flag 1073742336 leader-flag 1073742337
   awful-bad 1073741823 deplorable 100000 inserting 0 split-up 1

   ; --- nodes (tex.web 133-159), as box.l lays them ------------------------------------------
   (tl J) (J 'cur-list 'tail)
   (tail-append J n) (J 'cur-list @ L (pin (L 'tail) 'link n, pin L 'tail n))
   (new-null-box _) (cb-null-box 0)
   (new-glue g) {'type glue-node 'sub normal 'glue g 'leader () 'link ()}
   (new-param-glue J n) (new-glue (glue-par J n) @ p (pin p 'sub (n + 1), p))
   (new-skip-param J n) (new-glue (new-spec (glue-par J n)) @ p (pin p 'sub (n + 1), p))
   (new-kern w) {'type kern-node 'sub normal 'width w 'link ()}
   (new-penalty n) {'type penalty-node 'sub 0 'penalty n 'link ()}
   (new-disc _) {'type disc-node 'sub 0 'pre () 'post () 'link ()}
   (char-node? p) (p 'type = 'char)
   (tfm-of J f) (J 'fonts f 'tfm)
   (char-exists? J f c) (tfm-of J f @ t (t 'bc <= c && c <= t 'ec && 0 < <(t 'ci c)))
   (char-width J f c) (tfm-of J f @ t (t 'wd <(t 'ci c)))
   (char-height J f c) (tfm-of J f @ t (t 'ht ((t 'ci c) 1 // 16)))
   (char-italic J f c) (tfm-of J f @ t (t 'ic ((t 'ci c) 2 // 4)))
   (char-warning J f c)
    (int-par J tracing-lost-chars-code > 0 ?
       (begin-diagnostic J, print-nl J "Missing character: There is no ", print J c,
        print J " in font ", slow-print J (J 'fonts f 'name), print-char J 33, end-diagnostic J 0))
   (new-character J f c)
    (char-exists? J f c ? {'type 'char 'font f 'char c 'link ()} (char-warning J f c, ()))
   (copy-node-list p)
    (: h {'link ()}
       (go q p) (p = () ? (pin q 'link ()) (copy-node p @ r (pin q 'link r, go r (p 'link))))
       (go h p, h 'link))
   (copy-node p)
    (: r ({} @ t (map (k \ pin t k (p k)) (keys p), t))
       t (p 'type)
       ((? (t = hlist-node || t = vlist-node || t = unset-node) (pin r 'list (copy-node-list (p 'list)))
           (t = ins-node) (pin r 'ins (copy-node-list (p 'ins)))
           (t = glue-node) (pin r 'leader (copy-node-list (p 'leader)))
           (t = ligature-node) (pin r 'lig (copy-node-list (p 'lig)))
           (t = disc-node) (pin r 'pre (copy-node-list (p 'pre)), pin r 'post (copy-node-list (p 'post)))
           (t = adjust-node) (pin r 'adj (copy-node-list (p 'adj)))),
        r))
   ; the node replace_count nodes past p
   (skip-nodes p n) (n > 0 && p 'link != () ? (skip-nodes (p 'link) (n - 1)) p)

   ; --- displaying boxes (tex.web 173-198) ---------------------------------------------------
   (print-font J f) (print-esc J (font-id-text J f))
   (short-display J p0)
    (: (go p)
        (p != () ?
           (: t (p 'type)
              q (? (t = 'char)
                    (p 'font != J 'fisd ? (print-font J (p 'font), print-char J 32, pin J 'fisd (p 'font)),
                     print J (p 'char), p)
                   (elem t [hlist-node vlist-node ins-node whatsit-node mark-node adjust-node unset-node])
                    (print J "[]", p)
                   (t = rule-node) (print-char J 124, p)
                   (t = glue-node) (!(p 'glue == J 'zero-glue) ? (print-char J 32), p)
                   (t = math-node) (print-char J 36, p)
                   (t = ligature-node) (short-display J (p 'lig), p)
                   (t = disc-node)
                    (short-display J (p 'pre), short-display J (p 'post), skip-nodes p (p 'sub))
                   p)
              (go (q 'link))))
       (go p0))
   (print-font-and-char J p) (print-font J (p 'font), print-char J 32, print J (p 'char))
   (print-mark J l) (print-char J 123, show-token-list J l () (J 'max-print-line - 10), print-char J 125)
   (print-rule-dimen J d) (d = null-flag ? (print-char J 42) (print-scaled J d))
   ; Pascal's round, half away from zero
   (round-real x) (x >= 0 ? (floor (x + 0.5)) (0 - floor (0.5 - x)))
   (append-char J c) (pin J 'str-buf (c . J 'str-buf))
   (flush-char J) (pin J 'str-buf >(J 'str-buf))
   (node-list-display J p) (append-char J 46, show-node-list J p, flush-char J)
   (show-node-list J p0)
    (? (#(J 'str-buf) > J 'depth-threshold) (p0 != () ? (print J " []"))
       (: (go p n)
           (p != () ?
              (: _ (print-ln J) _ (print-current-string J)
                 (n + 1 > J 'breadth-max ? (print J "etc.") (display-node J p, go (p 'link) (n + 1)))))
          (go p0 0)))
   (display-node J p)
    (: t (p 'type)
       (? (t = 'char) (print-font-and-char J p)
          (t = hlist-node || t = vlist-node || t = unset-node) (display-box J p)
          (t = rule-node)
           (print-esc J "rule(", print-rule-dimen J (p 'height), print-char J 43,
            print-rule-dimen J (p 'depth), print J ")x", print-rule-dimen J (p 'width))
          (t = ins-node)
           (print-esc J "insert", print-int J (p 'sub), print J ", natural size ",
            print-scaled J (p 'height), print J "; split(", print-spec J (p 'split-top) "",
            print-char J 44, print-scaled J (p 'depth), print J "); float cost ",
            print-int J (p 'cost), node-list-display J (p 'ins))
          (t = glue-node) (display-glue J p)
          (t = kern-node)
           (? (p 'sub != mu-glue)
               (print-esc J "kern", p 'sub != normal ? (print-char J 32), print-scaled J (p 'width),
                p 'sub = acc-kern ? (print J " (for accent)"))
              (print-esc J "mkern", print-scaled J (p 'width), print J "mu"))
          (t = math-node)
           (print-esc J "math", print J (p 'sub = 0 ? "on" "off"),
            p 'width != 0 ? (print J ", surrounded ", print-scaled J (p 'width)))
          (t = ligature-node)
           (print-font-and-char J p, print J " (ligature ", p 'sub > 1 ? (print-char J 124),
            pin J 'fisd (p 'font), short-display J (p 'lig), p 'sub % 2 = 1 ? (print-char J 124),
            print-char J 41)
          (t = penalty-node) (print-esc J "penalty ", print-int J (p 'penalty))
          (t = disc-node)
           (print-esc J "discretionary", p 'sub > 0 ? (print J " replacing ", print-int J (p 'sub)),
            node-list-display J (p 'pre), append-char J 124, show-node-list J (p 'post), flush-char J)
          (t = mark-node) (print-esc J "mark", print-mark J (p 'mark))
          (t = adjust-node) (print-esc J "vadjust", node-list-display J (p 'adj))
          (print J "Unknown node type!")))
   (display-box J p)
    (: t (p 'type)
       _ (? (t = hlist-node) (print-esc J "h") (t = vlist-node) (print-esc J "v") (print-esc J "unset"))
       _ (print J "box(") _ (print-scaled J (p 'height)) _ (print-char J 43)
       _ (print-scaled J (p 'depth)) _ (print J ")x") _ (print-scaled J (p 'width))
       g (p 'gset)
       _ (g != 0 && p 'gsign != normal ?
            (print J ", glue set ", p 'gsign = 2 ? (print J "- "),
             (? (abs g > 20000.0)
                 (g > 0 ? (print-char J 62) (print J "< -"), print-glue J (20000 * 65536) (p 'gorder) "")
                (print-glue J (round-real (65536 * g)) (p 'gorder) ""))))
       _ (p 'shift != 0 ? (print J ", shifted ", print-scaled J (p 'shift)))
       (node-list-display J (p 'list)))
   (display-glue J p)
    (: s (p 'sub)
       (? (s >= a-leaders)
           (print-esc J "", (? (s = c-leaders) (print-char J 99) (s = x-leaders) (print-char J 120)),
            print J "leaders ", print-spec J (p 'glue) "", node-list-display J (p 'leader))
          (print-esc J "glue",
           s != normal ?
             (print-char J 40,
              (? (s < cond-math-glue) (print-skip-param J (s - 1)) (s = cond-math-glue) (print-esc J "nonscript")
                 (print-esc J "mskip")),
              print-char J 41),
           s != cond-math-glue ?
             (print-char J 32, print-spec J (p 'glue) (s < cond-math-glue ? "" "mu")))))
   (show-box J p)
    (pins J 'depth-threshold (int-par J show-box-depth-code) 'breadth-max (int-par J show-box-breadth-code),
     J 'breadth-max <= 0 ? (pin J 'breadth-max 5),
     show-node-list J p, print-ln J)

   ; --- the semantic nest (tex.web 211-219) ---------------------------------------------------
   (push-nest J)
    (: L (J 'cur-list) n (#(J 'nest))
       _ (n > J 'max-nest-stack ?
            (pin J 'max-nest-stack n, n = nest-size ? (overflow J "semantic nest size" nest-size)))
       H {'type 'head 'link ()}
       (pin J 'nest (L . J 'nest),
        pin J 'cur-list {'mode (L 'mode) 'head H 'tail H 'prev-depth (L 'prev-depth) 'sf (L 'sf)
                         'clang (L 'clang) 'pg 0 'ml (J 'line)}))
   (pop-nest J) (pin J 'cur-list <(J 'nest), pin J 'nest >(J 'nest))
   (set-mode J m) (pin (J 'cur-list) 'mode m)
   (contrib-head J) (J 'nest = () ? (J 'cur-list 'head) ((rev (J 'nest)) 0 'head))
   (show-activities J)
    (: _ (print-nl J "") _ (print-ln J)
       (each l)
        (two? l ?
           (: N <l m (N 'mode)
              _ (print-nl J "### ") _ (print-mode J m)
              _ (print J " entered at line ") _ (print-int J (abs (N 'ml)))
              _ (m = hmode && N 'pg != 8585216 ?
                   (print J " (language", print-int J (N 'pg % 65536), print J ":hyphenmin",
                    print-int J (N 'pg // 4194304), print-char J 44,
                    print-int J (N 'pg // 65536 % 64), print-char J 41))
              _ (N 'ml < 0 ? (print J " (\\output routine)"))
              _ (>l = () ?
                   (show-page-status J, N 'head 'link != () ? (print-nl J "### recent contributions:")))
              _ (show-box J (N 'head 'link))
              _ (? (abs m // 101 = 0)
                    (print-nl J "prevdepth ",
                     N 'prev-depth <= ignore-depth ? (print J "ignored") (print-scaled J (N 'prev-depth)),
                     N 'pg != 0 ?
                       (print J ", prevgraf ", print-int J (N 'pg), print J " line",
                        N 'pg != 1 ? (print-char J 115)))
                   (abs m // 101 = 1)
                    (print-nl J "spacefactor ", print-int J (N 'sf),
                     m > 0 && N 'clang > 0 ? (print J ", current language ", print-int J (N 'clang))))
              (each >l)))
       (each (J 'cur-list . J 'nest)))

   ; --- packaging, with tex.web's reports (644-679) ------------------------------------------
   ; par.l and box.l read their parameters by name off J 'params: eqtb's, as they stand
   param-ints
    [['pretolerance pretolerance-code] ['tolerance tolerance-code] ['looseness looseness-code]
     ['hangafter hang-after-code] ['linepenalty line-penalty-code]
     ['hyphenpenalty hyphen-penalty-code] ['exhyphenpenalty ex-hyphen-penalty-code]
     ['adjdemerits adj-demerits-code] ['doublehyphendemerits double-hyphen-demerits-code]
     ['finalhyphendemerits final-hyphen-demerits-code] ['interlinepenalty inter-line-penalty-code]
     ['clubpenalty club-penalty-code] ['widowpenalty widow-penalty-code]
     ['brokenpenalty broken-penalty-code] ['lefthyphenmin left-hyphen-min-code]
     ['righthyphenmin right-hyphen-min-code] ['uchyph uc-hyph-code] ['language language-code]
     ['hbadness hbadness-code] ['vbadness vbadness-code] ['mag mag-code] ['year year-code]
     ['month month-code] ['day day-code] ['time time-code]]
   param-dimens
    [['emergencystretch emergency-stretch-code] ['hsize hsize-code] ['hangindent hang-indent-code]
     ['parindent par-indent-code] ['lineskiplimit line-skip-limit-code] ['hfuzz hfuzz-code]
     ['vfuzz vfuzz-code] ['overfullrule overfull-rule-code] ['hoffset h-offset-code]
     ['voffset v-offset-code] ['splitmaxdepth split-max-depth-code] ['vsize vsize-code]]
   param-glues
    [['leftskip left-skip-code] ['rightskip right-skip-code] ['parfillskip par-fill-skip-code]
     ['baselineskip baseline-skip-code] ['lineskip line-skip-code] ['parskip par-skip-code]
     ['spaceskip space-skip-code] ['xspaceskip xspace-skip-code] ['splittopskip split-top-skip-code]]
   (sync-params J)
    (: pr (J 'params)
       (map (kv \ pin pr (kv 0) (int-par J (kv 1))) param-ints,
        map (kv \ pin pr (kv 0) (dimen-par J (kv 1))) param-dimens,
        map (kv \ pin pr (kv 0) (glue-par J (kv 1))) param-glues,
        pin pr 'parshape (equiv J par-shape-loc),
        map (k \ pin (J 'count) k (J 'eq (count-base + k))) ^10))
   (hpack J p w m) (sync-params J, cb-hpack J p w m)
   (vpackage J p h m l) (sync-params J, cb-vpackage J p h m l)
   ; box.l's report of a bad box, finished as tex.web 660-663 and 674-675 finish it
   (pack-report J r what v)
    (: h (r 'type = hlist-node) pbl (J 'pack-begin-line)
       _ (print-ln J) _ (print-nl J what)
       _ (? (what = "Overfull")
             (print J (h ? " \\hbox (" " \\vbox ("), print-scaled J v,
              print J (h ? "pt too wide" "pt too high"))
            (print J (h ? " \\hbox (badness " " \\vbox (badness "), print-int J v))
       _ (? (J 'output-active) (print J ") has occurred while \\output is active")
            (: _ (? (pbl != 0)
                     (print J (pbl > 0 && h ? ") in paragraph at lines " ") in alignment at lines "),
                      print-int J (abs pbl), print J "--")
                    (print J ") detected at line "))
               _ (print-int J (J 'line))
               (h ? () (print-ln J))))
       _ (h ? (print-ln J, pin J 'fisd null-font, short-display J (r 'list), print-ln J))
       (begin-diagnostic J, show-box J r, end-diagnostic J 1))
   (append-to-vlist J b)
    (: L (J 'cur-list)
       _ (L 'prev-depth > ignore-depth ?
            (: d (glue-par J baseline-skip-code 'width - L 'prev-depth - b 'height)
               (tail-append J
                  (? (d < dimen-par J line-skip-limit-code) (new-param-glue J line-skip-code)
                     (new-skip-param J baseline-skip-code @ p (pin (p 'glue) 'width d, p))))))
       (tail-append J b, pin L 'prev-depth (b 'depth)))

   ; --- the main loop (tex.web 1034-1044): par.l's, with get_next for its lookahead -----------
   (main-loop J)
    (: L (J 'cur-list)
       _ (L 'mode > 0 && int-par J language-code != L 'clang ? (not-yet J "\\language changes"))
       _ (pins L 'font (equiv J cur-font-loc) 'restricted (L 'mode < 0))
       (cp-lig J L (J 'cur-chr) (\ _ (lookahead J))))
   (lookahead J)
    (: _ (get-next J) c (J 'cur-cmd)
       (? (c = letter || c = other-char || c = char-given) (J 'cur-chr)
          (: _ (x-token J) c (J 'cur-cmd)
             (? (c = letter || c = other-char || c = char-given) (J 'cur-chr)
                (c = char-num) (scan-char-num J, J 'cur-val)
                (c = no-boundary) 'nb
                ()))))
   (font-glue J f)
    (J 'fonts f @ F
       (F 'glue = () ?
          (pin F 'glue (spec (font-param J f space-code) (font-param J f space-stretch-code) normal
                             (font-param J f space-shrink-code) normal)),
        F 'glue))
   (append-normal-space J)
    (tail-append J
       (glue-par J space-skip-code == J 'zero-glue ? (new-glue (font-glue J (equiv J cur-font-loc)))
          (new-param-glue J space-skip-code)))
   (app-space J)
    (: sf (J 'cur-list 'sf) xs (glue-par J xspace-skip-code)
       (tail-append J
          (? (sf >= 2000 && !(xs == J 'zero-glue)) (new-param-glue J xspace-skip-code)
             (: ss (glue-par J space-skip-code) f (equiv J cur-font-loc)
                b (new-spec (ss == J 'zero-glue ? (font-glue J f) ss))
                _ (sf >= 2000 ? (pin b 'width (b 'width + font-param J f extra-space-code)))
                _ (pins b 'stretch (xn-over-d J (b 'stretch) sf 1000) 'shrink (xn-over-d J (b 'shrink) 1000 sf))
                (new-glue b)))))

   ; --- building boxes and lists (tex.web 1055-1135) -----------------------------------------
   (append-glue J)
    (: s (J 'cur-chr)
       g (? (s = fil-code) (J 'fil-glue) (s = fill-code) (J 'fill-glue) (s = ss-code) (J 'ss-glue)
            (s = fil-neg-code) (J 'fil-neg-glue)
            (s = skip-code) (scan-glue J glue-val, J 'cur-val)
            (scan-glue J mu-val, J 'cur-val))
       (tail-append J (new-glue g), s > skip-code ? (pin (tl J) 'sub mu-glue)))
   (append-kern J)
    (: s (J 'cur-chr) _ (scan-dimen J (s = mu-glue) 0 0)
       (tail-append J (new-kern (J 'cur-val)), pin (tl J) 'sub s))
   (box-end J bc)
    (: b (J 'cur-box) m (abs (mode J))
       (? (bc < box-flag)
           (b != () ?
              (pin b 'shift bc,
               (? (m = vmode)
                   (append-to-vlist J b,
                    J 'adjust != () ?
                      (J 'adjust-head 'link != () ?
                         (pin (tl J) 'link (J 'adjust-head 'link), pin (J 'cur-list) 'tail (J 'adjust)),
                       pin J 'adjust ()),
                    mode J > 0 ? (build-page J))
                  (m = hmode) (pin (J 'cur-list) 'sf 1000, tail-append J b)
                  (not-yet J "math"))))
          (bc < ship-out-flag)
           (bc < box-flag + 256 ? (eq-define J (box-base - box-flag + bc) box-ref b)
              (geq-define J (box-base - box-flag - 256 + bc) box-ref b))
          (b != ()) (bc > ship-out-flag ? (append-leaders J bc b) (ship-out J b))))
   (append-leaders J bc b)
    (: _ (non-blank-non-relax J) cmd (J 'cur-cmd) m (abs (mode J))
       ((cmd = hskip && m != vmode) || (cmd = vskip && m = vmode) ?
          (append-glue J, pins (tl J) 'sub (bc - (leader-flag - a-leaders)) 'leader b)
          (print-err J "Leaders not followed by proper glue",
           set-help J ["You should say `\\leaders <box or rule><hskip or vskip>'."
                       "I found the <box or rule>, but there's no suitable"
                       "<hskip or vskip>, so I'm ignoring these leaders."],
           back-error J)))
   (begin-box J bc)
    (: c (J 'cur-chr)
       (? (c = box-code)
           (: _ (scan-eight-bit-int J) n (box-base + J 'cur-val)
              (pin J 'cur-box (equiv J n), pin (J 'eq) n (), box-end J bc))
          (c = copy-code)
           (scan-eight-bit-int J, pin J 'cur-box (copy-node-list (equiv J (box-base + J 'cur-val))),
            box-end J bc)
          (c = last-box-code) (last-box J, box-end J bc)
          (c = vsplit-code)
           (: _ (scan-eight-bit-int J) n (J 'cur-val)
              _ (scan-keyword J "to" ? ()
                   (print-err J "Missing `to' inserted",
                    set-help J ["I'm working on `\\vsplit<box number> to <dimen>';"
                                "will look for the <dimen> next."],
                    tex-error J))
              _ (scan-normal-dimen J)
              (pin J 'cur-box (vsplit J n (J 'cur-val)), box-end J bc))
          (: k (c - vtop-code)
             _ (set-saved J 0 bc)
             _ (? (k = hmode)
                   (scan-spec J (bc < box-flag && abs (mode J) = vmode ? adjusted-hbox-group hbox-group) 1)
                  (k = vmode) (scan-spec J vbox-group 1, normal-paragraph J)
                  (scan-spec J vtop-group 1, normal-paragraph J))
             _ (push-nest J)
             L (J 'cur-list)
             (? (k = hmode)
                 (pins L 'mode (0 - hmode) 'sf 1000,
                  equiv J every-hbox-loc != () ? (begin-token-list J (equiv J every-hbox-loc) every-hbox-text))
                (pins L 'mode (0 - vmode) 'prev-depth ignore-depth,
                 equiv J every-vbox-loc != () ? (begin-token-list J (equiv J every-vbox-loc) every-vbox-text))))))
   (last-box J)
    (: L (J 'cur-list) m (mode J)
       _ (pin J 'cur-box ())
       (? (abs m = mmode) (you-cant J, set-help J ["Sorry; this \\lastbox will be void."], tex-error J)
          (m = vmode && L 'head == L 'tail)
           (you-cant J,
            set-help J ["Sorry...I usually can't take things from the current page."
                        "This \\lastbox will therefore be void."],
            tex-error J)
          (L 'tail @ t
             (t 'type = hlist-node || t 'type = vlist-node ?
                (before-tail L @ p
                   (p != () ? (pin J 'cur-box t, pin t 'shift 0, pin L 'tail p, pin p 'link ())))))))
   ; the node before L's tail, or () when the tail is part of a discretionary (tex.web 1081)
   (before-tail L)
    (: t (L 'tail)
       (go q)
        (: p (q 'type = disc-node ? (skip-nodes q (q 'sub)) q)
           (? (p == t) () (p 'link == t) p (go (p 'link))))
       (go (L 'head)))
   (scan-spec J c three)
    (: s (three ? (saved J 0) 0)
       sc (? (scan-keyword J "to") 'exactly (scan-keyword J "spread") 'additional ())
       _ (sc = () ? (pin J 'cur-val 0) (scan-normal-dimen J))
       _ (three ? (set-saved J 0 s, pin J 'save-ptr (J 'save-ptr + 1)))
       _ (set-saved J 0 (sc = () ? 'additional sc))
       _ (set-saved J 1 (J 'cur-val))
       _ (pin J 'save-ptr (J 'save-ptr + 2))
       (new-save-level J c, scan-left-brace J))
   (scan-box J bc)
    (: _ (non-blank-non-relax J) cmd (J 'cur-cmd)
       (? (cmd = make-box) (begin-box J bc)
          (bc >= leader-flag && (cmd = hrule || cmd = vrule))
           (pin J 'cur-box (scan-rule-spec J), box-end J bc)
          (print-err J "A <box> was supposed to be here",
           set-help J ["I was expecting to see \\hbox or \\vbox or \\copy or \\box or"
                       "something like that. So you might find something missing in"
                       "your output. But keep trying; you can fix this later."],
           back-error J)))
   (package J c)
    (: d (dimen-par J box-max-depth-code)
       _ (unsave J)
       _ (pin J 'save-ptr (J 'save-ptr - 3))
       L (J 'cur-list)
       b (? (L 'mode = 0 - hmode) (hpack J (L 'head 'link) (saved J 2) (saved J 1))
            (: v (vpackage J (L 'head 'link) (saved J 2) (saved J 1) d)
               p (v 'list)
               h (p != () && !(char-node? p) && p 'type <= rule-node ? (p 'height) 0)
               (c = vtop-code ? (pins v 'depth (v 'depth - h + v 'height) 'height h), v)))
       _ (pin J 'cur-box b)
       _ (pop-nest J)
       (box-end J (saved J 0)))
   (norm-min h) (? (h <= 0) 1 (h >= 63) 63 h)
   (new-graf J indented)
    (: L (J 'cur-list)
       _ (pin L 'pg 0)
       _ (L 'mode = vmode || !(L 'head == L 'tail) ? (tail-append J (new-param-glue J par-skip-code)))
       _ (push-nest J)
       N (J 'cur-list)
       lang (int-par J language-code @ l (l <= 0 || l > 255 ? 0 l))
       _ (pins N 'mode hmode 'sf 1000 'clang lang
               'pg ((norm-min (int-par J left-hyphen-min-code) * 64
                     + norm-min (int-par J right-hyphen-min-code)) * 65536 + lang))
       _ (indented ?
            (new-null-box () @ b (pin b 'width (dimen-par J par-indent-code), tail-append J b)))
       _ (equiv J every-par-loc != () ? (begin-token-list J (equiv J every-par-loc) every-par-text))
       (#(J 'nest) = 1 ? (build-page J)))
   (indent-in-hmode J)
    (J 'cur-chr > 0 ?
       (new-null-box () @ p
          (pin p 'width (dimen-par J par-indent-code),
           abs (mode J) = hmode ? (pin (J 'cur-list) 'sf 1000) (not-yet J "math"),
           tail-append J p)))
   (head-for-vmode J)
    (? (mode J < 0)
        (? (J 'cur-cmd != hrule) (off-save J)
           (print-err J "You can't use `", print-esc J "hrule", print J "' here except with leaders",
            set-help J ["To put a horizontal rule in an hbox or an alignment,"
                        "you should use \\leaders or \\hrulefill (see The TeXbook)."],
            tex-error J))
       (back-input J, pin J 'cur-tok (J 'par-token), back-input J, pin (J 'cur) 'index inserted))
   (end-graf J)
    (mode J = hmode ?
       (J 'cur-list @ L (L 'head == L 'tail ? (pop-nest J) (line-break J (int-par J widow-penalty-code))),
        normal-paragraph J,
        pin J 'error-count 0))
   ; line_break is par.l's, on a view of the paragraph and the list it goes to (tex.web 815-816)
   (line-break J fwp)
    (: H (J 'cur-list)
       _ (pin J 'pack-begin-line (H 'ml))
       _ (pop-nest J)
       V (J 'cur-list)
       _ (sync-params J)
       M {'mode 'h 'hhead (H 'head) 'tail (H 'tail) 'hpg (H 'pg)
          'vhead (V 'head) 'vtail (V 'tail) 'pd (V 'prev-depth) 'vpg (V 'pg)}
       _ (cp-line-break J M fwp)
       (pins V 'tail (M 'vtail) 'prev-depth (M 'pd) 'pg (M 'vpg),
        pin J 'pack-begin-line 0))
   (begin-insert-or-adjust J)
    (: _ (? (J 'cur-cmd = vadjust) (pin J 'cur-val 255)
            (: _ (scan-eight-bit-int J)
               (J 'cur-val = 255 ?
                  (print-err J "You can't ", print-esc J "insert", print-int J 255,
                   set-help J ["I'm changing to \\insert0; box 255 is special."],
                   tex-error J, pin J 'cur-val 0))))
       _ (set-saved J 0 (J 'cur-val)) _ (pin J 'save-ptr (J 'save-ptr + 1))
       _ (new-save-level J insert-group) _ (scan-left-brace J) _ (normal-paragraph J)
       _ (push-nest J)
       (pins (J 'cur-list) 'mode (0 - vmode) 'prev-depth ignore-depth))
   (end-insert-group J)
    (: _ (end-graf J)
       q (glue-par J split-top-skip-code) d (dimen-par J split-max-depth-code)
       f (int-par J floating-penalty-code)
       _ (unsave J) _ (pin J 'save-ptr (J 'save-ptr - 1))
       p (vpackage J (J 'cur-list 'head 'link) 0 'additional max-dimen)
       _ (pop-nest J)
       _ (tail-append J
            (saved J 0 < 255 ?
               {'type ins-node 'sub (saved J 0) 'height (p 'height + p 'depth) 'ins (p 'list)
                'split-top q 'depth d 'cost f 'link ()}
               {'type adjust-node 'sub 0 'adj (p 'list) 'link ()}))
       (J 'nest = () ? (build-page J)))
   (make-mark J) (: l (scan-toks J 0 1) (tail-append J {'type mark-node 'sub 0 'mark l 'link ()}))
   (append-penalty J)
    (scan-int J, tail-append J (new-penalty (J 'cur-val)), mode J = vmode ? (build-page J))
   (delete-last J)
    (: L (J 'cur-list) c (J 'cur-chr)
       (? (mode J = vmode && L 'tail == L 'head)
           (c != glue-node || J 'last-glue != () ?
              (you-cant J,
               set-help J ["Sorry...I usually can't take things from the current page."
                           (? (c = kern-node) "Try `I\\kern-\\lastkern' instead."
                              (c != glue-node) "Perhaps you can make the output routine do it."
                              "Try `I\\vskip-\\lastskip' instead.")],
               tex-error J))
          (L 'tail 'type = c ?
             (before-tail L @ p (p != () ? (pin p 'link (), pin L 'tail p))))))
   (unpackage J)
    (: c (J 'cur-chr) _ (scan-eight-bit-int J) n (box-base + J 'cur-val) p (equiv J n)
       m (abs (mode J))
       (? (p = ()) ()
          (m = mmode || (m = vmode && p 'type != vlist-node) || (m = hmode && p 'type != hlist-node))
           (print-err J "Incompatible list can't be unboxed",
            set-help J ["Sorry, Pandora. (You sneaky devil.)"
                        "I refuse to unbox an \\hbox in vertical mode or vice versa."
                        "And I can't open any boxes in math mode."],
            tex-error J)
          (: L (J 'cur-list)
             _ (pin (L 'tail) 'link (c = copy-code ? (copy-node-list (p 'list)) (p 'list)))
             _ (c != copy-code ? (pin (J 'eq) n ()))
             (go t) (t 'link = () ? t (go (t 'link)))
             (pin L 'tail (go (L 'tail))))))
   (append-italic-correction J)
    (: L (J 'cur-list) t (L 'tail)
       (!(t == L 'head) && (char-node? t || t 'type = ligature-node) ?
          (tail-append J (new-kern (char-italic J (t 'font) (t 'char))), pin (tl J) 'sub explicit)))
   (append-discretionary J)
    (: _ (tail-append J (new-disc ()))
       (J 'cur-chr = 1 ?
          (: f (equiv J cur-font-loc) c (J 'fonts f 'hyphenchar)
             (c >= 0 && c < 256 ? (pin (tl J) 'pre (new-character J f c))))
          (pin J 'save-ptr (J 'save-ptr + 1), set-saved J -1 0, disc-group-again J)))
   (disc-group-again J)
    (new-save-level J disc-group, scan-left-brace J, push-nest J,
     pins (J 'cur-list) 'mode (0 - hmode) 'sf 1000)
   (build-discretionary J)
    (: _ (unsave J)
       L (J 'cur-list)
       ; only characters, kerns, boxes, rules and ligatures stay (tex.web 1121)
       (prune q n)
        (q 'link @ p
           (? (p = ()) [q n]
              (!(char-node? p) && p 'type > rule-node && p 'type != kern-node && p 'type != ligature-node)
               (: _ (print-err J "Improper discretionary list")
                  _ (set-help J ["Discretionary lists must contain only boxes and kerns."])
                  _ (tex-error J) _ (begin-diagnostic J)
                  _ (print-nl J "The following discretionary sublist has been deleted:")
                  _ (show-box J p) _ (end-diagnostic J 1)
                  (pin q 'link (), [q n]))
              (prune p (n + 1))))
       qn (prune (L 'head) 0) q <qn n (qn 1)
       p (L 'head 'link)
       _ (pop-nest J)
       d (tl J) s (saved J -1)
       (? (s = 0) (pin d 'pre p, set-saved J -1 1, disc-group-again J)
          (s = 1) (pin d 'post p, set-saved J -1 2, disc-group-again J)
          (: n2 (? (n > 0 && abs (mode J) = mmode)
                    (print-err J "Illegal math ", print-esc J "discretionary",
                     set-help J ["Sorry: The third part of a discretionary break must be"
                                 "empty, in math formulas. I had to delete your third part."],
                     tex-error J, 0)
                    (pin d 'link p, n))
             _ (n2 <= 255 ? (pin d 'sub n2)
                  (print-err J "Discretionary list is too long",
                   set-help J ["Wow---I never thought anybody would tweak me here."
                               "You can't seriously need such a huge discretionary list?"],
                   tex-error J))
             _ (n2 > 0 ? (pin (J 'cur-list) 'tail q))
             (pin J 'save-ptr (J 'save-ptr - 1)))))
   (do-assignments J)
    (: (go _)
        (non-blank-non-relax J,
         J 'cur-cmd > max-non-prefixed-command ?
           (pin J 'set-box-allowed 0, prefixed-command J, pin J 'set-box-allowed 1, go ()))
       (go ()))
   (make-accent J)
    (: _ (scan-char-num J) f (equiv J cur-font-loc) p (new-character J f (J 'cur-val))
       (p != () ?
          (: x (font-param J f x-height-code) s (font-param J f slant-code / 65536.0)
             a (char-width J f (p 'char))
             _ (do-assignments J)
             f2 (equiv J cur-font-loc) cmd (J 'cur-cmd)
             q (? (cmd = letter || cmd = other-char || cmd = char-given) (new-character J f2 (J 'cur-chr))
                  (cmd = char-num) (scan-char-num J, new-character J f2 (J 'cur-val))
                  (back-input J, ()))
             r (? (q = ()) p
                  (: t (font-param J f2 slant-code / 65536.0)
                     w (char-width J f2 (q 'char)) h (char-height J f2 (q 'char))
                     p1 (h != x ? (hpack J p 0 'additional @ b (pin b 'shift (x - h), b)) p)
                     delta (round-real ((w - a) / 2.0 + h * t - x * s))
                     k1 (new-kern delta) _ (pin k1 'sub acc-kern)
                     k2 (new-kern (0 - a - delta)) _ (pin k2 'sub acc-kern)
                     (pin (tl J) 'link k1, pin k1 'link p1, pin p1 'link k2, pin (J 'cur-list) 'tail k2,
                      q)))
             (tail-append J r, pin (J 'cur-list) 'sf 1000))))
   (align-error J)
    (? (abs (J 'align-state) > 2)
        (print-err J "Misplaced ", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
         set-help J (J 'cur-tok = tab-token + 38 ?
                       ["I can't figure out why you would want to use a tab mark"
                        "here. If you just want an ampersand, the remedy is"
                        "simple: Just type `I\\&' now. But if some right brace"
                        "up above has ended a previous alignment prematurely,"
                        "you're probably due for more error messages, and you"
                        "might try typing `S' now just to see what is salvageable."]
                       ["I can't figure out why you would want to use a tab mark"
                        "or \\cr or \\span just now. If something like a right brace"
                        "up above has ended a previous alignment prematurely,"
                        "you're probably due for more error messages, and you"
                        "might try typing `S' now just to see what is salvageable."]),
         tex-error J)
       (: _ (back-input J)
          _ (? (J 'align-state < 0)
                (print-err J "Missing { inserted", pin J 'align-state (J 'align-state + 1),
                 pin J 'cur-tok (left-brace-token + 123))
                (print-err J "Missing } inserted", pin J 'align-state (J 'align-state - 1),
                 pin J 'cur-tok (right-brace-token + 125)))
          _ (set-help J ["I've put in what seems to be necessary to fix"
                         "the current column of the current alignment."
                         "Try to go on, since this might almost work."])
          (ins-error J)))
   (no-align-error J)
    (print-err J "Misplaced ", print-esc J "noalign",
     set-help J ["I expect to see \\noalign only after the \\cr of"
                 "an alignment. Proceed, and I'll ignore this case."],
     tex-error J)
   (omit-error J)
    (print-err J "Misplaced ", print-esc J "omit",
     set-help J ["I expect to see \\omit only after tab marks or the \\cr of"
                 "an alignment. Proceed, and I'll ignore this case."],
     tex-error J)

   ; --- the page builder (tex.web 980-1028) ----------------------------------------------------
   ; the current page hangs off J 'page-head; J 'page-ins holds tex.web's page-insertion records,
   ; sorted by box number, each {'sub 'type 'height 'broken-ptr 'broken-ins 'last-ins 'best-ins}
   (at? p b) (? (p = ()) (b = ()) (b = ()) 0 (p == b))
   (last-node p) (p 'link = () ? p (last-node (p 'link)))
   (box-reg J n) (equiv J (box-base + n))
   (set-box-reg J n b) (pin (J 'eq) (box-base + n) b)
   (count-reg J n) (J 'eq (count-base + n))
   (scaled-count J x n) (count-reg J n = 1000 ? x ((x // 1000) * count-reg J n))
   (vpack J p h m) (vpackage J p h m max-dimen)
   (psf J k) (J 'page-so-far k)
   (psf! J k v) (pin (J 'page-so-far) k v)
   (set-contrib-tail J t) (pin (J 'nest = () ? (J 'cur-list) ((rev (J 'nest)) 0)) 'tail t)
   (print-totals J)
    (: (plus k s) (psf J k != 0 ? (print J " plus ", print-scaled J (psf J k), print J s))
       (print-scaled J (psf J 1), plus 2 "", plus 3 "fil", plus 4 "fill", plus 5 "filll",
        psf J 6 != 0 ? (print J " minus ", print-scaled J (psf J 6))))
   (show-page-status J)
    (: ph (J 'page-head)
       (count-ins q b n)
        (: q2 (q 'link) k (q2 'type = ins-node && q2 'sub = n ? 1 0)
           (q2 == b ? k (k + count-ins q2 b n)))
       (ph == J 'page-tail ? ()
          (print-nl J "### current page:",
           J 'output-active ? (print J " (held over for next output)"),
           show-box J (ph 'link),
           J 'page-contents > empty ?
             (print-nl J "total height ", print-totals J,
              print-nl J " goal height ", print-scaled J (psf J 0),
              map (r \ (: n (r 'sub)
                          _ (print-ln J) _ (print-esc J "insert") _ (print-int J n)
                          _ (print J " adds ") _ (print-scaled J (scaled-count J (r 'height) n))
                          (r 'type = split-up ?
                             (print J ", #", print-int J (count-ins ph (r 'broken-ins) n),
                              print J " might split"))))
                  (J 'page-ins)))))
   (freeze-page-specs J s)
    (pins J 'page-contents s 'page-max-depth (dimen-par J max-depth-code) 'least-page-cost awful-bad,
     psf! J 0 (dimen-par J vsize-code), map (k \ psf! J k 0) [1 2 3 4 5 6 7],
     int-par J tracing-pages-code > 0 ?
       (begin-diagnostic J, print-nl J "%% goal height=", print-scaled J (psf J 0),
        print J ", max depth=", print-scaled J (J 'page-max-depth), end-diagnostic J 0))
   (start-new-page J)
    (pins J 'page-contents empty 'page-tail (J 'page-head) 'last-glue () 'last-penalty 0
            'last-kern 0 'page-max-depth 0,
     pin (J 'page-head) 'link (), psf! J 7 0)
   (box-error J n)
    (tex-error J, begin-diagnostic J, print-nl J "The following box has been deleted:",
     show-box J (box-reg J n), end-diagnostic J 1, set-box-reg J n ())
   (ensure-vbox J n)
    (box-reg J n @ p
       (p != () && p 'type = hlist-node ?
          (print-err J "Insertions can only be added to a vbox",
           set-help J ["Tut tut: You're trying to \\insert into a"
                       "\\box register that now contains an \\hbox."
                       "Proceed, and I'll discard its present contents."],
           box-error J n)))
   ; the record for insertions into box n, made on the first (tex.web 1009)
   (page-ins-for J n)
    (: m (filter (r \ r 'sub = n) (J 'page-ins))
       (into r l) (l = () || <l 'sub > n ? (r . l) (<l . into r >l))
       (m != () ? <m
          (: r {'sub n 'type inserting 'height 0 'best-ins () 'last-ins () 'broken-ptr () 'broken-ins ()}
             _ (pin J 'page-ins (into r (J 'page-ins)))
             _ (ensure-vbox J n)
             _ (box-reg J n @ b (pin r 'height (b = () ? 0 (b 'height + b 'depth))))
             q (equiv J (skip-base + n))
             _ (psf! J 0 (psf J 0 - scaled-count J (r 'height) n - q 'width))
             _ (psf! J (2 + q 'sto) (psf J (2 + q 'sto) + q 'stretch))
             _ (psf! J 6 (psf J 6 + q 'shrink))
             _ (q 'sho != normal && q 'shrink != 0 ?
                  (print-err J "Infinite glue shrinkage inserted from ", print-esc J "skip", print-int J n,
                   set-help J ["The correction glue for page breaking with insertions"
                               "must have finite shrinkability. But you may proceed,"
                               "since the offensive shrinkability has been made finite."],
                   tex-error J))
             r)))
   ; an insertion goes onto the page, whole or to be split (tex.web 1008, 1010)
   (append-insertion J p)
    (: _ (J 'page-contents = empty ? (freeze-page-specs J inserts-only))
       n (p 'sub) r (page-ins-for J n)
       (? (r 'type = split-up) (pin J 'insert-penalties (J 'insert-penalties + p 'cost))
          (: _ (pin r 'last-ins p)
             delta (psf J 0 - psf J 1 - psf J 7 + psf J 6)
             h (scaled-count J (p 'height) n)
             ((h <= 0 || h <= delta) && p 'height + r 'height <= J 'eq (scaled-base + n) ?
                (psf! J 0 (psf J 0 - h), pin r 'height (r 'height + p 'height))
                (: w0 (? (count-reg J n <= 0) max-dimen
                         (psf J 0 - psf J 1 - psf J 7 @ w
                            (count-reg J n != 1000 ? ((w // count-reg J n) * 1000) w)))
                   room (J 'eq (scaled-base + n) - r 'height)
                   w (w0 > room ? room w0)
                   q (cg-vert-break J (p 'ins) w (p 'depth))
                   _ (pin r 'height (r 'height + J 'best-height-plus-depth))
                   _ (int-par J tracing-pages-code > 0 ?
                        (begin-diagnostic J, print-nl J "% split", print-int J n, print J " to ",
                         print-scaled J w, print-char J 44, print-scaled J (J 'best-height-plus-depth),
                         print J " p=",
                         (? (q = ()) (print-int J eject-penalty)
                            (q 'type = penalty-node) (print-int J (q 'penalty))
                            (print-char J 48)),
                         end-diagnostic J 0))
                   _ (pin J 'best-height-plus-depth (scaled-count J (J 'best-height-plus-depth) n))
                   _ (psf! J 0 (psf J 0 - J 'best-height-plus-depth))
                   _ (pins r 'type split-up 'broken-ptr q 'broken-ins p)
                   (? (q = ()) (pin J 'insert-penalties (J 'insert-penalties + eject-penalty))
                      (q 'type = penalty-node)
                       (pin J 'insert-penalties (J 'insert-penalties + q 'penalty))))))))
   (build-page J)
    (: c (contrib-head J)
       (contribute p)
        (: _ (psf J 7 > J 'page-max-depth ?
                (psf! J 1 (psf J 1 + psf J 7 - J 'page-max-depth), psf! J 7 (J 'page-max-depth)))
           (pin (J 'page-tail) 'link p, pin J 'page-tail p, pin c 'link (p 'link), pin p 'link ()))
       (update-heights p)
        (: q (? (p 'type = kern-node) p
                (: g (p 'glue)
                   _ (psf! J (2 + g 'sto) (psf J (2 + g 'sto) + g 'stretch))
                   _ (psf! J 6 (psf J 6 + g 'shrink))
                   (g 'sho != normal && g 'shrink != 0 ?
                      (print-err J "Infinite glue shrinkage found on current page",
                       set-help J ["The page about to be output contains some infinitely"
                                   "shrinkable glue, e.g., `\\vss' or `\\vskip 0pt minus 1fil'."
                                   "Such glue doesn't belong there; but you can safely proceed,"
                                   "since the offensive shrinkability has been made finite."],
                       tex-error J,
                       (new-spec g @ r (pin r 'sho normal, pin p 'glue r, r)))
                      g)))
           (psf! J 1 (psf J 1 + psf J 7 + q 'width), psf! J 7 0, contribute p))
       ; a legal breakpoint of penalty pi: champion it, and fire if it is time; 'exit, 'done or 'go
       (champion p pi)
        (pi >= inf-penalty ? 'go
           (: pt (psf J 1) pg (psf J 0)
              b (? (pt < pg)
                    (psf J 3 != 0 || psf J 4 != 0 || psf J 5 != 0 ? 0 (cb-badness (pg - pt) (psf J 2)))
                   (pt - pg > psf J 6) awful-bad
                   (cb-badness (pt - pg) (psf J 6)))
              c0 (? (b >= awful-bad) b (pi <= eject-penalty) pi
                    (b < inf-bad) (b + pi + J 'insert-penalties) deplorable)
              k (J 'insert-penalties >= 10000 ? awful-bad c0)
              _ (int-par J tracing-pages-code > 0 ?
                   (begin-diagnostic J, print-nl J "%", print J " t=", print-totals J,
                    print J " g=", print-scaled J pg, print J " b=",
                    (b = awful-bad ? (print-char J 42) (print-int J b)),
                    print J " p=", print-int J pi, print J " c=",
                    (k = awful-bad ? (print-char J 42) (print-int J k)),
                    (k <= J 'least-page-cost ? (print-char J 35)),
                    end-diagnostic J 0))
              _ (k <= J 'least-page-cost ?
                   (pins J 'best-page-break p 'best-size pg 'least-page-cost k,
                    map (r \ pin r 'best-ins (r 'last-ins)) (J 'page-ins)))
              (k = awful-bad || pi <= eject-penalty ? (fire-up J p, J 'output-active ? 'exit 'done) 'go)))
       ; one node off the contributions; 'exit leaves build_page at once
       (step p)
        (: t (p 'type)
           _ (pins J 'last-glue (t = glue-node ? (p 'glue) ()) 'last-penalty 0 'last-kern 0)
           _ (? (t = penalty-node) (pin J 'last-penalty (p 'penalty))
                (t = kern-node) (pin J 'last-kern (p 'width)))
           pc (J 'page-contents)
           ; pi, or what to do instead
           pi (? (t <= rule-node)
                  (? (pc < box-there)
                      (: _ (pc = empty ? (freeze-page-specs J box-there) (pin J 'page-contents box-there))
                         q (new-skip-param J top-skip-code)
                         s (q 'glue)
                         _ (pin s 'width (s 'width > p 'height ? (s 'width - p 'height) 0))
                         (pin q 'link p, pin c 'link q, 'next))
                     (psf! J 1 (psf J 1 + psf J 7 + p 'height), psf! J 7 (p 'depth), 'contribute))
                 (t = whatsit-node || t = mark-node) 'contribute
                 (t = glue-node)
                  (? (pc < box-there) 'recycle (J 'page-tail 'type < math-node) 0 'update)
                 (t = kern-node)
                  (? (pc < box-there) 'recycle (p 'link = ()) 'exit
                     (p 'link 'type = glue-node) 0 'update)
                 (t = penalty-node) (pc < box-there ? 'recycle (p 'penalty))
                 (t = ins-node) (append-insertion J p, 'contribute)
                 (confusion J "page"))
           (? (pi = 'next || pi = 'exit) pi
              (pi = 'recycle) (pin c 'link (p 'link), pin p 'link (), 'next)
              (pi = 'contribute) (contribute p, 'next)
              (pi = 'update) (update-heights p, 'next)
              (champion p pi @ k
                 (? (k = 'go) (t < glue-node || t > kern-node ? (contribute p) (update-heights p), 'next)
                    (k = 'done) 'next
                    'exit))))
       (go _) (c 'link = () ? 'next (step (c 'link) = 'exit ? 'exit (go ())))
       (c 'link = () || J 'output-active ? ()
          ((go ()) = 'exit ? () (set-contrib-tail J c))))
   ; the best page into box 255, and the output routine or a shipout (tex.web 1012-1023)
   (fire-up J c)
    (: bpb (J 'best-page-break)
       _ (? (bpb 'type = penalty-node)
             (geq-word-define J (int-base + output-penalty-code) (bpb 'penalty),
              pin bpb 'penalty inf-penalty)
             (geq-word-define J (int-base + output-penalty-code) inf-penalty))
       M (J 'cur-mark)
       _ (peep M bot-mark-code () != () ?
            (pin M top-mark-code (M bot-mark-code), pin M first-mark-code ()))
       _ (c == bpb ? (pin J 'best-page-break ()))
       _ (box-reg J 255 != () ?
            (print-err J "", print-esc J "box", print J "255 is not void",
             set-help J ["You shouldn't use \\box255 except in \\output routines."
                         "Proceed, and I'll discard its present contents."],
             box-error J 255))
       _ (pin J 'insert-penalties 0)
       hold (int-par J holding-inserts-code > 0)
       ; each box an insertion goes to acts as a queue
       _ (hold ? ()
            (map (r \ (r 'best-ins != () ?
                         (: n (r 'sub) _ (ensure-vbox J n)
                            _ (box-reg J n = () ? (set-box-reg J n (new-null-box ())))
                            h {'type 'head 'link (box-reg J n 'list)}
                            (pins r 'qhead h 'last-ins (last-node h)))))
                 (J 'page-ins)))
       Q {'q {'type 'head 'link ()}}
       qh (Q 'q)
       ; box n's queue closed, and p split if it must be; answers 1 when p keeps a remainder
       (wrap-up r p s)
        (: w (? (r 'type = split-up && r 'broken-ins == p && r 'broken-ptr != ())
                (: s2 (: (go s) (s 'link == r 'broken-ptr ? s (go (s 'link))) (go s))
                   _ (pin s2 'link ())
                   _ (pin (J 'params) 'splittopskip (p 'split-top))
                   rest (cg-prune-top J (r 'broken-ptr))
                   _ (pin p 'ins rest)
                   (rest = () ? 0 (vpack J rest 0 'additional @ t (pin p 'height (t 'height + t 'depth), 1))))
                0)
           _ (pin r 'best-ins ())
           _ (set-box-reg J (r 'sub) (vpack J (r 'qhead 'link) 0 'additional))
           w)
       (walk prev p)
        (? (at? p (J 'best-page-break)) prev
           (p 'type = ins-node && !hold)
            (: r <(filter (r \ r 'sub = p 'sub) (J 'page-ins))
               wait (? (r 'best-ins = ()) 1
                       (: s (r 'last-ins)
                          _ (pin s 'link (p 'ins))
                          (r 'best-ins == p ? (wrap-up r p s) (pin r 'last-ins (last-node s), 0))))
               _ (pin prev 'link (p 'link))
               _ (pin p 'link ())
               _ (wait != 0 ?
                    (pin (Q 'q) 'link p, pin Q 'q p, pin J 'insert-penalties (J 'insert-penalties + 1)))
               (walk prev (prev 'link)))
           (p 'type = mark-node)
            (: _ (peep M first-mark-code () = () ? (pin M first-mark-code (p 'mark)))
               _ (pin M bot-mark-code (p 'mark))
               (walk p (p 'link)))
           (walk p (p 'link)))
       prev (walk (J 'page-head) (J 'page-head 'link))
       p (J 'best-page-break)
       ch (contrib-head J)
       _ (p != () ?
            (: _ (ch 'link = () ? (set-contrib-tail J (J 'page-tail)))
               (pin (J 'page-tail) 'link (ch 'link), pin ch 'link p, pin prev 'link ())))
       ; box 255 packed with vbadness and vfuzz out of the way
       sb (int-par J vbadness-code) sf (dimen-par J vfuzz-code)
       _ (pin (J 'eq) (int-base + vbadness-code) inf-bad)
       _ (pin (J 'eq) (dimen-base + vfuzz-code) max-dimen)
       _ (set-box-reg J 255 (vpackage J (J 'page-head 'link) (J 'best-size) 'exactly (J 'page-max-depth)))
       _ (pin (J 'eq) (int-base + vbadness-code) sb)
       _ (pin (J 'eq) (dimen-base + vfuzz-code) sf)
       _ (start-new-page J)
       _ (Q 'q == qh ? () (pin (J 'page-head) 'link (qh 'link), pin J 'page-tail (Q 'q)))
       _ (pin J 'page-ins ())
       _ (peep M top-mark-code () != () && peep M first-mark-code () = () ?
            (pin M first-mark-code (M top-mark-code)))
       (? (equiv J output-routine-loc = ()) (default-output J)
          (J 'dead-cycles >= int-par J max-dead-cycles-code)
           (print-err J "Output loop---", print-int J (J 'dead-cycles),
            print J " consecutive dead cycles",
            set-help J ["I've concluded that your \\output is awry; it never does a"
                        "\\shipout, so I'm shipping \\box255 out myself. Next time"
                        "increase \\maxdeadcycles if you want me to be more patient!"],
            tex-error J, default-output J)
          (pins J 'output-active 1 'dead-cycles (J 'dead-cycles + 1),
           push-nest J,
           pins (J 'cur-list) 'mode (0 - vmode) 'prev-depth ignore-depth 'ml (0 - J 'line),
           begin-token-list J (equiv J output-routine-loc) output-text,
           new-save-level J output-group, normal-paragraph J, scan-left-brace J)))
   (default-output J)
    (: ph (J 'page-head) ch (contrib-head J)
       _ (ph 'link != () ?
            (: _ (ch 'link = () ? (set-contrib-tail J (J 'page-tail)) (pin (J 'page-tail) 'link (ch 'link)))
               (pin ch 'link (ph 'link), pin ph 'link (), pin J 'page-tail ph)))
       (ship-out J (box-reg J 255), set-box-reg J 255 ()))
   ; the output routine's right brace (tex.web 1026-1028)
   (resume-page-builder J)
    (: I (J 'cur)
       _ (I 'loc != () || (I 'index != output-text && I 'index != backed-up) ?
            (print-err J "Unbalanced output routine",
             set-help J ["Your sneaky output routine has problematic {'s and/or }'s."
                         "I can't handle that very well; good luck."],
             tex-error J,
             (: (go _) (get-token J, J 'cur 'loc != () ? (go ())) (go ()))))
       _ (end-token-list J) _ (end-graf J) _ (unsave J)
       _ (pins J 'output-active 0 'insert-penalties 0)
       _ (box-reg J 255 != () ?
            (print-err J "Output routine didn't use all of ", print-esc J "box", print-int J 255,
             set-help J ["Your \\output commands should empty \\box255,"
                         "e.g., by saying `\\shipout\\box255'."
                         "Proceed; I'll discard its present contents."],
             box-error J 255))
       L (J 'cur-list)
       _ (L 'tail == L 'head ? () (pin (J 'page-tail) 'link (L 'head 'link), pin J 'page-tail (L 'tail)))
       ph (J 'page-head) ch (contrib-head J)
       _ (ph 'link != () ?
            (: _ (ch 'link = () ? (set-contrib-tail J (J 'page-tail)))
               (pin (J 'page-tail) 'link (ch 'link), pin ch 'link (ph 'link),
                pin ph 'link (), pin J 'page-tail ph)))
       (pop-nest J, build-page J))
   ; \vsplit n to h (tex.web 977-979)
   (vsplit J n h)
    (: v (box-reg J n) M (J 'cur-mark)
       _ (pin M split-first-mark-code (), pin M split-bot-mark-code ())
       (? (v = ()) ()
          (v 'type != vlist-node)
           (print-err J "", print-esc J "vsplit", print J " needs a ", print-esc J "vbox",
            set-help J ["The box you are trying to split is an \\hbox."
                        "I can't split such a box, so I'll leave it alone."],
            tex-error J, ())
          (: _ (sync-params J)
             q (cg-vert-break J (v 'list) h (dimen-par J split-max-depth-code))
             (marks p)
              (: _ (p 'type = mark-node ?
                      (peep M split-first-mark-code () = () ?
                         (pin M split-first-mark-code (p 'mark), pin M split-bot-mark-code (p 'mark))
                         (pin M split-bot-mark-code (p 'mark))))
                 (at? (p 'link) q ? (pin p 'link ()) (marks (p 'link))))
             _ (at? (v 'list) q ? (pin v 'list ()) (marks (v 'list)))
             q2 (cg-prune-top J q)
             _ (set-box-reg J n (q2 = () ? () (vpack J q2 0 'additional)))
             (vpackage J (v 'list) h 'exactly (dimen-par J split-max-depth-code)))))
   ; page.l's vert_break, on glue it made finite (tex.web 976)
   (split-shrink-warn J)
    (print-err J "Infinite glue shrinkage found in box being split",
     set-help J ["The box you are \\vsplitting contains some infinitely"
                 "shrinkable glue, e.g., `\\vss' or `\\vskip 0pt minus 1fil'."
                 "Such glue doesn't belong there; but you can safely proceed,"
                 "since the offensive shrinkability has been made finite."],
     tex-error J)

   ; --- shipping out (tex.web 638-641) ---------------------------------------------------------
   (ship-out J p)
    (: tr (int-par J tracing-output-code > 0)
       _ (tr ? (print-nl J "", print-ln J, print J "Completed box being shipped out"))
       _ (? (J 'term-offset > J 'max-print-line - 9) (print-ln J)
            (J 'term-offset > 0 || J 'file-offset > 0) (print-char J 32))
       _ (print-char J 91)
       j (: (go j) (j > 0 && J 'eq (count-base + j) = 0 ? (go (j - 1)) j) (go 9))
       _ (map (\ k (print-int J (J 'eq (count-base + k)), k < j ? (print-char J 46))) ^(j + 1))
       _ (flush (J 'term-out))
       _ (tr ? (print-char J 93, begin-diagnostic J, show-box J p, end-diagnostic J 1))
       _ (? (p 'height > max-dimen || p 'depth > max-dimen
             || p 'height + p 'depth + dimen-par J v-offset-code > max-dimen
             || p 'width + dimen-par J h-offset-code > max-dimen)
             (print-err J "Huge page cannot be shipped out",
              set-help J ["The page just created is more than 18 feet tall or"
                          "more than 18 feet wide, so I suspect something went wrong."],
              tex-error J,
              !tr ? (begin-diagnostic J, print-nl J "The following box has been deleted:",
                     show-box J p, end-diagnostic J 1))
            (: _ (J 'output-file-name = () ?
                    (J 'job-name = () ? (open-log-file J),
                     pin J 'output-file-name (J 'job-name + ".dvi")))
               _ (J 'pages = 0 ? (prepare-mag J))
               _ (sync-params J)
               (cb-ship J p)))
       _ (!tr ? (print-char J 93))
       _ (pin J 'dead-cycles 0)
       (flush (J 'term-out)))
   ; the postamble, and what the log says of it (tex.web 642)
   (finish-dvi J)
    (? (J 'pages = 0) (print-nl J "No pages of output.")
       (: _ (prepare-mag J) _ (sync-params J)
          b (cb-dvi J)
          _ (open (J 'output-file-name) "w" @ q (say q b, close q))
          (print-nl J "Output written on ", slow-print J (J 'output-file-name),
           print J " (", print-int J (J 'pages), print J " page", J 'pages != 1 ? (print-char J 115),
           print J ", ", print-int J #b, print J " bytes).")))

   ; what caja cannot do yet: said plainly, and the run ends
   (not-yet J what)
    (print-err J "caja cannot yet do ", print J what, print J " (", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
     print-char J 41, set-help J [], pin J 'history fatal-error-stop, jump-out J)
))
