#!/usr/bin/env bash
#
# test-secrets.sh — regression suite for secrets-management foundation.
#
# Runs in an isolated tmp directory (no impact on the methodology repo).
#
# Coverage:
#   - bash_protect.py: ENV_DUMP_PATTERNS reliably catch env / printenv /
#     echo $SECRET / source .env
#   - bash_protect.py: legitimate operations pass (git, ls, methodology scripts)
#   - secrets-guard.py: blocks staged .env files; blocks token-in-content
#   - with-secret.sh: subprocess sees value, parent stdout does not
#   - set-secret.sh: atomic write to .env
#   - check-secret.sh: boolean check, exit 0/1
#   - validate-secrets.sh: manifest vs .env consistency
#   - _get-secret-raw.sh: refuses without --explicit-stdout, works with flag
#
# Exit codes:
#   0  all tests passed
#   1  one or more tests failed
#
# Usage:
#   bash tests/test-secrets.sh
#   bash tests/test-secrets.sh --verbose

set -uo pipefail
# Note: deliberately NOT using `set -e` because we run subprocesses that
# intentionally exit non-zero (blocked hooks, missing secrets) and capture
# their exit codes via `$?` in _assert.

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

METH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR=$(mktemp -d -t methodology-secrets-test-XXXXXX)
HOOK="$METH_DIR/templates/.claude/hooks/bash_protect.py"
GUARD="$METH_DIR/templates/.claude/hooks/secrets-guard.py"

pass=0
fail=0
fail_details=()

_run_hook() {
  local cmd="$1"
  local payload
  payload=$(CMD="$cmd" py -c "import json,os,sys; sys.stdout.write(json.dumps({'tool_input':{'command': os.environ['CMD']}}))")
  printf '%s' "$payload" | py "$HOOK" 2>/dev/null
}

_assert() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass+1))
    $VERBOSE && echo "  PASS  $label"
  else
    fail=$((fail+1))
    fail_details+=("$label (expected $expected, got $actual)")
    echo "  FAIL  $label  (expected $expected, got $actual)"
  fi
}

cd "$TEST_DIR"
mkdir -p .claude scripts
cat > .claude/secrets-manifest.yaml <<'EOF'
manifest_version: 1
config:
  entropy_threshold: 4.5
  hook_enabled: true
secrets:
  - key: TEST_PAT
    purpose: "test secret"
    required: true
    scope: per-project
    sensitivity: high
    token_pattern: "ghp_[A-Za-z0-9]{36,}"
    how_to_obtain: |
      Run: bash scripts/set-secret.sh TEST_PAT <value>
EOF

cp "$METH_DIR/scripts/with-secret.sh" scripts/
cp "$METH_DIR/scripts/set-secret.sh" scripts/
cp "$METH_DIR/scripts/check-secret.sh" scripts/
cp "$METH_DIR/scripts/validate-secrets.sh" scripts/
cp "$METH_DIR/scripts/_get-secret-raw.sh" scripts/

echo "Test dir: $TEST_DIR"
echo "Hook: $HOOK"
echo ""
echo "=== Group 1: bash_protect.py ENV_DUMP patterns (reliable subset) ==="

for cmd in \
  'env' \
  'printenv' \
  'env | grep GITHUB' \
  'set | grep PAT' \
  'echo $GITHUB_PAT' \
  'echo ${GITHUB_TOKEN}' \
  'source .env' \
  '. .env'
do
  _run_hook "$cmd"; code=$?
  _assert "block: $cmd" "$code" "2"
done

for cmd in \
  'git status' \
  'git add .env.example' \
  'ls -la' \
  'echo hello' \
  'bash scripts/with-secret.sh GITHUB_PAT -- git push' \
  'bash scripts/check-secret.sh GITHUB_PAT'
do
  _run_hook "$cmd"; code=$?
  _assert "allow: $cmd" "$code" "0"
done

