# /sync-audit — Audit methodology adoption gaps

> **Цель:** проверить какие features methodology (накопившиеся при обновлениях) **не применены** к этому проекту. Не правит сама — только **report + рекомендации `/plan` per gap**. Пользователь выбирает приоритет.

**Когда запускать:**
- Auto-trigger из `auto-update-watchdog.py` после successful sync если methodology version delta ≥ `audit_threshold` minor (default 3)
- Fallback trigger из `/plan` Шаг -3 (если auto не сработал)
- Manual: пользователь вручную после major обновлений методологии или вступления в проект

**Отличие от `/architecture-audit`:** /architecture-audit — что **построено в проекте** vs design (SYSTEM-MAP drift, AGENT-GAPS patterns). /sync-audit — что **methodology предлагает** vs **применено в проекте** (features adoption).

---

## Рекомендуемая модель

**Default tier (Sonnet)** — checklist + grep + report. Reasoning минимальный.
**Upgrade to Capable** не требуется (нет архитектурного анализа).
**Pre-flight model check:** да — спроси какая модель активна. Если на Capable — это over-powered, рекомендация Default для cost-savings.

---

## Шаг -0.5 — Remote update check (v4.44.0+)

**Цель:** убедиться что локальная копия `it-dev-methodology/` актуальна **до** delta analysis. Без этого шага delta analysis сравнивает с потенциально stale версией.

1. Определить путь к methodology: читать `CLAUDE.local.md ## Auto-update → methodology_path` (default: `../it-dev-methodology`)
2. Проверить что папка существует: если нет → показать инструкцию и перейти к Шагу 0
3. Проверить наличие новых commits на remote:
   ```
   git -C <methodology_path> fetch origin main --dry-run
   ```
4. По результату:

**Если fetch failed (exit ≠ 0, network error, auth error):**
```
⚠️ Не удалось проверить обновления methodology (сеть недоступна или нет credentials).
   Продолжаю с текущей локальной версией — delta analysis может быть неполным.
   Для ручного обновления: git -C <path> pull origin main
```
→ продолжить с локальной версией

**Если локальная версия актуальна (no new commits):**
```
✅ it-dev-methodology актуальна (нет новых commits на remote).
```
→ продолжить к Шагу 0

**Если есть новые commits:**
```
📦 Обнаружены обновления it-dev-methodology!
   Локальная: <local HEAD short>
   Remote:    <FETCH_HEAD short>

Рекомендую обновить перед анализом чтобы видеть актуальный delta.

Варианты:
  a) Обновить сейчас (если GITHUB_PAT настроен) (рекомендуется):
     bash scripts/with-secret.sh GITHUB_PAT -- git -C <path> pull origin main --ff-only

  b) Обновить вручную в терминале:
     git -C <path> pull origin main

  c) Пропустить — продолжить с текущей локальной версией (delta может быть неполным)

Выбор (a/b/c):
```

**Если выбрано (a):** выполнить pull через with-secret.sh. При ошибке (non-ff, auth) → fallback к инструкции (b).
**Если выбрано (b):** показать точную команду и ждать подтверждения "готово".
**Если выбрано (c):** продолжить с предупреждением.

**После успешного pull:** перечитать `CHANGELOG.md` с диска (обновлённый файл) перед Шагом 1b.

**Если `auto_pull: true` в `CLAUDE.local.md ## Auto-update`:** автоматически выбрать вариант (a) без вопроса. Показать только результат.

---

## Шаг 0 — Pre-flight

1. Прочитать `.claude/.version` → текущая methodology version (например `v4.22.0`)
2. Прочитать `.claude/state/triggers.json` → `last_auto_pull` (когда был последний sync) + `last_sync_audit` (когда был последний audit)
3. Если `.claude/.version` отсутствует → ⛔ «Bootstrap не выполнен — запусти `new-project-init.sh` сначала (auto-update-watchdog.py должен был это уведомить)»

---

