#!/usr/bin/env bash
#
# sync-doctor.sh — READ-ONLY health snapshot of methodology install.
# DUAL-COPY: канон scripts/sync-doctor.sh — менять синхронно с templates/scripts/sync-doctor.sh (ADR-014).
#
# Checks (always printed, even if N/A):
#   version  — consumer-vs-clone (раздельно от clone-vs-remote — закрывает G-107 conflation)
#   hooks    — each hook in settings.json exists on disk + Python available
#   secrets  — manifest presence + validate-secrets.sh (delegated)
#   deps     — Python ≥3.10, gh auth (boolean only, no token values)
#   dev-checks — gated: info-only if dev profile detected
#
# READ-ONLY: ничего не пишет (ни файлы, ни state, ни triggers.json).
# При FAIL — направляет на полный /sync-audit (который чинит).
#
# Usage:
#   bash scripts/sync-doctor.sh [--json] [--online] [--methodology-path DIR]
#   (no flags)          human-readable, exit 0=PASS / 1=FAIL
#   --json              JSON object on stdout, same exit contract
#   --online            also check clone-vs-remote via git ls-remote
#   --methodology-path  path to methodology clone (default: CLAUDE.local.md methodology_path)
#
# Not for direct user invocation — use /sync-audit --doctor command instead.

set -u

JSON_MODE=0
ONLINE=0
METHODOLOGY_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json)               JSON_MODE=1; shift ;;
    --online)             ONLINE=1; shift ;;
    --methodology-path)   METHODOLOGY_PATH="$2"; shift 2 ;;
    --methodology-path=*) METHODOLOGY_PATH="${1#*=}"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Python resolver (Bash 3.2: no ${var,,})
# ---------------------------------------------------------------------------
PYTHON=""
PY_VER="N/A"
for _cmd in py python3 python; do
  if command -v "$_cmd" >/dev/null 2>&1; then
    PYTHON="$_cmd"
    PY_VER=$("$_cmd" --version 2>&1 | sed 's/Python //')
    break
  fi
done

