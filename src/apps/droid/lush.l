; src/apps/droid/lush.l -- lush on a phone, a login shell in the mitty through a porthole:
;   love apk -L LOVE -n lush -p pics.salt.lush -P RECORD_AUDIO src/apps/droid/lush.l
; the mic is for what it runs: tuner hears through it
(quit ((cite 'mitty 'mitty-main) ["--window" ((cite 'posix 'selfpath) 0) "lush" "--login"]))
