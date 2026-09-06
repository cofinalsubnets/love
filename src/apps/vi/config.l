; src/apps/vi/config.l -- the theme: molokayo, as plain data the painter reads.
; src/apps/lux/config.l is the shape -- a body-less `:`, values not code.
;
; the theme is keyed by vim highlight group, not by syntax class. src/apps/vi/hue.l
; says "a comment is a Comment"; this file says "in molokayo a Comment is 59 /
; #75715E". that split is what lets the generated vim syntax file emit plain
; `hi def link` lines -- a syntax file that hardcoded colours would fight the
; reader's own colorscheme -- while pulchritude, which has no colorscheme, still
; gets the same molokayo out of the same table. swap the numbers below for
; another scheme's and only the editor follows.
;
; every value is lifted verbatim from awesome-vim-colorschemes: molokayo.vim is
; molokai.vim with `molokai_original = 1` plus its own `hi!` lines, and molokayo
; wins where it defines a group (Identifier, Special). nothing here is
; approximated by us -- the cterm numbers are molokai's own 256-colour block, so
; a terminal that cannot do 24-bit still shows the author's fallback.
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
      (Identifier 214 "#ffb700" ())          ; molokayo over molokai's #fd971f/208
      (Special    81  "#66d0ef" (italic))    ; molokayo over molokai's #66d9ef
      (Operator   161 "#F92672" ())
      (Delimiter  241 "#8F8F8F" ()))

   ; the page palettes: a role a row, `(role "#rrggbb")`, and a scheme is one palette or
   ; a light/dark pair. hueweb spells each role as the css variable of the same name
   ; (--bg, --fg ..), so a sheet built on hw-vars answers to the reader's theme by
   ; construction, and every sheet in the tree reads its colours off this table.
   hue-page
    '((paper ((bg "#fffdf9") (fg "#1f1c19") (dim "#6f6862") (rule "#e6e0d6") (link "#8a4b2a") (pre "#f4f0e9"))
             ((bg "#16151a") (fg "#e8e4dd") (dim "#9a938b") (rule "#2e2b33") (link "#e0a06a") (pre "#1e1d24")))
      ; tokyo-night, the front page's: periwinkle on polar-night blue, dark only, and the
      ; roles that page adds -- code text and its edge, the pre slab, muted heads, the
      ; footer, the hover hash, the glow's rgb, the terminal's rim, the crew's lights
      (tokyo-night ((bg "#04060e") (fg "#c0caf5") (dim "#565f89") (rule "#3b4261") (link "#7aa2f7") (pre "#1f2335")
                    (code "#a9b1d6") (edge "#292e42") (slab "#16161e") (mute "#737aa2") (faint "#414868")
                    (hash "#545c7e") (em "#9aa5ce") (glow "122,162,247") (rim "#34406e")
                    (red "#f7768e") (cyan "#7dcfff") (teal "#73daca"))))

   ; the user's own rows, read as data (never evaled) at editor birth and folded
   ; over the above -- kore ships as a baked image, so editing this file is not a
   ; knob anyone downstream has. same row shape; a file with no rows in it means
   ; no overrides, which is a perfectly good thing for a theme file to mean.
   hue-theme-file "/.love/hue.l")
) ; module 'vi
