# AUTO-GENERATED from methodology-platform v7.0.2
# Synced: 2026-06-19
# DO NOT EDIT — changes will be overwritten on next sync
# Modify via PR to https://github.com/cait-solutions/it-dev-methodology
# Emergency override: edit locally + open PR within 48h

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
    # -----------------------------------------------------------------------
    # G-062 fixes: two new leak vectors
    # -----------------------------------------------------------------------
    # INLINE ENV ASSIGNMENT with secret-like key name and long value.
    # This is the exact pattern from the Keycloak incident where agent wrote:
    #   KEYLOCK_ADMIN_CREDENTIALS="KeycloakAdmin2024!" bash scripts/keycloak-...
    # The value is visible in the Bash tool input → transcript → API.
    #
    # Only matches keys containing secret-indicator substrings to avoid
    # false positives on legitimate vars like NODE_ENV=production.
    # Secret indicators (case-sensitive): SECRET, TOKEN, PASS, PASSWORD,
    #   API_KEY, _KEY, KEY_ (standalone), CRED, CREDENTIAL, PWD, AUTH,
    #   ADMIN, PRIVATE, CERT, BEARER, _PAT, PAT_ (Personal Access Token)
    r'(?:[A-Z][A-Z0-9_]*(?:SECRET|TOKEN|PASS(?:WORD)?|API_KEY|_KEY|KEY_|CRED(?:ENTIAL)?|'
    r'PWD|AUTH|ADMIN|PRIVATE|CERT|BEARER|_PAT|PAT_)[A-Z0-9_]*)=["\'][^"\']{8,}["\']'
    r'[^\S\r\n]+(?:bash|sh|python|py|node)\b',
    r'(?:[A-Z][A-Z0-9_]*(?:SECRET|TOKEN|PASS(?:WORD)?|API_KEY|_KEY|KEY_|CRED(?:ENTIAL)?|'
    r'PWD|AUTH|ADMIN|PRIVATE|CERT|BEARER|_PAT|PAT_)[A-Z0-9_]*)=[^\s"\';&|]{8,}'
    r'[^\S\r\n]+(?:bash|sh|python|py|node)\b',
    # _get-secret-raw.sh with --explicit-stdout: this script outputs the secret
    # value to stdout. Agents MUST NOT call it directly (only users can, in terminal).
    # with-secret.sh injection pattern is the correct agent-facing API.
    r'_get-secret-raw\.sh\b.*--explicit-stdout',
    r'_get-secret-raw\.sh\b',  # block entirely — no legitimate agent use case
]


