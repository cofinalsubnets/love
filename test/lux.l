; --- connect's unix-socket refusals answer a nom, not a scare; hosted only ---
(hosted ? (do
  (test (lit? connect))
  (test ('enoent = connect ['unix "/nonexistent/never/sock"]))   ; no such path
  (test ('badarg = connect ['unix ""]))                          ; empty path: refused up here
  (test (nom? (connect ['unix "/tmp"])))                             ; a directory
  (test ('badarg = connect ['unix 7]))                           ; not a string
  (test_fin ())
) 0)
