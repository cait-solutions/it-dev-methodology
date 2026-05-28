"""
PreToolUse hook for Bash — blocks destructive commands and reliable secret-dump patterns.

Wired in .claude/settings.json under "hooks.PreToolUse" with matcher "Bash".
Exit code 2 blocks the tool call; stderr is shown to the user.

Threat model (HONEST):
  This hook is BEST-EFFORT for secret leak prevention via Bash. Regex-based
  shell parsing is fundamentally leaky — there are too many ways to construct
  a command (substitution, eval, escape, base64 wrapping, etc.) that read .env
  and pipe to stdout. Don't pretend otherwise.

  REAL defense layers for secrets (in order of strength):

    L5  settings.json `permissions.deny` — harness blocks Read/Bash on .env
        patterns BEFORE this hook runs. Primary structural barrier.
    L4  templates/.claude/hooks/secrets-guard.py — blocks `git commit` of
        staged .env files or detected tokens. Catches leaks at the commit
        boundary even if they slipped past everything else.
    L4  /review token detector — catches leaks at PR review boundary.
    L2  Rotation discipline — documented in skills/secrets-management/.
        When (not if) a leak happens, the response is rotate-immediately.

  This file (bash_protect.py) contributes:
    - DANGEROUS_PATTERNS: rm -rf / git push --force / etc. (long-standing)
    - ENV_DUMP_PATTERNS: `env`, `printenv`, `echo $GITHUB_PAT`, `source .env`.
      These are reliably detectable AND have no legitimate use case for
      methodology workflows.

  We DO NOT try to filter `cat .env` / `grep .env` / `awk .env` / etc. here
  because:
    (a) settings.json `Bash(cat .env*)` deny already catches the common cases,
    (b) determined adversarial prompt can always construct a bypass
        (base64 encode, command substitution, hex dump, send to remote, ...),
    (c) trying creates a false sense of security and complicated regex maintenance.

  If you need to add a pattern here, it MUST satisfy BOTH:
    (1) No legitimate methodology workflow needs it.
    (2) The regex is precise enough that there's no escape via simple variation.

Extend DANGEROUS_PATTERNS for project-specific dangerous commands.
"""
import sys
import json
import re

DANGEROUS_PATTERNS = [
    r'rm\s+-rf',
    r'DROP\s+TABLE',
    r'DROP\s+DATABASE',
    r'TRUNCATE\s+',
    r'docker\s+system\s+prune',
    r'docker\s+volume\s+prune',
    r'git\s+push\s+(-f|--force)',
    r'git\s+reset\s+--hard',
    r'git\s+clean\s+-f',
    r':>\s*[^\s]+\.env',
    r'mkfs\.',
]

# Patterns that dump environment variables (containing loaded secrets) to stdout.
# These are reliably caught because they have specific command names with no
# legitimate methodology use case — you should NEVER need `env` / `printenv`
# in normal work; if you genuinely need to inspect env (debugging), do it
# outside Claude Code.
#
# Case-SENSITIVE on purpose (`head` ≠ git `HEAD` ≠ HTTP HEAD).
ENV_DUMP_PATTERNS = [
    # Bare `env` (dumps all env vars including injected secrets)
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*env(?:\s*$|\s*\||\s*>|\s*\d*>)',
    # `printenv` — same effect
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*printenv(?:\s|$)',
    # `set | grep` — common shell pattern to dump shell variables
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*set\s*\|\s*grep',
    # Direct echo of a known secret variable name
    r'echo\s+["\']*\$\{?(?:GITHUB_PAT|GITHUB_TOKEN|ANTHROPIC_API_KEY|OPENAI_API_KEY|'
    r'AWS_SECRET|AWS_SECRET_ACCESS_KEY|GH_TOKEN|GIT_TOKEN|DATABASE_URL|'
    r'REDIS_URL|VAULT_TOKEN|API_KEY|SECRET_KEY)',
    # `source .env` / `. .env` — loads values into calling shell where they
    # can then leak via subsequent commands. No legitimate methodology use:
    # methodology scripts read .env via `with-secret.sh` injection pattern instead.
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*source\s+(?:[^\s;&|]+/)?\.env(?:\.[a-z0-9_]+)?(?:\s|$)',
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*\.\s+(?:[^\s;&|]+/)?\.env(?:\.[a-z0-9_]+)?(?:\s|$)',
]


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "")

for pattern in DANGEROUS_PATTERNS:
    if re.search(pattern, cmd, re.IGNORECASE):
        sys.stderr.write(f"BLOCKED: dangerous command matches /{pattern}/: {cmd[:120]}\n")
        sys.exit(2)

# Secret-dump checks. Case-sensitive.
for pattern in ENV_DUMP_PATTERNS:
    if re.search(pattern, cmd):
        sys.stderr.write(
            f"BLOCKED: command would dump environment to stdout (matched /{pattern[:60]}.../).\n"
            f"  Command: {cmd[:200]}\n"
            f"  Rationale: env vars in tool output → transcript → API → leak.\n"
            f"  Use instead:\n"
            f"    bash scripts/check-secret.sh KEY        # boolean only\n"
            f"    bash scripts/with-secret.sh KEY -- cmd  # inject as env to subprocess\n"
            f"  Reading file content (.env): see settings.json permissions.deny rules.\n"
        )
        sys.exit(2)
