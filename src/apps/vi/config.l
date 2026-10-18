; src/apps/vi/config.l -- the theme: molokai, two hues our own, as plain data the painter reads.
;
; keyed by vim highlight group, not syntax class: hue.l says a comment is a Comment, this says
; what a Comment looks like. the values are molokai's (Tomas Restrepo's, after Wimer
; Hazenberg's monokai), the cterm numbers its 256-colour fallback.
;
; a row is `(group cterm256 "#rrggbb" faces)`, faces drawn from (bold italic).
(module 'vi
(:
   hue-theme
    '((Comment    59  "#75715E" ())
      (String     144 "#E6DB74" ())
      (Number     135 "#AE81FF" ())
      (Constant   135 "#AE81FF" (bold))
      (Statement  161 "#F92672" (bold))
      (Function   118 "#A6E22E" ())
      (Identifier 214 "#ffaa1e" ())          ; ours, over molokai's #fd971f/208
      (Special    81  "#62d2f2" (italic))    ; ours, over molokai's #66d9ef
      (Operator   161 "#F92672" ())
      (Delimiter  241 "#8F8F8F" ())
      (Type       81  "#66D9EF" ())          ; these two paint only src/apps/vi/hues.l's classes
      (PreProc    118 "#A6E22E" ()))

   ; the named themes, by a bare name in the theme file or :colorscheme. molokai keeps the
   ; terminal's ground; the others carry Normal and Visual, whose ground is a fifth and sixth
   ; column, cterm256 and "#rrggbb". nord's, tokyo-night's and solarized's values are
   ; upstream's (LICENSE); paper is the tree's own
   hue-themes
    [['molokai hue-theme]
     ['nord
       '((Normal     254 "#D8DEE9" () 237 "#2E3440")
         (Visual     254 "#D8DEE9" () 59 "#434C5E")
         (Comment    60  "#616E88" (italic))
         (String     144 "#A3BE8C" ())
         (Number     139 "#B48EAD" ())
         (Constant   254 "#D8DEE9" ())
         (Statement  109 "#81A1C1" ())
         (Function   110 "#88C0D0" ())
         (Identifier 254 "#D8DEE9" ())
         (Special    254 "#D8DEE9" ())
         (Operator   109 "#81A1C1" ())
         (Delimiter  255 "#ECEFF4" ())
         (Type       109 "#81A1C1" ())
         (PreProc    109 "#81A1C1" ()))]
     ['tokyo-night
       '((Normal     146 "#a9b1d6" () 234 "#1a1b26")
         (Visual     146 "#a9b1d6" () 236 "#2b2f41")
         (Comment    60  "#51597d" (italic))
         (String     149 "#9ece6a" ())
         (Number     215 "#ff9e64" ())
         (Constant   215 "#ff9e64" ())
         (Statement  141 "#bb9af7" ())
         (Function   111 "#7aa2f7" ())
         (Identifier 153 "#c0caf5" ())
         (Special    117 "#89ddff" ())
         (Operator   117 "#89ddff" ())
         (Delimiter  117 "#89ddff" ())
         (Type       38  "#0db9d7" ())
         (PreProc    80  "#73daca" ()))]
     ['solarized-light
       '((Normal     66  "#657b83" () 230 "#fdf6e3")
         (Visual     230 "#fdf6e3" () 247 "#93a1a1")
         (Comment    247 "#93a1a1" (italic))
         (String     36  "#2aa198" ())
         (Number     36  "#2aa198" ())
         (Constant   36  "#2aa198" ())
         (Statement  100 "#859900" ())
         (Function   32  "#268bd2" ())
         (Identifier 32  "#268bd2" ())
         (Special    166 "#dc322f" ())
         (Operator   100 "#859900" ())
         (Delimiter  166 "#dc322f" ())
         (Type       136 "#b58900" ())
         (PreProc    166 "#cb4b16" ()))]
     ['paper
       '((Normal     234 "#1f1c19" () 231 "#fffdf9")
         (Visual     234 "#1f1c19" () 253 "#e6e0d6")
         (Comment    244 "#8b8379" (italic))
         (String     23  "#2f6f4f" ())
         (Number     94  "#8a4b2a" ())
         (Constant   94  "#8a4b2a" (bold))
         (Statement  89  "#7a2e5c" (bold))
         (Function   24  "#2a5c8a" ())
         (Identifier 60  "#5a3e8a" ())
         (Special    130 "#b04a1a" (italic))
         (Operator   89  "#7a2e5c" ())
         (Delimiter  246 "#9a938b" ())
         (Type       24  "#1f6f78" ())
         (PreProc    58  "#6b5a1e" ()))]]

   ; the page palettes: `(role "#rrggbb")` rows, a scheme one palette or a light/dark pair.
   ; hueweb spells each role as the css variable of the same name (--bg, --fg ..)
   hue-page
    '((paper ((bg "#fffdf9") (fg "#1f1c19") (dim "#6f6862") (rule "#e6e0d6") (link "#8a4b2a") (pre "#f4f0e9"))
             ((bg "#16151a") (fg "#e8e4dd") (dim "#9a938b") (rule "#2e2b33") (link "#e0a06a") (pre "#1e1d24")))
      ; tokyo-night, the front page's: dark only, with the roles that page adds
      (tokyo-night ((bg "#04060e") (fg "#c0caf5") (dim "#565f89") (rule "#3b4261") (link "#7aa2f7") (pre "#1f2335")
                    (code "#a9b1d6") (edge "#292e42") (slab "#16161e") (mute "#737aa2") (faint "#414868")
                    (hash "#545c7e") (em "#9aa5ce") (glow "122,162,247") (rim "#34406e")
                    (red "#f7768e") (cyan "#7dcfff") (teal "#73daca"))))

   ; the user's own rows, read as data (never evaled) at editor start and folded over the
   ; above; same row shape
   hue-theme-file "/.love/hue.l")
) ; module 'vi
