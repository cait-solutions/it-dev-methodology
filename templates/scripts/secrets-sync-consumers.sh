#!/usr/bin/env bash
#
# secrets-sync-consumers.sh — Copy sharing_type:shared-service secrets from this
# project's .env to all local consumer repos declared in CLAUDE.local.md.
#
# WHY: Developers with multiple consumer repos on one machine should not need
# to enter the same shared-service credential (VPS password, shared API key)
# in every repo. Identity secrets (GitHub PAT, personal tokens) are explicitly
# excluded — each developer must create their own via how_to_obtain.
#
# Usage:
#   bash scripts/secrets-sync-consumers.sh              # interactive sync
#   bash scripts/secrets-sync-consumers.sh --dry-run    # show what would change
#
# Security model:
#   - LOCAL ONLY. No git, no remote, no network.
#   - Reads from: SOURCE_REPO/.env + ~/.config/it-dev/secrets.env (shared scope)
#   - Writes to: CONSUMER/.env (gitignored in each consumer)
#   - Creates backup: CONSUMER/.env.backup-sync-{timestamp} before any write
#   - identity secrets: never copied, hard skip with explicit warning
#
# Bash 3.2+ compatible (no ${var,,}, no associative arrays).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SOURCE_DIR = the repo whose .env + CLAUDE.local.md drive the sync.
# Default = current working directory (run from the repo that holds the real
# secrets + consumers_root — e.g. the documentation repo), NOT the script's
# location (scripts/ is sync-owned and physically lives in the code repo).
SOURCE_DIR="$(pwd)"
DRY_RUN=false

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: bash scripts/secrets-sync-consumers.sh [--dry-run]"
      echo ""
      echo "Copies sharing_type:shared-service secrets from this project's .env"
      echo "to all local consumer repos listed in CLAUDE.local.md."
      echo ""
      echo "  --dry-run   Show what would be copied without making changes."
      echo ""
      echo "Identity secrets (GitHub PAT, personal tokens) are NEVER copied."
      echo "Each developer must create those via how_to_obtain instructions."
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate source manifest
# ---------------------------------------------------------------------------
SOURCE_MANIFEST="$SOURCE_DIR/.claude/secrets-manifest.yaml"
if [ ! -f "$SOURCE_MANIFEST" ]; then
  echo "ERROR: .claude/secrets-manifest.yaml not found in $SOURCE_DIR" >&2
  echo "   Run from the root of a project that has secrets-manifest.yaml." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse consumers_root from CLAUDE.local.md
# ---------------------------------------------------------------------------
CLAUDE_LOCAL="$SOURCE_DIR/CLAUDE.local.md"
if [ ! -f "$CLAUDE_LOCAL" ]; then
  echo "ERROR: CLAUDE.local.md not found in $SOURCE_DIR" >&2
  exit 1
fi

CONSUMERS_ROOT=""
in_consumers_section=false
while IFS= read -r line; do
  if echo "$line" | grep -q "^## Consumers"; then
    in_consumers_section=true
  fi
  if $in_consumers_section; then
    if echo "$line" | grep -q "consumers_root:"; then
      # Strip key, trailing inline comment (# ...), quotes, and surrounding whitespace.
      CONSUMERS_ROOT=$(echo "$line" \
        | sed 's/.*consumers_root:[[:space:]]*//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
        | tr -d '"')
      break
    fi
    if echo "$line" | grep -qE "^## [^C]"; then
      break
    fi
  fi
done < "$CLAUDE_LOCAL"

if [ -z "$CONSUMERS_ROOT" ]; then
  echo "ERROR: consumers_root not found in CLAUDE.local.md ## Consumers" >&2
  exit 1
fi

CONSUMERS_ROOT="${CONSUMERS_ROOT/#\~/$HOME}"

