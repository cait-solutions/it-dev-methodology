"""
PreToolUse hook — guards against committing or echoing secret VALUES.

Triggered on Bash tool calls. Inspects two failure modes:

1. STAGED COMMIT CHECK:
   When the command contains `git commit`, inspect the staged diff (git diff --cached)
   for high-entropy strings or known token prefixes (ghp_, sk-, sk-ant-, xoxb-, AKIA, ya29.).
   If any match → block the commit with exit 2 + remediation steps.

2. STAGED .ENV CHECK:
   When `git add` / `git commit` includes a path like `.env` or `secrets.env`
   (not whitelisted templates), block immediately.

Whitelisted files (commit-safe even if they look secret):
  - .env.example, .env.example.template
  - .env.*.template (e.g. .env.prod.template)
  - secrets-manifest.yaml.template
  - skills/secrets-management/SKILL.md

Exit codes:
  0  — no issue, proceed
  2  — block tool call (stderr is shown to user)

Bash 3.2 / Windows-friendly (only relies on `git` + python stdlib).
"""
import sys
import json
import re
import subprocess
import math
import os


TOKEN_PREFIX_PATTERNS = [
    r'ghp_[A-Za-z0-9]{36,}',
    r'github_pat_[A-Za-z0-9_]{40,}',
    r'gho_[A-Za-z0-9]{36,}',
    r'sk-ant-[A-Za-z0-9_\-]{32,}',
    r'sk-[A-Za-z0-9]{32,}',
    r'xox[baprs]-[A-Za-z0-9-]{10,}',
    r'AKIA[0-9A-Z]{16}',
    r'ya29\.[A-Za-z0-9_\-]{20,}',
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
]

WHITELISTED_PATHS = [
    r'\.env\.example(\.template)?$',
    r'\.env\.[a-z]+\.template$',
    r'secrets-manifest\.ya?ml\.template$',
    r'skills[\\/]secrets-management[\\/]',
    r'\.env\.lock$',
]

PROTECTED_PATHS = [
    r'(^|[\\/])\.env$',
    r'(^|[\\/])\.env\.[a-z0-9_]+$',
    r'(^|[\\/])secrets\.env$',
    r'(^|[\\/])secrets\.local\.',
]

# Files where matched-pattern false positives may live (e.g. methodology
# documentation that quotes token shapes in examples). The hook still warns
# on these, but with a softer message and only blocks if entropy AND prefix.
ALLOW_DOCUMENTATION_PATHS = [
    r'CLAUDE\.md$',
    r'CLAUDE_LONG\.md$',
    r'PRODUCT\.md$',
    r'templates[\\/].*\.template\.md$',
    r'commands[\\/].*\.md$',
    r'skills[\\/].*\.md$',
    r'commands-local[\\/].*\.md$',
]


def _is_whitelisted(path):
    return any(re.search(p, path, re.IGNORECASE) for p in WHITELISTED_PATHS)


def _is_protected(path):
    return any(re.search(p, path, re.IGNORECASE) for p in PROTECTED_PATHS)


def _is_documentation(path):
    return any(re.search(p, path, re.IGNORECASE) for p in ALLOW_DOCUMENTATION_PATHS)


def _shannon_entropy(s):
    if not s:
        return 0.0
    freq = {}
    for c in s:
        freq[c] = freq.get(c, 0) + 1
    total = len(s)
    return -sum((n / total) * math.log2(n / total) for n in freq.values())


def _get_threshold():
    # Read entropy_threshold from manifest if present, else default.
    manifest = ".claude/secrets-manifest.yaml"
    if not os.path.exists(manifest):
        return 4.5
    try:
        with open(manifest, encoding="utf-8-sig") as f:  # BOM-tolerant (G-081)
            for line in f:
                m = re.match(r'^\s*entropy_threshold:\s*([0-9.]+)', line)
                if m:
                    return float(m.group(1))
    except Exception:
        pass
    return 4.5


def _staged_files():
    """Return (files, error_msg). Distinguishes empty-staging (files=[], err=None)
    from infrastructure failure (files=[], err='...') so the caller can warn."""
    try:
        r = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode != 0:
            return [], f"git diff --cached --name-only returned exit {r.returncode}"
        return [ln.strip() for ln in r.stdout.splitlines() if ln.strip()], None
    except subprocess.TimeoutExpired:
        return [], "git diff --cached --name-only timed out (>10s)"
    except Exception as e:
        return [], f"git diff failed: {e.__class__.__name__}: {e}"


