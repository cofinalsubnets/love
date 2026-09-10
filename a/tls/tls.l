; tls, assembled: each part a (module 'tls form, so the parts register the one
; module and the loader keeps the file-made registration -- sb's and lush's shape.
; bytes is first because it is the floor the ciphers index with; chacha and
; poly1305 are the two halves of the aead above it.
(borrow "a/tls/bytes.l")
(borrow "a/tls/chacha.l")
(borrow "a/tls/poly1305.l")
(borrow "a/tls/client.l")
