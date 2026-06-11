# /sync-audit — Audit methodology adoption gaps

> **Цель:** проверить какие features methodology (накопившиеся при обновлениях) **не применены** к этому проекту, и **самостоятельно починить** то что чинится детерминированно.
>
> **Two-tier disposition (v4.58.0 — user-friendly «одна команда делает всё»):**
> - **Self-heal (авто, без вопроса):** детерминированные идемпотентные fix'ы где ответ единственный — stale-скрипты (авто-sync), mermaid-ссылки формат (авто update-mermaid-links), очистка placeholder'ов. Consumer запускает ТОЛЬКО `/sync-audit` — остальное делается само.
> - **Report + рекомендация (требует решения):** неоднозначные gaps где нужен выбор человека (создать секцию PRODUCT.md, исправить broken link на правильный путь, добавить validators) → `/plan` per gap.
>
> ⛔ НЕ просить пользователя запускать `bash scripts/...` вручную для self-heal класса — это и есть та работа которую `/sync-audit` делает за него.

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

> **⛔ Живой upstream HEAD, не stale local ref (closes G-088 — класс «фикс не доезжает молча»).** Реальный инцидент: ERP-клон v4.68.0, upstream v5.13.0, `/sync-audit` сказал «актуальна». Причина: `git fetch --dry-run` мог тихо упасть (auth) или быть пропущен → дальше Шаг 1b сравнивал **локальный** stale VERSION с `.claude/.version` (оба v4.68) → ложное «актуальна». Фикс: сравнивать против **живого** `git ls-remote` (читает upstream HEAD напрямую, без обновления локального ref, работает на shallow-клонах). fetch-fail → verdict «**НЕ смог проверить**», НЕ «актуальна».

1. Определить путь к methodology: читать `CLAUDE.local.md ## Auto-update → methodology_path` (default: `../it-dev-methodology`)
2. Проверить что папка существует: если нет → показать инструкцию и перейти к Шагу 0
3. Получить **живой upstream HEAD** и сравнить с локальным:
   ```
   remote_head=$(git -C <methodology_path> ls-remote origin -h refs/heads/main | cut -f1)
   local_head=$(git -C <methodology_path> rev-parse HEAD)
   ```
   `ls-remote` — read-only сетевой вызов, читает HEAD ветки **на remote сейчас** (не обновляет локальный `origin/main` ref → не зависит от того когда последний раз делали fetch; работает на shallow-клонах).
4. По результату:

**Если `ls-remote` failed (exit ≠ 0 / пустой `remote_head` — network/auth):**
```
⚠️ НЕ смог проверить upstream methodology (сеть недоступна или нет credentials).
   ⛔ Версионная актуальность НЕ подтверждена — это НЕ «актуальна».
   Delta analysis ниже основан на ЛОКАЛЬНОЙ версии и может быть неполным/устаревшим.
   Проверь вручную: git -C <path> ls-remote origin -h refs/heads/main  (сравни с git -C <path> rev-parse HEAD)
   Обновить: git -C <path> pull origin main
```
→ продолжить с локальной версией, **но пометить verdict как `unverified`** (Шаг 1b обязан показать «версия не подтверждена», не «актуальна»).

**Если `remote_head == local_head` (upstream HEAD совпадает с локальным):**
```
✅ it-dev-methodology актуальна (upstream HEAD = локальный, проверено через ls-remote).
```
→ продолжить к Шагу 0

**Если `remote_head != local_head` (upstream впереди) — АВТО-PULL ПО УМОЛЧАНИЮ (closes G-094):**

Дефолт = обновить автоматически **без вопроса**. `git pull --ff-only` неразрушающий (при diverged-клоне просто фейлится, не теряет данные), поэтому подтверждение не нужно. Вопрос показывается ТОЛЬКО при явном `auto_pull: false` (opt-out для осторожных — см. ниже).

```
📦 Обнаружены обновления it-dev-methodology — обновляю автоматически...
   Локальная: <local_head short> → Remote: <remote_head short>
```

**Pre-pull проверка чистоты дерева (ОБЯЗАТЕЛЬНО до pull — closes «коммиты нужно закрыть до pull»):**
```bash
git -C <path> status --porcelain
```
- **Вывод НЕ пустой (есть незакоммиченные/неотслеживаемые правки в клоне методологии)** → НЕ делать pull вслепую (`--ff-only` упадёт «would be overwritten» / «unstaged changes»). Явно:
  ```
  ⚠️ Авто-pull отложен: в клоне методологии (<path>) есть незакоммиченные изменения.
     git pull их затронет. Закрой их сначала — один из вариантов:
       git -C <path> status                  # посмотреть что не закоммичено
       git -C <path> stash                   # отложить временно → после pull: git -C <path> stash pop
       git -C <path> add -A && git -C <path> commit -m "..."   # ИЛИ закоммитить
     Затем повтори /sync-audit.
  ```
  → пометить verdict `stale` (обновление не применено), продолжить с локальной версией. НЕ запускать pull.
