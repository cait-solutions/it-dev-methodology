"""
Stop hook — scans the last Claude response AND last user message for
admission/correction phrases. When found and AGENT-GAPS.md was not recently
written, outputs a reminder so Claude proposes logging the gap.

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

USER_CORRECTION_PATTERNS = [
    r"ты (добавил|сделал|написал).{0,40}(но|а) не",
    r"я (также|ещё|тоже) просил",
    r"ты (не сделал|пропустил|не учёл)",
    r"(почему|а) ты не\b",
    r"не сделал аналогичное",
    r"а (что|как) с\b",
    r"(плохо|неправильно) (отработал|сделал)",
    r"агент пропустил",
    r"you (added|did).{0,40}(but|yet) (not|didn.?t)",
    r"you (missed|skipped)\b",
    r"you didn.?t.{0,20}(also|as well|similarly)",
]

GAPS_FILE = "AGENT-GAPS.md"
RECENT_WRITE_SECONDS = 60


def _extract_text(content) -> str:
    if isinstance(content, list):
        return " ".join(
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    return str(content)


def get_last_messages(transcript_path: str) -> tuple[str, str]:
    """Return (last_assistant_text, last_user_text)."""
    if not transcript_path or not os.path.exists(transcript_path):
        return "", ""
    last_assistant = ""
    last_user = ""
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
        for line in reversed(lines):
            try:
                entry = json.loads(line)
                role = entry.get("role", "")
                if role == "assistant" and not last_assistant:
                    last_assistant = _extract_text(entry.get("content", ""))
                elif role == "user" and not last_user:
                    last_user = _extract_text(entry.get("content", ""))
                if last_assistant and last_user:
                    break
            except (json.JSONDecodeError, AttributeError):
                continue
    except OSError:
        pass
    return last_assistant, last_user


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

    last_assistant, last_user = get_last_messages(data.get("transcript_path", ""))

    ai_admission = last_assistant and any(
        re.search(p, last_assistant, re.IGNORECASE) for p in ADMISSION_PATTERNS
    )
    user_correction = last_user and any(
        re.search(p, last_user, re.IGNORECASE) for p in USER_CORRECTION_PATTERNS
    )

    if not ai_admission and not user_correction:
        sys.exit(0)

    if gaps_recently_written():
        sys.exit(0)

    source = "в ответе агента" if ai_admission else "в сообщении разработчика"
    print(
        f"📋 AGENT-GAPS WATCHDOG: обнаружен признак ошибки/пропуска ({source}).\n"
        "Если ещё не предложено — предложи запись в AGENT-GAPS.md:\n"
        "  Категория: [prompt-gap | context-gap | logic-gap | assumption-gap | completeness-gap | scope-gap]\n"
        "  Гипотеза: одна строка почему\n"
        "  (Если уже предложил залогировать — игнорируй это напоминание)"
    )


if __name__ == "__main__":
    main()
