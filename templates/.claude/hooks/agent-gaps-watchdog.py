"""
Stop hook — scans the last Claude response for admission phrases.
When found and AGENT-GAPS.md was not recently written, outputs a reminder
so Claude proposes logging the gap.

Wired in .claude/settings.json under "hooks.Stop".

Anti-loop: stop_hook_active=True means we are already in a hook-triggered
turn — exit immediately to prevent recursion.
"""
import json
import os
import re
import sys
import time

ADMISSION_PATTERNS = [
    r"\bты прав\b",
    r"\bвы правы\b",
    r"\bя пропустил\b",
    r"\bя не предусмотрел\b",
    r"\bя упустил\b",
    r"\bя был неточен\b",
    r"\bя ошибся\b",
    r"\bдействительно пропустил\b",
    r"\bне учёл\b",
    r"\byou'?re right\b",
    r"\bi missed\b",
    r"\bi overlooked\b",
    r"\bi didn'?t account\b",
    r"\bi failed to\b",
]

GAPS_FILE = "AGENT-GAPS.md"
RECENT_WRITE_SECONDS = 60


def get_last_assistant_message(transcript_path: str) -> str:
    if not transcript_path or not os.path.exists(transcript_path):
        return ""
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
        for line in reversed(lines):
            try:
                entry = json.loads(line)
                if entry.get("role") != "assistant":
                    continue
                content = entry.get("content", "")
                if isinstance(content, list):
                    return " ".join(
                        block.get("text", "")
                        for block in content
                        if isinstance(block, dict) and block.get("type") == "text"
                    )
                return str(content)
            except (json.JSONDecodeError, AttributeError):
                continue
    except OSError:
        pass
    return ""


def gaps_recently_written() -> bool:
    if not os.path.exists(GAPS_FILE):
        return False
    return time.time() - os.path.getmtime(GAPS_FILE) < RECENT_WRITE_SECONDS


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if data.get("stop_hook_active"):
        sys.exit(0)

    last_msg = get_last_assistant_message(data.get("transcript_path", ""))
    if not last_msg:
        sys.exit(0)

    found = any(re.search(p, last_msg, re.IGNORECASE) for p in ADMISSION_PATTERNS)
    if not found:
        sys.exit(0)

    if gaps_recently_written():
        sys.exit(0)

    print(
        "📋 AGENT-GAPS WATCHDOG: в ответе выше обнаружено признание ошибки/пропуска.\n"
        "Если ещё не предложено — предложи запись в AGENT-GAPS.md:\n"
        "  Категория: [prompt-gap | context-gap | logic-gap | assumption-gap | completeness-gap | scope-gap]\n"
        "  Гипотеза: одна строка почему\n"
        "  (Если уже предложил залогировать — игнорируй это напоминание)"
    )


if __name__ == "__main__":
    main()
