; test/host/login.l -- love login (src/apps/login.l) over a fake root: the accounts it finds,
; the password it takes, the groups and environment it gives, and the utmp record it lays
;   cat test/00-init.l test/host/00-host.l test/host/login.l | out/love
(borrow '(login crypt posix))
(: r ("out/.login-law." + show (getpid 0))
   hk (crypt-hash "secret" "$6$abcdefgh")
   _ (mkdir r 493, mkdir (r + "/etc") 493, mkdir (r + "/run") 493, mkdir (r + "/var") 493,
      mkdir (r + "/var/log") 493)
   _ (uwrite (r + "/etc/passwd") ("root:x:0:0:root:/root:/bin/bash\n# a comment\nkit:x:1000:1000:Kit,,,:/home/kit:/bin/zsh\n"
                                  + "lock:x:1001:1001::/home/lock:\nold:" + hk + ":1002:1002::/:/bin/sh\nnoshadow:x:1003:1003::/:/bin/sh\n"))
   _ (uwrite (r + "/etc/shadow") ("root:*:19000:0:99999:7:::\nkit:" + hk + ":19000:0:99999:7:::\nlock:!" + hk + ":19000::::::\n"))
   _ (uwrite (r + "/etc/group") "root:x:0:\nkit:x:1000:\naudio:x:29:kit,lock\nvideo:x:44:lock\nwheel:x:10:kit\n")
   kit (login-who r "kit")
   u (login-utrec 7 4242 "tty3" "kit" "" 1794000000)
   u2 (login-utrec 7 4343 "tty3" "kit" "" 1794000100)
   u5 (login-utrec 7 99 "tty5" "lock" "" 1794000200)
   (le s i n) (foldl (\ a k (a + (s (i + k) << (8 * k)))) 0 ^n)
   _ (test (kit = ["kit" 1000 1000 "Kit,,," "/home/kit" "/bin/zsh" hk])
           (login-who r "lock" 5 = "/bin/sh")                      ; an empty shell is sh
           ((login-who r "old") 6 = hk)                           ; a hash in passwd itself
           ((login-who r "noshadow") 6 = "!")                     ; an x with no shadow row is locked
           (nil? (login-who r "nobody")) (nil? (login-who r "# a comment"))
           (login-groups r "kit" 1000 = [1000 29 10]) (login-groups r "lock" 1001 = [1001 29 44])
           (login-auth r "kit" "secret" = kit)
           (nil? (login-auth r "kit" "Secret")) (nil? (login-auth r "kit" ""))
           (nil? (login-auth r "lock" "secret"))                   ; ! before the hash
           (nil? (login-auth r "root" "")) (nil? (login-auth r "nobody" "secret"))
           (login-auth r "old" "secret" 0 = "old")
           (login-env kit "xterm" = [["HOME" "/home/kit"] ["SHELL" "/bin/zsh"] ["USER" "kit"]
                                     ["LOGNAME" "kit"] ["TERM" "xterm"] ["PATH" "/usr/local/bin:/usr/bin:/bin"]])
           (login-id "tty3" = "3") (login-id "pts/12" = "s/12") (login-id "console" = "sole")
           (#u = 384) (le u 0 2 = 7) (le u 4 4 = 4242) (snip u 8 12 = "tty3") (u 12 = 0)
           (snip u 40 41 = "3") (snip u 44 47 = "kit") (le u 340 4 = 1794000000)
           (login-utmp "" u = u)
           (login-utmp u u2 = u2)                                  ; a line's slot is taken again
           (login-utmp u u5 = u + u5)
           (login-utmp (u + u5) u2 = u2 + u5))
   _ (each ["/etc/passwd" "/etc/shadow" "/etc/group"] (f \ unlink (r + f)))
   _ (each ["/etc" "/run" "/var/log" "/var" ""] (d \ rmdir (r + d)))
   (puts "login: ok\n"))