- **Вывод пустой (дерево чистое)** → продолжить к pull.

Выполнить (только при чистом дереве):
```bash
git -C <path> pull origin main --ff-only
```
(публичный репо — credentials не нужны; работает с GitHub / GitLab / любым git-хостингом)

**Обработка результата pull:**
- ✅ **Успех** → перейти к auto-apply (ниже).
- ❌ **Non-ff (diverged — локальные правки в клоне методологии)** → НЕ молчать, явно:
  ```
  ❌ Авто-pull не прошёл: клон методологии разошёлся с upstream (non-ff).
     В <path> есть локальные коммиты/правки. Разреши вручную:
       git -C <path> status          # посмотреть что локально
       git -C <path> pull origin main --rebase   # ИЛИ закоммить/stash + pull
     Затем повтори /sync-audit.
  ```
  → пометить verdict `stale` (обновление не применено), продолжить с локальной версией.
- ❌ **Auth/network ошибка** → показать:
  ```
  ❌ Авто-pull не прошёл (сеть/auth). Настрой gh и повтори:
       gh auth login
       git -C <path> pull origin main --ff-only
  ```
  → пометить verdict `unverified`.

**После успешного pull — auto-apply (self-heal, без вопроса, closes G-092):**
```bash
bash scripts/sync-methodology.sh .
```
- ✅ OK → сообщить (⚠️ restart-предупреждение ОБЯЗАТЕЛЬНО — closes G-098):
  ```
  ✅ Методология обновлена и применена (commands/, hooks/ актуальны на диске).

  ⚠️ ПЕРЕЗАПУСТИ СЕССИЮ Claude Code — иначе НЕ вступит в силу:
     Команды (/sync-audit, /plan, /code, …) загружаются в контекст ОДИН РАЗ при старте сессии.
     ТЕКУЩАЯ сессия держит СТАРЫЕ версии команд. Всё что ты увидишь до рестарта —
     поведение СТАРОЙ версии (напр. старые правила auto_pull, старые шаги), не обновлённой.
     Файлы на диске уже новые — но активная сессия их перечитает только после рестарта.
  ```
- ❌ Failed → показать ошибку + `⚠️ Pull прошёл но sync-apply упал — запусти вручную: bash scripts/sync-methodology.sh .`

Затем перечитать `CHANGELOG.md` с диска (обновлённый файл) перед Шагом 1b.

**Opt-out — `auto_pull: false` в `CLAUDE.local.md ## Auto-update`** (для осторожных, кто хочет контроль над клоном методологии):
показать вопрос вместо авто-pull:
```
📦 Обнаружены обновления it-dev-methodology!
   Локальная: <local_head short> → Remote: <remote_head short>
Обновить сейчас? (y = pull+apply / n = пропустить с verdict stale)
```
- **y** → выполнить pull (та же обработка результата выше) + auto-apply.
- **n** → продолжить, **пометить verdict `stale`** — Шаг 1b ОБЯЗАН показать «📦 устарел на N, обновись», НЕ «актуальна». Тихий фолбэк на «актуальна» при known-stale = нарушение (G-088).

> **Семантика `auto_pull` (инвертирована в v5.20.0, closes G-094):** поле **отсутствует / `true`** → авто-pull дефолтом (без вопроса). **`false`** → вернуть вопрос y/n (opt-out для осторожных). Раньше было наоборот (default спрашивал, true=авто) — половинчатая автоматизация: G-092 авто-applied sync ПОСЛЕ pull, но сам pull оставался за вопросом.

> **⛔ Verdict propagation в Шаг 1b (closes G-088):** результат Шага -0.5 — один из трёх: `up-to-date` (HEAD совпал) / `stale` (upstream впереди, обновление пропущено/не сделано) / `unverified` (ls-remote failed). Шаг 1b и финальный Итог обязаны отразить ИМЕННО этот verdict. `stale` → «устарел на N версий, обновись». `unverified` → «актуальность НЕ подтверждена». **Только `up-to-date` даёт право написать «актуальна».** Сравнение локального VERSION с `.claude/.version` (оба могут быть stale синхронно) НЕ является подтверждением актуальности относительно upstream.

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

