#!/bin/sh
# test/kore/laws.sh -- the love-level laws: every kore module read into one love, then test/law/kore.l
. "$(dirname "$0")/common.sh"

echo "UTILS apps/kore/{text,core,fs,re,sed,awk,expr,bc,less,find,diff,patch,man,lens}.l test/law/kore.l"
out=$ho/.test_kore.out
# lush's job.l + glob.l ride along because find.l captures sh-match at its define
{ cat test/00-init.l apps/kore/text.l apps/kore/u.l apps/kore/core.l apps/kore/fs.l apps/kore/re.l \
      apps/kore/sed.l apps/kore/awk.l apps/kore/expr.l apps/kore/bc.l apps/kore/proc.l apps/kore/less.l apps/libra/lint.l apps/vi/config.l apps/vi/hue.l \
      apps/vi/core.l apps/vi/vi.l apps/kore/diff.l apps/kore/patch.l apps/lush.l \
      apps/kore/find.l apps/kore/man.l apps/kore/lens.l; \
  echo "(borrow 'kore)"; \
  cat test/law/kore.l; } | "$m" > "$out" 2>&1
r=$?
cat "$out"
[ $r -eq 0 ] && grep -q "test/law/kore: myers" "$out" || fail "utils (exit $r)"

