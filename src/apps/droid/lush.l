; src/apps/droid/lush.l -- a phone's love: the dream, then a login shell on the terminal under it:
;   love apk -L LOVE -n love -p pics.salt.love -P RECORD_AUDIO src/apps/droid/lush.l
; the mic is for what it runs: tuner hears through it. autonomous unless LUSHFLAGS says
; otherwise: our verbs before the phone's own, so top is ours and not toybox's. the terminal
; opens first: the bridge takes a deck's first window for love's own. a deck past the first,
; its LOVE_FACE ending .N, is the shell at once. -k: the keyboard waits for the dream's end
(: _ (? !(string? (getenv "LUSHFLAGS")) (setenv "LUSHFLAGS" "a"))
   me ((cite 'posix 'selfpath) 0)
   first (getenv "LOVE_FACE" @ p (string? p && 1 < #p && p (#p - 2) = 46 ? 0 1))
   (quit ((cite 'mitty 'mitty-main)
     (first ? ["-k" me "lush" "-c" "\"$0\" lore dream; printf '\\033[?7727l'; exec \"$0\" lush --login" me] [me "lush" "--login"]))))