**Если consumer_version = current_version:**
- **И verdict Шага -0.5 = `up-to-date`** → "✅ Версия актуальна (подтверждено живым ls-remote)".
- **И verdict = `stale`** → ⛔ НЕ «актуальна»: "📦 Локальный клон совпадает с consumer (оба `<version>`), НО upstream впереди (`<remote_head>`). Клон устарел — `git -C <methodology_path> pull origin main`, затем повтори /sync-audit для актуального delta." *(closes G-088: consumer_version = current_version значит только что consumer синхронен СО СВОИМ клоном — НЕ что клон актуален относительно upstream.)*
- **И verdict = `unverified`** → "🟡 Локально consumer = клон (`<version>`), но upstream НЕ проверен (ls-remote failed). Актуальность относительно GitHub не подтверждена."

---

## Шаг 1.5 — Run format-migrations (self-heal, v4.58.0)

> **Единая точка обновления consumer'ов.** Когда методология меняет ФОРМАТ уже заполненного артефакта (mermaid-ссылка, placeholder'ы, обёртки секций), `sync-methodology.sh` сам по себе НЕ трогает заполненный пользователем контент — он overwrite-canonical для methodology-owned файлов, но не трансформирует project-owned артефакты. Этот разрыв закрывает **migration registry** (Flyway/Alembic pattern): каждое format-изменение = версионированный migration-файл с idempotent transform. `/sync-audit` прогоняет миграции автоматически.
>
> **Расширяемость (структурная):** новое format-улучшение методологии = новый файл `scripts/migrations/v<X.Y.Z>-<id>.sh`. Команда `/sync-audit` **НЕ меняется** — runner подхватывает все миграции из директории. Это и есть «новое учитывается автоматически».

1. **Убедиться что migrations синхронизированы** (consumer мог быть на stale версии без них):
   ```bash
   # Если scripts/migrations/ отсутствует или _runner.sh нет → авто-sync (self-heal):
   test -f scripts/migrations/_runner.sh || bash <methodology_path>/scripts/sync-methodology.sh .
   ```
2. **Прогнать runner:**
   ```bash
   bash scripts/migrations/_runner.sh .
   ```
   Runner: для каждой миграции из `scripts/migrations/v*.sh` — если ещё не применена (по `.claude/state/migrations-applied.txt`) И `detect` находит старый формат → `auto` миграция применяется сама (idempotent), `report` миграция выводится для решения человека.
3. **Распарсить вывод runner:**
   - `HEALED: <id> — <описание>` → 🟢 автоматически починено (внести в Шаг 3 отчёт + список изменённых файлов для коммита).
   - `REPORT: <id> — <описание>` → 🟡 требует решения человека → рекомендация `/plan`.
   - `SKIPPED` → уже применено / не нужно (молча).

⛔ **Это и есть user-friendly «одна команда».** Consumer запускает только `/sync-audit` — миграции форматов применяются сами. НЕ просить запускать `update-mermaid-links.sh` / migration-скрипты вручную.

---

## Шаг 1 — Inventory gaps (5 проверок)

Пройди по 5 gap-проверкам по порядку. Для каждой — output одной короткой секции с конкретикой.

### Gap 1: PRODUCT.md `## Логика компонентов` (v4.19.0)

**Цель:** проверить что секция существует и покрывает major компоненты кодовой базы.

⛔ Discipline-creating: «покрытие < 50%» требует **двух чисел** (documented / total), не оценки на глаз.

1. Есть ли секция `## Логика компонентов` в `PRODUCT.md`? Посчитать подсекции:
   ```bash
   grep -c "^### " PRODUCT.md   # documented = число подсекций
   ```
2. Посчитать total major-компонентов кодовой базы (адаптировать под структуру):
   ```bash
   find src/services src/components lib -maxdepth 1 -type d 2>/dev/null | wc -l   # total
   # methodology-platform / non-standard struct: компонентов нет → coverage N/A (см. ниже)
   ```
3. Вычислить: `coverage = documented / total`. Output по числу:
   - Секция отсутствует → 🔴 **High** — sync mechanism v4.19.0 не работает
   - `coverage < 0.5` → 🟡 **Medium** — `{total − documented}` компонентов без секций (перечислить какие)
   - `coverage ≥ 0.8` → 🟢 OK
   - `total = 0` (methodology-platform / нет runtime-компонентов) → 🟢 **N/A** — у продукта нет кодовых компонентов для `## Логика компонентов`
