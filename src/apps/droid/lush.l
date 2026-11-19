; src/apps/droid/lush.l -- lush on a phone, a login shell on the terminal alone:
;   love apk -L LOVE -n love -p pics.salt.love -P RECORD_AUDIO src/apps/droid/lush.l
; the mic is for what it runs: tuner hears through it. autonomous unless LUSHFLAGS says
; otherwise: our verbs before the phone's own, so top is ours and not toybox's
(: _ (? !(string? (getenv "LUSHFLAGS")) (setenv "LUSHFLAGS" "a"))
   (quit ((cite 'mitty 'mitty-main) [((cite 'posix 'selfpath) 0) "lush" "--login"])))
