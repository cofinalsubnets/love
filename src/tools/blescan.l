; blescan -- a bluetooth le scan through inle's /dev/hci, the controller's h4 bytes (the pi's
; radio on its rom's firmware): the controller reset and named, then a passive scan, each
; advertiser a row the first time it is heard, and a tally at the end. receive only: nothing
; goes to the radio but the scan's own commands
;   love src/tools/blescan.l [-d DEV] [SECONDS]      DEV /dev/hci, SECONDS 30
(borrow 'posix)
(: (die m) (say err ("blescan: " + m + "\n"), flush err, quit 1)
   (num s) (foldl (a \ c \ a * 10 + c - 48) 0 (map s ^#s))
   (h2 b) (string [("0123456789abcdef" (b // 16)) ("0123456789abcdef" (b % 16))])
   (hex s) (join "" (map (i \ h2 (s i)) ^#s))
   (le s i n) (foldl (a \ k \ a * 256 + s (i + k)) 0 (rev ^n))
   ; an address as it is written, its bytes high first
   (addr s i) (join ":" (map (k \ h2 (s (i + 5 - k))) ^6))
   ; the words past the script's own path, which a boot line's run leaves in front
   args (>argv @ (f . r) (#f > 2 && snip f (#f - 2) #f = ".l" ? r >argv) _ ())
   dev (args @ ("-d" . d . _) d _ "/dev/hci")
   r (open dev "r")
   w (open dev "w")
   _ (port? r && port? w ? 0 (die ("no " + dev)))
   got {'b ""}
   (fill _) (cue? r ? (see r @ -1 (die (dev + " ended")) c (pin got 'b (got 'b + string c + chug r))))
   ; the next event within ms, its bytes from the 4; a byte that opens no event is dropped
   (event t)
    (: b (got 'b)
       (? (0 < #b && b 0 != 4) (pin got 'b (snip b 1 #b), event t)
          (3 <= #b && 3 + b 2 <= #b) (pin got 'b (snip b (3 + b 2) #b), snip b 0 (3 + b 2))
          (t < clock 0) ()
          (fill 0, rest 5, event t)))
   (cmd op ps) (say w (string [1 (op % 256) (op // 256) #ps] + ps), flush w)
   ; a command's completion: its event's parameters past the status, or the die
   (call what op ps)
    (: t (clock 0 + 3000)
       (go _) (event t @ () (die ("no answer to " + what))
                         (e && e 1 = 14 && le e 4 2 = op) (e 6 = 0 ? (snip e 7 #e) (die (what + " refused, status " + show (e 6))))
                         _ (go 0))
       (cmd op ps, go 0))
   ; an advertisement's fields: the name, else the maker's id and bytes, else its raw bytes
   (fields d)
    (: (go i n m) (? (#d <= i + 1 || d i = 0) [n m]
                     (: k (d i) ty (d (i + 1)) v (snip d (i + 2) (i + 1 + k))
                        (go (i + 1 + k) (ty = 8 || ty = 9 ? v n) (ty = 255 && 2 <= #v ? ("maker " + h2 (v 1) + h2 (v 0) + " " + hex (snip v 2 #v)) m))))
       (go 0 "" ""))
   (main as)
    (: secs (as @ ("-d" . _ . [s]) (num s) ("-d" . _) 30 [s] (num s) _ 30)
       _ (call "reset" 3075 "")
       v (call "read version" 4097 "")
       _ (say out "; hci \(show (v 0)) rev \(show (le v 1 2)), lmp \(show (v 3)) sub \(radix (le v 6 2) 16), maker \(radix (le v 4 2) 16)\n")
       a (call "read address" 4105 "")
       _ (say out "; address \(addr a 0)\n", flush out)
       _ (call "event mask" 3073 (string [255 255 255 255 255 31 0 32]))   ; the defaults and le meta
       _ (call "scan parameters" 8203 (string [0 16 0 16 0 0 0]))          ; passive, 10 ms of 10 ms
       _ (call "scan on" 8204 (string [1 0]))
       seen {}
       end (clock 0 + 1000 * secs)
       ; a legacy report: its kind, address kind, address, data and rssi, the first of the event's
       (heard e)
        (: d (snip e 14 (14 + e 13)) rs (e (14 + e 13)) rssi (rs < 128 ? rs (rs - 256)) ad (addr e 7)
           f (fields d) n (peep seen ad ())
           (pin seen ad [((n @ [c _ _] c _ 0) + 1) (n @ [_ x _] (max x rssi) _ rssi) (<f @ "" (n @ [_ _ y] y _ "") s s)],
            n @ () (say out "\(ad) rssi \(show rssi) \(<f) \(<>f)\n", flush out) _ 0))
       (go _) (clock 0 < end ? (event end @ () 0 (e && e 1 = 62 && e 3 = 2 && 14 <= #e && 15 + e 13 <= #e) (heard e, go 0) _ (go 0)))
       _ (go 0)
       _ (call "scan off" 8204 (string [0 0]))
       ks (sort (keys seen))
       (say out "; \(show #ks) advertisers in \(show secs) s\n",
        each ks (k \ seen k @ [c x n] (say out ";   \(k) \(show c) heard, best rssi \(show x) \(n)\n")),
        flush out))
   (main args))
