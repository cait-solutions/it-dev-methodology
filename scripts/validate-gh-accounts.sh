#!/usr/bin/env bash
#
# validate-gh-accounts.sh — gate: gh_account обязателен для github.com repos в auto_commit_consumers.
#
# WHY (P-012, domain:git-push кластер v6.9.0):
#   gh_account в CLAUDE.local.md whitelist — OPTIONAL. Нет enforcement → агент забывал поле →
#   /push-consumers угадывал owner из remote URL (ненадёжно если URL неверный) → wrong account → 403.
#   Минимум 3 domain:git-push инцидента за 30 дней. Этот gate закрывает класс структурно:
#   deploy НЕВОЗМОЖЕН если любой github.com repo в whitelist не имеет явного gh_account.
#
# Вызывается из deploy-push.sh внутри methodology guard (closes methodology-only scope).
# Consumers guard=false → этот gate до них не доезжает.
#
# Exit 0 = все github.com repos имеют gh_account (или нет github.com repos).
# Exit 1 = gate failure: ≥1 repos missing gh_account → deploy blocked.
# Exit 2 = config error (CLAUDE.local.md не найден → skip gracefully, exit 0).
#
# Bash 3.2+ compatible (Git Bash on Windows): no associative arrays, no ${var,,}.

set -uo pipefail

CONFIG="${1:-CLAUDE.local.md}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHODOLOGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$CONFIG" ]; then
  echo "  ⚡ validate-gh-accounts: $CONFIG not found — skip." >&2
  exit 0
fi

# _parse_whitelist: outputs TSV lines "RELATIVE_PATH\tGH_ACCOUNT" for each entry.
# Parses the ```yaml auto_commit_consumers: block in CLAUDE.local.md.
# GH_ACCOUNT is empty string if the field is absent for an entry.
_parse_whitelist() {
  awk '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      if (entry_path != "") { print entry_path "\t" entry_gh }
      entry_path = $0
      sub(/^[^:]*:[[:space:]]*/, "", entry_path)
      sub(/[[:space:]]*#.*$/,     "", entry_path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", entry_path)
      entry_gh = ""
    }
    /^[[:space:]]+gh_account:/ {
      gh = $0
      sub(/^[^:]*:[[:space:]]*/, "", gh)
      sub(/[[:space:]]*#.*$/,     "", gh)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gh)
      entry_gh = gh
    }
    END { if (entry_path != "") print entry_path "\t" entry_gh }
  ' "$CONFIG"
}

FAILED=0
CHECKED=0

while IFS="	" read -r ENTRY_PATH ENTRY_GH; do
  [ -z "$ENTRY_PATH" ] && continue

  # Resolve path relative to methodology repo directory
  ABS_PATH=""
  if cd "$METHODOLOGY_DIR/$ENTRY_PATH" 2>/dev/null; then
    ABS_PATH="$(pwd)"
    cd - >/dev/null 2>&1
  else
    # Repo not present on this machine — skip silently
    continue
  fi

  # Check if this repo has a github.com HTTPS remote
  REMOTE_URL="$(git -C "$ABS_PATH" remote get-url origin 2>/dev/null || true)"
  case "$REMOTE_URL" in
    https://github.com/*) : ;;
    *) continue ;;   # GitLab / SSH / other → no gh CLI needed → skip
  esac

  CHECKED=$((CHECKED + 1))

  if [ -z "$ENTRY_GH" ]; then
    REPO_NAME="$(basename "$ABS_PATH")"
    OWNER="${REMOTE_URL#https://github.com/}"
    OWNER="${OWNER%%/*}"
    OWNER="${OWNER%.git}"
    printf "  ❌ MISSING gh_account: %s\n     path: %s\n     remote: %s\n     Добавь в CLAUDE.local.md → auto_commit_consumers:\n       gh_account: %s\n" \
      "$REPO_NAME" "$ENTRY_PATH" "$REMOTE_URL" "$OWNER" >&2
    FAILED=$((FAILED + 1))
  else
    echo "  ✅ gh_account: $ENTRY_GH → $(basename "$ABS_PATH")"
  fi

done < <(_parse_whitelist)

echo ""
if [ "$FAILED" -gt 0 ]; then
  echo "❌ validate-gh-accounts: $FAILED repo(s) missing gh_account (checked $CHECKED github.com repos)." >&2
  echo "   Заполни gh_account для каждого репо → затем повтори деплой." >&2
  exit 1
fi

if [ "$CHECKED" -eq 0 ]; then
  echo "  ℹ️  validate-gh-accounts: нет github.com repos в whitelist — OK."
else
  echo "✅ validate-gh-accounts: все $CHECKED github.com repo(s) имеют gh_account."
fi
exit 0
