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
  value=$(awk '/^## Branching/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

MODE=$(_get_field "mode" "solo")
AGENT_BRANCH=$(_get_field "agent_branch" "ai-dev")
PRODUCTION_BRANCH=$(_get_field "production_branch" "main")
INTEGRATION_BRANCH=$(_get_field "integration_branch" "$PRODUCTION_BRANCH")
PR_TOOL=$(_get_field "pr_tool" "manual")

echo "Branching config (from $CONFIG):"
echo "  mode:               $MODE"
echo "  agent_branch:       $AGENT_BRANCH"
echo "  production_branch:  $PRODUCTION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  integration_branch: $INTEGRATION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  pr_tool:            $PR_TOOL"
echo ""

if [[ "$MODE" == "team" ]]; then
  echo "▶ Team mode → git push origin ${AGENT_BRANCH}:${AGENT_BRANCH}"
  git push origin "${AGENT_BRANCH}:${AGENT_BRANCH}"
  echo ""

  if [[ "$PR_TOOL" == "auto-merge" ]]; then
    PR_TITLE=$(git log -1 --format="%s")
    echo "▶ auto-merge → gh pr create + merge"
    PR_URL=$(gh pr create \
      --base "$INTEGRATION_BRANCH" \
      --head "$AGENT_BRANCH" \
      --title "$PR_TITLE" \
      --body "Auto-deploy via deploy-push.sh")
    echo "  PR: $PR_URL"
    gh pr merge "$PR_URL" --merge --delete-branch=false
    echo "✅ Merged: ${AGENT_BRANCH} → ${INTEGRATION_BRANCH}"
  else
    echo "✅ Pushed. Create PR: ${AGENT_BRANCH} → ${INTEGRATION_BRANCH}"
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
    if [[ -n "$REMOTE_URL" ]]; then
      _base="${REMOTE_URL%.git}"
      echo "   GitHub: ${_base}/compare/${INTEGRATION_BRANCH}...${AGENT_BRANCH}?expand=1"
    fi
  fi
else
  echo "▶ Solo mode → git push origin ${AGENT_BRANCH}:${PRODUCTION_BRANCH}"
  git push origin "${AGENT_BRANCH}:${PRODUCTION_BRANCH}"
  echo ""
  echo "✅ Deployed to ${PRODUCTION_BRANCH}"
fi
