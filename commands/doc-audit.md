# /doc-audit — Полный аудит актуальности документации и диаграмм

> **Цель:** одной командой проверить ВСЁ содержимое документации на актуальность — все карты, все диаграммы, все ссылки, все реестры. Ручной on-demand вариант «up to date / up to code» для документов: cadence-аудиты (/architecture-audit ≥5 планов, /retro ≥15) проверяют по расписанию, deploy-gate — только перед push; между ними пропуски накапливаются невидимо. /doc-audit закрывает это окно. Closes G-122 remediation-путь / P-009 manual-вариант / BS-3 consumer-путь (ручной).

**Когда запускать:**
- Подозрение что документация отстала от кода (после серии быстрых релизов, после параллельных сессий).
- Перед onboarding нового разработчика / передачей проекта.
- После периода когда enforcement-механизм был сломан или отсутствовал (пропуски того периода cadence-проверки не поднимут).
- Просто «проверь всё сейчас» — без повода.

**⛔ НЕ дублирует соседей** (три команды — три разные оси):

| Команда | Ось | Тип проверки |
|---|---|---|
| `/doc-audit` | **mechanical freshness** — содержимое актуально? ссылки живы? копии синхронны? | script-driven, детерминированный, on-demand |
| `/architecture-audit` | **semantic drift** — SYSTEM-MAP соответствует реальному коду? | LLM-driven, cadence ≥5 планов |
| `/sync-audit` | **adoption drift** — проект догнал версию методологии? | checklist, по version-delta |

Cadence-аудиты /doc-audit **не заменяет** — semantic ≠ mechanical. Семантику стрелок/связей grep не проверит (P-009).

> **map-staleness (v6.1.0) — третья detection-ось, не семантика.** Ловит **time-drift**: компонент изменён в git позже карты, которая его описывает (маппинг из LAR «Связанные артефакты») → подсказка «сверь стрелки/labels». Это **mechanical** (commit-времена), дополняет presence (coverage) + url-freshness (mermaid-links). НЕ проверяет *верность* связи — синхронный коммит карты+кода с неверной стрелкой ось пропустит (это остаётся за `/architecture-audit` Способность D, ADR-015 detect+couple). Закрывает /diagnose root cause «содержимое диаграммы отстаёт от логики молча».

---

## Рекомендуемая модель

**Default tier:** **Fast tier (Haiku)** — команда детерминированная: запуск скрипта + представление результатов, reasoning минимальный.

**Upgrade to Default (Sonnet) if:** пользователь просит интерпретировать результаты (приоритизация WARN-долга, «что чинить первым»), или найденные FAIL требуют диагностики причин.

**❌ Не нужен Capable** — нет архитектурного анализа; если FAIL-оси указывают на системную проблему → отдельный /diagnose (там Capable).

**Mid-task escalation:** нет (single-pass).

**Pre-flight model check:** да — спроси какая модель активна (или используй подтверждённую в сессии). Если Capable для простого прогона — упомяни что Fast достаточно (cost-saving), не блокируй.

---

## Шаг 0 — Resolve doc-root

1. Прочитать `CLAUDE.local.md ## Auto-update → doc_repo_path`:
   - `doc_repo_path: <путь>` (two-repo) → передать `--doc-root <путь>`.
   - `doc_repo_path: null` или секция отсутствует (single-repo) → без аргумента (default `.`).
2. ⚠️ Не делать вывод «документации нет» если файлы не найдены в cwd — сначала проверить doc-репо (класс G-065/G-071).

---

## Шаг 1 — Прогон аудита

```bash
# Two-repo (methodology-platform):
bash scripts/doc-audit.sh --doc-root ../it-dev-methodology-documentation

# Single-repo (consumer):
bash scripts/doc-audit.sh

# «Проверить И обновить»: авто-обновить все mermaid.live ссылки (оба корня) перед проверкой:
bash scripts/doc-audit.sh --doc-root ../it-dev-methodology-documentation --fix
```

**Режимы:** дефолт = read-only прогон. `/doc-audit fix` (пользователь сказал «обнови» / «fix») → `--fix`: единственный безопасный авто-fix — mermaid-ссылки детерминированно регенерируются из кода диаграмм (`update-mermaid-links.sh`, оба корня). Содержимое диаграмм/карт `--fix` НЕ трогает — это ручной/plan-путь (Шаг 3).

Скрипт прогоняет все оси (каждая graceful-skip если не применима):

| Ось | Что проверяет | Severity |
|---|---|---|
| parity | dual-copy `scripts/` ↔ `templates/scripts/` идентичны (G-122; только methodology-platform) | FAIL |
| maps-coverage | команды/skills/скрипты присутствуют в картах; diagram-freshness; node-readability (G-121); **map-staleness** | FAIL/WARN |
| ↳ map-staleness | компонент изменён в git позже карты, которая его описывает (через LAR «Связанные артефакты») → сверь стрелки/labels диаграммы (v6.1.0) | WARN |
| mermaid-links | mermaid.live URL соответствует коду диаграммы (оба репо) | FAIL |
| mermaid-syntax | антипаттерны (транслит кириллицы и т.п.) | WARN |
| links | внутренние `.md` ссылки резолвятся | WARN |
| doc-freshness | `docs/services/*/OVERVIEW.md` «Обновлён:» vs git log | WARN |
| lar | LIVING-ARTIFACTS реестр: указанные файлы существуют | FAIL/WARN |
| artifact-map | ARTIFACT-MAP консистентность с commands/ | WARN |