⛔ Severity без показанных чисел documented/total = Gap 1 не проверен.

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
   - Antipattern (EN-only): `"Hooks Layer"`, `"reads config"`, `"writes state"`, `"invokes if X"`
   - Antipattern (транслитерация): `"Stanet"`, `"Zapuskaet"`, `"dobavlen"` — русские слова латиницей НЕ являются RU
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

### Gap 7: Mermaid live links (v4.37.0; migration-based v4.58.0)

**Цель:** все Mermaid-блоки имеют актуальные ссылки в новом формате (голый URL). **Формат-миграция уже выполнена в Шаге 1.5** (`mermaid-bare-url` migration, auto/idempotent — closes G-072: stale-консьюмер чинится сам). Здесь — только финальная валидация что не осталось реальных (не-формат) проблем.

1. Запустить валидацию (формат уже починен миграцией):
   ```bash
   bash scripts/validate-mermaid-links.sh
   # two-repo: также --root <doc_repo_path>
   ```
2. Output:
   - `OK` → 🟢 (миграция Шага 1.5 привела формат к актуальному).
   - `MISSING_LINK`/`STALE_LINK` всё ещё есть после миграции → 🔴 **High**: это РЕАЛЬНАЯ проблема (не формат) — диаграмма изменилась но URL не перегенерён, или блок не покрыт миграцией. Эскалировать.
   - Нет Mermaid-блоков → 🟢 N/A.

### Gap 8: Internal link integrity (v4.55.0 — Docs-as-Code)

**Цель:** проверить что markdown-ссылки `[...](path)` на локальные файлы резолвятся (не битые). Ловит class G-076: артефакт ссылается на файл которого нет (typo / перемещён / two-repo артефакт указан локальным путём вместо `../<doc-repo>/`).

1. Проверить наличие `scripts/validate-links.sh`:
   - Отсутствует → **авто-sync** `bash <methodology_path>/scripts/sync-methodology.sh .` (self-heal: получить скрипт сам, не просить юзера), затем п. 2
   - Присутствует → п. 2
2. Запустить: `bash scripts/validate-links.sh`
3. Output:
   - `BROKEN_LINK` найдены → 🔴 **High severity**: список битых ссылок (file:line). **Report, не auto-fix** — выбор правильного пути неоднозначен (typo? перемещён? two-repo `../<doc_repo_path>/...`?), нужно решение человека → рекомендация `/plan` или точечная правка.
   - `OK` → 🟢 OK

### Gap 9: ROADMAP.md «Визуальный roadmap» секция (v5.26.0)

**Цель:** проверить что ROADMAP.md содержит секцию `## Визуальный roadmap` с mermaid-блоком. Применимо если ROADMAP.md существует (без него N/A).

1. Проверить наличие `ROADMAP.md` (или `<doc_repo_path>/ROADMAP.md` в two-repo):
   - Не существует → 🟢 N/A
2. Grep на секцию:
   ```bash
   grep -q "## Визуальный roadmap" ROADMAP.md && echo PRESENT || echo MISSING
   ```
3. Если секция есть — проверить наличие mermaid-блока внутри неё:
   ```bash
   grep -A 5 "## Визуальный roadmap" ROADMAP.md | grep -q '```mermaid' && echo HAS_MERMAID || echo NO_MERMAID
   ```
4. Output:
   - Секция отсутствует → 🟡 **Medium** — ROADMAP.md без визуализации: добавить по шаблону из `templates/ROADMAP.template.md ## Визуальный roadmap`; автоматически добавить нельзя (контент project-owned). **Report**, не self-heal.
   - Секция есть, mermaid-блок есть, URL валиден (Gap 7 уже проверяет) → 🟢 OK
   - Секция есть, mermaid-блок есть, URL stale → покрывается Gap 7 (STALE_LINK)
   - Секция есть, mermaid-блок отсутствует → 🟡 **Medium** — секция-заглушка без диаграммы (добавить код по шаблону)

### Gap 10: LIVING-ARTIFACTS.md presence (v5.30.0)

**Цель:** проверить что Living Artifact Registry создан — единая точка lifecycle для всех механизмов/артефактов проекта.

1. Определить путь к LAR (прочитать `CLAUDE.local.md ## Auto-update → doc_repo_path`):
   - single-repo (`doc_repo_path: null`): `docs/architecture/LIVING-ARTIFACTS.md`
   - two-repo: `<doc_repo_path>/docs/architecture/LIVING-ARTIFACTS.md`