## Шаг 1b — Version delta analysis (v4.43.0+)

**Цель:** показать что конкретно добавилось в методологии с версии consumer и что нужно сделать.

1. Взять `consumer_version` из `.claude/.version`
2. Взять `current_version` из methodology `VERSION` файла (если methodology repo доступен рядом) или из `synced_at` в `.claude/.version`
3. Открыть `CHANGELOG.md` в methodology repo (путь: рядом с methodology или `../it-dev-methodology/CHANGELOG.md`)
4. Найти все записи **выше** блока `## v{consumer_version}` — это новые milestones
5. Вывести ordered plan:

```
## Version delta: {consumer_version} → {current_version}

Найдено N новых milestones. Рекомендуемый порядок действий:

### 🔴 Critical (выполни в первую очередь)
[milestone title] (vX.Y.Z)
  Что добавилось: ...
  Команды:
    bash scripts/sync-methodology.sh .
    bash scripts/set-secret.sh KEY

### 🟡 Recommended
...

### 🟢 Optional
...

---
Следующий шаг: выполни Critical actions, затем запусти /sync-audit снова.
```

**Если CHANGELOG.md недоступен:**
```
ℹ️  CHANGELOG.md не найден — delta analysis пропущен.
   Найди methodology repo рядом и запусти sync-methodology.sh .
   Затем повтори /sync-audit.
```

**Если consumer_version = current_version:** пропустить, написать "✅ Версия актуальна".

---

## Шаг 1 — Inventory gaps (5 проверок)

Пройди по 5 gap-проверкам по порядку. Для каждой — output одной короткой секции с конкретикой.

### Gap 1: PRODUCT.md `## Логика компонентов` (v4.19.0)

**Цель:** проверить что секция существует и покрывает major компоненты кодовой базы.

1. Прочитать `PRODUCT.md` — есть ли секция `## Логика компонентов`?
2. Если есть — посчитать подсекции `### <component-name>`
3. Просканировать кодовую базу для major компонентов:
   - `src/services/*` или `services/*` (если monorepo)
   - `src/components/*` или `lib/*/*`
   - Топ-уровневые модули (`auth`, `payments`, `users`, и т.п.)
4. Output:
   - Секция отсутствует → 🔴 **High severity** — основной sync mechanism v4.19.0 не работает
   - Секция есть, покрытие < 50% компонентов → 🟡 **Medium severity** — N компонентов без секций
   - Секция есть, покрытие ≥ 80% → 🟢 OK

### Gap 2: CLAUDE.local.md `## Sync validators` (v4.20.0)

**Цель:** проверить что sync validators framework активирован.

1. Прочитать `CLAUDE.local.md` — есть ли секция `## Sync validators`?
2. Если есть — посчитать validators (yaml `- name:` блоки)
3. Output:
   - Секция отсутствует → 🟡 **Medium severity** — `/review` sync validators не сработают (но subjective checks работают)
   - Секция есть, < 3 validators → 🟢 Partial (минимум, возможно достаточно)
   - Секция есть, ≥ 5 validators → 🟢 OK

### Gap 3: CLAUDE.local.md `## Auto-update` + hook (v4.18.0)

**Цель:** проверить что auto-update механизм установлен.

1. Прочитать `CLAUDE.local.md` — есть ли секция `## Auto-update`?
2. Проверить `.claude/hooks/auto-update-watchdog.py` существует?
3. Проверить `.claude/settings.json` содержит `SessionStart` event с этим hook?
4. Output:
   - Hook отсутствует → 🟡 **Medium severity** — методология не обновляется автоматически (нужен manual `bash scripts/sync-methodology.sh .`)
   - Hook есть, секция отсутствует → 🟢 Partial (дефолты работают)
   - Всё есть → 🟢 OK

### Gap 4: Mermaid hybrid language (v4.18.0)

**Цель:** проверить что Mermaid labels в картах соответствуют hybrid правилу (RU описания + EN identifiers).

