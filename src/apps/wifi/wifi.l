; src/apps/wifi/wifi.l -- a wpa2-psk station over nl80211, for a radio whose firmware runs the
; 4-way handshake itself (brcmfmac's idsup): the pmk from the passphrase, a scan for the ssid,
; a connect carrying the pmk, then dhcp's address and route. no eapol is read here.
;   love -l src/apps/wifi/netlink.l -l src/apps/wifi/dhcp.l src/apps/wifi/wifi.l IFACE SSID PASSPHRASE
;   ..wifi.l IFACE CONF       the ssid and passphrase as CONF's first two lines, a third the
;                             country's two letters (US), whose rules the radio keeps
; run so it stays: the lease renewed at half its time, its dns in /run/resolv.conf, and a link
; gone or a renewal refused a failure, for helm to start it again
;   (wifi-pmk pass ssid)      -> the 32-byte pmk, pbkdf2-hmac-sha1 over 4096 rounds
;   (wifi-up iface ssid pass cc) -> the lease as dhcp answers it, or a scare 'wifi why; cc "" for none
;   (wifi-hold iface lease)   -> never; a scare 'wifi why when the link or the lease goes
(module (wifi wifi-pmk wifi-hmac1 wifi-ies wifi-rsn wifi-rsn-ie wifi-up wifi-hold wifi-conf)
(borrow '(posix bytes hashes netlink dhcp))
(:
   ; --- the numbers: nl80211's ---
   CmdTriggerScan 33  CmdGetScan 32  CmdNewScan 34  CmdScanAborted 35  CmdConnect 46  CmdDisconnect 48  CmdReqSetReg 27
   AIfindex 3  AMac 6  AIe 42  AScanSsids 45  ABss 47  AFreq 38  ASsid 52  AAuth 53  APrivacy 70
   AStatus 72  APairwise 73  AGroup 74  AWpa 75  AAkm 76  APmk 254  ARegAlpha2 33
   BBssid 1  BFreq 2  BIes 6  BSignal 7
   Ccmp 1027076  Tkip 1027074  Psk 1027074              ; 00-0f-ac:4, :2, and the akm's :2

   ; --- the pmk ---
   (fill c n) (string (map (_ \ c) ^n))
   (wifi-hmac1 k)
    (: kp (k + zbytes (64 - #k)) xi (xorb kp (fill 54 64)) xo (xorb kp (fill 92 64))
       (m \ hex2b (sha1 (xo + hex2b (sha1 (xi + m))))))
   (wifi-pmk pass ssid)
    (: h (wifi-hmac1 pass)
       (blk i) (: (go j u t) (j = 4096 ? t (h u @ v (go (j + 1) v (xorb t v))))
                  u1 (h (ssid + wrbe i 4))
                  (go 1 u1 u1))
       (snip (blk 1 + blk 2) 0 32))

   ; --- a beacon's elements, and its rsn element read ---
   (wifi-ies s)
    (: n #s
       (go i) (n < i + 2 || n < i + 2 + s (i + 1) ? () ([(s i) (snip s (i + 2) (i + 2 + s (i + 1)))] . go (i + 2 + s (i + 1))))
       (go 0))
   ; -> (group pairwise akms), suites as big-endian words; () if it runs short
   (suites s i k) (k = 0 ? () (rdbe s i 4 . suites s (i + 4) (k - 1)))
   (wifi-rsn b)
    (: np (#b < 8 ? 0 (rdle b 6 2))
       ka (8 + 4 * np)
       (#b < ka + 2 ? () (: na (rdle b ka 2) (#b < ka + 2 + 4 * na ? ()
                                             [(rdbe b 2 4) (suites b 8 np) (suites b (ka + 2) na)]))))
   ; ours: version 1, the ap's group, one pairwise, psk, no capabilities
   (wifi-rsn-ie group pair) (string [48 20 1 0] + wrbe group 4 + string [1 0] + wrbe pair 4 + string [1 0] + wrbe Psk 4 + string [0 0])

   (say1 s) (puts ("wifi: " + s + "\n"))
   (gone s) (scare 'wifi s)
   (trim s) (#s > 0 && (s (#s - 1) = 10 || s (#s - 1) = 13) ? (trim (snip s 0 (#s - 1))) s)
   (sysnet ifc f) (uread ("/sys/class/net/" + ifc + "/" + f) @ [1 s] (trim s) (gone ("no " + ifc + " (" + f + ")")))

   ; the first event of nl80211 that `pick` answers for, its cmd and attributes handed in
   (ev-take ev fam pick)
    (: (scan ms) (? (atom? ms) (go 0)
                    (<ms @ [t _ _ b] (t = fam ? (pick (b 0) (genl-attrs b) @ v (v != () ? v (scan >ms))) (scan >ms))))
       (go _) (recv ev @ r (two? r ? (scan (nl-msgs (r 1))) (gone ("events: " + show r))))
       (go 0))
   ; the same within ms, 0 on none
   (ev-in ms ev fam pick) (within ms (_ \ ev-take ev fam pick))
   (for? ix as) (nl-rd32 (nl-get as AIfindex (zbytes 4)) = ix)

   ; the bss to join: ssid's, wpa2-psk, the strongest
   (bss-of b)
    (: as (nl-attrs (nl-get (genl-attrs b) ABss "") 0)
       es (wifi-ies (nl-get as BIes ""))
       [(nl-get as BBssid "") (nl-rd32 (nl-get as BFreq (zbytes 4))) (nl-err (nl-rd32 (nl-get as BSignal (zbytes 4))))
        (nl-get es 0 "") (wifi-rsn (nl-get es 48 ""))])
   (fit? ssid x) (x 3 = ssid && x 4 != () && elem Psk (x 4 2) && (elem Ccmp (x 4 1) || elem Tkip (x 4 1)))
   (best l) (foldl (a \ x \ (a = () || a 2 < x 2 ? x a)) () l)

   (wifi-up ifc ssid pass cc)
    (: ix (read (sysnet ifc "ifindex"))
       mac (hex2b (join "" (split ":" (sysnet ifc "address"))))
       pmk (wifi-pmk pass ssid)
       was (sysnet ifc "operstate")
       rt (nl-open 0 ())
       _ (rt-up rt ix)
       nl (nl-open 16 ())
       f (genl-family nl "nl80211")
       _ (f = () ? (gone "no nl80211"))
       fam <f
       (grp n) (nl-get (f 1) n 0)
       ev (nl-open 16 [(grp "scan") (grp "mlme")])
       (ask cmd flags as) (nl-ask nl fam flags (genl-msg cmd as))
       ; the country only advises: a refusal is said, and the join goes on under the world's rules
       _ (cc != "" ? (trap (_ \ (ask CmdReqSetReg 0 [(nl-attr ARegAlpha2 (nl-str cc))], say1 ("country " + cc))) 0
                           (a \ b \ say1 ("country " + cc + " refused: " + show b))) 0)
       _ (say1 ("scanning for " + ssid + " on " + ifc))
       _ (ask CmdTriggerScan 0 [(nl-attr AIfindex (nl-u32 ix)) (nl-nest AScanSsids [(nl-attr 1 ssid)])])
       done (ev-in 20000 ev fam (c \ as \ (for? ix as && (c = CmdNewScan || c = CmdScanAborted) ? [c] ())))
       _ (two? done && <done = CmdNewScan ? 0 (gone (done = 0 ? "no scan result in 20 s" "scan aborted")))
       seen (map bss-of (ask CmdGetScan 768 [(nl-attr AIfindex (nl-u32 ix))]))
       b (best (filter (fit? ssid) seen))
       _ (b = () ? (gone (ssid + ": no wpa2-psk bss among " + show #seen)))
       rsn (b 4)
       pair (elem Ccmp (rsn 1) ? Ccmp Tkip)
       ; a last run's association first, and its going seen: connect refuses while one stands
       up (was = "up" ? (trap (_ \ (ask CmdDisconnect 0 [(nl-attr AIfindex (nl-u32 ix)) (nl-attr 54 (nl-u16 3))]), 1) 0 (a \ b \ 0)) 0)
       _ (up = 1 ? (ev-in 3000 ev fam (c \ as \ (for? ix as && c = CmdDisconnect ? [c] ()))) 0)
       _ (say1 ("joining " + b2hex (b 0) + " at " + show (b 1) + " MHz, " + show (b 2 // 100) + " dBm"))
       _ (ask CmdConnect 0
              [(nl-attr AIfindex (nl-u32 ix)) (nl-attr AMac (b 0)) (nl-attr ASsid ssid) (nl-attr AFreq (nl-u32 (b 1)))
               (nl-attr AAuth (nl-u32 0)) (nl-attr APrivacy "") (nl-attr AWpa (nl-u32 2))
               (nl-attr APairwise (nl-u32 pair)) (nl-attr AGroup (nl-u32 (<rsn))) (nl-attr AAkm (nl-u32 Psk))
               (nl-attr AIe (wifi-rsn-ie (<rsn) pair)) (nl-attr APmk pmk)])
       ; a failure comes as a connect too, its status set; our own disconnect's event is passed over
       st (ev-in 30000 ev fam (c \ as \ (for? ix as && c = CmdConnect ? [(nl-rd16 (nl-get as AStatus (zbytes 2)))] ())))
       _ (? !(two? st) (gone "no connect result in 30 s")
            (<st = 0) (say1 "associated, keyed by the radio")
            (gone ("connect refused, status " + show <st)))
       l (dhcp ix mac 3000)
       _ (l = () ? (gone "no dhcp lease"))
       _ (rt-addr rt ix <l (l 1))
       _ (l 2 != "" ? (rt-gateway rt ix (snip (l 2) 0 4)))
       (say1 ("address " + quad-show <l + "/" + show (l 1)
              + (l 2 != "" ? (", router " + quad-show (l 2)) "")
              + (l 3 != "" ? (", dns " + quad-show (l 3)) "")
              + ", lease " + show (l 4) + " s"),
        l))

   (resolv l) (l 3 != "" ? (uwrite "/run/resolv.conf" ("nameserver " + quad-show (snip (l 3) 0 4) + "\n")) 0)
   ; every 10 s the link looked at; at half the lease's time it is asked again
   (wifi-hold ifc l)
    (: ix (read (sysnet ifc "ifindex"))
       mac (hex2b (join "" (split ":" (sysnet ifc "address"))))
       rt (nl-open 0 ())
       (half l) ((l 4 < 120 ? 3600 (l 4)) // 2)
       (go t l) (: _ (rest 10000)
                   _ (sysnet ifc "operstate" = "up" ? 0 (gone "the link went down"))
                   (t + 10 < half l ? (go (t + 10) l)
                      (dhcp ix mac 3000 @ n (? !(two? n) (gone "the lease was not renewed")
                                               (rt-addr rt ix <n (n 1), resolv n, go 0 n)))))
       (go 0 l))
   ; a conf's lines: the ssid, the passphrase, the country if any
   (wifi-conf p) (uread p @ [1 s] (lines s @ ls (#ls < 2 ? (gone (p + ": wants an ssid line and a passphrase line"))
                                                [(trim <ls) (trim (ls 1)) (#ls > 2 ? (trim (ls 2)) "")]))
                   (gone ("cannot read " + p)))

   ; run as a script: the words after this file's name
   (after l) (atom? l ? () (<l @ (_ + "wifi.l") >l (after >l)))
   as (after cmdline)
   (run ifc sp) (: l (wifi-up ifc <sp (sp 1) (sp 2)) (resolv l, wifi-hold ifc l))
   _ (#as = 3 || #as = 2
      ? (trap (_ \ run (as 0) (#as = 3 ? [(as 1) (as 2) ""] (wifi-conf (as 1)))) 0
              (a \ b \ (say err ("wifi: " + show a + " " + show b + "\n"), quit 1)))
      0)
)
)
