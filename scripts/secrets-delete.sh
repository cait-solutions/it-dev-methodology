#!/usr/bin/env bash
#
# secrets-delete.sh — delete a secret from .env (and optionally from manifest).
#
# Usage:
#   bash scripts/secrets-delete.sh KEY                    # interactive confirm (also removes from manifest)
#   bash scripts/secrets-delete.sh KEY --yes              # skip confirm (CI/CD)
#   bash scripts/secrets-delete.sh KEY --keep-manifest    # delete from .env only, keep manifest entry
#
# Exit codes:
#   0  success
#   1  KEY not found in .env
#   2  usage error
#   5  user aborted

set -uo pipefail

MANIFEST=".claude/secrets-manifest.yaml"
TARGET=".env"

usage() {
  echo "Usage: bash scripts/secrets-delete.sh KEY [--yes] [--keep-manifest]" >&2
  echo "       Deletes KEY from .env AND manifest by default." >&2
  echo "       --keep-manifest  remove from .env only, keep manifest entry" >&2
  exit 2
}

if [[ $# -lt 1 ]]; then
  usage
fi

KEY="$1"
shift

SKIP_CONFIRM=false
FROM_MANIFEST=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)             SKIP_CONFIRM=true; shift ;;
    --keep-manifest)   FROM_MANIFEST=false; shift ;;
    --from-manifest)   FROM_MANIFEST=true; shift ;;  # backward compat
    --help|-h)         usage ;;
    *)                 echo "Unknown option: $1" >&2; usage ;;
  esac
done

if ! [[ "$KEY" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
  echo "ERROR: key must be UPPER_SNAKE_CASE: $KEY" >&2
  exit 2
fi

# Check KEY exists in .env
if [[ ! -f "$TARGET" ]] || ! grep -qE "^${KEY}=" "$TARGET"; then
  echo "ERROR: $KEY not found in $TARGET" >&2
  echo "       Available keys: $(awk -F= '/^[A-Z][A-Z0-9_]*=/{print $1}' "$TARGET" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Warn if KEY is required in manifest
if [[ -f "$MANIFEST" ]]; then
  req=$(awk -v k="$KEY" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*required:[[:space:]]*true/ { print "true"; exit }
  ' "$MANIFEST")
  if [[ "${req:-}" == "true" ]]; then
    echo "" >&2
    echo "WARNING: $KEY is marked required: true in secrets-manifest.yaml" >&2
    echo "    Deleting it will cause validate-secrets.sh to report MISSING." >&2
    echo "    Consider updating the manifest to required: false first." >&2
    echo "" >&2
  fi
fi

# Confirm
if ! $SKIP_CONFIRM; then
  if [[ -t 0 ]]; then
    printf "Delete %s from %s? (yes/no): " "$KEY" "$TARGET"
    read -r confirm
    if [[ "$confirm" != "yes" ]]; then
      echo "Aborted." >&2
      exit 5
    fi
  else
    echo "ERROR: non-interactive mode requires --yes flag" >&2
    exit 2
  fi
fi

# Backup + atomic delete
LOCK="${TARGET}.lock"
TMP="${TARGET}.tmp.$$"
ts=$(py -c "import datetime; print(datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))" 2>/dev/null || echo "$$")
BACKUP="${TARGET}.backup-${ts}"

_cleanup() {
  local code=$?
  [[ -f "$TMP" ]] && rm -f "$TMP" 2>/dev/null || true
  [[ -d "$LOCK" ]] && rmdir "$LOCK" 2>/dev/null || true
  exit $code
}
trap _cleanup INT TERM EXIT

# Lock
if command -v flock >/dev/null 2>&1; then
  exec 200>"$LOCK"
  flock -x -w 5 200 || { echo "ERROR: could not acquire lock" >&2; exit 3; }
else
  tries=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    tries=$((tries+1)); [[ $tries -gt 50 ]] && { echo "ERROR: lock busy" >&2; exit 3; }; sleep 0.1
  done
fi

# Backup
cp "$TARGET" "$BACKUP" 2>/dev/null || true

# Delete line (atomic via tmp + mv)
grep -vE "^${KEY}=" "$TARGET" > "$TMP"
mv "$TMP" "$TARGET"
chmod 600 "$TARGET" 2>/dev/null || true

# Release lock
trap - INT TERM EXIT
[[ -d "$LOCK" ]] && rmdir "$LOCK" 2>/dev/null || true

echo "" >&2
echo "Deleted $KEY from $TARGET" >&2
echo "   Backup: $BACKUP" >&2

# Optional: remove from manifest
if $FROM_MANIFEST && [[ -f "$MANIFEST" ]]; then
  MTMP="${MANIFEST}.tmp.$$"
  py - "$MANIFEST" "$MTMP" "$KEY" <<'PYEOF'
import sys, re
src, dst, key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, encoding='utf-8') as f:
    lines = f.readlines()
out = []
in_entry = False
key_re = re.compile(rf'^\s*-\s*key:\s*{re.escape(key)}\s*$')
next_key_re = re.compile(r'^\s*-\s*key:\s*')
i = 0
while i < len(lines):
    line = lines[i]
    if not in_entry and key_re.match(line):
        in_entry = True; i += 1; continue
    if in_entry and (next_key_re.match(line) or (line.strip() == '' and i+1 < len(lines) and next_key_re.match(lines[i+1]))):
        in_entry = False; out.append(line); i += 1; continue
    if in_entry:
        i += 1; continue
    out.append(line); i += 1
with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(out)
PYEOF
  if [[ -f "$MTMP" && -s "$MTMP" ]]; then
    mv "$MTMP" "$MANIFEST"
    echo "   Also removed entry from $MANIFEST" >&2
  fi
fi

echo "   To restore: bash scripts/secrets-rollback.sh $BACKUP" >&2
