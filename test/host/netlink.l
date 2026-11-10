; test/host/netlink.l -- sock.c's netlink and packet families, and the wifi station's pieces
; that need no radio: generic netlink's control family, an rtnetlink link dump, the pmk's
; 802.11i vector, an rsn element read, a dhcp frame laid and an offer read back
(borrow "src/apps/wifi/netlink.l")
(borrow "src/apps/wifi/dhcp.l")
(borrow "src/apps/wifi/wifi.l")
(borrow '(bytes netlink dhcp wifi))
(: p (nl-open 16 ())
   f (genl-family p "nlctrl")
   r (nl-open 0 ())
   links (map (b \ nl-get (nl-attrs b 16) 3 "") (nl-ask r 18 768 (zbytes 16)))
   ; unprivileged a packet socket is refused by name; as root it binds lo's arp
   pk (bind '(packet 1 2054))
   _ (hot? pk ? (close pk) 0)
   _ (test (hot? p) (hot? r)
           (f = [16 [["notify" 16]]])
           ((genl-family p "no-such-family") = ())
           (elem "lo\0" links)
           (pk = 'eperm || hot? pk)
           ((bind '(netlink 99)) = 'badarg) ((bind '(netlink)) = 'badarg)
           ((bind '(netlink 16 0)) = 'badarg) ((bind '(packet 0 1)) = 'badarg)
           ((bind '(packet 1 70000)) = 'badarg) ((listen '(netlink 16)) = 'badarg)
           ((send p [0] 5) = 'badarg) ((send p ["x"] "") = 'badarg))
   ; a request the kernel refuses scares with its errno: getfamily with no name is -einval
   e (trap (_ \ nl-ask p 16 0 (genl-msg 3 [])) 0 (a \ b \ [a b]))
   _ (test (e = ['netlink -22]))
   _ (close p, close r)

   ; ieee 802.11i's vector: "password" over "IEEE"
   _ (test (b2hex (wifi-pmk "password" "IEEE") = "f42c6fc52df0ebef9ebb4b90b38a5f902e83fe1b135a70e23aed762e9710a12e"))
   ; an ap's rsn: group tkip, pairwise ccmp and tkip, akm psk
   ie (hex2b "0100000fac020200000fac04000fac020100000fac020c00")
   _ (test (wifi-rsn ie = [1027074 [1027076 1027074] [1027074]])
           ((wifi-rsn (snip ie 0 9)) = ())
           (b2hex (wifi-rsn-ie 1027074 1027076) = "30140100000fac020100000fac040100000fac020000")
           (wifi-ies (string [0 2 104 105 48 1 7 221]) = [[0 "hi"] [48 (string 7)]]))

   ; a conf's two lines, a crlf's cr off
   cf "out/hostnif/wifi.conf"
   _ (uwrite cf "my net\r\npass phrase \n")
   _ (test (wifi-conf cf = ["my net" "pass phrase "]))
   ; a discover: its ip header sums to 0, a reply to 68 with our xid reads back
   mac (hex2b "b827eb112233")
   d (dhcp-frame mac 305419896 [(string [53 1 1])])
   bp (string 2 + snip d 29 44 + string [192 168 1 50] + snip d 48 268)
   o (snip d 0 20 + wrbe 67 2 + wrbe 68 2 + snip d 24 28 + bp + string [53 1 2 1 4 255 255 255 0 3 4 192 168 1 1 0 255])
   m (dhcp-read o 305419896)
   _ (test (ip-sum (snip d 0 20) = 0) (#d = 272) (rdbe d 38 2 = 32768)
           (<m = 2) (quad-show (m 1) = "192.168.1.50")
           (m 2 = [[53 (string 2)] [1 (string [255 255 255 0])] [3 (string [192 168 1 1])]])
           ((dhcp-read o 1) = ()) ((dhcp-read (snip o 0 100) 305419896) = ()))
   (test_fin (),
    say err "test/host/netlink: netlink and packet sockets, the pmk, rsn and dhcp frames: ok",
    put err 10,
    0))
