; --- test/lux.l: a smoke test for lux's socket nif (src/love/sock.c), linked by love0 too ---
; (connect ['unix path]) opens a unix-domain stream socket; a real round trip needs an X
; display, so that proof lives in the lux spikes. here: the nif is present and every
; refusal answers nil, not a scare. the answers are the OS's, so it skips where there is no
; kernel (hosted). run: cat test/00-init.l test/lux.l | out/love
(hosted ? (do
  (test (lit? connect))
  (test ('enoent = connect ['unix "/nonexistent/never/sock"]))   ; no such path
  (test ('badarg = connect ['unix ""]))                          ; empty path: refused up here
  (test (nom? (connect ['unix "/tmp"])))                             ; a directory, not a socket
  (test ('badarg = connect ['unix 7]))                           ; not a string
  (test_fin ())
) 0)
