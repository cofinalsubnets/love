; test/host/gcleak.l -- the collector loses no block: love0, linked over the host's malloc, boots
; under valgrind with no definite leak. its boot runs minors that outgrow the survivors' block
; run: cat test/00-init.l test/host/gcleak.l | out/love
(: vg? (<(hark ["sh" "-c" "command -v valgrind >/dev/null"]) = 0)
   r (vg? ? (hark ["sh" "-c" "valgrind -q --leak-check=full --errors-for-leak-kinds=definite --error-exitcode=9 out/love0 -e 1 2>&1"]) [0 "1"])
   _ (test (<r = 0))
   0)
(test_fin (), puts "gcleak: ok", putc 10, 0)