# Resolve relative consumers_root against the CLAUDE.local.md directory (not cwd).
case "$CONSUMERS_ROOT" in
  /*|[A-Za-z]:[\\/]*) : ;;  # already absolute (POSIX or Windows drive path)
  *)
    CONSUMERS_ROOT="$(cd "$SOURCE_DIR/$CONSUMERS_ROOT" 2>/dev/null && pwd)" \
      || { echo "ERROR: cannot resolve relative consumers_root from $SOURCE_DIR" >&2; exit 1; }
    ;;
esac

if [ ! -d "$CONSUMERS_ROOT" ]; then
  echo "ERROR: consumers_root directory not found: $CONSUMERS_ROOT" >&2
  exit 1
fi

echo "Source:          $SOURCE_DIR"
echo "Consumers root:  $CONSUMERS_ROOT"
if $DRY_RUN; then
  echo "Mode:            DRY RUN (no changes will be made)"
fi
echo ""

# ---------------------------------------------------------------------------
# Collect keys by sharing_type from a manifest
# ---------------------------------------------------------------------------
collect_keys_by_sharing_type() {
  local manifest="$1"
  local want_type="$2"   # "shared-service" or "identity"
  local current_key=""
  local sharing_type_val="identity"  # default: identity (safe — never sync by default)
  local in_secrets=false

  while IFS= read -r line; do
    if echo "$line" | grep -q "^secrets:"; then
      in_secrets=true; continue
    fi
    if ! $in_secrets; then continue; fi

    if echo "$line" | grep -qE "^[[:space:]]*-[[:space:]]*key:"; then
      if [ -n "$current_key" ] && [ "$sharing_type_val" = "$want_type" ]; then
        echo "$current_key"
      fi
      current_key=$(echo "$line" | sed 's/.*key:[[:space:]]*//' | tr -d ' ')
      sharing_type_val="identity"
    fi
    if echo "$line" | grep -q "sharing_type:"; then
      sharing_type_val=$(echo "$line" | sed 's/.*sharing_type:[[:space:]]*//' | tr -d ' ')
    fi
  done < "$manifest"

  if [ -n "$current_key" ] && [ "$sharing_type_val" = "$want_type" ]; then
    echo "$current_key"
  fi
}

# ---------------------------------------------------------------------------
# Read a key's value from .env file
# ---------------------------------------------------------------------------
read_env_value() {
  local key="$1"
  local env_file="$2"
  if [ ! -f "$env_file" ]; then echo ""; return; fi
  grep -E "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2- || echo ""
}

