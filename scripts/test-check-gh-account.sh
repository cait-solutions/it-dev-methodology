#!/usr/bin/env bash
#
# test-check-gh-account.sh — regression guard for the whitelist gh_account parser.
#
# WHY: the awk lookup in check-gh-account.sh had a dead-code emit bug — it only resolved
# the LAST whitelist entry; every other (middle) entry returned empty → URL-owner fallback.
# Masked because the URL owner usually coincided with the intended gh_account. This test
# asserts that a MIDDLE entry resolves (the failure that was invisible) + a no-gh_account
# entry returns empty. Scripts-only (check-gh-account.sh is maintainer push tooling,
# not delivered to consumers) — no dual-copy.
#
# Hermetic: uses a fixture CLAUDE.local.md + the --lookup-whitelist internal hook
# (no gh CLI, no auth switch, no real consumer dirs needed).
#
# Bash 3.2+ compatible.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CGA="$SCRIPT_DIR/check-gh-account.sh"
FIX="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/_test_cga_$$.md")"
fails=0

cat > "$FIX" <<'EOF'
# fixture CLAUDE.local.md

## auto_commit_consumers

```yaml
auto_commit_consumers:
  - path: ../first-documentation
    branch: ai-dev
    gh_account: first-acct
  - path: ../middle-documentation
    # middle entry — the one the dead-code bug never resolved
    branch: main
    gh_account: middle-acct
  - path: ../no-account-documentation
    branch: ai-dev
  - path: ../last-documentation
    branch: ai-dev
    gh_account: last-acct
```
EOF

_assert() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $desc (= '$actual')"
  else
    echo "  FAIL: $desc — expected '$expected', got '$actual'"
    fails=$((fails + 1))
  fi
}

echo "test-check-gh-account: whitelist parser regression"

_assert "first entry resolves"  "first-acct"  "$(bash "$CGA" --lookup-whitelist '../first-documentation'  "$FIX")"
_assert "MIDDLE entry resolves (dead-code bug guard)" "middle-acct" "$(bash "$CGA" --lookup-whitelist '../middle-documentation' "$FIX")"
_assert "last entry resolves"   "last-acct"   "$(bash "$CGA" --lookup-whitelist '../last-documentation'   "$FIX")"
_assert "no-gh_account entry → empty" "" "$(bash "$CGA" --lookup-whitelist '../no-account-documentation' "$FIX")"
_assert "absent entry → empty" "" "$(bash "$CGA" --lookup-whitelist '../does-not-exist' "$FIX")"

rm -f "$FIX" 2>/dev/null || true

if [ "$fails" -eq 0 ]; then
  echo "PASS: test-check-gh-account (5/5)"
  exit 0
else
  echo "FAIL: test-check-gh-account ($fails failed)"
  exit 1
fi
