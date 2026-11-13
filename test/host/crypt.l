; test/host/crypt.l -- the shadow hashes (src/apps/crypt.l): drepper's sha512-crypt vectors, rfc
; 7914's scrypt vectors through yescrypt.c, and settings libxcrypt answered for the edges (an empty
; password, an empty salt, a hash past the salt, p and t, classic scrypt by $y$)
;   cat test/00-init.l test/host/crypt.l | out/love
(borrow '(crypt bytes))
(: hw "$6$saltstring$svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJuesI68u4OTLiBFdcbYEdFCoEOfaS35inz1"
   _ (test (hw = crypt-hash "Hello world!" "$6$saltstring")
         ("$6$rounds=10000$saltstringsaltst$OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbHbbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v."
          = crypt-hash "Hello world!" "$6$rounds=10000$saltstringsaltstring")
         ("$6$rounds=5000$toolongsaltstrin$lQ8jolhgVRVhY4b5pZKaysCLi0QBxGoNeKQzQ3glMhwllF7oGDZxUhx1yxdYcz/e1JSbq3y6JMxxl8audkUEm0"
          = crypt-hash "This is just a test" "$6$rounds=5000$toolongsaltstring")
         ("$6$rounds=1000$roundstoolow$kUMsbe306n21p9R.FRkW3IGn.S9NPN0x50YhH1xhLsPuWGsUSklZt58jaTfF4ZEQpyUNGc0dqbpBYYBaHHrsX."
          = crypt-hash "the minimum number is still observed" "$6$rounds=10$roundstoolow")
         ("$6$x$QSmr1Bx2g4O6BzKvdkgOcyU6H91X6I/XBv5pSalMhSPkwdH6Beo3F455xZJg0v//bxVK5F4OE5k1.0xuR26MK0"
          = crypt-hash "" "$6$x")
         ("$6$$Z7WSO9A8tKGD2oGB9t2ViKdYTIHgnjMZIbdOJElGnO.QoZE5zDsfnF1WHM.IL2KPxhNG4/v/zU9LBcGhxg5Uy."
          = crypt-hash "pw" "$6$")
         ("$6$rounds=2000$abc$Z/IoF69o2Mn3//dd1nJT0vo92qnfGi2vR/PPR1quEmqQQckFN9CbgqryfNjiLWzKNyj8zrPRve1BZ9fcMIqIh/"
          = crypt-hash "pw" "$6$rounds=2000$abc$tail")
         (crypt-check "Hello world!" hw)
         !(crypt-check "Hello world?" hw)
         !(crypt-check "Hello world!" (snip hw 0 (#hw - 1)))       ; a stored hash cut short
         !(crypt-check "Hello world!" "!")                          ; a locked account
         !(crypt-check "" "")                                       ; no hash is no login
         (nil? (crypt-hash "pw" "$6$rounds=x$salt"))
         (nil? (crypt-hash "pw" "$1$salt")))
   ys "$y$j9T$LdJMENpBABJJ3hIHjB1Bi."
   yh (ys + "$iofk68xbXBoXKsxTyMBCh2qkQuzQZ2Zik521F9TsTq6")
   (kdf pw salt prm) (yescrypt-kdf (cask (yescrypt-room (prm 1) (prm 2) (prm 3))) pw salt prm)
   _ (test (kdf "password" "NaCl" [0 1024 8 16 0] = hex2b "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b373162")
           (kdf "" "" [0 16 1 1 0] = hex2b "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442")
           (crypt-hash "pleaseletmein" ys = yh)
           (crypt-hash "" ys = ys + "$0VoQRSq3WjXDU.r5dyEx3bs9lIvBVufPNCNqODXmIC8")
           (crypt-hash "pleaseletmein" "$y$j7T0./$LdJMENpBABJJ3hIHjB1Bi."         ; p 2, t 2
            = "$y$j7T0./$LdJMENpBABJJ3hIHjB1Bi.$IQiHTm4FySXxZqOXhktAPRzimy7JkqqyJUzR4JnBVW3")
           (crypt-hash "pleaseletmein" "$y$j9T/.$LdJMENpBABJJ3hIHjB1Bi."          ; t 1
            = "$y$j9T/.$LdJMENpBABJJ3hIHjB1Bi.$YbyoYtto/nyANkHZMrni8UQvDGy61WvOuTAu8aWt8/4")
           (crypt-hash "pleaseletmein" "$y$.75$abcd" = "$y$.75$abcd$6pIrSV1uZArvzUpjI2qvCJpArYP2n.h0hFDzjAA0j43")   ; classic
           (crypt-hash "pleaseletmein" "$y$j8T$" = "$y$j8T$$nPqMeWL0AjOFzZJXqc0KUL7M939WaZBF.nUpj9wsWO3")             ; no salt
           (crypt-hash "pleaseletmein" (ys + "$tail") = yh)
           (crypt-check "pleaseletmein" yh) !(crypt-check "pleaseletmeim" yh)
           (nil? (crypt-hash "pw" "$y$j9T$x"))                     ; one digit is no byte
           (nil? (crypt-hash "pw" "$y$k9T$abcd"))                  ; a flavour yescrypt.c does not run
           (nil? (crypt-hash "pw" "$y$j9T"))
           (crypt-d64 "LdJMENpBABJJ3hIHjB1Bi." @ b (crypt-e64 b = "LdJMENpBABJJ3hIHjB1Bi."))
           (nil? (kdf "pw" "" [0 15 1 1 0])) (nil? (kdf "pw" "" [7 16 1 1 0])) (nil? (kdf "pw" "" [0 16 1 1 1]))
           (nil? (yescrypt-kdf (cask 64) "pw" "" [0 16 1 1 0])))  ; a cask too small
   (puts "crypt: ok\n"))
