# /scope-out — Визуальный обзор отложенного / out-of-scope scope

> **Цель:** показать **одной Mermaid-диаграммой** весь отложенный / непокрытый / out-of-scope scope проекта — то что осознанно НЕ сделано. Закрывает «нет визуальности» — данные живут текстом в 5+ файлах (IDEAS, PRODUCT-GAPS, AGENT-GAPS, ROADMAP, triggers.json recommendations[], last_plan_session.deferred[]), и владелец, глядя на карты, их пропускает.
>
> **Эфемерная по дизайну:** диаграмма **не сохраняется в файл** — генерируется из текстовых источников при каждом запуске и выбрасывается. Источник правды = текстовые файлы; диаграмма — производная проекция → **не может устареть** (L4: нет альтернативного пути для drift). Это НЕ 7-я постоянная карта (нет refresh policy, нет PR-coupling).

**Когда запускать:**
- Хочешь увидеть «что отложено» визуально, одним взглядом (не читая 5 файлов).
- Перешёл по anchor-узлу `📋 Отложенный scope → /scope-out` в любой living/draft карте.
- Перед `/vision review` / `/vision strategy` — обзор накопленного backlog.

**Отличие от соседей:**
- `/vision review` — **обрабатывает** IDEAS (raw → P-NNN решения). `/scope-out` — только **визуализирует** уже классифицированное, ничего не меняет.
- Draft maps Шаг 99.54 кластер — показывает отложенное **текущего плана** (per-plan, эфемерно). `/scope-out` — **весь проект** (агрегат), включает deferred[] **последнего** завершённого плана (из `triggers.json`). После закрытия сессии, draft исчезает — `/scope-out` сохраняет данные через `last_plan_session.deferred[]`.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **Low** · thinking: **OFF** (запуск скрипта + показ URL — mechanical) / **High** · thinking: **ON** (интерпретация backlog — приоритизация/кластеризация). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Fast tier (Haiku)** — команда детерминированная: запуск скрипта + представление результата, reasoning минимальный.

**Upgrade to Default (Sonnet) if:** пользователь просит интерпретировать backlog (приоритизация, кластеризация по темам, «что закрыть первым») — это reasoning поверх визуализации.

**❌ Не нужен Capable** — нет архитектурного анализа.

**Mid-task escalation:** нет (single-pass).

**Pre-flight model check:** да — спроси какая модель активна. Если на Capable/Default для простого показа — это over-powered, упомяни что Fast достаточно (cost-saving), но не блокируй.

---

## Шаг 0 — Resolve источники

1. Прочитать `CLAUDE.local.md ## Auto-update → doc_repo_path`:
   - `doc_repo_path: <путь>` (two-repo, methodology-platform) → артефакты в doc-репо → передать `--root <doc_repo_path>`.
   - `doc_repo_path: null` или секция отсутствует (single-repo consumer) → артефакты локальны → `--root` не нужен (default `.`).
   - ⚠️ **Не делать вывод "scope пуст" если файлы не найдены в cwd** — сначала проверить doc-репо (тот же класс что G-065/G-071: файл может быть в sibling-репо).

---

## Шаг 1 — Сгенерировать view

```bash
# Two-repo (methodology-platform):
bash scripts/scope-view.sh --root ../it-dev-methodology-documentation

# Single-repo (consumer):
bash scripts/scope-view.sh

# Полный backlog без дефолт-фильтра (если High+in-roadmap мало):
bash scripts/scope-view.sh --all

# Offline / нет Python для URL — показать код диаграммы:
bash scripts/scope-view.sh --print-only
```

**Что парсится** (каждый источник опционален — graceful skip если отсутствует):

| Источник | Что берётся | Цвет узла |
|---|---|---|
| `PRODUCT-GAPS.md` | `Статус: open` (🔴 High) или `in-roadmap` | 🔴 hi / 🟡 med |
| `AGENT-GAPS.md` | `Статус: open` (cap 8 в дефолте) | 🟡 med |
| `ROADMAP.md` | разделы Considered / On hold / Arch review | 🔵 road |
| `triggers.json` | `recommendations[]` status `proposed*` | 🟣 rec |
| `triggers.json` | `last_plan_session.deferred[]` (closes P-013) | 🟪 def (dashed) |

**Дефолт-фильтр (anti node-explosion):** только High severity product-gaps + in-roadmap + первые 8 agent-gaps. `--all` снимает фильтр. Скрипт пишет в stderr `SCOPE_META total=N dropped=M` — **если `dropped > 0`, упомяни пользователю** сколько скрыто и что `--all` покажет всё (no silent truncation).

---

## Шаг 2 — Показать пользователю

Вывести **голый URL на отдельной строке** (формат mermaid.live, Ctrl+Click открывает):

```
🔭 Отложенный / out-of-scope scope (фильтр: <High+in-roadmap | все>, всего N):

https://mermaid.live/edit#pako:...

📊 Скрыто дефолт-фильтром: M записей. Полный backlog: /scope-out --all
   (если dropped == 0 → строку не показывать)
```

⛔ **pako-URL ТОЛЬКО из stdout `scope-view.sh` / `mermaid-link.py`** — самостоятельная генерация невозможна (LLM не выполняет zlib deflate). L3 cite-gate: видел ли ты этот URL в stdout tool-вызова в ЭТОЙ сессии? Нет → перейти на `--print-only` (показать код).

Если `total == 0` → диаграмма покажет «✅ Нет отложенного scope». Это валидный результат, не ошибка.

---

## Граница (что /scope-out НЕ делает)

- ❌ Не пишет файлы (read-only агрегатор).
- ❌ Не меняет статусы gap'ов (это `/vision review` / `/plan`).
- ❌ Не агрегирует out-of-scope «на лету» из voida — читает только то что **захвачено на write-time** (/plan Шаг 99.3 «Не учтено → out of scope» + /review out-of-scope findings → PRODUCT-GAPS/ROADMAP). Если источники пусты — view пуст. Discovery без capture = пустая комната.

---

$ARGUMENTS
---

## Вывод простым языком (обязательно — Plain-language output rule)

Заверши вывод этой команды коротким блоком `## Простыми словами` (2-5 строк): что это значит для пользователя + конкретная committed-рекомендация / следующий шаг («Рекомендую X»), а НЕ открытый вопрос — понятным языком, без жаргона/меток. Вопрос допустим только после явной рекомендации. Остальной вывод (разбор, метки, детали) оставь как есть — резюме добавляется в конце. См. CLAUDE.md → Plain-language output rule.
