; --- test/lux.l: a runnable smoke test for lux's socket nif (inle/sock.c) ---
; inle/sock.c links love0 as well as the final `love`, so this is a corpus law; it
; still reads standalone, like test/net.l:
;
;   cat test/00-init.l test/lux.l | out/love
;
; (connectu path) opens a unix-domain stream socket. a real round trip needs a
; unix listener on the other end -- that is an X display socket in practice, so
; the integration proof lives in the lux spikes (against Xephyr),
; not the gate. Here: the nif is present and every refusal lane answers nil,
; not a scare -- absence is nothing.
; the nif links on every seat, but the ANSWERS below are the OS's: a seat with no unix
; sockets under it refuses differently. skip where there is no kernel (hosted).
(? hosted (do
  (assert (lit? connectu))
  (assert ('enoent = (connectu "/nonexistent/never/sock")))   ; no such path
  (assert ('badarg = (connectu "")))                          ; empty path: refused up here
  (assert (nom? (connectu "/tmp")))                             ; a directory, not a socket
  (assert ('badarg = (connectu 7)))                           ; not a string
  (test_fin ())
  (say err "lux: ok\n")
) 0)