echo ""
echo "=== Group 2: with-secret.sh injection (no leak to parent stdout) ==="

bash scripts/set-secret.sh TEST_PAT "ghp_$(printf 'A%.0s' {1..40})" >/dev/null 2>&1
result=$(bash scripts/with-secret.sh TEST_PAT -- bash -c 'if [ -n "$TEST_PAT" ]; then echo "saw-secret-in-subproc"; else echo "no-secret"; fi' 2>&1)
if [[ "$result" == *"saw-secret-in-subproc"* ]] && [[ "$result" != *"ghp_AAAA"* ]]; then
  pass=$((pass+1))
  $VERBOSE && echo "  PASS  with-secret injects without leaking value"
else
  fail=$((fail+1))
  fail_details+=("with-secret injection leak: output=$result")
  echo "  FAIL  with-secret injection — output: $result"
fi

bash scripts/with-secret.sh NONEXISTENT -- echo ok >/dev/null 2>&1
_assert "with-secret blocks missing key" "$?" "1"

echo ""
echo "=== Group 3: set-secret atomic write ==="

if [[ -f .env ]]; then
  pass=$((pass+1)); $VERBOSE && echo "  PASS  set-secret created .env"
else
  fail=$((fail+1)); fail_details+=("set-secret did not create .env"); echo "  FAIL  set-secret"
fi

bash scripts/set-secret.sh TEST_PAT "ghp_$(printf 'B%.0s' {1..40})" >/dev/null 2>&1
count=$(grep -c "^TEST_PAT=" .env)
_assert "set-secret updates in place (no duplicate)" "$count" "1"

echo ""
echo "=== Group 4: check-secret boolean ==="

bash scripts/check-secret.sh TEST_PAT >/dev/null 2>&1
_assert "check-secret returns 0 for present key" "$?" "0"

bash scripts/check-secret.sh NONEXISTENT >/dev/null 2>&1
_assert "check-secret returns 1 for missing key" "$?" "1"

echo ""
echo "=== Group 5: validate-secrets ==="

bash scripts/validate-secrets.sh >/dev/null 2>&1
_assert "validate-secrets passes when required present" "$?" "0"

cp .env .env.backup
> .env
bash scripts/validate-secrets.sh >/dev/null 2>&1
_assert "validate-secrets fails when required missing" "$?" "1"
mv .env.backup .env

echo ""
echo "=== Group 6: _get-secret-raw escape hatch ==="

bash scripts/_get-secret-raw.sh TEST_PAT >/dev/null 2>&1
_assert "_get-secret-raw refuses without --explicit-stdout" "$?" "2"

value=$(bash scripts/_get-secret-raw.sh TEST_PAT --explicit-stdout 2>/dev/null)
if [[ "$value" == ghp_* ]]; then
  pass=$((pass+1)); $VERBOSE && echo "  PASS  _get-secret-raw with flag returns value"
else
  fail=$((fail+1)); fail_details+=("_get-secret-raw with flag did not return value"); echo "  FAIL  _get-secret-raw with flag"
fi

echo ""
echo "=== Group 7: secrets-guard.py (commit-time) ==="

git init -q 2>/dev/null || true
git config user.email "test@test.local" 2>/dev/null
git config user.name "test" 2>/dev/null

git add -f .env 2>/dev/null
echo '{"tool_input":{"command":"git commit -m test"}}' | py "$GUARD" >/dev/null 2>&1
_assert "secrets-guard blocks staged .env" "$?" "2"

git reset HEAD .env >/dev/null 2>&1

mkdir -p src
printf 'const token = "ghp_%s";\n' "$(printf 'C%.0s' {1..40})" > src/leak.js
git add src/leak.js
echo '{"tool_input":{"command":"git commit -m test"}}' | py "$GUARD" >/dev/null 2>&1
_assert "secrets-guard blocks token in committed source" "$?" "2"

echo ""
echo "=== Group 8: v4.34.1 hardening regressions ==="