2. Проверить наличие файла:
   ```bash
   # single-repo:
   test -f docs/architecture/LIVING-ARTIFACTS.md && echo PRESENT || echo MISSING
   # two-repo (пример):
   test -f ../it-dev-methodology-documentation/docs/architecture/LIVING-ARTIFACTS.md && echo PRESENT || echo MISSING
   ```

3. Если PRESENT — запустить `validate-lar.sh` (если скрипт доступен).
   Читать `CLAUDE.local.md ## Auto-update → doc_repo_path` чтобы определить тип репо:
   ```bash
   # single-repo (doc_repo_path: null или не задан):
   bash scripts/validate-lar.sh

   # two-repo (doc_repo_path задан, напр. ../it-dev-methodology-documentation):
   # --root = code-repo (где живут scripts/, templates/, commands/)
   # --doc-root = doc-repo (где живут ROADMAP.md, DEVLOG.md, VISION.md и т.п.)
   bash scripts/validate-lar.sh \
     --root . \
     --lar <doc_repo_path>/docs/architecture/LIVING-ARTIFACTS.md \
     --doc-root <doc_repo_path>
   ```
   - Если `validate-lar.sh` отсутствует → авто-sync `bash <methodology_path>/scripts/sync-methodology.sh .`, затем повторить
   - `MISSING_FILE` → 🟡 Medium: пути в LAR не существуют на диске (обновить LAR или создать файлы)
   - `OK` → проверить количество строк: `grep -c "^| \`" <LAR_PATH>`
     - 0 строк → 🟡 Medium: LAR пуст

4. Output:
   - Файл отсутствует → 🟡 **Medium severity** — lifecycle-реестр не создан; создать из `templates/LIVING-ARTIFACTS.template.md`. Без LAR /plan Шаг -1.3 Adjacent Impact неполон.
   - Файл есть, `validate-lar.sh` → MISSING_FILE → 🟡 **Medium severity** — LAR содержит несуществующие пути.
   - Файл есть, таблица заполнена, все пути существуют → 🟢 OK

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
| 10 | LIVING-ARTIFACTS.md presence | 🟡/🟢 | [PRESENT/MISSING] | `/plan`: создать из `templates/LIVING-ARTIFACTS.template.md` |

**Контекст:**
- Версия в этом репо: `<from .claude/.version>` ← текущая, актуальная
- Последний sync-audit был на: `<last_sync_audit.methodology_version из triggers.json>` (или «никогда»)
- Last auto-pull: `<from triggers.json>`

⚠️ **Важно:** финальная фраза "полностью применена" должна содержать версию из `.claude/.version` (текущая), **не** из triggers.json (stale значение прошлого аудита). Пример корректной фразы: "Methodology **v4.43.0** (текущая в репо) проверена на соответствие 5 gap-классам. Audit запускался в контексте v4.43.0."

**Few-shot: правильная vs неправильная финальная фраза (S-027):**

✅ **Правильно** — версия из `.claude/.version`, количество gap-классов конкретное:
```
Methodology v4.59.0 (текущая) проверена на соответствие 7 gap-классам.
Gaps: 2 high / 1 medium / 4 low. Audit запускался в контексте v4.59.0.
```

❌ **Неправильно** — "полностью применена" без версии и без счётчика:
```
Methodology полностью применена. Всё в порядке.
```
(G-057: агент не знает реальную версию и количество — фраза ложная)

❌ **Неправильно** — версия из triggers.json (stale):
```
Methodology v4.27.0 полностью применена.
```
(Если `.claude/.version` = v4.59.0, а triggers.json = v4.27.0 — это stale значение)

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

- **Format-changes (трансформация заполненных артефактов) НЕ требуют правки этой команды** — добавь версионированный migration-файл `scripts/migrations/v<X.Y.Z>-<id>.sh` (auto/report), runner Шага 1.5 подхватит автоматически. Это структурное решение расширяемости (Flyway/Alembic pattern).
- Adoption-gaps (новый структурный feature class: новая секция конфига, новый hook) — пока требуют новую Gap-секцию здесь. Кандидат на будущее: декларативный gap-registry по аналогии с migrations.
- Mermaid labels check (Gap 4) — sample-based (3-5 blocks), не exhaustive. Полный hybrid refactor требует отдельного /plan.
- Path patterns для Gap 1 (поиск major компонентов) могут не работать для monorepo / non-standard структур — graceful skip с сообщением «не могу определить структуру, проверь вручную».
- Не запускает /plan сам — намеренно. Каждый gap может требовать архитектурного решения (где path patterns? создать секции для каких компонентов?). Пользователь решает.

---

$ARGUMENTS
