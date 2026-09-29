; apps/ssh/ssh.l -- ssh from source: the module assembled, the client fired (cli.l).
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;
; a command runs by exec, and without one a shell -- over a pty when stdin is a terminal,
; or as -t / -T say. the host key is held to known_hosts (plain or hashed names): a match
; goes on, a changed or revoked key stops, and an unknown host, or one known under another
; key type, is asked about on the terminal -- yes adds it, anything else or no terminal
; stops. -o takes UserKnownHostsFile and StrictHostKeyChecking: ask (the default),
; accept-new (add an unknown host unasked), yes (never ask, refuse) and no (skip the check).
;
;   out/love apps/ssh/ssh.l user@host
(borrow "apps/tls/tls.l")
(borrow "apps/ssh/sha512.l")
(borrow "apps/ssh/ed25519.l")
(borrow "apps/ssh/aes.l")
(borrow "apps/ssh/bcrypt.l")
(borrow "apps/ssh/client.l")
(borrow "apps/ssh/server.l")
(borrow "apps/ssh/cli.l")

(: s (cite 'verbs 'fire ["ssh" "ssh.l"])
   (two? s ? (quit (urun (cite 'ssh-cli 'ssh-main) >s))))