# ---------------------------------------------------------------------------
# G-077/G-078 fixes: the CONFIRMED git-https token-leak vector + .env reads.
#
# Incident: with-secret.sh failed (non-TTY) → agent fell back to:
#   grep GITHUB_PAT .env  →  git remote set-url origin https://user:TOKEN@github.com/...
# Token landed in the Bash command → transcript → API. Neither env-dump nor
# destructive patterns matched it (orthogonal command class).
#
# Industry principle (credential-helper / ssh-agent): the agent must be
# STRUCTURALLY incapable of naming the secret value in any command. These
# patterns close the no-alternative-path (L5) for the two observed routes.
# Correct auth path = git credential helper (git-credential-from-env.sh) —
# agent runs plain `git push`, token flows via helper stdin, never argv.
# ---------------------------------------------------------------------------
SECRET_EXFIL_PATTERNS = [
    # (1) Token embedded in an HTTPS URL with userinfo: https://user:SECRET@host
    #     Catches `git remote set-url`, `git push https://x:tok@...`, `git clone …`.
    #     Requires BOTH user AND password segment (`:` then `@`) to avoid matching
    #     plain `https://github.com/owner/repo` (no `@`, no userinfo). The password
    #     segment must be non-trivial (≥1 char) and not an obvious placeholder.
    r'https?://[^/\s:@]+:[^/\s@]+@',
    # (2) Reading .env (or .env.*) content via common readers → stdout/transcript.
    #     `.env` must be a BARE FILE ARGUMENT — at end-of-command or before a
    #     pipe/redirect — NOT inside quotes (that's a search *pattern*, e.g.
    #     `grep "\.env" settings.json` legitimately searches for the text ".env"
    #     in another file). The negative lookahead excludes .env.example (safe
    #     template). Trailing position (\s*(?:$|[|;&><])) ensures .env is the
    #     target file, not a search string followed by the real file.
    r'(?:^|[;|&(`]|\&\&|\|\|)\s*'
    r'(?:cat|grep|egrep|fgrep|sed|awk|head|tail|less|more|nl|tac|xxd|od|strings)\b'
    r'(?:\s+[^\s;&|><]+)*?'                 # any intermediate args (flags/patterns), non-greedy
    r'\s+(?:[^\s;&|"\'><]+/)?'              # .env preceded by space, optional UNQUOTED dir prefix
    r'\.env(?!\.example\b)(?:\.[A-Za-z0-9_-]+)?'
    r'\s*(?:$|[|;&><])',                    # .env is final/target → file, not a quoted pattern
    # (3) Redirect .env into a reader via stdin: `< .env cat`, `cat < .env`
    r'<\s*(?:[^\s;&|]+/)?\.env(?!\.example\b)(?:\.[A-Za-z0-9_-]+)?\b',
    # (4) python/node one-liners that open .env (open('.env'), readFileSync('.env'))
    r'''(?:open|readFileSync|read_text|Path)\s*\(\s*["'][^"']*\.env(?!\.example)''',
]


# Methodology-managed secret scripts — invocations are allowed even though
# they reference secret operations. The scripts themselves enforce safety
# (interactive read -s, no value echo).
_METHODOLOGY_SECRET_SCRIPTS = (
    r'bash\s+(?:[^\s;&|]+/)?scripts/'
    r'(?:with-secret|set-secret|check-secret|validate-secrets|secrets-scrub|'
    r'secrets-show|secrets-edit|secrets-update|secrets-rollback|'
    r'secrets-cleanup-backups|git-credential-from-env|clone-consumer|secrets-delete)'
    r'(?:\.sh)?(?:\s|$|[|;&])'
)

# Git operations that may reference blocked names in commit messages (-m, -F)
# or documentation context — these are not execution paths.
_GIT_COMMIT_ALLOWLIST = r'git\s+(?:commit|tag|notes\s+add)\b'


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "")

# Methodology secret-management scripts — allow even if patterns below match.
if re.search(_METHODOLOGY_SECRET_SCRIPTS, cmd):
    sys.exit(0)

# git commit / tag — may reference script names in commit messages, not execution paths.
if re.search(_GIT_COMMIT_ALLOWLIST, cmd):
    sys.exit(0)

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

# Secret-exfil checks (G-077/G-078): token-in-URL + .env reads.
# Case-sensitive except where the pattern is intentionally broad.
for pattern in SECRET_EXFIL_PATTERNS:
    if re.search(pattern, cmd):
        sys.stderr.write(
            f"BLOCKED: command would expose a secret in the transcript "
            f"(matched /{pattern[:50]}.../).\n"
            f"  Command: {cmd[:200]}\n"
            f"  Rationale: token in an HTTPS URL or .env read → Bash argv/output → "
            f"transcript → API → leak. This is the confirmed git-https leak vector.\n"
            f"  Correct git auth (token NEVER in command):\n"
            f"    1. Configure credential helper ONCE (deploy-push.sh does this auto):\n"
            f"       git config credential.helper \"!bash $(pwd)/scripts/git-credential-from-env.sh\"\n"
            f"    2. Then just: git push   (token flows via helper stdin, not argv)\n"
            f"  OR use SSH remotes (no token string exists at all).\n"
            f"  To read a secret's presence: bash scripts/check-secret.sh KEY (boolean).\n"
        )
        sys.exit(2)
