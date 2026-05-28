#!/usr/bin/env bash
#
# set-secret.sh — atomically add/update a secret in .env or shared store.
#
# Usage:
#   bash scripts/set-secret.sh KEY value                  # writes to ./.env
#   bash scripts/set-secret.sh --shared KEY value         # writes to ~/.config/it-dev/secrets.env
#
# Atomicity: writes to .env.tmp.$$ then mv → final path (POSIX-atomic).
# Concurrency: flock if available, falls back to mkdir-based lock.
# Permissions: sets chmod 600 on target after first write.
#
# IMPORTANT: This is the ONLY supported way agents should write secrets.
# Do NOT echo a value into .env via the agent (the value would land in
# the agent's tool input string → transcript → Anthropic API → leak).
# Instead: tell the user to run this script themselves, ONE-TIME.
#
# Exit codes:
#   0 — success
#   1 — value validation failed (e.g. token_pattern in manifest mismatch)
#   2 — usage error
#   3 — write / permission error
#   4 — high-sensitivity key blocked from --shared scope

set -euo pipefail

SHARED_ENV="${HOME}/.config/it-dev/secrets.env"
MANIFEST=".claude/secrets-manifest.yaml"

usage() {
  echo "Usage:" >&2
  echo "  bash scripts/set-secret.sh KEY value             # per-project .env" >&2
  echo "  bash scripts/set-secret.sh --shared KEY value    # ~/.config/it-dev/secrets.env" >&2
  echo "" >&2
  echo "After setting, agents in any session will use this value automatically." >&2
  exit 2
}

SCOPE="project"
if [[ "${1:-}" == "--shared" ]]; then
  SCOPE="shared"
  shift
fi

if [[ $# -ne 2 ]]; then
  usage
fi

KEY="$1"
VALUE="$2"

# Validate KEY shape (UPPER_SNAKE_CASE).
if ! [[ "$KEY" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
  echo "ERROR: key must be UPPER_SNAKE_CASE (matched [A-Z][A-Z0-9_]*): $KEY" >&2
  exit 2
fi

# Reject obviously empty values.
if [[ -z "$VALUE" ]]; then
  echo "ERROR: refusing to set empty value for $KEY" >&2
  exit 1
fi

# Honor manifest sensitivity: high → reject --shared.
if [[ "$SCOPE" == "shared" && -f "$MANIFEST" ]]; then
  sensitivity=$(awk -v k="$KEY" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*sensitivity:/ {
      sub(/^[[:space:]]*sensitivity:[[:space:]]*/, "")
      gsub(/[[:space:]"'"'"']/, "")
      print
      exit
    }
  ' "$MANIFEST")
  if [[ "$sensitivity" == "high" ]]; then
    echo "BLOCKED: $KEY is marked sensitivity:high in manifest → cannot be stored in --shared scope." >&2
    echo "Use per-project .env instead: bash scripts/set-secret.sh $KEY <value>" >&2
    exit 4
  fi
fi

# Honor manifest token_pattern if defined.
if [[ -f "$MANIFEST" ]]; then
  pattern=$(awk -v k="$KEY" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*token_pattern:/ {
      sub(/^[[:space:]]*token_pattern:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$MANIFEST")
  if [[ -n "${pattern:-}" && "$pattern" != "null" ]]; then
    if ! echo "$VALUE" | grep -Eq "$pattern"; then
      echo "WARNING: value for $KEY does not match expected token_pattern: $pattern" >&2
      echo "         (proceeding anyway — manifest pattern may be too strict)" >&2
    fi
  fi
fi

if [[ "$SCOPE" == "shared" ]]; then
  TARGET="$SHARED_ENV"
  mkdir -p "$(dirname "$TARGET")"
  chmod 700 "$(dirname "$TARGET")" 2>/dev/null || true
else
  TARGET=".env"
  # If .env missing but .env.example exists, do NOT auto-copy
  # (.env.example may contain comments user wants to keep verbatim).
  # Just create an empty file.
  [[ -f "$TARGET" ]] || touch "$TARGET"
fi

LOCK="${TARGET}.lock"
TMP="${TARGET}.tmp.$$"

# Acquire lock — flock if available, mkdir fallback.
_acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 200>"$LOCK"
    flock -x -w 5 200 || { echo "ERROR: could not acquire lock on $LOCK after 5s" >&2; return 3; }
  else
    local tries=0
    while ! mkdir "$LOCK" 2>/dev/null; do
      tries=$((tries+1))
      [[ $tries -gt 50 ]] && { echo "ERROR: lock $LOCK busy after 5s" >&2; return 3; }
      sleep 0.1
    done
    trap "rmdir '$LOCK' 2>/dev/null || true" EXIT
  fi
}

_acquire_lock

# Compose new file content: replace line if KEY= exists, else append.
if [[ -f "$TARGET" ]] && grep -qE "^${KEY}=" "$TARGET"; then
  # Replace existing line. Use awk to avoid sed delimiter conflicts with value.
  awk -v key="$KEY" -v val="$VALUE" '
    BEGIN { replaced=0 }
    $0 ~ "^" key "=" {
      if (val ~ /[[:space:]"'"'"'#]/) {
        printf "%s=\"%s\"\n", key, val
      } else {
        printf "%s=%s\n", key, val
      }
      replaced=1
      next
    }
    { print }
  ' "$TARGET" > "$TMP"
else
  # Append.
  if [[ -f "$TARGET" ]]; then
    cp "$TARGET" "$TMP"
  else
    : > "$TMP"
  fi
  if [[ "$VALUE" =~ [[:space:]\"\'#] ]]; then
    printf '%s="%s"\n' "$KEY" "$VALUE" >> "$TMP"
  else
    printf '%s=%s\n' "$KEY" "$VALUE" >> "$TMP"
  fi
fi

mv "$TMP" "$TARGET"
chmod 600 "$TARGET" 2>/dev/null || true

# Verify chmod actually took effect (closes G-016 — Windows NTFS doesn't enforce
# POSIX permissions by default, so chmod 600 may be silently ignored).
# Warn once per session, not per key — use marker in $TMPDIR.
_marker="${TMPDIR:-/tmp}/.set-secret-chmod-warned-$$"
if [[ ! -f "$_marker" ]]; then
  _actual=$(stat -c '%a' "$TARGET" 2>/dev/null || stat -f '%Lp' "$TARGET" 2>/dev/null || echo "")
  if [[ -n "$_actual" && "$_actual" != "600" && "$_actual" != "400" ]]; then
    echo "" >&2
    echo "⚠️  chmod 600 requested but actual permissions: $_actual" >&2
    echo "    (likely Windows NTFS — POSIX permissions not enforced through filesystem)" >&2
    echo "    File is readable by other local users." >&2
    echo "    On shared Windows workstation, restrict via PowerShell:" >&2
    echo "      icacls \"$TARGET\" /inheritance:r /grant:r \"%USERNAME%:F\"" >&2
    echo "    On single-user dev machine: trusted OS boundary, no action needed." >&2
    echo "    (This warning shown once per session.)" >&2
    : > "$_marker" 2>/dev/null || true
  fi
fi

# Release lock (only matters for mkdir fallback path).
if [[ -d "$LOCK" ]]; then
  rmdir "$LOCK" 2>/dev/null || true
fi

echo "✅ Set $KEY in $TARGET (scope: $SCOPE)" >&2
echo "   Verify: bash scripts/check-secret.sh $KEY" >&2
