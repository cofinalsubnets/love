; src/apps/droid/tuner-mic.l -- the tuner on a phone, listening, through window.l's bridge:
;   love apk -L LOVE -n tuner -p pics.salt.tuner -P RECORD_AUDIO src/apps/droid/tuner-mic.l
; it asks for the mic at its first start and hears once granted; a tap on the left, middle
; or right third is a, s or A; back ends it
(quit ((cite (quote tuner) (quote tuner-main)) ["--window"]))