---

## Шаг 1.5 — Missing artifacts check (agent-driven)

После прогона скрипта — агент проверяет наличие ожидаемых артефактов в doc-root через Glob/Read.

**Expected artifacts (проверять в doc-root):**

| Артефакт | Тип | Обязательность |
|---|---|---|
| `VISION.md` | content-heavy | обязателен |
| `PRODUCT.md` | content-heavy | обязателен |
| `DEVLOG.md` | structural | обязателен |
| `ROADMAP.md` | content-heavy | рекомендован |
| `docs/architecture/SYSTEM-MAP.md` | content-heavy | рекомендован |
| `docs/product/USER-MAP.md` | content-heavy | рекомендован |
| `docs/product/ARTIFACT-MAP.md` | content-heavy | рекомендован |
| `docs/architecture/LIVING-ARTIFACTS.md` | structural | рекомендован |
| `MARKETING.md` | content-heavy | опциональный (`--with-marketing`) |

Каждый отсутствующий файл → MISSING запись для Шага 2.
Severity: обязателен → WARN · рекомендован → INFO · опциональный → INFO.

⚠️ Two-repo: пути резолвятся от doc-root (из `CLAUDE.local.md doc_repo_path`), не от cwd code-repo.

---

## Шаг 2 — Представить результаты

Показать пользователю Summary-таблицу скрипта + интерпретацию:

1. **FAIL-оси** — перечислить с конкретными файлами. Это ошибки, чинить сейчас.
2. **WARN-оси** — сгруппировать по типу долга (stale-диаграммы / node-format миграция / битые ссылки).
3. **SKIP-оси** — упомянуть одной строкой (не применимо для этого проекта — это нормально).
4. **MISSING артефакты** — перечислить с командой создания (из Шага 3 таблицы). Сгруппировать: обязательные → рекомендованные → опциональные.

---

## Шаг 3 — Предложить fixes (порядок строгий)

1. **Auto-fixable первыми** — выполнить сразу с подтверждением:
   - stale/missing mermaid-ссылки → повторный прогон с `--fix` (обновит ссылки в ОБОИХ репо) либо точечно `bash scripts/update-mermaid-links.sh [--root DIR]`
   - после фикса — повторить упавшую ось для верификации.
2. **Missing artifacts** — для каждого MISSING из Шага 1.5:

   **Context gathering (однократно, перед всеми предложениями):**

   Trigger: ≥1 content-heavy артефакт в MISSING **И** `VISION.md` + `PRODUCT.md` оба отсутствуют.
   Если хотя бы один из них присутствует — skip (контекст уже есть, вопросы не задавать).

   ```
   📋 Для создания артефактов нужен минимальный контекст (3 вопроса):
   1. Что делает проект? (одно предложение: домен + основная функция)
   2. Кто основной пользователь? (роль/тип)
   3. Текущий статус? (идея / MVP / продакшн)
   ```

   Собранный контекст используется как prefix при предложении каждой команды.
   Команды задают свои вопросы сами — повторно не спрашивать.

   **Artifact → Command (предложить для каждого MISSING):**

   | Отсутствует | Команда | Тип |
   |---|---|---|
   | `VISION.md` | `/vision` (strategy) | content-heavy |
   | `PRODUCT.md` | `/plan [product]` | content-heavy |
   | `ROADMAP.md` | `/vision review` | content-heavy |
   | `docs/architecture/SYSTEM-MAP.md` | `/plan [code]` "создать SYSTEM-MAP" | content-heavy |
   | `docs/product/USER-MAP.md` | `/plan [product]` "создать USER-MAP" | content-heavy |
   | `docs/product/ARTIFACT-MAP.md` | `/plan [methodology]` "создать ARTIFACT-MAP" | content-heavy |
   | `MARKETING.md` | `/define-positioning` | content-heavy |
   | `DEVLOG.md` | создать из шаблона — авто, без вопросов | structural |
   | `docs/architecture/LIVING-ARTIFACTS.md` | добавить задачей в ближайший `/plan` Шаг 5 | structural |

   Structural артефакты — создать сразу с подтверждением (без контекстных вопросов).
   Content-heavy — предложить команду с кратким напоминанием собранного контекста:

   ```
   ⚠️ MISSING: VISION.md → запустить `/vision` (strategy).
      Контекст: [ответы 1-3 выше]
      Запустить сейчас? (y / позже)
   ```

3. **Ручные точечные** (stale-маркер диаграммы, битая ссылка) → предложить исправить в этой сессии, показав конкретный файл:строку.
4. **Системный долг** (миграция node-format всех карт, массовый stale) → НЕ чинить ad-hoc, предложить `/plan` с конкретным scope из результатов аудита.

**⛔ Не создавать новый реестр долга** — долг уже трекается существующими путями: RISKS.md, AGENT-GAPS/PRODUCT-GAPS, `deferred[]` (P-013). Аудит = снимок, не ledger.

---

## Граница (что /doc-audit НЕ делает)

- ❌ Не проверяет semantic drift диаграмм vs код — это `/architecture-audit` (presence ≠ semantics, P-009).
- ❌ Не проверяет adoption методологии — это `/sync-audit`.
- ❌ Не меняет файлы сам (read-only прогон); fixes — отдельными шагами с подтверждением.
- ❌ Не заменяет deploy-gate — gate остаётся последним рубежом перед push.
- ❌ Не заполняет созданные артефакты контентом — только указывает команды; каждая команда ведёт свой intake.
