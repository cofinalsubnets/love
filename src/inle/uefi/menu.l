; src/inle/uefi/menu.l -- the boot menu, love.cmd's program on an ESP beside love.stay. boot.l
; on the volume names the entries; an arrow or a digit picks one, the timeout boots the
; default, and the firmware starts it. an image that returns, or a refused load, comes back to
; the menu with its status. the last row is love's own shell.
;
; boot.l, its forms read as data:
;   (timeout 5)                        seconds before the default boots, and after a boot that
;                                      comes back, before a reboot; 0 waits for a key
;   (default 0)                        the row the timeout boots, from 0
;   (entry TITLE PATH [CMD [INITRD]])  PATH and INITRD on the boot volume, CMD its LoadOptions
;
; read by a law (argv names another file) it only defines; the doors are what it boots through
(borrow 'cli)
(: ; a text's forms; a torn one ends it
   (bm-forms t) (sound t @ r (two? r ? (<r . bm-forms >r) ()))
   bm-shell ["love" () "" ()]
   ; boot.l as {'timeout 'default 'rows}, each row [title path cmd initrd], the shell row last
   (bm-conf t)
    (: (add c f)
        (f @ ['timeout (s && charm? s && 0 <= s)] (pin c 'timeout s)
             ['default (i && charm? i && 0 <= i)] (pin c 'default i)
             ('entry . (e && string? <e && string? <>e))
               (pin c 'rows (c 'rows + [[<e <>e (peep e 2 "") (peep e 3 ())]]))
             c)
       c (foldl add {'timeout 5 'default 0 'rows ()} (string? t ? (bm-forms t)))
       n #(c 'rows)
       (pins c 'rows (c 'rows + [bm-shell]) 'default (c 'default < n ? (c 'default) 0)))

   ; the state: 'cur the row, 'until the timeout's clock or (), 'edit the line being edited or
   ; (), 'pick [row cmd] once chosen or ['reset], 'msg the last boot's word, 'back 1 when the
   ; timeout reboots
   (bm-new c msg) {'cur (c 'default) 'until (0 < c 'timeout ? (clock 0 + 1000 * c 'timeout))
                   'edit () 'pick () 'msg msg 'shown ()}
   (bm-left st) (st 'until @ () () u (max 0 ((u - clock 0 + 999) // 1000)))

   (bm-fit s w) (#s <= w ? s (snip s 0 (max 0 w)))
   (bm-show c st w h)
    (: rows (c 'rows) cur (st 'cur)
       (row i r) (: s "\(i + 1)  \(bm-fit <r (w - 8))" (i = cur ? (sgr 7 " \(s) ") "  \(s)"))
       (lines i l) (two? l ? (row i <l . lines (i + 1) >l) ())
       r (rows cur)
       foot (? (string? (st 'edit)) "\(bm-fit <r 16): \(bm-fit (st 'edit) (w - 20))"
               (st 'until) (st 'back ? "a reboot in \(bm-left st)s, a key waits" "\(<r) in \(bm-left st)s, a key waits")
               "arrows or a digit pick, enter boots, e edits the line")
       body (["love boot" ""] + lines 0 rows + ["" (st 'msg) foot])
       ("\e[H" + catmap (l \ "\(l)\e[K\r\n") (take (h - 1) body) + "\e[J"))

   ; a key; the first one stops the timeout
   (bm-step c st k)
    (: rows (c 'rows) n #rows cur (st 'cur) e (st 'edit)
       (go i) (pin st 'cur ((i % n + n) % n))
       (pick i cmd) (pin st 'pick [(rows i) cmd])
       (pin st 'until (),
        (? (string? e)
            (? (k = 13 || k = 10) (pick cur e)
               (k = 27) (pin st 'edit ())
               (k = 127 || k = 8) (pin st 'edit (snip e 0 (max 0 (#e - 1))))
               (k = 21) (pin st 'edit "")
               (32 <= k <= 126) (pin st 'edit (e + string k))
               st)
          (? (k = -8 || k = 107) (go (cur - 1))
             (k = -9 || k = 106) (go (cur + 1))
             (k = 13 || k = 10) (pick cur ((rows cur) 2))
             (k = 101 && !(nil? ((rows cur) 1))) (pin st 'edit ((rows cur) 2))
             (49 <= k <= 57 && k - 49 < n) (pick (k - 49) ((rows (k - 49)) 2))
             st))))
   ; the timeout picks the default, or after a boot that came back the reboot; a frame is
   ; wanted when the seconds shown move
   (bm-tick c st)
    (: s (bm-left st)
       (? (s = 0) (pin st 'pick (st 'back ? ['reset] [((c 'rows) (c 'default)) ((c 'rows) (c 'default) 2)]), 1)
          (s != st 'shown) (pin st 'shown s, 1)
          0))

   ; the choice through the doors: 'read a path's bytes or (), 'boot path cmd initrd (()
   ; none) its status, 'shell. answers the menu's next word
   (bm-boot d p)
    (: r <p cmd <>p t <r path (r 1) rd (r 3)
       (? (nil? path) ((d 'shell) (), "")
          (: bytes (string? rd ? ((d 'read) rd))
             (? (string? rd && nil? bytes) "\(t): no \(rd)"
                ((d 'boot) path cmd bytes @ s
                  (? (s <= -1000) "\(t): the firmware refused \(path), status \(-1000 - s)"
                     (s < 0) "\(t): \(path) failed, \(s)"
                     "\(t) returned \(s)"))))))

   ; a visit's state: the first runs the timeout to the default; one after a boot that came
   ; back runs it to a reboot, so a pc whose own loader chained here is back there unattended
   (bm-visit c msg first)
    (: st (bm-new c msg)
       (? first st (msg != "") (pin st 'back 1) (pin st 'until ())))
   ; the visit's choice through the doors: a reboot, or a boot and the next visit
   (bm-after c d st)
    (st 'pick @ ['reset] ((d 'reset) ())
                p (bm-run c d (bm-boot d p) 0))
   ; one visit to the menu, then its choice
   (bm-run c d msg first)
    (: st (bm-visit c msg first)
       (stage-run {'show (w \ h \ bm-show c st w h) 'step (bm-step c st) 'over? (_ \ two? (st 'pick))
                   'tick (_ \ bm-tick c st) 'every 100 'modes ['hide]},
        (two? (st 'pick) ? (bm-after c d st))))
   ; no boot.l, or one naming nothing, is the shell alone
   (bm-main d)
    (: c (bm-conf ((d 'read) "/boot.l"))
       (#(c 'rows) = 1 ? ((d 'shell) ()) (bm-run c d "" 1)))

   (bm-doors _)
    {'read efi-read
     'boot (p \ cmd \ rd \ (nil? rd ? (kexec p cmd) (kexec-initrd p cmd rd)))
     'reset (_ \ reset 0)
     'shell (_ \ k-prog ["pier" "--here"] @ pr (two? pr ? (trap (_ \ <pr >pr) () (a \ b \ 0))))})

(peep argv 1 "" @ (_ + "uefi/menu.l") (bm-main (bm-doors ())) 0)
