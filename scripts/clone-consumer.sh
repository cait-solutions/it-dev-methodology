#!/usr/bin/env bash
#
# clone-consumer.sh — clone a consumer repo using credential helper, never
# putting token in URL or shell history.
#
# Reads consumer config from consumers/<name>.yaml (repo URL, target path).
#
# Usage:
#   bash scripts/clone-consumer.sh <consumer-name>
#
# Example:
#   bash scripts/clone-consumer.sh erp-documentation
#
# Approach: configure local git credential helper for the host, then run
# `git clone <https-url> <target>`. Git itself calls the helper for the token —
# the agent never sees it.
#
# Exit codes:
#   0  cloned successfully
#   1  consumer config missing or malformed
#   2  usage error
#   3  git clone failed

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/clone-consumer.sh <consumer-name>" >&2
  echo "" >&2
  echo "Available consumers:" >&2
  if [[ -d "consumers" ]]; then
    ls consumers/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/\.yaml$//' | sed 's/^/  /' >&2
  fi
  exit 2
fi

NAME="$1"
CFG="consumers/${NAME}.yaml"

if [[ ! -f "$CFG" ]]; then
  echo "ERROR: consumer config not found: $CFG" >&2
  exit 1
fi

# Parse minimal YAML fields (repo, local_path).
REPO=$(grep -E "^repo:" "$CFG" | head -1 | sed 's/^repo:[[:space:]]*//' | tr -d '"'"'"'' | tr -d '[:space:]')
LOCAL_PATH=$(grep -E "^local_path:" "$CFG" | head -1 | sed 's/^local_path:[[:space:]]*//' | tr -d '"'"'"'' | tr -d '[:space:]')

if [[ -z "$REPO" || -z "$LOCAL_PATH" ]]; then
  echo "ERROR: $CFG missing required fields (repo, local_path)" >&2
  exit 1
fi

if [[ -d "$LOCAL_PATH/.git" ]]; then
  echo "Consumer already cloned at: $LOCAL_PATH"
  echo "To update: cd $LOCAL_PATH && git pull"
  exit 0
fi

# Extract host (e.g. github.com, code.nexchance.de) for credential helper config.
HOST=$(echo "$REPO" | sed -E 's|https?://([^/]+).*|\1|')

if [[ -z "$HOST" ]]; then
  echo "ERROR: cannot derive host from repo URL: $REPO" >&2
  exit 1
fi

# Configure credential helper for this host using methodology's helper script.
HELPER_PATH="$(pwd)/scripts/git-credential-from-env.sh"
if [[ ! -f "$HELPER_PATH" ]]; then
  echo "ERROR: credential helper not found: $HELPER_PATH" >&2
  exit 1
fi

echo "Cloning $NAME"
echo "  repo:       $REPO"
echo "  local_path: $LOCAL_PATH"
echo "  host:       $HOST"
echo "  helper:     $HELPER_PATH"
echo ""

mkdir -p "$(dirname "$LOCAL_PATH")"

# Use a temporary credential helper config to avoid polluting user's global gitconfig.
# Git supports `-c` flag for one-shot config overrides.
git -c "credential.https://${HOST}.helper=!bash ${HELPER_PATH}" \
    clone "$REPO" "$LOCAL_PATH"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  echo "" >&2
  echo "git clone failed (exit $exit_code)." >&2
  echo "If the failure was 'Authentication failed':" >&2
  echo "  1. Ensure GITHUB_PAT (or applicable token) is set: bash scripts/check-secret.sh GITHUB_PAT" >&2
  echo "  2. If missing: bash scripts/set-secret.sh GITHUB_PAT <value>" >&2
  echo "  3. Re-run this script." >&2
  exit 3
fi

echo "✅ Cloned $NAME → $LOCAL_PATH"
echo "Next steps:"
echo "  cd $LOCAL_PATH"
echo "  # ... work on the consumer repo ..."
