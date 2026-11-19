; src/apps/hearts/dev.l -- hearts on the device, run by helm's units and the app:
;   love dev.l mount         the ESP rw at /boot, data at /data
;   love dev.l restart | off
; the disk: the ESP /dev/vda1, the root /dev/vda2 (read-only), data /dev/vda3
(borrow 'posix)
(: argv cmdline
   (tell s) (say err ("hearts: " + s + "\n"))
   (gone s) (tell s, quit 1)

   (domount _)
    (mount "/dev/vda1" "/boot" "vfat" @ r (nom? r ? (gone ("cannot mount the ESP: " + show r)) 0),
     mount "/dev/vda3" "/data" "ext4" @ r (nom? r ? (gone ("cannot mount data: " + show r)) 0),
     tell "up")

   verb (#argv > 2 ? (argv 2) "")
   (verb @
     "mount"   (domount 0)
     "restart" (sync 0, reboot 0)
     "off"     (sync 0, reboot 1)
     (gone ("no verb " + verb))))
