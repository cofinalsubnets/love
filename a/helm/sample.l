; a/helm/sample.l -- a helm config, and the whole language in one page.
; run it: love -l a/helm/unit.l -l a/helm/sup.l -l a/helm/moor.l \
;              -l a/helm/helm.l -e "(helm-main [\"check\" \"a/helm/sample.l\"])"

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
