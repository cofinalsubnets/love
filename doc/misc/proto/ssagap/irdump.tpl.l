(: _ (use 'moon)
   is9 ["out/host/" "./" "src/" "out/lib/" "src/apps/moon/lib/math/" "src/apps/moon/include/"]
   src "@FILE@"
   r (cc-parse src {'is is9 'ds '("ai_tco=1" "AiHaveVersionH") 'tgt 'x64 'os 'linux 'vb () 'dia 'moon})
   _ (? !(okv? r) (puts ("!! parsefail " + src + "\n"))
        (@ r [_ ast stag sigs weaks sfns svars sects alias aligns ainl noinl consts rstrs]
           (: ob (cgen-obj ast stag sigs weaks [sfns svars sects alias aligns ainl noinl consts rstrs ()] 'x64)
              (? !(two? ob) (puts ("!! genfail " + src + "\n"))
                 (: _ (puts ("== " + src + "\n"))
                    _ (putx <>ob)
                    _ (putc 10)
                    0)))))
   0)
