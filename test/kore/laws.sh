#!/bin/sh
# test/kore/laws.sh -- the love-level laws: every kore module read into one love, then test/law/kore.l
. "$(dirname "$0")/common.sh"

echo "UTILS src/apps/kore/{text,core,fs,re,sed,awk,expr,bc,less,find,diff,patch,man,lens}.l test/law/kore.l"
out=$ho/.test_kore.out
# lush's job.l + glob.l ride along because find.l captures sh-match at its define
{ cat test/00-init.l src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/core.l src/apps/kore/fs.l src/apps/kore/re.l \
      src/apps/kore/sed.l src/apps/kore/awk.l src/apps/kore/expr.l src/apps/kore/bc.l src/apps/kore/proc.l src/apps/kore/less.l src/apps/libra/lint.l src/apps/vi/config.l src/apps/vi/hue.l src/apps/vi/hues.l \
      src/apps/vi/core.l src/apps/vi/vi.l src/apps/kore/diff.l src/apps/kore/patch.l src/apps/lush.l \
      src/apps/kore/find.l src/apps/kore/man.l src/apps/kore/lens.l; \
  echo "(borrow 'kore)"; \
  cat test/law/kore.l; } | "$m" > "$out" 2>&1
r=$?
cat "$out"
[ $r -eq 0 ] && grep -q "test/law/kore: myers" "$out" || fail "utils (exit $r)"