def _staged_diff():
    """Return (diff, error_msg). On timeout/failure returns ('', err) so caller
    can decide whether to allow the commit with a warning vs hard-block."""
    try:
        r = subprocess.run(
            ["git", "diff", "--cached", "--unified=0"],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode != 0:
            return "", f"git diff --cached returned exit {r.returncode}: {r.stderr[:200]}"
        return r.stdout, None
    except subprocess.TimeoutExpired:
        return "", "git diff --cached timed out (>15s); content scan SKIPPED"
    except Exception as e:
        return "", f"git diff failed: {e.__class__.__name__}: {e}"


def check_commit(cmd):
    # 1. Block if any staged path is a protected secret file (not whitelisted).
    files, files_err = _staged_files()
    if files_err:
        # Cannot determine staged files — warn but don't hard-block (would lock
        # out the user from committing if git is misbehaving). /review will
        # catch any leak that slips through here.
        sys.stderr.write(
            f"WARN: secrets-guard could not enumerate staged files ({files_err}).\n"
            f"      File-level secret check SKIPPED. /review will catch leaks.\n"
        )

    blocked_files = []
    for f in files:
        if _is_whitelisted(f):
            continue
        if _is_protected(f):
            blocked_files.append(f)

    if blocked_files:
        sys.stderr.write(
            "BLOCKED: commit includes secret file(s):\n  "
            + "\n  ".join(blocked_files)
            + "\nUnstage them: git reset HEAD <file>\n"
            "These paths are gitignored by methodology .gitignore template;\n"
            "if you used `git add -f` to force them, undo that.\n"
        )
        sys.exit(2)

    # 2. Scan staged diff content for token prefixes + high entropy strings.
    diff, diff_err = _staged_diff()
    if diff_err:
        sys.stderr.write(
            f"WARN: secrets-guard could not scan diff content ({diff_err}).\n"
            f"      Content-level secret check SKIPPED. /review will catch leaks.\n"
            f"      If you suspect a token was committed, rotate it preemptively.\n"
        )
        return
    if not diff:
        return

    # Track current file in diff (for documentation softening).
    current_file = ""
    threshold = _get_threshold()
    leaks = []

    for line in diff.splitlines():
        if line.startswith("+++ b/"):
            current_file = line[len("+++ b/"):].strip()
            continue
        if not line.startswith("+") or line.startswith("+++"):
            continue
        added = line[1:]

        # Skip whitelisted files entirely.
        if current_file and _is_whitelisted(current_file):
            continue

        # Token-prefix match — strong signal.
        prefix_hit = None
        for pat in TOKEN_PREFIX_PATTERNS:
            m = re.search(pat, added)
            if m:
                prefix_hit = (pat, m.group(0)[:8] + "..." + m.group(0)[-4:])
                break

        if prefix_hit:
            leaks.append((current_file, added[:80], "token-prefix", prefix_hit[0]))
            continue

        # Entropy-based heuristic: find long alphanumeric runs and score them.
        for token in re.findall(r'[A-Za-z0-9+/=_-]{24,}', added):
            ent = _shannon_entropy(token)
            if ent >= threshold:
                # In documentation files, require a second signal (e.g. quoted prefix)
                # to avoid noisy false positives on legitimate base64/hashes.
                if current_file and _is_documentation(current_file):
                    continue
                leaks.append((current_file, added[:80], f"entropy={ent:.2f}", token[:6] + "..."))
                break

    if leaks:
        sys.stderr.write(
            f"BLOCKED: staged diff appears to contain {len(leaks)} secret value(s).\n\n"
        )
        for fname, snippet, reason, hint in leaks[:5]:
            sys.stderr.write(f"  {fname}: ({reason}) {hint}\n    > {snippet}\n")
        if len(leaks) > 5:
            sys.stderr.write(f"  ... and {len(leaks) - 5} more\n")
        sys.stderr.write(
            "\nRemediation:\n"
            "  1. ROTATE the leaked token at the provider (it's now considered exposed).\n"
            "  2. git reset HEAD <file>  +  edit out the value  +  re-stage.\n"
            "  3. If commit overrides this hook (--no-verify), /review will still catch it.\n"
            "If this is a false positive in a documentation example, add the file to\n"
            ".claude/secrets-manifest.yaml config.entropy_threshold or wrap value as `<example>`.\n"
        )
        sys.exit(2)


def check_add(cmd):
    # Detect `git add` with explicit .env path. For broad globs (git add .),
    # we rely on the commit-time check (above) since staged contents are what matters.
    if re.search(r'\bgit\s+add\b.*(\.env\b|secrets\.env\b|secrets\.local\.)', cmd):
        # Allow templated whitelisted paths.
        if re.search(r'\.env\.example|\.env\.[a-z]+\.template|secrets-manifest\.yaml\.template', cmd):
            return
        sys.stderr.write(
            "BLOCKED: refusing to `git add` a secret file.\n"
            "  Command: " + cmd[:120] + "\n"
            "  .env / secrets.env are gitignored by methodology — if you used -f to force,\n"
            "  rotate any tokens that may have been exposed and remove the file from staging.\n"
        )
        sys.exit(2)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    cmd = (data.get("tool_input") or {}).get("command", "")

    # Only act on git operations that can leak.
    if "git commit" in cmd or "git add" in cmd:
        check_add(cmd)
    if "git commit" in cmd:
        check_commit(cmd)


if __name__ == "__main__":
    main()
