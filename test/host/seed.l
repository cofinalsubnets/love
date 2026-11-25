; test/host/seed.l -- `love seed` where a file it makes can't be run (a noexec mount, android)
(borrow '(posix kore))
(: love (cwd 0 + "/out/love")
   dir ("/tmp/seedtest-" + show (getpid 0))
   ask "(puts (+ \"denied=\" (show (cite (quote source) (quote seed-denied?) \"LOVE\"))))"
   (sh cmd) (hark ["sh" "-c" cmd])
   _ (mkdir dir 493) _ (mkdir (dir + "/d") 493) _ (mkdir (dir + "/r") 493)
   q (open (dir + "/in.sh") "w")
   _ (say q ("unset LOVE LUSHFLAGS\ncd \"$1\" || exit 98\n\"$2\" -e '" + replace ask "LOVE" love + "' < /dev/null\n"
             + "echo; ls -A out\n\"$2\" seed r 2>&1; echo rc=$?; ls -A r/*/out\n"))
   _ (close q)
   ; where files run the probe says so, and leaves nothing
   r (sh ("cd " + dir + " && env -u LOVE " + love + " -e '" + replace ask "LOVE" love + "' < /dev/null; ls -A out"))
   _ (test (<r = 0) (has? >r "denied=0") (! (has? >r "seedprobe")))
   ; in a noexec mount it refuses: a native seed stops before it builds and names another machine (99: no mount here)
   m (sh ("unshare -Urm sh -c 'mount -t tmpfs -o noexec,size=200m tmpfs " + dir + "/r || exit 99; exec sh " + dir + "/in.sh "
          + dir + "/r " + love + "' 2>/dev/null"))
   _ (<m = 99 || <m = 1 && >m = "" ? (gate-partly "seed: no noexec mount here, its refusal skipped")
       (test (has? >m "denied=1") (! (has? >m "seedprobe")) (has? >m "can't be run, so this binary can't be rebuilt there")
             (has? >m "rc=1") (! (has? >m "CC\t")) (has? >m "love seed ")))
   (sh ("rm -r " + dir), 0))
(test_fin (), puts "seed: ok", putc 10, 0)
