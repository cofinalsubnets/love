; src/apps/hearts/app.l -- rung 0's test app. it says it is well unless its root carries
; /etc/sick, then takes the next update disk (/dev/vdb, vdc, .. by the count in /data/next), one
; an attempt, and restarts into it; a refused one is passed over, and with none left it powers off.
(borrow 'posix)
(: (dev a) (spawn (["/bin/love" "/lib/hearts/dev.l"] + a) @ p (charm? p && 0 <= p ? (wait p) 127))
   (tell s) (say err ("hearts: " + s + "\n"))
   ver (uread "/etc/version" @ r (two? r ? <>r "?\n"))
   _ (tell ("app " + snip ver 0 (#ver - 1)))
   (disk k) ("/dev/vd" + string (97 + k))
   (next k)
    (? !(two? (stat (disk k))) (tell "done", dev ["off"])
       (uwrite "/data/next" (show (k + 1)), sync 0,
        dev ["update" (disk k)] @ r
          (r = 0 ? (dev ["restart"]) (next (k + 1)))))
   (? (two? (stat "/etc/sick")) (tell "app sick: it never says it is well")
      (dev ["well"] = 0 ? (next (uread "/data/next" @ r (two? r ? (read <>r) 1))) (tell "well refused"))))
