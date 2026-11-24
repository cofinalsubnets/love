; src/apps/droid/lush.l -- a phone's love: the dream, or what `love opens` says, then a login
; shell on the terminal under it:
;   love apk -L LOVE -n love -p pics.salt.love -P RECORD_AUDIO src/apps/droid/lush.l
; the mic is for what it runs: tuner hears through it. autonomous unless LUSHFLAGS says
; otherwise: our verbs before the phone's own, so top is ours and not toybox's. the terminal
; opens first: the bridge takes a deck's first window for love's own. a deck past the first,
; its LOVE_FACE ending .N, is the shell at once. -k: the keyboard waits for the dream's end.
; a setting over within three seconds is the dream after all
(: _ (? !(string? (getenv "LUSHFLAGS")) (setenv "LUSHFLAGS" "a"))
   me ((cite 'posix 'selfpath) 0)
   first (getenv "LOVE_FACE" @ p (string? p && 1 < #p && p (#p - 2) = 46 ? 0 1))
   ws (first ? (cite 'opens 'opens-get 0) ())
   ok (first && (cite 'opens 'opens-ok? ws))
   dream "\"$0\" lore dream; " shell "printf '\\033[?7727l'; exec \"$0\" lush --login"
   (quit ((cite 'mitty 'mitty-main)
     (? (!first || ws = ["lush"]) [me "lush" "--login"]
        ok ([me "lush" "-c" ("t=$(date +%s); \"$0\" \"$@\"; [ $(($(date +%s) - t)) -lt 3 ] && " + dream + shell) me] + ws)
        ["-k" me "lush" "-c" (dream + shell) me]))))
