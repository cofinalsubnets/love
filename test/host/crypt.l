; test/host/crypt.l -- the shadow hashes (src/apps/crypt.l): drepper's sha512-crypt vectors, and
; settings libxcrypt answered for the edges (an empty password, an empty salt, a hash past the salt)
;   cat test/00-init.l test/host/crypt.l | out/love
(borrow 'crypt)
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
   (puts "crypt: ok\n"))
