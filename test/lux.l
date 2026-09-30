; --- test/lux.l: a runnable smoke test for lux's socket nif (src/love/sock.c) ---
; src/love/sock.c links love0 as well as the final `love`, so this is a corpus law; it
; still reads standalone, like test/net.l:
;
;   cat test/00-init.l test/lux.l | out/love
;
; (connect ['unix path]) opens a unix-domain stream socket. a real round trip needs a
; unix listener on the other end -- that is an X display socket in practice, so
; the integration proof lives in the lux spikes (against Xephyr),
; not the gate. Here: the nif is present and every refusal lane answers nil,
; not a scare -- absence is nothing.
; the nif links on every seat, but the ANSWERS below are the OS's: a seat with no unix
; sockets under it refuses differently. skip where there is no kernel (hosted).
(? hosted (do
  (test (lit? connect))
  (test ('enoent = connect ['unix "/nonexistent/never/sock"]))   ; no such path
  (test ('badarg = connect ['unix ""]))                          ; empty path: refused up here
  (test (nom? (connect ['unix "/tmp"])))                             ; a directory, not a socket
  (test ('badarg = connect ['unix 7]))                           ; not a string
  (test_fin ())
) 0)
