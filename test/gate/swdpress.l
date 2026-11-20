; test/gate/swdpress.l -- a button pressed through a probe's open-drain line, for
; test/gate/mcuboard.sh: held low for a round trip to the probe, then let go.
;   love swdpress.l LINE PROBE..   LINE aux or rst, PROBE `lovswd TTY`
(borrow "swd.l")
(: (fail m) (say err ("swdpress: " + m + "\n"), quit 1)
   as >argv
   _ (#as < 3 ? (fail "usage: love swdpress.l aux|rst lovswd TTY") 0)
   ln (as 0 @ "aux" 'aux "rst" 'rst _ (fail ("no line " + as 0)))
   w (drop 1 as @ ["lovswd" tty] (probe-wire tty) _ (fail ("no probe known as " + show (drop 1 as))))
   _ (w ln 1) _ (w 'id 0) _ (w ln 0) _ (w 'id 0)
   (w 'close 0, 0))
