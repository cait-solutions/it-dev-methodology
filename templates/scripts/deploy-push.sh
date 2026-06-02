#!/usr/bin/env bash
#
# deploy-push.sh — reads branching config from CLAUDE.local.md and runs the correct git push.
#
# Eliminates manual conditional logic for agents: run this script instead of writing
# git push commands directly. The script reads mode (solo|team) and chooses the
# correct push target, preventing the class of error where solo pattern (ai-dev:main)
# is used in a team-mode project.
#
# Usage:
#   bash scripts/deploy-push.sh [path/to/CLAUDE.local.md]
#   Default config path: CLAUDE.local.md (in current directory)

set -euo pipefail

CONFIG="${1:-CLAUDE.local.md}"

_get_field() {
  local field="$1"
  local default="$2"
  if [[ ! -f "$CONFIG" ]]; then
    echo "$default"
    return
  fi
  local value
  # Extract value after 'field:', strip inline '# comment', then strip CR/whitespace.
  # (Template yaml ships inline comments, e.g. `worktree_isolation: off  # ...` —
  #  without comment-stripping the value would read as 'off#...'.)
  value=$(awk '/^## Branching/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

MODE=$(_get_field "mode" "solo")
AGENT_BRANCH=$(_get_field "agent_branch" "ai-dev")
PRODUCTION_BRANCH=$(_get_field "production_branch" "main")
INTEGRATION_BRANCH=$(_get_field "integration_branch" "$PRODUCTION_BRANCH")
PR_TOOL=$(_get_field "pr_tool" "manual")
WORKTREE_ISOLATION=$(_get_field "worktree_isolation" "off")

# ---------------------------------------------------------------------------
# Concurrent-session isolation (closes P-001): when worktree_isolation: auto,
# the deploy branch is the CURRENT branch (a namespaced ai-dev/<task> from an
# isolated worktree), NOT the shared agent_branch. Reading the current branch
# avoids the class-bug where hardcoded agent_branch pushes the wrong worktree's
# branch. When isolation is off, behavior is unchanged (current branch == agent_branch).
# ---------------------------------------------------------------------------
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "$AGENT_BRANCH")
if [[ "$WORKTREE_ISOLATION" == "auto" ]]; then
  PUSH_BRANCH="$CURRENT_BRANCH"
else
  PUSH_BRANCH="$AGENT_BRANCH"
fi

echo "Branching config (from $CONFIG):"
echo "  mode:               $MODE"
echo "  agent_branch:       $AGENT_BRANCH"
echo "  worktree_isolation: $WORKTREE_ISOLATION"
echo "  push_branch:        $PUSH_BRANCH"
echo "  production_branch:  $PRODUCTION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  integration_branch: $INTEGRATION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  pr_tool:            $PR_TOOL"
echo ""

# ---------------------------------------------------------------------------
# Auto-wire credential helper (S3 / closes G-079: orphaned helper).
# For HTTPS remotes, configure git-credential-from-env.sh as the credential
# helper BEFORE push, so `git push` authenticates via helper stdin — the token
# NEVER appears in any command argv (the confirmed leak vector). Idempotent:
# skips if already configured, if remote is SSH (no token needed), or if the
# helper script is absent. This removes the agent's incentive to fall back to
# `git remote set-url https://user:TOKEN@...` when auth is needed.
# ---------------------------------------------------------------------------
_wire_credential_helper() {
  local remote_url helper_path host
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  # SSH remote → no token, no helper needed.
  case "$remote_url" in
    https://*) : ;;                       # proceed
    *) return 0 ;;                        # ssh/git/empty → nothing to wire
  esac
  # Locate the helper script relative to THIS script (works in code or doc repo).
  helper_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-credential-from-env.sh"
  [[ -f "$helper_path" ]] || return 0     # helper absent → leave git defaults
  # Extract host: https://host/... → host
  host="${remote_url#https://}"; host="${host%%/*}"; host="${host%%:*}"
  [[ -n "$host" ]] || return 0
  # Already configured for this host? (idempotent)
  if git config --get "credential.https://${host}.helper" >/dev/null 2>&1; then
    return 0
  fi
  git config "credential.https://${host}.helper" "!bash ${helper_path}"
  echo "🔑 credential helper wired for ${host} (token via helper stdin, not argv)"
}
_wire_credential_helper

if [[ "$MODE" == "team" ]]; then
  echo "▶ Team mode → git push origin ${PUSH_BRANCH}:${PUSH_BRANCH}"
  git push origin "${PUSH_BRANCH}:${PUSH_BRANCH}"
  echo ""

  if [[ "$PR_TOOL" == "auto-merge" ]]; then
    PR_TITLE=$(git log -1 --format="%s")
    echo "▶ auto-merge → gh pr create + merge"
    PR_URL=$(gh pr create \
      --base "$INTEGRATION_BRANCH" \
      --head "$PUSH_BRANCH" \
      --title "$PR_TITLE" \
      --body "Auto-deploy via deploy-push.sh")
    echo "  PR: $PR_URL"
    gh pr merge "$PR_URL" --merge --delete-branch=false
    echo "✅ Merged: ${PUSH_BRANCH} → ${INTEGRATION_BRANCH}"
  else
    echo "✅ Pushed. Create PR: ${PUSH_BRANCH} → ${INTEGRATION_BRANCH}"
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
    if [[ -n "$REMOTE_URL" ]]; then
      _base="${REMOTE_URL%.git}"
      echo "   GitHub: ${_base}/compare/${INTEGRATION_BRANCH}...${PUSH_BRANCH}?expand=1"
    fi
  fi
else
  echo "▶ Solo mode → git push origin ${PUSH_BRANCH}:${PRODUCTION_BRANCH}"
  git push origin "${PUSH_BRANCH}:${PRODUCTION_BRANCH}"
  echo ""
  echo "✅ Deployed to ${PRODUCTION_BRANCH}"
fi
