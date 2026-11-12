; src/apps/wifi/netlink.l -- netlink's wire over sock.c's (netlink proto group ..): messages,
; attributes, generic netlink's families, and rtnetlink's link, address and route. a datagram
; holds whole messages, each and each attribute 4-aligned, in the host's byte order (le here)
;   (nl-open proto groups)          -> a bound port, or the bind's nom
;   (nl-msg type flags seq body)    -> one message's bytes
;   (nl-attr type body)             -> an attribute; (nl-nest type attrs) nests a list of them
;   (nl-attrs s i)                  -> s's attributes from i, as ((type body) ..)
;   (nl-get as type d)              -> the first one's body by type, else d
;   (nl-msgs s)                     -> a datagram's messages, as ((type flags seq body) ..)
;   (nl-ask p type flags body)      -> the bodies answering one request; a refusal scares 'netlink errno
;   (genl-family p name)            -> (id ((group id) ..)) for a generic family, () if none
;   (genl-msg cmd attrs)            -> a generic message's body; (genl-attrs body) reads one
;   (rt-up p ifindex) (rt-addr p ifindex quad plen) (rt-gateway p ifindex quad)
;   a quad is an address as 4 bytes, network order
(module (netlink nl-open nl-msg nl-attr nl-nest nl-attrs nl-get nl-msgs nl-ask nl-err
         nl-u8 nl-u16 nl-u32 nl-str nl-rd16 nl-rd32 genl-family genl-msg genl-attrs
         rt-up rt-addr rt-gateway)
(borrow '(bytes))
(:
   ; --- the numbers: linux's uapi ---
   NlmError 2  NlmDone 3
   FRequest 1  FMulti 2  FAck 4  FDump 768  FCreate 1024  FExcl 512  FReplace 256
   GenlCtrl 16  CtrlGetFamily 3  CtrlFamilyId 1  CtrlFamilyName 2  CtrlMcastGroups 7

   (nl-u8 v) (wrle v 1)
   (nl-u16 v) (wrle v 2)
   (nl-u32 v) (wrle v 4)
   (nl-str s) (s + string 0)
   (nl-rd16 s) (rdle s 0 2)
   (nl-rd32 s) (rdle s 0 4)
   (nl-err v) (v >= 2147483648 ? (v - 4294967296) v)

   (nl-open proto groups) (bind ('netlink . proto . groups))
   (nl-msg type flags seq body) (nl-u32 (16 + #body) + nl-u16 type + nl-u16 flags + nl-u32 seq + nl-u32 0 + body)
   (nl-attr type body) (: n (4 + #body) (nl-u16 n + nl-u16 type + body + zbytes (padk n 4)))
   (nl-nest type as) (nl-attr (type | 32768) (join "" as))
   ; the nested and byte-order flags come off the type
   (nl-attrs s i)
    (: n #s
       (go i) (? (n < i + 4) ()
                 (: l (rdle s i 2)
                    (l < 4 || n < i + l ? () ([(rdle s (i + 2) 2 & 16383) (snip s (i + 4) (i + l))] . go (i + l + padk l 4)))))
       (go i))
   (nl-get as type d) (atom? as ? d (<as @ [t b] (t = type ? b (nl-get >as type d))))
   (nl-msgs s)
    (: n #s
       (go i) (? (n < i + 16) ()
                 (: l (rdle s i 4)
                    (l < 16 || n < i + l ? ()
                       ([(rdle s (i + 4) 2) (rdle s (i + 6) 2) (rdle s (i + 8) 4) (snip s (i + 16) (i + l))]
                        . go (i + l + padk l 4)))))
       (go 0))

   ; one request's answer: a dump's parts to its done, else to its ack; others' seqs are skipped
   seqs {'n 0}
   (nl-seq 0) (peep seqs 'n 0 + 1 @ k (pin seqs 'n k, k))
   (nl-ask p type flags body)
    (: k (nl-seq 0)
       dump ((flags & FDump) = FDump)
       sent (send p [0] (nl-msg type (FRequest | flags | (dump ? 0 FAck)) k body))
       (take ms acc)
        (? (atom? ms) (go acc)
           (<ms @ [t _ q b]
              (? (q != k) (take >ms acc)
                 (t = NlmDone) (rev acc)
                 (t = NlmError) (nl-err (rdle b 0 4) @ e (e = 0 ? (rev acc) (scare 'netlink e)))
                 (take >ms (b . acc)))))
       (go acc) (recv p @ r (two? r ? (take (nl-msgs (r 1)) acc) (scare 'netlink r)))
       (sent = p ? (go ()) (scare 'netlink sent)))

   ; --- generic netlink ---
   (genl-msg cmd as) (string cmd + string 1 + nl-u16 0 + join "" as)
   (genl-attrs b) (nl-attrs b 4)
   (unz s) (#s > 0 && s (#s - 1) = 0 ? (snip s 0 (#s - 1)) s)
   (genl-family p name)
    (trap (_ \ (: as (genl-attrs <(nl-ask p GenlCtrl 0 (genl-msg CtrlGetFamily [(nl-attr CtrlFamilyName (nl-str name))])))
                  gs (map (g \ (nl-attrs (g 1) 0 @ ga [(unz (nl-get ga 1 "")) (nl-rd32 (nl-get ga 2 ""))]))
                          (nl-attrs (nl-get as CtrlMcastGroups "") 0))
                  [(nl-rd16 (nl-get as CtrlFamilyId "")) gs]))
          0 (a \ b \ ()))

   ; --- rtnetlink: the link up, an address, the default route ---
   (ifinfo ifindex flags change) (nl-u8 0 + nl-u8 0 + nl-u16 0 + nl-u32 ifindex + nl-u32 flags + nl-u32 change)
   (rt-up p ifindex) (nl-ask p 16 0 (ifinfo ifindex 1 1))
   (bcast q plen) (: v (rdbe q 0 4) m (plen = 0 ? 0 ((4294967295 << (32 - plen)) & 4294967295)) (wrbe (v | (m ^ 4294967295)) 4))
   (rt-addr p ifindex q plen)
    (nl-ask p 20 (FCreate | FReplace)
       (nl-u8 2 + nl-u8 plen + nl-u8 0 + nl-u8 0 + nl-u32 ifindex
        + nl-attr 2 q + nl-attr 1 q + nl-attr 4 (bcast q plen)))
   (rt-gateway p ifindex q)
    (nl-ask p 24 (FCreate | FReplace)
       (nl-u8 2 + nl-u8 0 + nl-u8 0 + nl-u8 0 + nl-u8 254 + nl-u8 16 + nl-u8 0 + nl-u8 1 + nl-u32 0
        + nl-attr 5 q + nl-attr 4 (nl-u32 ifindex)))
))
