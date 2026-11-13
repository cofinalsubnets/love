; src/apps/hearts/seat.l -- a hearts seat's helm config: love greet on tty1, back after
; each session ends. data, read by helm as /etc/helm.l; test/host/helm.l checks it
(oneshot mounts (exec "/bin/love" "/lib/hearts/dev.l" "mount"))
(service greet (after mounts) (exec "/bin/love" "greet" "tty1") (restart always))
(target default (wants mounts greet))