# ---------------------------------------------------------------------------
# Resolve methodology path
# ---------------------------------------------------------------------------
if [ -z "$METHODOLOGY_PATH" ]; then
  if [ -f "CLAUDE.local.md" ]; then
    _mpath=$(grep "methodology_path:" CLAUDE.local.md 2>/dev/null | head -1 | sed 's/.*methodology_path:[[:space:]]*//' | tr -d '[:space:]"'"'"')
    if [ -n "$_mpath" ] && [ "$_mpath" != "null" ]; then
      METHODOLOGY_PATH="$_mpath"
    fi
  fi
  [ -z "$METHODOLOGY_PATH" ] && METHODOLOGY_PATH="../it-dev-methodology"
fi
# methodology_path: . means this repo IS the methodology
if [ "$METHODOLOGY_PATH" = "." ]; then
  METHODOLOGY_PATH="$(pwd)"
fi

# ---------------------------------------------------------------------------
# State variables (all core sections always emit a value)
# ---------------------------------------------------------------------------
FAILS=0

VER_STATUS="N/A"
VER_CONSUMER="N/A"
VER_CLONE="N/A"
VER_DELTA="N/A"
VER_UPSTREAM="not checked (offline)"

HOOKS_STATUS="N/A"
HOOKS_MISSING=""

SECRETS_STATUS="N/A"

DEPS_STATUS="N/A"
DEPS_PY="N/A"
DEPS_GH="N/A"

DEV_STATUS="N/A"

# ---------------------------------------------------------------------------
# Section 1: version (consumer-vs-clone — закрывает G-107 conflation)
# ---------------------------------------------------------------------------
if [ -f ".claude/.version" ]; then
  VER_CONSUMER=$(grep "^methodology:" .claude/.version 2>/dev/null | head -1 \
    | sed 's/^methodology:[[:space:]]*//' | tr -d '[:space:]')
fi
if [ -f "$METHODOLOGY_PATH/VERSION" ]; then
  VER_CLONE=$(cat "$METHODOLOGY_PATH/VERSION" 2>/dev/null | tr -d '[:space:]')
fi

if [ "$VER_CONSUMER" = "N/A" ] && [ "$VER_CLONE" = "N/A" ]; then
  VER_DELTA="cannot-compare (no .claude/.version and no methodology VERSION found)"
  VER_STATUS="WARN"
elif [ "$VER_CONSUMER" = "N/A" ]; then
  VER_DELTA="cannot-compare (no .claude/.version — run new-project-init.sh first)"
  VER_STATUS="WARN"
elif [ "$VER_CLONE" = "N/A" ]; then
  VER_DELTA="cannot-compare (methodology clone not found at: $METHODOLOGY_PATH)"
  VER_STATUS="WARN"
elif [ "$VER_CONSUMER" = "$VER_CLONE" ]; then
  VER_DELTA="SYNCED"
  VER_STATUS="PASS"
else
  VER_DELTA="BEHIND"
  VER_STATUS="FAIL"
  FAILS=$((FAILS+1))
fi

# clone-vs-remote axis (only with --online)
if [ "$ONLINE" -eq 1 ]; then
  if git -C "$METHODOLOGY_PATH" ls-remote origin refs/heads/main >/dev/null 2>&1; then
    _remote_sha=$(git -C "$METHODOLOGY_PATH" ls-remote origin refs/heads/main 2>/dev/null | cut -f1)
    _local_sha=$(git -C "$METHODOLOGY_PATH" rev-parse refs/remotes/origin/main 2>/dev/null || echo "")
    if [ -z "$_remote_sha" ]; then
      VER_UPSTREAM="unverified (empty response from ls-remote)"
    elif [ -z "$_local_sha" ]; then
      VER_UPSTREAM="unverified (cannot read local remote ref)"
    elif [ "$_remote_sha" = "$_local_sha" ]; then
      VER_UPSTREAM="matches clone (up-to-date)"
    else
      VER_UPSTREAM="upstream ahead of clone — run: git -C $METHODOLOGY_PATH pull"
    fi
  else
    VER_UPSTREAM="unverified (ls-remote failed — auth or offline)"
  fi
fi

# ---------------------------------------------------------------------------
# Section 2: hooks liveness (mirror of sync-methodology.sh:690-692)
# Зеркало — менять синхронно при изменении паттерна в sync-methodology.sh
# ---------------------------------------------------------------------------
_settings=".claude/settings.json"
if [ -f "$_settings" ]; then
  _hook_names=$(
    {
      grep -oE '\.claude/hooks/[A-Za-z0-9_.-]+\.py' "$_settings" 2>/dev/null \
        | sed 's#\.claude/hooks/##'
      grep -oE '\.claude/hooks/[A-Za-z0-9_.-]+\.sh' "$_settings" 2>/dev/null \
        | sed 's#\.claude/hooks/##'
      grep -oE 'run-hook\.sh [A-Za-z0-9_.-]+\.py' "$_settings" 2>/dev/null \
        | sed 's#run-hook\.sh ##'
    } | sort -u
  )
  HOOKS_STATUS="PASS"
  for _h in $_hook_names; do
    [ -z "$_h" ] && continue
    if [ ! -f ".claude/hooks/$_h" ]; then
      HOOKS_MISSING="$HOOKS_MISSING $_h"
      HOOKS_STATUS="FAIL"
    fi
  done
  if [ "$HOOKS_STATUS" = "FAIL" ]; then
    FAILS=$((FAILS+1))
  fi
  if [ -z "$PYTHON" ]; then
    HOOKS_STATUS="${HOOKS_STATUS}+FAIL(python missing — hooks cannot run)"
    FAILS=$((FAILS+1))
  fi
else
  HOOKS_STATUS="N/A (no .claude/settings.json)"
fi

# ---------------------------------------------------------------------------
# Section 3: secrets
# ---------------------------------------------------------------------------
if [ -f ".claude/secrets-manifest.yaml" ]; then
  if [ -f "scripts/validate-secrets.sh" ]; then
    if bash scripts/validate-secrets.sh >/dev/null 2>&1; then
      SECRETS_STATUS="PASS"
    else
      SECRETS_STATUS="FAIL"
      FAILS=$((FAILS+1))
    fi
  else
    SECRETS_STATUS="WARN (manifest present but validate-secrets.sh not found)"
  fi
else
  SECRETS_STATUS="N/A (no manifest — ни одной декларации)"
fi

# ---------------------------------------------------------------------------
# Section 4: runtime deps
# ---------------------------------------------------------------------------
if [ -n "$PYTHON" ]; then
  _py_major=$(echo "$PY_VER" | cut -d. -f1 | tr -cd '0-9')
  _py_minor=$(echo "$PY_VER" | cut -d. -f2 | tr -cd '0-9')
  if [ -n "$_py_major" ] && [ -n "$_py_minor" ] \
      && [ "$_py_major" -ge 3 ] 2>/dev/null \
      && [ "$_py_minor" -ge 10 ] 2>/dev/null; then
    DEPS_PY="Python $PY_VER [PASS]"
  else
    DEPS_PY="Python $PY_VER [FAIL — need ≥3.10, hooks require it]"
    DEPS_STATUS="FAIL"
    FAILS=$((FAILS+1))
  fi
else
  DEPS_PY="not found [FAIL — hooks require Python 3.10+]"
  DEPS_STATUS="FAIL"
  FAILS=$((FAILS+1))
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    DEPS_GH="gh auth: ok [PASS]"
  else
    DEPS_GH="gh auth: not logged in [WARN — push via credential helper possible]"
  fi
else
  DEPS_GH="gh: not found [WARN — push via credential helper possible]"
fi

[ "$DEPS_STATUS" = "FAIL" ] || DEPS_STATUS="PASS"

# ---------------------------------------------------------------------------
# Section 5: dev-checks (gated — info only, does not affect exit)
# ---------------------------------------------------------------------------
_is_dev=0
if [ -f "services-registry.yaml" ]; then
  _is_dev=1
elif [ -f "CLAUDE.local.md" ]; then
  if grep -qE 'domain:[[:space:]]*(dev|backend|frontend|fullstack|api)' CLAUDE.local.md 2>/dev/null; then
    _is_dev=1
  fi
fi

if [ "$_is_dev" -eq 1 ]; then
  _dev_found=""
  for _cfg in services-registry.yaml pyproject.toml setup.cfg Makefile; do
    [ -f "$_cfg" ] && _dev_found="${_dev_found} $_cfg"
  done
  DEV_STATUS="INFO (dev profile${_dev_found:+ — found:$_dev_found})"
else
  DEV_STATUS="N/A (non-dev workspace)"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [ "$JSON_MODE" -eq 1 ]; then
  if [ -z "$PYTHON" ]; then
    echo '{"error":"Python not found — cannot produce JSON output"}' >&2
    exit 2
  fi
  _healthy="true"
  [ "$FAILS" -gt 0 ] && _healthy="false"
  _missing_list=$(echo "$HOOKS_MISSING" | tr ' ' '\n' | grep -v '^$' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')
  [ -z "$_missing_list" ] && _missing_list=""
  "$PYTHON" - <<PYEOF
import json, sys
data = {
  "healthy": $_healthy,
  "version": {
    "consumer": "$VER_CONSUMER",
    "clone": "$VER_CLONE",
    "delta": "$VER_DELTA",
    "upstream": "$VER_UPSTREAM",
    "status": "$VER_STATUS"
  },
  "hooks": {
    "status": "$HOOKS_STATUS",
    "missing": [x for x in "$HOOKS_MISSING".split() if x]
  },
  "secrets": {"status": "$SECRETS_STATUS"},
  "deps": {
    "python": "$DEPS_PY",
    "gh_auth": "$DEPS_GH",
    "status": "$DEPS_STATUS"
  },
  "dev_checks": {"status": "$DEV_STATUS"}
}
print(json.dumps(data, indent=2, ensure_ascii=False))
sys.exit(0 if data["healthy"] else 1)
PYEOF
  exit $?
fi

# Human-readable
echo "=== sync-doctor — install health snapshot ==="
echo ""
echo "version:"
echo "  consumer-vs-clone: consumer=$VER_CONSUMER  clone=$VER_CLONE  →  $VER_DELTA  [$VER_STATUS]"
echo "  clone-vs-upstream: $VER_UPSTREAM"
echo ""
echo "hooks:"
if [ "$HOOKS_STATUS" = "PASS" ]; then
  echo "  all hooks present  [PASS]"
elif echo "$HOOKS_STATUS" | grep -q "FAIL"; then
  echo "  [FAIL] MISSING:$HOOKS_MISSING"
else
  echo "  $HOOKS_STATUS"
fi
echo ""
echo "secrets:  $SECRETS_STATUS"
echo ""
echo "deps:"
echo "  $DEPS_PY"
echo "  $DEPS_GH"
echo "  status: $DEPS_STATUS"
echo ""
echo "dev-checks:  $DEV_STATUS"
echo ""

if [ "$FAILS" -gt 0 ]; then
  echo "=== HEALTH: FAIL ($FAILS issue(s)) ==="
  echo "→ для починки: запусти полный /sync-audit (применяет фиксы и обновляет state)"
  echo "→ для clone-vs-remote оси: bash scripts/sync-doctor.sh --online"
  exit 1
else
  echo "=== HEALTH: PASS — install выглядит здоровым ==="
  if [ "$VER_UPSTREAM" = "not checked (offline)" ]; then
    echo "ℹ  upstream не проверен (offline snapshot) — для полной проверки: /sync-audit или --online"
  fi
  exit 0
fi
