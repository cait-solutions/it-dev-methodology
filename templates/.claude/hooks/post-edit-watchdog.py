"""
PostToolUse hook — runs configured scripts after Edit/Write tool calls.

Wired in .claude/settings.json under "hooks.PostToolUse" with matcher "Edit|Write".
Always exits 0 (non-blocking side-effect hook).

Config: CLAUDE.local.md section "## Post-edit hooks"

    ## Post-edit hooks

    rules:
      - pattern: "```mermaid"
        script: scripts/update-mermaid-links.sh
        file_arg: true
      - pattern: "## Changelog"
        script: scripts/update-changelog-links.sh
        file_arg: true

Rules are matched against the changed text (new_string for Edit, content for Write)
OR against the full file on disk (QB11: if pattern exists anywhere in the file, run script
even when the edit itself didn't touch the mermaid block — e.g. editing a Done table).
If pattern found in changed text OR in file on disk → run script.
file_arg: true  → script is called with the file path as argument
file_arg: false → script is called without arguments

Default rule (used when ## Post-edit hooks section is absent):
  - pattern: "```mermaid"
    script: scripts/update-mermaid-links.sh
    file_arg: true

Security: script paths are validated against path traversal.
"""
import json
import os
import re
import subprocess
import sys

DEFAULT_RULES = [
    {"pattern": "```mermaid", "script": "scripts/update-mermaid-links.sh", "file_arg": True},
]

SAFE_SCRIPT_RE = re.compile(r'^[a-zA-Z0-9_\-/.]+\.(?:sh|py|js|rb)$')


def is_safe_script_path(path: str) -> bool:
    """Reject path traversal and absolute paths — scripts must be relative project paths."""
    if not path or os.path.isabs(path):
        return False
    normalized = os.path.normpath(path)
    if normalized.startswith(".."):
        return False
    return bool(SAFE_SCRIPT_RE.match(path))


def parse_rules_from_claude_local() -> list:
    """Read ## Post-edit hooks section from CLAUDE.local.md. Returns list of rule dicts."""
    for candidate in ["CLAUDE.local.md", "../CLAUDE.local.md"]:
        if not os.path.exists(candidate):
            continue
        try:
            text = open(candidate, encoding="utf-8-sig").read()  # BOM-tolerant (G-081)
        except Exception:
            continue

        # Extract ## Post-edit hooks section
        m = re.search(r'##\s+Post-edit hooks\s*\n(.*?)(?=\n##\s|\Z)', text, re.DOTALL)
        if not m:
            return []

        section = m.group(1)

        # Parse simple YAML-like rules list
        rules = []
        current = {}
        for line in section.splitlines():
            line = line.strip()
            if line.startswith("- pattern:"):
                if current:
                    rules.append(current)
                current = {"pattern": line.split(":", 1)[1].strip().strip('"').strip("'"),
                           "file_arg": True}
            elif line.startswith("script:") and current is not None:
                current["script"] = line.split(":", 1)[1].strip().strip('"').strip("'")
            elif line.startswith("file_arg:") and current is not None:
                val = line.split(":", 1)[1].strip().lower()
                current["file_arg"] = val not in ("false", "no", "0")
        if current:
            rules.append(current)

        return rules

    return []


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write"):
        sys.exit(0)

    tool_input = data.get("tool_input") or {}
    file_path = tool_input.get("file_path", "")

    # Edit uses new_string, Write uses content
    changed_text = tool_input.get("new_string") or tool_input.get("content") or ""

    if not changed_text or not file_path:
        sys.exit(0)

    # Load rules — from CLAUDE.local.md or defaults.
    # Note: if ## Post-edit hooks section exists but has no rules → returns [] → DEFAULT_RULES used.
    # To disable default mermaid rule: add a dummy rule or remove the section entirely.
    rules = parse_rules_from_claude_local() or DEFAULT_RULES

    for rule in rules:
        pattern = rule.get("pattern", "")
        script = rule.get("script", "")
        file_arg = rule.get("file_arg", True)

        if not pattern or not script:
            continue
        # QB11: match against changed text OR full file on disk
        # (covers edits to tables/text in files that also contain a mermaid block)
        in_changed = pattern in changed_text
        in_file = False
        if not in_changed and file_path and os.path.exists(file_path):
            try:
                in_file = pattern in open(file_path, encoding="utf-8-sig").read()
            except Exception:
                pass
        if not in_changed and not in_file:
            continue
        if not is_safe_script_path(script):
            print(f"[post-edit-watchdog] Skipped unsafe script path: {script}", file=sys.stderr)
            continue
        if not os.path.exists(script):
            # Graceful skip — consumer on older methodology version
            print(f"[post-edit-watchdog] Script not found (run sync-methodology.sh): {script}",
                  file=sys.stderr)
            continue

        try:
            cmd = ["bash", script, file_path] if file_arg else ["bash", script]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.stdout.strip():
                print(f"[post-edit-watchdog] {script}: {result.stdout.strip()}", file=sys.stderr)
        except Exception as e:
            print(f"[post-edit-watchdog] Error running {script}: {e}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
