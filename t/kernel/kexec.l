; t/kernel/kexec.l -- the machine boots a module it fetched: what a page does with a
; module the machine built (a/doom.l's nest on inle), off the page's own origin. under
; node the origin is a directory (inle.mjs --origin) holding the doom module
(: r (fetch "/doom.wasm" "/d.wasm")
   _ (? (charm? r && r = 0) 0 (scare 'no-fetch r))
   _ (puts "kexec: booting the fetched module\n", flush out)
   (kexec "/d.wasm" "sh -c 'doom; echo doom-rc=$?'"))
