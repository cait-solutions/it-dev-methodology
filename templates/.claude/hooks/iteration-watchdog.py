"""
PostToolUse hook — iteration-depth watchdog (L4 reasoning-escalation regulator).

Wired in .claude/settings.json under "hooks.PostToolUse" matcher "Edit|Write".
Always exits 0 (non-blocking side-effect hook).

WHY (closes G-082): /code Шаг 1.5 Complexity reassessment имеет escalation-триггеры
ТОЛЬКО про масштаб (≥3 файла, ≥50 файлов, out-of-scope). Reasoning-depth проблемы
(битьё об один сложный баг N итераций без сходимости) структурно невидимы — задача
"маленькая" по объёму. erp G-047: sidebar animation, 1 файл, Sonnet циклил
поверхностными фиксами (overflow-hidden ×N), не эскалировал; Opus решил за раз через
pattern-comparison с эталоном.

L4 а не L3: G-049 эмпирически показал что агент ИГНОРИРУЕТ собственные правила
(2× подряд просил console-команды несмотря на правило). Self-check чекбокс в Шаге 1.5
(L3) — тот же класс который провалился. Hook (L4) считает РЕАЛЬНЫЕ Edit-итерации
независимо от того читает ли агент свои правила — внешний регулятор.

МЕХАНИЗМ — двухступенчатая escalation ladder:
- Считает повторные Edit/Write одного frontend-файла (.vue/.css/.tsx/.jsx/.svelte/.html)
  в пределах одного git HEAD (= "до следующего commit").
- **Ступень 1** на N-й итерации (default 3) → сигнал АГЕНТУ: «СТОП поверхностные патчи →
  reasoning-подход (pattern-comparison с эталоном + измерь реальный DOM)». Шанс текущей
  модели решить через reasoning, без эскалации модели.
- **Ступень 2** на N2-й итерации (default N+2 = 5) → сигнал ПОЛЬЗОВАТЕЛЮ: ступень-1
  reasoning-подход не помог (баг всё ещё не сходится) → «начни новую сессию + переключись
  на Capable (Opus) reasoning-модель — задача deep-reasoning, текущая не сходится».
- State: .claude/state/edit-iterations.json — {file: {count, head, stage2_shown}}.
- Reset-on-commit: при смене git HEAD счётчик файла сбрасывается (новый commit =
  предыдущая итерация завершилась успешно). Это закрывает RPN-150 (counter врёт
  между задачами).
- Ступень-2 сообщение одноразовое per cycle (stage2_shown flag) — не спамит каждую
  итерацию после N2 если пользователь осознанно продолжает.

WHY ladder (user feedback 2026-06-06): один сигнал на пороге был недостаточен — нужна
прогрессия «сначала дай текущей модели шанс на reasoning-подход (ступень 1), и только
если НЕ помогло — эскалируй к пользователю на смену модели/сессии (ступень 2)». Смена
модели = действие пользователя (Граница 8, model-tier rule: self-switch невозможен).

Config: CLAUDE.local.md секция "## Iteration watchdog":
    ## Iteration watchdog
    threshold: 3
    threshold_escalate: 5
    extensions: .vue .css .tsx .jsx .svelte .html .scss

Дефолты используются если секция отсутствует (threshold_escalate default = threshold + 2).
"""
import json
import os
import re
import subprocess
import sys

DEFAULT_THRESHOLD = 3
DEFAULT_EXTENSIONS = (".vue", ".css", ".scss", ".tsx", ".jsx", ".svelte", ".html")

STATE_REL = os.path.join(".claude", "state", "edit-iterations.json")


def parse_config():
    """Читает ## Iteration watchdog из CLAUDE.local.md. Возвращает (threshold, threshold_escalate, extensions)."""
    threshold = DEFAULT_THRESHOLD
    threshold_escalate = None  # default = threshold + 2 (вычисляется после парсинга)
    extensions = DEFAULT_EXTENSIONS
    for candidate in ("CLAUDE.local.md", "../CLAUDE.local.md"):
        if not os.path.exists(candidate):
            continue
        try:
            text = open(candidate, encoding="utf-8-sig").read()
        except Exception:
            continue
        m = re.search(r'##\s+Iteration watchdog\s*\n(.*?)(?=\n##\s|\Z)', text, re.DOTALL)
        if not m:
            break
        section = m.group(1)
        tm = re.search(r'^\s*threshold:\s*(\d+)', section, re.MULTILINE)
        if tm:
            threshold = int(tm.group(1))
        em2 = re.search(r'^\s*threshold_escalate:\s*(\d+)', section, re.MULTILINE)
        if em2:
            threshold_escalate = int(em2.group(1))
        em = re.search(r'^\s*extensions:\s*(.+)$', section, re.MULTILINE)
        if em:
            exts = tuple(e if e.startswith(".") else "." + e
                         for e in em.group(1).split())
            if exts:
                extensions = exts
        break
    if threshold_escalate is None or threshold_escalate <= threshold:
        threshold_escalate = threshold + 2
    return threshold, threshold_escalate, extensions


