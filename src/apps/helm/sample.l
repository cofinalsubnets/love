; src/apps/helm/sample.l -- a helm config, and the whole language in one page.
; run it: love -l src/apps/helm/unit.l -l src/apps/helm/sup.l -l src/apps/helm/moor.l \
;              -l src/apps/helm/helm.l -e "(helm-main [\"check\" \"src/apps/helm/sample.l\"])"

(oneshot clock
  (exec "/bin/sh" "-c" "date +%s > /tmp/helm-boot-stamp"))

(service ticker
  (after clock)
  (exec "/bin/sh" "-c" "while :; do echo tick; sleep 1; done")
  (restart always)
  (log "/tmp/helm-ticker.log"))

(service flapper
  (exec "/bin/sh" "-c" "exit 1")
  (restart on-fail)
  (tries 2))

(target default
  (wants ticker flapper))