# ---------------------------------------------------------------------------
# Mask a value for display (first 4 + last 4 chars)
# ---------------------------------------------------------------------------
mask_value() {
  local val="$1"
  local len=${#val}
  if [ "$len" -le 8 ]; then
    printf '%s' "****"
  else
    printf '%s' "${val:0:4}****${val: -4}"
  fi
}

# ---------------------------------------------------------------------------
# Gather source values
# ---------------------------------------------------------------------------
SOURCE_ENV="$SOURCE_DIR/.env"
SHARED_ENV="$HOME/.config/it-dev/secrets.env"

SHARED_KEYS=()
while IFS= read -r k; do
  [ -n "$k" ] && SHARED_KEYS+=("$k")
done < <(collect_keys_by_sharing_type "$SOURCE_MANIFEST" "shared-service")

IDENTITY_KEYS=()
while IFS= read -r k; do
  [ -n "$k" ] && IDENTITY_KEYS+=("$k")
done < <(collect_keys_by_sharing_type "$SOURCE_MANIFEST" "identity")

if [ ${#SHARED_KEYS[@]} -eq 0 ]; then
  echo "INFO: No sharing_type:shared-service keys found in source manifest."
  echo "   To mark a secret as syncable, add  sharing_type: shared-service  to its manifest entry."
  exit 0
fi

echo "Keys eligible for sync (sharing_type:shared-service):"
for k in "${SHARED_KEYS[@]}"; do
  src_val=$(read_env_value "$k" "$SOURCE_ENV")
  if [ -z "$src_val" ] && [ -f "$SHARED_ENV" ]; then
    src_val=$(read_env_value "$k" "$SHARED_ENV")
  fi
  if [ -n "$src_val" ]; then
    echo "  [OK]   $k = $(mask_value "$src_val")"
  else
    echo "  [MISS] $k — not set in source (will skip)"
  fi
done

if [ ${#IDENTITY_KEYS[@]} -gt 0 ]; then
  echo ""
  echo "Identity secrets (never synced — each developer creates their own):"
  for k in "${IDENTITY_KEYS[@]}"; do
    echo "  [SKIP] $k"
  done
fi
echo ""

# ---------------------------------------------------------------------------
# Find consumer repos
# ---------------------------------------------------------------------------
CONSUMER_REPOS=()
for d in "$CONSUMERS_ROOT"/*/; do
  [ -d "$d" ] || continue
  if [ -f "${d}.claude/secrets-manifest.yaml" ]; then
    real_d="$(cd "$d" && pwd)"
    real_src="$(cd "$SOURCE_DIR" && pwd)"
    if [ "$real_d" != "$real_src" ]; then
      CONSUMER_REPOS+=("$d")
    fi
  fi
done

if [ ${#CONSUMER_REPOS[@]} -eq 0 ]; then
  echo "INFO: No consumer repos found in $CONSUMERS_ROOT"
  echo "   (looking for directories with .claude/secrets-manifest.yaml)"
  exit 0
fi

echo "Found ${#CONSUMER_REPOS[@]} consumer repo(s)."
echo ""

# ---------------------------------------------------------------------------
# Sync loop
# ---------------------------------------------------------------------------
TOTAL_WRITTEN=0
TOTAL_SKIPPED=0

for consumer in "${CONSUMER_REPOS[@]}"; do
  consumer_name="$(basename "$consumer")"
  consumer_manifest="${consumer}.claude/secrets-manifest.yaml"
  consumer_env="${consumer}.env"

  echo "--- $consumer_name ---"

  backup_created=false

  for key in "${SHARED_KEYS[@]}"; do
    # Read source value: per-project .env first, then shared scope
    src_val=$(read_env_value "$key" "$SOURCE_ENV")
    if [ -z "$src_val" ] && [ -f "$SHARED_ENV" ]; then
      src_val=$(read_env_value "$key" "$SHARED_ENV")
    fi

    if [ -z "$src_val" ]; then
      echo "  [SKIP] $key — not set in source"
      TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
      continue
    fi

    # Check if consumer manifest declares this exact key
    if ! grep -q "key: $key" "$consumer_manifest" 2>/dev/null; then
      # Fuzzy: look for keys with same prefix (e.g. GITHUB_* vs GITHUB_IDK_*)
      prefix=$(echo "$key" | sed 's/_[A-Z0-9]*$//')
      similar=$(grep "key:" "$consumer_manifest" 2>/dev/null | grep -i "$prefix" | head -3 | \
                sed 's/.*key:[[:space:]]*//' | tr -d ' ' | tr '\n' ' ')
      if [ -n "$similar" ]; then
        echo "  [WARN] $key — not in consumer manifest"
        echo "         Similar keys: $similar"
        printf "         Include anyway? (y/n) [n]: "
        if ! $DRY_RUN; then
          read -r user_choice </dev/tty || user_choice="n"
        else
          user_choice="n"
          echo "(dry-run)"
        fi
        case "$user_choice" in
          y|Y) : ;;
          *) echo "  [SKIP] skipped."; TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1)); continue ;;
        esac
      else
        echo "  [INFO] $key — not in consumer manifest, skipping"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
      fi
    fi

    # Conflict check: consumer already has this key
    existing_val=$(read_env_value "$key" "$consumer_env")
    if [ -n "$existing_val" ]; then
      if [ "$existing_val" = "$src_val" ]; then
        echo "  [OK]   $key — already up to date"
        continue
      fi
      echo "  [DIFF] $key — conflict:"
      echo "         current: $(mask_value "$existing_val")"
      echo "         source:  $(mask_value "$src_val")"
      printf "         Override? (y/n) [n]: "
      if ! $DRY_RUN; then
        read -r user_choice </dev/tty || user_choice="n"
      else
        user_choice="n"
        echo "(dry-run: would ask)"
      fi
      if [ "$user_choice" != "y" ] && [ "$user_choice" != "Y" ]; then
        echo "  [KEEP] kept existing."
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
      fi
    fi

    if $DRY_RUN; then
      echo "  [DRY]  would write $key"
      continue
    fi

    # Backup before first write to this consumer
    if ! $backup_created; then
      ts=$(date +%Y%m%d-%H%M%S 2>/dev/null || date +%s)
      if [ -f "$consumer_env" ]; then
        cp "$consumer_env" "${consumer_env}.backup-sync-${ts}"
        echo "  [BAK]  .env.backup-sync-${ts}"
      fi
      backup_created=true
    fi

    # Write: replace existing line or append
    if [ -f "$consumer_env" ] && grep -q "^${key}=" "$consumer_env"; then
      tmp="${consumer_env}.tmp$$"
      sed "s|^${key}=.*|${key}=${src_val}|" "$consumer_env" > "$tmp" && mv "$tmp" "$consumer_env"
    else
      printf '%s=%s\n' "$key" "$src_val" >> "$consumer_env"
    fi
    echo "  [DONE] $key — written"
    TOTAL_WRITTEN=$((TOTAL_WRITTEN + 1))
  done
  echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
if $DRY_RUN; then
  echo "  Dry run — no changes made"
else
  echo "  Written: $TOTAL_WRITTEN  |  Skipped: $TOTAL_SKIPPED"
fi
echo ""
echo "  Identity secrets were NOT synced (by design)."
echo "  Each developer creates those via: bash scripts/secrets-show.sh KEY"
