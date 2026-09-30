; --- test/host/ssh.l: ssh's crypto and wire floor, against published numbers ---
; not in the test/*.l corpus: this loads a crew file and splices its module.
;
;   sha512   FIPS 180-4's "abc", the empty string, and the lengths either side of
;            both padding edges (111/112, 127/128, 239/240) -- the digests off
;            python's hashlib, over bytes (7i + 1) & 255.
;   ed25519  RFC 8032 §7.1 tests 1-3: the public key, the signature, and verify's
;            answer on it and on each way of spoiling it; signing's walk traced to one
;            schedule whatever the scalar.
;   wire     RFC 4251 §5's mpint examples, and base64 both ways on a key blob.
;   aes      FIPS 197 appendix C's three key sizes, and SP 800-38A F.5.5's ctr blocks.
;   locked   a key ssh-keygen locked (aes256-ctr, bcrypt 4 rounds, "hunter2 pass"):
;            the seed and public key come out as the bare key's, a wrong passphrase
;            and none are told apart, and bcrypt-hash refuses a short state.
;   known_hosts  hashed names (ssh-keygen -H's lines), [host]:port, name lists and case,
;            @revoked, another key type, @cert-authority skipped.
;   clean    banner and disconnect text: controls, c1 and malformed utf-8 dropped.
;   verdict  the host key under each StrictHostKeyChecking: ask, accept-new, yes, no.
;   strict   strict kex ends on an ignore before newkeys; sequence numbers never wrap.
;
; the transport runs against a live sshd, which no gate stands up; see src/apps/ssh/ssh.l.
;
; run:  cat test/00-init.l test/host/ssh.l | out/love

(borrow "src/apps/ssh/ssh.l")
(borrow 'posix)
(borrow 'tls)
(borrow 'ssh)

(: ssht-run (\ n (bytes n (i \ (i * 7 + 1) & 255))))

; --- sha512 -----------------------------------------------------------------------
(test
 ((hex (sha512 "abc")) = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
 ((hex (sha512 "")) = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e")
 ((hex (sha512 (ssht-run 111))) = "3dfde1184fd99f233f98be4250f4edb9b535157909b668334370742204d97e047f1fd6a74bb5ba447f337286f421d9af957811f7ef62a458771457da126cb65e")
 ((hex (sha512 (ssht-run 112))) = "acc96c509e6d01787330a4c6a241e2cda9dcc2529dbe4288dbbcc3812133233c4698831127cf6ed0b333632b22715a5ce53a0a1002a684367b71c98aa6d1d900")
 ((hex (sha512 (ssht-run 127))) = "a315910cb7812a8e66d87c0c49a42d93dbe97bf0240ee995792292c529256d93f40199a59b3f6266343f302651fea1589e2040a2f3756126d3fe4f421a72079d")
 ((hex (sha512 (ssht-run 128))) = "31f33a52b36dc2e70c83b604fa999a5cabf33bf70e4556fbed7bff10870c1b7b241dd3f15d1ade24599f068fc58ab51e0028b0f0c98895c23358e8dee032ce06")
 ((hex (sha512 (ssht-run 239))) = "d5e023834c68aeb6e8eef9619ed5fb6fd8b3df796b49d18dce5f6fae76f3f6cae8ddf055611c4031bf5fe6aa68708360f5de1fe69a77055eb55612c5509d5e19")
 ((hex (sha512 (ssht-run 240))) = "67b19552bd96d84b251b262b7eef6fe73b2fdeabc4a4a0e4de2c8c621ee395729b3877c85c2b0fa79e379ca718f1a00d7508d8a5c04967fe240d4608edf05c10"))

; --- ed25519 ----------------------------------------------------------------------
(: ssht-ed [["9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
             "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a" ""
             "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"]
            ["4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"
             "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c" "72"
             "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"]
            ["c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7"
             "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025" "af82"
             "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a"]])
(: ssht-flip (\ s i (snip s 0 i + string (s i ^ 1) + snip s (i + 1) #s)))
(each ssht-ed
 (\ v (: seed (unhex (v 0)) pub (unhex (v 1)) m (unhex (v 2)) sig (unhex (v 3))
         _ (test ((ed-pub seed) = pub)
                 ((ed-sign seed pub m) = sig)
                 (ed-verify pub m sig)
                 !(ed-verify pub (m + "x") sig)
                 !(ed-verify pub m (ssht-flip sig 0))
                 !(ed-verify pub m (ssht-flip sig 40))
                 !(ed-verify (ssht-flip pub 3) m sig)
                 !(ed-verify pub m (snip sig 0 63)))
         0)))
; an S at or past the group order is refused, not reduced
(: ssht-s (le-bytes (le-num (snip (unhex (ssht-ed 0 3)) 32 64) + ed-l)))
(test !(ed-verify (unhex (ssht-ed 0 1)) "" (snip (unhex (ssht-ed 0 3)) 0 32 + ssht-s)))
; signing's walk keeps one schedule: on a trace curve, the integers, every scalar takes 256
; doublings and 64 additions and lands on itself; the ends of the scalar range land right
(: ssht-walk
    (\ v (: n {} (bump k) (pin n k (peep n k 0 + 1))
            r (p2-walk (\ a b (: _ (bump 'a) s (a 0 0 + b 0 0) [[s]])) (a \ (: _ (bump 'd) s (2 * a 0 0) [[s]]))
                       [[0]] (map (j \ [[j]]) ^16) (ed-nib (p2-limbs v)))
            [(r 0 0) (peep n 'a 0) (peep n 'd 0)])))
(test (all (v \ ssht-walk v = [v 64 256]) [0 1 257 ((1 << 252) + 12345) (ed-l - 1) ((1 << 251) + 1)])
      ((ed-lenc (ed-mulb (p2-limbs 0))) = ed-enc ed-zero)
      ((ed-lenc (ed-mulb (p2-limbs 1))) = ed-enc ed-b)
      ((ed-lenc (ed-mulb (p2-limbs (ed-l - 1)))) = ed-enc [(ed-q - ed-b 0) (ed-b 1) 1 0])
      ((ed-lenc (ed-mulb (p2-limbs 5))) = ed-enc (ed-scale 5 ed-b)))

; --- wire -------------------------------------------------------------------------
(test
 ((hex (mpint "")) = "00000000")
 ((hex (mpint (unhex "09a378f9b2e332a7"))) = "0000000809a378f9b2e332a7")
 ((hex (mpint (unhex "0080"))) = "000000020080")
 ((hex (mpint (unhex "80"))) = "000000020080")
 ((b64e (sstr "ssh-ed25519") 1) = "AAAAC3NzaC1lZDI1NTE5")
 ((b64e "a" 1) = "YQ==") ((b64e "ab" 1) = "YWI=") ((b64e "ab" 0) = "YWI")
 ((b64d "YWJj\nZA==") = "abcd")
 ((split "a,b,,c" 44) = ["a" "b" "" "c"]))

; --- aes ---------------------------------------------------------------------------
(: ssht-pt (unhex "00112233445566778899aabbccddeeff")
   ssht-k (\ n (bytes n (i \ i))))
(test
 ((hex (aes-block (aes-keys (ssht-k 16)) ssht-pt)) = "69c4e0d86a7b0430d8cdb78070b4c55a")
 ((hex (aes-block (aes-keys (ssht-k 24)) ssht-pt)) = "dda97ca4864cdfe06eaf70a0ec0d7191")
 ((hex (aes-block (aes-keys (ssht-k 32)) ssht-pt)) = "8ea2b7ca516745bfeafc49904b496089")
 ((hex (aes-ctr (aes-keys (unhex "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"))
                (unhex "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
                (unhex "6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c8")))
  = "601ec313775789a5b7a7f504bbf3d228f443e3ca4d62b59aca84e990cacaf5c52b09"))

; --- locked ------------------------------------------------------------------------
(: ssht-locked "-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABAq+kveuN
Z17BsmPa1Md8wXAAAABAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIDcERXZe0kI6eIjy
5PUJU++85fY6HsCmyORUx/NzZHOyAAAAkPN3f5IjZ2sIsQeYZzexRxAA+EgLNM+MebY3VC
m594r+i1s31ys6d00QWdtc50oWaqi9ulHjKG2pHzs1gwVASTmxJAiVZmeg3xuQQRyGj4n0
yhcmcvR1Kk/5mDAkkx6AfTGCj1aECfbQ0DY0aadgW+MGRmQn3ZqCXwiKZO/KYWdeipu8Gy
fW2MNFrwA/N0XZFA==
-----END OPENSSH PRIVATE KEY-----
"
   ssht-open (\ pw (ssh-keytext "k" ssht-locked (_ \ pw))))
(test
 ((ssht-open "hunter2 pass")
  = [(unhex "d4f658b3f8b868eab4eb83ad53111e2d8662b20739cf7067d6a14ea7de9dce29")
     (unhex "370445765ed2423a7888f2e4f50953efbce5f63a1ec0a6c8e454c7f3736473b2")])
 ((ssht-open "hunter3 pass") = "k: incorrect passphrase")
 ((ssht-open ()) = "k: no passphrase")
 (nil? (bcrypt-hash (zeros 4167) (zeros 64) (zeros 64))))

; --- known_hosts --------------------------------------------------------------------
; A and B are ed25519 host keys, E an ecdsa one. the two |1| lines are ssh-keygen -H's
; hashing of host.example -> A and [host.example]:2222 -> B
(: ssht-A "AAAAC3NzaC1lZDI1NTE5AAAAIO0TSO+AKyQIW+nLyBH5ShJuGY9aA5HGVvldHbw3RevU"
   ssht-B "AAAAC3NzaC1lZDI1NTE5AAAAIIjzN8j24WQCC+Qs/RdwB9LO3iYAyiLrElD/19WgjBxv"
   ssht-E "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNcFYQ2uU1waR/grVojE4yexgKia8zmbjtoLtjWz2EPYJmuAMEJ/K1acW7Lwr6TcxtrksKjMzZ5H8I7oE4IVM1I="
   ssht-hashed ("|1|k3f2BYy9Tf8jpd50gASQsBOGpmQ=|ZsaR5CrYMkv8zDTu7+X0HCZqC1I= ssh-ed25519 " + ssht-A
                + "\n|1|3gz7dhtAQvhPlrIsr4PaXQad3V4=|usRtgYWKuw2f+Zia85QPi2VWOv8= ssh-ed25519 " + ssht-B + "\n")
   ssht-khp ((cwd 0) + "/out/.ssht-kh")
   ssht-nm (cite 'ssh-cli 'kh-name)
   ssht-kh (\ txt nm key (: q (open ssht-khp "w") _ (say q txt) _ (close q)
                            (cite 'ssh-cli 'kh-check ssht-khp nm (b64d key)))))
(test
 ((ssht-nm "Host.Example" 22) = "host.example")
 ((ssht-nm "Host.Example" 2222) = "[host.example]:2222")
 ((ssht-kh ssht-hashed "host.example" ssht-A) = ['ok 1 "ssh-ed25519" 0])
 ((ssht-kh ssht-hashed "host.example" ssht-B) = ['bad 1 "ssh-ed25519" 0])
 ((ssht-kh ssht-hashed (ssht-nm "host.example" 2222) ssht-B) = ['ok 2 "ssh-ed25519" 0])
 ((ssht-kh ssht-hashed (ssht-nm "host.example" 2222) ssht-A) = ['bad 2 "ssh-ed25519" 0])
 ((ssht-kh ssht-hashed "other.example" ssht-A) = ['new 0 "" 0])
 ((ssht-kh ("host.example ecdsa-sha2-nistp256 " + ssht-E + "\n") "host.example" ssht-A)
  = ['other 1 "ecdsa-sha2-nistp256" 0])
 ((ssht-kh ("@revoked * ssh-ed25519 " + ssht-A + "\nhost.example ssh-ed25519 " + ssht-A + "\n") "host.example" ssht-A)
  = ['revoked 1 "ssh-ed25519" 0])
 ((ssht-kh ("[host.example]:2222 ssh-ed25519 " + ssht-A + "\n") "host.example" ssht-A) = ['new 0 "" 0])
 ((ssht-kh ("# a comment\n\nalias,Host.Example\tssh-ed25519 " + ssht-A + " note\n") "host.example" ssht-A)
  = ['ok 3 "ssh-ed25519" 0])
 ((ssht-kh ("@cert-authority host.example ecdsa-sha2-nistp256 " + ssht-E + "\n") "host.example" ssht-A)
  = ['new 0 "" 1])
 ((ssht-kh ("host.example ssh-ed25519 " + ssht-B + "\nhost.example ssh-ed25519 " + ssht-A + "\n") "host.example" ssht-A)
  = ['ok 2 "ssh-ed25519" 0]))

; --- clean -------------------------------------------------------------------------
; a peer's banner and disconnect text: c0 but tab and newline, del, c1 and malformed utf-8 go
(test
 ((ssh-clean "d\xe2\x80\x94e") = "d\xe2\x80\x94e")
 ((ssh-clean "a\x1b[31mb\tc\r\nz") = "a[31mb\tc\nz")
 ((ssh-clean "x\xc2\x9by\xc2\xa0z") = "xy\xc2\xa0z")
 ((ssh-clean "p\x80q\x9br\x7fs\xffu\xe0\x80\x80v\xed\xa0\x80w\xf0\x9f\x98\x80") = "pqrsuvw\xf0\x9f\x98\x80")
 ((ssh-clean "\xe2\x80") = ""))

; --- verdict ------------------------------------------------------------------------
; the host key's verdict under each StrictHostKeyChecking. ask (the default) asks about an
; unknown host and one known under another type: yes adds, no or no terminal refuses.
; accept-new adds an unknown host unasked, yes refuses it unasked, no skips the check
(: ssht-kv (cite 'ssh-cli 'kh-verdict)
   ssht-opts (\ k (: o (tablet 4) (pin o 'shk k, o)))
   ssht-asked (tablet 2)
   ssht-ask (\ ans m (pin ssht-asked 'n (peep ssht-asked 'n 0 + 1), pin ssht-asked 'm m, ans))
   ssht-v (\ k nm ask (: q (open ssht-khp "w") _ (say q ("host.example ecdsa-sha2-nistp256 " + ssht-E + "\n")) _ (close q)
                         (ssht-kv "ssh" (ssht-opts k) ssht-khp nm (b64d ssht-A) "SHA256:x" ask)))
   ssht-n (\ _ (peep ssht-asked 'n 0))
   ssht-pre (\ p r (string? r && snip r 0 #p = p))
   ssht-other "WARNING: the host key for host.example is known as ecdsa-sha2-nistp256 in "
   ssht-q "The authenticity of host 'new.example' can't be established.\nED25519 key fingerprint is SHA256:x.\n")
(test
 ; another key type: asked under ask and accept-new, refused unasked under yes
 (ssht-pre ssht-other (ssht-v "ask" "host.example" (ssht-ask ())))
 ((ssht-v "ask" "host.example" (ssht-ask "yes")) = 'add)
 (ssht-pre ssht-other (ssht-v "ask" "host.example" (ssht-ask "no")))
 ((ssht-v "accept-new" "host.example" (ssht-ask "yes")) = 'add)
 ((ssht-n 0) = 4)
 (ssht-pre ssht-other (ssht-v "yes" "host.example" (ssht-ask "yes")))
 ((ssht-n 0) = 4)
 ; an unknown host: asked under ask, added unasked under accept-new, refused unasked under yes
 ((ssht-v "ask" "new.example" (ssht-ask "yes")) = 'add)
 (ssht-pre ssht-q (ssht-asked 'm))
 ((ssht-v "ask" "new.example" (ssht-ask "no")) = "Host key verification failed.")
 ((ssht-v "ask" "new.example" (ssht-ask ())) = "Host key verification failed.")
 ((ssht-n 0) = 7)
 ((ssht-v "accept-new" "new.example" (ssht-ask "no")) = 'add)
 (ssht-pre "No ssh-ed25519 host key is known for new.example" (ssht-v "yes" "new.example" (ssht-ask "yes")))
 ((ssht-n 0) = 7)
 ; no check at all
 ((ssht-v "no" "host.example" (ssht-ask "no")) = 'go)
 ((ssht-v "no" "new.example" (ssht-ask "no")) = 'go)
 ((ssht-n 0) = 7))

; --- strict ---------------------------------------------------------------------------
; a pipe as the transport, framed by ssh-send and read by ssh-next: under strict kex an
; ignore ends the read, otherwise it is passed over; a sequence number never wraps
(: ssht-m32 ((1 << 32) - 1)
   ssht-ends (\ _ (: p (pipe 0) r (tablet 8) w (tablet 8)
                      (pins r 's (fdopen <p) 'pend "" 'rseq 0 'sseq 0 'busy 0,
                       pins w 's (fdopen >p) 'pend "" 'rseq 0 'sseq 0 'busy 0,
                       [r w])))
   ssht-fed (\ ps (: e (ssht-ends 0) _ (each ps (p \ ssh-send (e 1) p)) _ (close (e 1 's)) e)))
(test
 (: e (ssht-fed [(u8 2 + sstr "") (u8 20 + "x")]) _ (pin (e 0) 'strict 1) (nil? (ssh-next (e 0))))
 (: e (ssht-fed [(u8 2 + sstr "") (u8 20 + "x")]) ((ssh-next (e 0)) = u8 20 + "x"))
 (: e (ssht-fed [(u8 20 + "y")]) _ (pin (e 0) 'rseq ssht-m32) a (ssh-recv (e 0))
    _ (pin (e 0) 'rseq 0) (nil? a && ssh-recv (e 0) = u8 20 + "y"))
 (: e (ssht-ends 0) _ (pin (e 1) 'sseq ssht-m32) a (ssh-send (e 1) (u8 20 + "z"))
    (nil? a && nil? (ssh-recv (e 0)))))

(test_fin (),
 puts "src/apps/ssh: ok -- sha512 (fips 180-4), ed25519 (rfc 8032 7.1), mpint + base64,
aes (fips 197, sp 800-38a), a locked key (bcrypt_pbkdf + aes256-ctr),
known_hosts, banner text, the host key prompts, strict kex and sequence wrap
",
 0)