# G-014 regression: methodology own .gitignore must exclude .env patterns.
# This test reads the source repo's gitignore (not test dir's) to verify
# that future maintainers don't accidentally remove the rules.
METH_GITIGNORE="$METH_DIR/.gitignore"
if [[ -f "$METH_GITIGNORE" ]]; then
  grep -qE '^\.env$' "$METH_GITIGNORE" && grep -qE '^\.env\.\*$' "$METH_GITIGNORE" && \
    grep -qE '^!\.env\.example$' "$METH_GITIGNORE"
  _assert "G-014: methodology own .gitignore protects secrets" "$?" "0"
else
  fail=$((fail+1)); fail_details+=("G-014: methodology .gitignore not found"); echo "  FAIL  G-014: .gitignore missing"
fi

# G-015 regression: settings.json deny includes critical reader patterns
# beyond the v4.34.0 cat/grep/awk list (python/node/perl/diff/iconv/tee).
SETTINGS="$METH_DIR/templates/settings.template.json"
if [[ -f "$SETTINGS" ]]; then
  expected_patterns=(
    '"Bash(python \*\.env\*)"'
    '"Bash(node \*\.env\*)"'
    '"Bash(perl \*\.env\*)"'
    '"Bash(diff \*\.env\*)"'
    '"Bash(iconv \*\.env\*)"'
    '"Bash(tee \*\.env\*)"'
  )
  all_present=true
  for pat in "${expected_patterns[@]}"; do
    if ! grep -qF "${pat//\\/}" "$SETTINGS"; then
      all_present=false
      break
    fi
  done
  if $all_present; then
    pass=$((pass+1)); $VERBOSE && echo "  PASS  G-015: settings.json deny covers python/node/perl/diff/iconv/tee"
  else
    fail=$((fail+1)); fail_details+=("G-015: settings.json missing expected reader patterns"); echo "  FAIL  G-015: missing patterns"
  fi
else
  fail=$((fail+1)); fail_details+=("G-015: settings.template.json not found"); echo "  FAIL  G-015"
fi

# G-016 regression: set-secret.sh contains stat-verify after chmod 600.
# We don't try to detect actual NTFS behaviour (depends on OS); we verify
# the script has the warn block that would fire on detection.
SETSECRET="$METH_DIR/scripts/set-secret.sh"
if grep -q "Windows NTFS" "$SETSECRET" && grep -q "icacls" "$SETSECRET"; then
  pass=$((pass+1)); $VERBOSE && echo "  PASS  G-016: set-secret.sh has Windows NTFS chmod warn"
else
  fail=$((fail+1)); fail_details+=("G-016: set-secret.sh missing NTFS warn block"); echo "  FAIL  G-016: NTFS warn missing"
fi

# G-017 regression: /plan Шаг 99.3 contains mandatory sub-checks block.
PLAN="$METH_DIR/commands/plan.md"
if grep -q "Mandatory sub-checks" "$PLAN" && grep -q "Dogfood check" "$PLAN" && \
   grep -q "Systematic source enumeration" "$PLAN" && grep -q "Cross-platform verification" "$PLAN"; then
  pass=$((pass+1)); $VERBOSE && echo "  PASS  G-017: /plan Confidence Declaration has mandatory sub-checks"
else
  fail=$((fail+1)); fail_details+=("G-017: /plan mandatory sub-checks block missing"); echo "  FAIL  G-017: sub-checks missing"
fi

echo ""
echo "=== Summary ==="
total=$((pass + fail))
echo "  Passed: $pass / $total"
if [[ $fail -gt 0 ]]; then
  echo "  Failed: $fail"
  for d in "${fail_details[@]}"; do
    echo "    - $d"
  done
fi
echo ""
echo "Test dir (manual cleanup): $TEST_DIR"

if [[ $fail -eq 0 ]]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ $fail TEST(S) FAILED"
  exit 1
fi