def git_head():
    """Текущий git HEAD (short) или '' если не git-репо/недоступен."""
    try:
        r = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def load_state(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8-sig") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(path, state):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
    except Exception:
        pass


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
    if not file_path:
        sys.exit(0)

    threshold, threshold_escalate, extensions = parse_config()

    # Только frontend/visual файлы — reasoning-depth проблема острее всего там
    # (CSS/DOM рендеринг не выводится из source, нужно измерение — урок G-039/G-047).
    if not file_path.lower().endswith(extensions):
        sys.exit(0)

    head = git_head()
    state = load_state(STATE_REL)

    # Normalize key (basename достаточно — разные пути одного файла редки в сессии)
    key = os.path.normpath(file_path)
    entry = state.get(key, {})

    # Reset-on-commit: если HEAD сменился с прошлой итерации → предыдущий цикл
    # завершился (закоммичен), счётчик обнуляется. (RPN-150 mitigation)
    if entry.get("head") != head:
        entry = {"count": 0, "head": head, "stage2_shown": False}

    entry["count"] = entry.get("count", 0) + 1
    entry["head"] = head
    entry.setdefault("stage2_shown", False)

    name = os.path.basename(file_path)

    # Ступень 2 (N2): ступень-1 reasoning-подход не помог — баг всё ещё не сходится.
    # Эскалация к ПОЛЬЗОВАТЕЛЮ (смена модели/сессии — действие пользователя, не агента).
    # Одноразово per cycle (stage2_shown) — не спамить если пользователь осознанно продолжает.
    if entry["count"] >= threshold_escalate and not entry["stage2_shown"]:
        entry["stage2_shown"] = True
        state[key] = entry
        save_state(STATE_REL, state)
        print(
            f"\n🛑 ITERATION-WATCHDOG СТУПЕНЬ 2: {name} редактировался {entry['count']}× без commit.\n"
            f"   Ступень-1 reasoning-подход (pattern-comparison + DOM-измерение) НЕ помог —\n"
            f"   баг не сходится на текущей модели. Это deep-reasoning задача.\n"
            f"   РЕКОМЕНДАЦИЯ ПОЛЬЗОВАТЕЛЮ:\n"
            f"   • Закрой эту сессию → начни НОВУЮ сессию на Capable (Opus) reasoning-модели.\n"
            f"   • Чистый контекст + сильнее reasoning обычно решает то на чём слабее модель циклит\n"
            f"     (эмпирика G-082: Sonnet циклил sidebar, Opus решил за раз через pattern-comparison).\n"
            f"   (Порог ступени-2={threshold_escalate}, настраивается: CLAUDE.local.md ## Iteration watchdog → threshold_escalate.)",
            file=sys.stderr,
        )
        sys.exit(0)

    state[key] = entry
    save_state(STATE_REL, state)

    # Ступень 1 (N): дать ТЕКУЩЕЙ модели шанс на reasoning-подход (без эскалации модели).
    if entry["count"] >= threshold:
        print(
            f"\n🔁 ITERATION-WATCHDOG СТУПЕНЬ 1: {name} редактировался {entry['count']}× без commit.\n"
            f"   Это сигнал reasoning-depth проблемы (не scope) — N локальных фиксов одного\n"
            f"   visual/CSS/поведенческого бага вместо root-cause.\n"
            f"   ДЕЙСТВИЯ НА ТЕКУЩЕЙ МОДЕЛИ (см. /code Шаг 1.5 + G-047/G-039):\n"
            f"   1. Останови локальные патчи. Найди РАБОТАЮЩИЙ эталон-аналог (grep похожий\n"
            f"      компонент) и сравни МЕХАНИЗМ, не симптом.\n"
            f"   2. Измерь реальный DOM (Playwright/getBoundingClientRect), не рассуждай из source.\n"
            f"   Если это не поможет — на {threshold_escalate}-й итерации watchdog предложит\n"
            f"   пользователю сменить модель/сессию (ступень 2).\n"
            f"   (Порог ступени-1={threshold}, настраивается в CLAUDE.local.md ## Iteration watchdog.)",
            file=sys.stderr,
        )

    sys.exit(0)


if __name__ == "__main__":
    sys.exit(main())