1. Grep по `docs/**/*.md` — найти Mermaid блоки (между ` ```mermaid ` и ` ``` `)
2. Sample 3-5 blocks (если их > 5) или все (если ≤ 5):
   - Проверить labels nodes/edges на полностью EN content (кроме emoji / EN identifiers типа имён файлов)
   - Antipattern: `"Hooks Layer"`, `"reads config"`, `"writes state"`, `"invokes if X"`
3. Output:
   - Найдены файлы с EN-only labels → 🟢 **Low severity** — N файлов могут требовать hybrid refactor (cosmetic, не блокирует)
   - Все labels hybrid → 🟢 OK
   - Нет Mermaid blocks → 🟢 N/A

### Gap 6: PRODUCT-GAPS.md (v4.24.0)

**Цель:** проверить что product gaps namespace отделён от agent gaps.

1. Существует ли `PRODUCT-GAPS.md` в корне проекта?
2. Если существует `AGENT-GAPS.md` И существует `PRODUCT-GAPS.md` → 🟢 OK (split применён)
3. Если есть только `AGENT-GAPS.md` без `PRODUCT-GAPS.md` → 🟡 **Medium severity** — рекомендация запустить migration script + bootstrap PRODUCT-GAPS из template
4. Если ни одного нет → 🟢 N/A (gap culture не используется в проекте)

Output:
- Оба файла OK → 🟢 split применён
- Только AGENT-GAPS → 🟡 рекомендация: `bash <methodology>/scripts/migrate-agent-to-product-gaps.sh --dry-run` + bootstrap из template

### Gap 5: Skills frontmatter spec (v4.16.2) — только если `.claude/skills/` существует

**Цель:** проверить что Agent Skills frontmatter соответствует Anthropic spec.

1. Если `.claude/skills/` не существует → 🟢 N/A (skills не используются)
2. Для каждого `.claude/skills/*/SKILL.md`:
   - `description` single-line string ≤ 1024 chars? (НЕ multi-line `description: |`)
   - `version`, `type` внутри `metadata:` блока? (НЕ top-level)
   - `name` lowercase + digits + hyphens, ≤ 64 chars, без "anthropic"/"claude"?
3. Output:
   - M skills проверено, N с нарушениями → 🔴 **High severity** если N > 0 (skills могут не активироваться корректно)
   - Все OK → 🟢 OK

### Gap 7: Mermaid live links (v4.37.0)

**Цель:** проверить что все Mermaid-блоки в проекте имеют актуальные mermaid.live ссылки (голый URL на строке перед блоком).

1. Проверить наличие `scripts/update-mermaid-links.sh` и `scripts/validate-mermaid-links.sh`:
   - Отсутствуют → 🟡 **Medium severity** — запустить `sync-methodology.sh` чтобы получить скрипты
   - Присутствуют → перейти к п. 2
2. Запустить валидацию:
   ```bash
   bash scripts/validate-mermaid-links.sh
   ```
3. Output:
   - `MISSING_LINK` или `STALE_LINK` найдены → 🟡 **Medium severity**:
     ```
     Найдены Mermaid-блоки без актуальных ссылок (MISSING/STALE).
     Запустить bash scripts/update-mermaid-links.sh и закоммитить? (y/n)
     ```
     - `y` → запустить скрипт, показать результат (`Done: N link(s) updated`), предложить закоммитить изменённые файлы
     - `n` → зафиксировать как 🟡 unresolved, продолжить audit
   - `OK` → 🟢 OK
   - Нет Mermaid-блоков в проекте → 🟢 N/A

---

## Шаг 2 — Severity assessment

Распредели gaps по severity (используя классификацию выше):

| Severity | Critically | Когда применять |
|---|---|---|
| 🔴 **High** | блокирует ключевые workflows | секция отсутствует И не существует workaround |
| 🟡 **Medium** | улучшает workflow significantly | feature недоступна но workaround есть (manual instead of automated) |
| 🟢 **Low** | cosmetic / consistency | не блокирует, polish |

