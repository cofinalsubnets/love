; tls, assembled: each part a (module 'tls form, so the parts register the one
; module and the loader keeps the file-made registration -- sb's and lush's shape.
; bytes is first because it is the floor the ciphers index with; chacha and
; poly1305 are the two halves of the aead above it; verify reads the server's key and its
; signature, and the client stands on all of them.
(borrow "apps/tls/bytes.l")
(borrow "apps/tls/chacha.l")
(borrow "apps/tls/poly1305.l")
(borrow "apps/tls/verify.l")
(borrow "apps/tls/client.l")
