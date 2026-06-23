"""
Stop hook — scans the last Claude response AND last user message for
admission/correction phrases. When found and AGENT-GAPS.md was not recently
written, outputs a reminder so Claude proposes logging the gap.

Scope (since v4.24.0): только AGENT-GAPS (agent's reasoning failures —
"я пропустил", "ты прав", "я не предусмотрел"). НЕ записывает в
PRODUCT-GAPS.md — product coverage gaps классифицируются вручную через
/plan Шаг -4 (user feedback "продукт не покрывает X" → PRODUCT-GAPS,
не auto-detected этим hook).

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

# Research finding detection — two paths:
# (1) WebSearch + verdict keyword → Source: <url>
# (2) direct-experience: operational pattern + verdict keyword → Source: direct-experience
# Neither path fires on a single signal alone (anti-noise: both signals required per path).
# This covers incidental findings during any session (planned research uses /research command).
VERDICT_KEYWORDS = [
    r"\bviable\b",
    r"\bnot.viable\b",
    r"\bblocked\b",
    r"\bconfirmed\b",
    r"\bconditional\b",
    r"\bunclear\b",
    r"\bзапрещает\b",
    r"\bподходит\b",
    r"\bне подходит\b",
    r"\bзакрыт\b",
    r"\bподтверждено\b",
    r"\bnot.allowed\b",
    r"\bnot.permitted\b",
    r"\bprohibited\b",
    r"\bavailable\b.{0,20}\bmarket\b",
]

# Operational finding detection — execution-based constraints discovered without WebSearch.
# Requires BOTH an operational pattern AND a verdict keyword (anti-noise double requirement).
# Examples: "iproyal не подходит для SMTP" + "not-viable" → direct-experience finding.
OPERATIONAL_PATTERNS = [
    r"\bне подходит для\b",
    r"\bне работает\b.{0,60}\b(через|с|для)\b",
    r"\b(заблокировал|забанил)\b",
    r"\brate.?limit\b",
    r"\bне поддерживает\b",
    r"\bworkaround\b",
    r"\bблокирует.{0,40}\b(порт|запрос|smtp|доступ|api)\b",
    r"\bнедоступен\b",
    r"\bdoes not (support|work|allow)\b",
    r"\bnot (supported|working)\b.{0,40}\b(via|through|for|on)\b",
    r"\b(blocked|banned).{0,40}\b(request|port|smtp|api|ip)\b",
    r"\brate.?limit(ing|ed)?\b",
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


def check_websearch_used(transcript_path: str) -> bool:
    """Return True if WebSearch tool was called in the current assistant turn."""
    if not transcript_path or not os.path.exists(transcript_path):
        return False
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
        found_assistant = False
        for line in reversed(lines):
            try:
                entry = json.loads(line)
                role = entry.get("role", "")
                if role == "user":
                    if found_assistant:
                        break  # passed current turn boundary
                elif role == "assistant":
                    found_assistant = True
                    content = entry.get("content", [])
                    if isinstance(content, list):
                        for block in content:
                            if (isinstance(block, dict)
                                    and block.get("type") == "tool_use"
                                    and block.get("name") == "WebSearch"):
                                return True
            except (json.JSONDecodeError, AttributeError):
                continue
    except OSError:
        pass
    return False


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

    # Admission watchdog — runs independently of research watchdog below
    ai_admission = last_assistant and any(
        re.search(p, last_assistant, re.IGNORECASE) for p in ADMISSION_PATTERNS
    )
    user_correction = last_user and any(
        re.search(p, last_user, re.IGNORECASE) for p in USER_CORRECTION_PATTERNS
    )

    if (ai_admission or user_correction) and not gaps_recently_written():
        source = "в ответе агента" if ai_admission else "в сообщении разработчика"
        print(
            f"📋 AGENT-GAPS WATCHDOG: обнаружен признак ошибки/пропуска ({source}).\n"
            "Если ещё не предложено — предложи запись в AGENT-GAPS.md:\n"
            "  Категория: [prompt-gap | context-gap | logic-gap | assumption-gap | completeness-gap | scope-gap]\n"
            "  Гипотеза: одна строка почему\n"
            "  (Если уже предложил залогировать — игнорируй это напоминание)"
        )

    # Research watchdog — runs always (independent of admission)
    main_research(data, last_assistant)


def main_research(data: dict, last_assistant: str) -> None:
    """Research watchdog — two paths:
    (1) WebSearch + verdict keyword → Source: <url>
    (2) direct-experience: operational pattern + verdict keyword → Source: direct-experience
    Verdict keyword required for both paths (anti-noise gate).
    """
    has_verdict = last_assistant and any(
        re.search(p, last_assistant, re.IGNORECASE) for p in VERDICT_KEYWORDS
    )
    if not has_verdict:
        return

    websearch_used = check_websearch_used(data.get("transcript_path", ""))
    if websearch_used:
        source_hint = "<url>"
    else:
        has_operational = any(
            re.search(p, last_assistant, re.IGNORECASE) for p in OPERATIONAL_PATTERNS
        )
        if not has_operational:
            return
        source_hint = "direct-experience"

    print(
        "🔍 RESEARCH WATCHDOG: обнаружен вывод из исследования/опыта.\n"
        "Если вывод влияет на решение и ещё не записан — предложи строку в DEVLOG:\n"
        f"  [research:<slug>] → <что изучали>: <вывод>. <verdict>. Source: {source_hint}\n"
        "  verdict: viable / not-viable / blocked / confirmed / conditional / unclear\n"
        "  Для planned research: /research команда"
    )


if __name__ == "__main__":
    main()
