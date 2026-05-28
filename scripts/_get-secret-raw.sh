#!/usr/bin/env bash
#
# _get-secret-raw.sh — ESCAPE HATCH: read secret value to stdout.
#
# ⛔ AGENT MUST NOT CALL THIS WITHOUT --explicit-stdout FLAG.
#
# This is a forcing function. By default the script exits with an instructive
# error pointing to with-secret.sh (injection pattern). Only with the explicit
# flag does it actually output the value — and at that point you've taken
# responsibility for ensuring the value doesn't end up in transcripts/logs.
#
# Legitimate use cases (rare):
#   - Manual debugging by a human running the script directly in terminal.
#   - Scripts that genuinely need raw value AND can guarantee no logging
#     (e.g. piping into another tool that doesn't echo).
#
# Usage:
#   bash scripts/_get-secret-raw.sh KEY                    # error + instructions
#   bash scripts/_get-secret-raw.sh KEY --explicit-stdout  # outputs value
#
# Exit codes:
#   0  value printed (only with --explicit-stdout)
#   1  missing secret
#   2  missing required flag (the default — forcing function)
#   3  usage error

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/_get-secret-raw.sh KEY [--explicit-stdout]" >&2
  exit 3
fi

KEY="$1"
EXPLICIT=false
if [[ "${2:-}" == "--explicit-stdout" ]]; then
  EXPLICIT=true
fi

if ! $EXPLICIT; then
  echo "BLOCKED: refusing to print secret value to stdout by default." >&2
  echo "" >&2
  echo "  This is a safety forcing function — values printed to stdout end up" >&2
  echo "  in transcripts (~/.claude/projects/*.jsonl) and may be sent to the" >&2
  echo "  Anthropic API as part of conversation context, where they cannot be" >&2
  echo "  recalled. Use injection instead:" >&2
  echo "" >&2
  echo "    bash scripts/with-secret.sh $KEY -- <your-command>" >&2
  echo "" >&2
  echo "  If you absolutely need raw value (e.g. manual paste into terminal" >&2
  echo "  app that does NOT log), add the flag:" >&2
  echo "" >&2
  echo "    bash scripts/_get-secret-raw.sh $KEY --explicit-stdout" >&2
  echo "" >&2
  echo "  Doing so is YOUR responsibility — agents should never use this flag." >&2
  exit 2
fi

# At this point user explicitly opted in. Resolve and print.
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"
MANIFEST=".claude/secrets-manifest.yaml"
if [[ -f "$MANIFEST" ]]; then
  custom=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
           | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
           | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  [[ -n "${custom:-}" ]] && SHARED_ENV="${custom/#\~/$HOME}"
fi

_lookup() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local line
  line=$(grep -E "^${KEY}=" "$file" 2>/dev/null | head -1)
  [[ -z "$line" ]] && return 1
  local value="${line#${KEY}=}"
  value=$(echo "$value" | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  [[ -z "$value" ]] && return 1
  printf '%s' "$value"
  return 0
}

if value=$(_lookup ".env"); then
  printf '%s\n' "$value"
  exit 0
fi
if value=$(_lookup "$SHARED_ENV"); then
  printf '%s\n' "$value"
  exit 0
fi
if [[ -n "${!KEY:-}" ]]; then
  printf '%s\n' "${!KEY}"
  exit 0
fi

echo "MISSING_SECRET: $KEY" >&2
exit 1