---

## Шаг 3 — Report (финальный output для пользователя)

⛔ **Antipattern G-050 — НЕ оборачивай таблицу ниже в ` ``` ` code fence.** Markdown table рендерится корректно plain.

Выведи таблицу gaps с рекомендациями:

| # | Gap | Severity | Status | Рекомендуемая команда |
|---|---|---|---|---|
| 1 | PRODUCT.md ## Логика компонентов | 🔴/🟡/🟢 | [статус из Gap 1] | `/plan`: завести секцию для top-N компонентов |
| 2 | CLAUDE.local.md ## Sync validators | 🟡/🟢 | [статус из Gap 2] | `/plan`: добавить секцию с custom paths под структуру проекта |
| 3 | Auto-update hook + ## Auto-update | 🟡/🟢 | [статус из Gap 3] | `/plan`: установить hook + добавить секцию |
| 4 | Mermaid hybrid language | 🟢 | [N файлов с EN labels] | `/plan`: пройти по hybrid refactor (incremental) |
| 5 | Skills frontmatter spec | 🔴/🟢 | [N skills с нарушениями] | `/plan`: spec compliance fix |
| 7 | Mermaid live links | 🟡/🟢 | [MISSING/STALE/OK] | `bash scripts/update-mermaid-links.sh` |

**Контекст:**
- Версия в этом репо: `<from .claude/.version>` ← текущая, актуальная
- Последний sync-audit был на: `<last_sync_audit.methodology_version из triggers.json>` (или «никогда»)
- Last auto-pull: `<from triggers.json>`

⚠️ **Важно:** финальная фраза "полностью применена" должна содержать версию из `.claude/.version` (текущая), **не** из triggers.json (stale значение прошлого аудита). Пример корректной фразы: "Methodology **v4.43.0** (текущая в репо) проверена на соответствие 5 gap-классам. Audit запускался в контексте v4.43.0."

---

## Шаг 4 — Disposition обязательна

После показа таблицы — **жди явного выбора пользователя**. НЕ запускай `/plan` автоматически.

Спроси:

```
📋 Какой gap взять первым? Рекомендую начать с High severity (если есть)
   или с Gap 1 (PRODUCT components) если это первый /sync-audit — это
   основной sync mechanism, остальные validators опираются на него.

   Варианты:
   1. Запустить /plan для Gap N (укажи номер)
   2. Отложить все (записать решение в DEVLOG с причиной)
   3. Помечу некоторые как irrelevant (с обоснованием) — какие?

   Жду ответа.
```

**⛔ НЕ запускать `/plan` без явного подтверждения пользователя.**

---

## Шаг 5 — Финализация state

После того как пользователь выбрал disposition (или решил отложить):

1. Обновить `triggers.json`:
   ```json
   "last_sync_audit": {
     "date": "<ISO date>",
     "methodology_version": "<v4.X.Y>",
     "gaps_found": N,
     "gaps_high_severity": M
   }
   ```
2. Запись в DEVLOG:
   ```
   [sync-audit] YYYY-MM-DD: methodology v4.X.Y, gaps N (high M / med K / low L)
   Disposition: [запуск /plan для Gap N / отложено: причина / некоторые irrelevant: причины]
   ```

---

## Ограничения

- /sync-audit покрывает 7 features (v4.16.0-v4.37.0). При добавлении нового feature class в methodology — нужно добавить новую Gap-секцию в эту команду.
- Mermaid labels check (Gap 4) — sample-based (3-5 blocks), не exhaustive. Полный hybrid refactor требует отдельного /plan.
- Path patterns для Gap 1 (поиск major компонентов) могут не работать для monorepo / non-standard структур — graceful skip с сообщением «не могу определить структуру, проверь вручную».
- Не запускает /plan сам — намеренно. Каждый gap может требовать архитектурного решения (где path patterns? создать секции для каких компонентов?). Пользователь решает.

---

$ARGUMENTS
