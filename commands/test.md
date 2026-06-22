# /test — Оркестратор тестирования приложения

> **Цель:** обнаружить Frontend и Backend баги (технические, логические, визуальные) в разрабатываемом приложении консьюмера. Навигатор + оркестратор: выбирает уровень теста, помогает сгенерировать недостающие, запускает их **в консьюмер-проекте**, найденное → CODE-GAPS.md. **Advisory** — сообщает результат, не блокирует merge (вердикт о корректности кода — за разработчиком, Граница 12).

**ЗАПРЕЩЕНО:** выносить блокирующий вердикт о корректности кода консьюмера (это работа разработчика + линтеров). Методология **ведёт** тестирование, не **исполняет** движок и не судит код. Реальный прогон — агент в окружении консьюмера.

> Запускается **по запросу** (как `/marketing`), не авто-триггер. Знание как писать тесты — в skill `testing-strategy` (auto-activation). Эта команда оркестрирует прогон.

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **High** · thinking: **ON** — генерация тестов = понимание acceptance criteria (reasoning). Баг не сходится за N итераций → deep-reasoning, остаётся High+ON. См. `.claude/model-tiers.md` § Effort & Thinking.

**Strategy:** Default (Sonnet) — основной выбор для генерации и запуска тестов.

**Default tier (Sonnet):** Достаточна для генерации E2E/contract/visual тестов, запуска, разбора результатов, записи в CODE-GAPS.

**Upgrade to Capable tier (Opus) if:**
- Логический баг не воспроизводится — нужен глубокий анализ механизма (reasoning-depth, как `/code` Шаг 1.5)
- N-я итерация (N≥3) над одним visual/поведенческим багом без root cause
- Генерация property-based инвариантов для нетривиальной бизнес-логики
- L2 regression suite на большом приложении (cross-module анализ)

**❌ Fast tier (Haiku):** НЕ рекомендуется
- Генерация тестов требует понимания acceptance criteria и edge-входов
- Допустимо только для запуска уже существующего suite (без генерации) + чтение pass/fail

**Mid-task escalation:** **да** — если логический/visual баг не сходится после 2-3 попыток (тот же reasoning-depth сигнал что `/code` Шаг 1.5 — измерь реальный DOM, найди эталон-аналог, рассмотри upgrade).

**Pre-flight model check:** **да — при старте** спроси пользователя какая модель активна (или используй подтверждённую в сессии) и сравни с Default. Если mismatch ≥ 2 ступени — пауза + рекомендация.

---

## Навигационная карта по project_type

`/test` ведёт себя по-разному в зависимости от `project_type` (из `CLAUDE.md` / `CLAUDE.local.md`). Стек-специфика — в skill `testing-strategy` + `.claude/rules/<stack>.md`, не здесь.

| project_type | L1 focused | L2 regression | Visual | Основные инструменты |
|---|---|---|---|---|
| `web-app` | ✓ E2E flows | ✓ полный suite | ✓ snapshot/AI | Playwright/Cypress + visual |
| `api-service` | ✓ contract + integration | ✓ + schema fuzzing | — | Pact + Schemathesis |
| `ai-agent` | ✓ E2E + behavior | ✓ + state-pollution | (если UI) | E2E + property-based |
| `cli-tool` | ✓ smoke + stdout snapshot | ✓ | — | нативный + snapshot |
| `library` | ✓ unit + property-based | ✓ | — | Hypothesis/fast-check |
| **non-dev** (content/lead-gen) | domain-проверка ИЛИ N/A | N/A | N/A | ссылки/данные консистентны? иначе явный `N/A — нет автоматизируемых code-тестов` |

⛔ Если project_type не поддерживает автоматизируемые тесты (non-dev, или нет фреймворка) → явно вывести `N/A — [причина]`, не пытаться форсировать Playwright. Это не провал — это корректное вырождение (QB10).

---

## Шаг 0 — Контекст и уровень

1. Прочитать `project_type`, стек (из `CLAUDE.md` / `.claude/rules/`).
2. Определить **уровень** запрашиваемого теста:
   - **L1 focused** (`/test` / `/test <feature>`): тесты на затронутую фичу/задачу — happy + edge.
   - **L2 regression** (`/test regression`): весь накопленный suite + visual baseline — «тяжёлая артиллерия», перед prod.
   - **visual** (`/test visual`): только visual regression против baseline.
3. Если фреймворк тестов не настроен → предложить установку (`npx playwright install`, `pip install schemathesis`) ИЛИ explicit skip с причиной.

---

## Шаг 1 — Генерация недостающих тестов (если нужно)

Активируется skill `testing-strategy` (знание per стек). По acceptance criteria задачи:
- **Frontend:** E2E user-flow (проверяет **результат бизнес-логики**, не только рендер) + visual snapshot.
- **Backend:** contract test (Pact) если есть FE↔BE; Schemathesis из OpenAPI/GraphQL; property-based для логики.
- **Логические баги:** property-based инварианты («для любого входа X держится Y»), не только примеры.

Не дублировать существующие тесты — grep что уже покрыто.

---

## Шаг 2 — Запуск в консьюмер-проекте

⛔ Реальный прогон — в окружении консьюмера, не методология:
```bash
npx playwright test            # web E2E + visual
npx playwright test --update-snapshots   # обновить baseline при намеренном UI-изменении
schemathesis run <schema-url>  # API fuzzing
pytest / npm test              # unit/integration/property
```

Visual: первый прогон создаёт baseline (версионируется в консьюмер-репо). Регрессия baseline ≠ намеренное изменение — разобраться, не слепо обновлять.

---

## Шаг 3 — Найденное → CODE-GAPS.md

Для каждого найденного бага — запись в `CODE-GAPS.md` (consumer-owned):
- `Bug-ID: C-NNN`, категория (открытый список: frontend-visual / frontend-logic / backend-contract / backend-crash / regression / perf / …), severity, симптом, expected/actual, статус `open`.
- Если фикс делается сразу (мелкий) → после фикса статус `fixed` + DEVLOG `[fix:X]` + `[test-found:category]`.

⛔ **CODE-GAPS.md отсутствует** в проекте → создать из `templates/CODE-GAPS.md.template` (bootstrap мог его не создать на старом проекте — `sync-methodology.sh` / ручное копирование).

---

## Шаг 4 — Вывод (advisory)

```
🧪 Тестирование: [уровень] — [project_type]

Запущено: [N тестов / suite]
✅ Прошло: [N]
🔴 Упало: [N] → CODE-GAPS C-NNN..C-MMM (категории)

Найденные баги (в CODE-GAPS.md, статус open):
- C-NNN [категория] severity — [симптом]

Рекомендация: [исправить C-NNN до prod / regression-guard добавить / acceptable]
```

⛔ **Advisory, не блок:** `/test` сообщает результат и рекомендацию. Решение «продолжать с падающими тестами или нет» — за разработчиком (Граница 12). Блокирующий gate в `/deploy` — отдельная фаза методологии (разблокируется по подтверждённому сигналу), не в этой команде.

**Связь с другими командами:**
- `/review` Шаг 3 проверяет что CODE-GAPS обновлён и тесты запускались (процессная валидация, не повторный прогон).
- `/diagnose` — если баг из CODE-GAPS не воспроизводится / непонятен root cause.
- `/code` — фикс найденного бага (обновляет статус CODE-GAPS → fixed/regression-guard).

---

$ARGUMENTS
