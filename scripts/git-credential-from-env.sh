#!/usr/bin/env bash
#
# git-credential-from-env.sh — git credential helper that reads GITHUB_PAT from .env.
#
# This lets `git push` / `git pull` over HTTPS authenticate WITHOUT the agent
# ever seeing the token value. Git itself talks to this helper directly.
#
# Setup (one-time per repo, or globally via ~/.gitconfig):
#
#   git config credential."https://github.com".helper \
#     "!bash $(pwd)/scripts/git-credential-from-env.sh"
#
# Or globally:
#
#   git config --global credential."https://github.com".helper \
#     "!bash <abs-path-to-methodology>/scripts/git-credential-from-env.sh"
#
# Once configured, all GitHub HTTPS operations transparently use GITHUB_PAT
# from .env / shared / process env (priority chain via with-secret.sh logic).
#
# Protocol (git credential helper spec):
#   git invokes us with one of: get | store | erase
#   stdin is a sequence of `key=value\n` lines; blank line terminates.
#   For `get`, we print `username=...\npassword=...\n\n` on stdout.

set -euo pipefail

ACTION="${1:-}"

# We only handle `get`. `store` and `erase` are no-ops (we don't cache).
if [[ "$ACTION" != "get" ]]; then
  exit 0
fi

# Read input (we don't actually need it — we always supply GITHUB_PAT for github.com).
# But we must consume stdin or git may hang on some versions.
while IFS= read -r line; do
  [[ -z "$line" ]] && break
done

# Source the secret via with-secret.sh's lookup logic, but inline (we can't
# call with-secret.sh here because it expects -- separator + a real command).
# Reimplement minimal lookup:

SHARED_ENV="${HOME}/.config/it-dev/secrets.env"
MANIFEST=".claude/secrets-manifest.yaml"
if [[ -f "$MANIFEST" ]]; then
  custom=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
           | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
           | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  [[ -n "${custom:-}" ]] && SHARED_ENV="${custom/#\~/$HOME}"
fi

KEY="GITHUB_PAT"
TOKEN=""

if [[ -f ".env" ]]; then
  TOKEN=$(grep -E "^${KEY}=" ".env" 2>/dev/null | head -1 \
          | sed -E "s/^${KEY}=//" \
          | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
fi
if [[ -z "$TOKEN" && -f "$SHARED_ENV" ]]; then
  TOKEN=$(grep -E "^${KEY}=" "$SHARED_ENV" 2>/dev/null | head -1 \
          | sed -E "s/^${KEY}=//" \
          | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
fi
if [[ -z "$TOKEN" ]]; then
  TOKEN="${GITHUB_PAT:-}"
fi

if [[ -z "$TOKEN" ]]; then
  # Silently exit — git will fall back to other helpers (gh, manager, etc).
  # Don't print anything (stdout goes to git, stderr would alarm user).
  exit 0
fi

# Username can be anything when using a PAT as password for GitHub.
printf 'username=oauth2\n'
printf 'password=%s\n' "$TOKEN"
printf '\n'
