; --- test/host/ssh.l: ssh's crypto and wire floor, against published numbers ---
; not in the test/*.l corpus: this loads a crew file and splices its module.
;
;   sha512   FIPS 180-4's "abc", the empty string, and the lengths either side of
;            both padding edges (111/112, 127/128, 239/240) -- the digests off
;            python's hashlib, over bytes (7i + 1) & 255.
;   ed25519  RFC 8032 §7.1 tests 1-3: the public key, the signature, and verify's
;            answer on it and on each way of spoiling it.
;   wire     RFC 4251 §5's mpint examples, and base64 both ways on a key blob.
;
; the transport runs against a live sshd, which no gate stands up; see apps/ssh/ssh.l.
;
; run:  cat test/00-init.l test/host/ssh.l | out/love

(borrow "apps/ssh/ssh.l")
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
(: ssht-s (le-bytes (le-num (snip (unhex ((ssht-ed 0) 3)) 32 64) + ed-l)))
(test !(ed-verify (unhex ((ssht-ed 0) 1)) "" (snip (unhex ((ssht-ed 0) 3)) 0 32 + ssht-s)))

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

(test_fin (),
 puts "apps/ssh: ok -- sha512 (fips 180-4), ed25519 (rfc 8032 7.1), mpint + base64
",
 0)
