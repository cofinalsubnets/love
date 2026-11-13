; src/apps/hearts/app.l -- rung 0's test app: it says its version and that it is done, then
; powers off.
(borrow 'posix)
(: (dev a) (spawn (["/bin/love" "/lib/hearts/dev.l"] + a) @ p (charm? p && 0 <= p ? (wait p) 127))
   (tell s) (say err ("hearts: " + s + "\n"))
   ver (uread "/etc/version" @ r (two? r ? <>r "?\n"))
   (tell ("app " + snip ver 0 (#ver - 1)), tell "done", dev ["off"]))
