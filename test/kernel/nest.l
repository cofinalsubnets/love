; test/kernel/nest.l -- the artifact rebuilds its own wasm module aboard: the source laid off
; the carried tarball, cook driven with this kernel as the toolchain, and the module linked
; under the seat's collector budget -- what `love web` and `love doom` do on the page. a
; task shares no environment with its spawner here, so what cook is told goes on its line.
(: nest ("/home/love-" + love-version)
   mod (nest + "/out/love.wasm")
   _ (puts "nest: laying the source\n")
   _ ((cite 'source 'src-nest) "/home")
   _ (puts "nest: cook wasm LOVE=love\n")
   _ (flush out)
   st ((cite 'doom 'run-in) nest ["cook" "wasm" "LOVE=love" "LUSHFLAGS=-a" "LOVE_ARMED=1"])
   q (two? (stat mod) && open mod "r")
   n (hot? q ? (: s (slurp q) (close q, #s)) 0)
   _ (puts ("nest: cook wasm answered " + show st + ", "
            + (0 < n ? ("the module stands (" + show n + " bytes)") "the module is missing") + "\n"))
   _ (flush out)
   (reset))
