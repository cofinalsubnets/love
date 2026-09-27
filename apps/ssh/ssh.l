; apps/ssh/ssh.l -- ssh from source: the module assembled, the client fired (cli.l).
;
;   ssh [-p port] [-i identity] [-l user] [-t | -T] [-o option=value] [user@]host [command ..]
;
; a command runs by exec, and without one a shell -- over a pty when stdin is a terminal,
; or as -t / -T say. the host key is held to known_hosts: a match goes on, a changed key
; stops, an unknown host is added and said (openssh's accept-new). -o takes
; UserKnownHostsFile and StrictHostKeyChecking=no, which skips the check. hashed
; known_hosts lines are HMAC-SHA1 and not read; such a host reads as unknown.
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
   (two? s ? ((cite 'ssh-cli 'ssh-main) >s)))
