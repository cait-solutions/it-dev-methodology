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

> **Self-dogfood note (methodology_path: .):** Для methodology-platform (`CLAUDE.local.md methodology_path: .`) `/sync-audit` делает self-аудит — версионный delta всегда 0 (репо IS методология). Результат: Gap 1 (version delta) всегда пусто. Gaps 2-10 проверяются нормально (формат, mermaid, validators и т.д.). После деплоя `deploy-push.sh` запускает `sync-methodology.sh .` автоматически — дополнительный `/sync-audit` для self-case избыточен для версионного sync, но полезен для format-gaps.

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
→ **выполнить Consumer-vs-clone sync check (ниже)**, затем продолжить к Шагу 0

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
- ❌ Failed → показать ошибку + `⚠️ Pull прошёл но sync-apply упал — запусти вручную: bash <methodology_path>/scripts/sync-methodology.sh <consumer_root>`

→ **выполнить Consumer-vs-clone sync check (ниже)**

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

### Consumer-vs-clone sync check (closes G-107 — авто-синхронизация consumer с клоном)

**Цель:** убедиться что consumer (этот проект) синхронизирован с локальным клоном методологии. Выполняется **после** каждого remote-check результата (up-to-date, pull success, или ls-remote failed). Закрывает класс «clone обновлён, но consumer не синхронизирован — /sync-audit говорит "актуально"» (G-107).

> **⛔ Self-dogfood guard:** если `methodology_path: .` (methodology-platform = IS клон) → **пропустить этот подшаг** (consumer и клон — один репо, sync-methodology.sh уже вызван в auto-apply выше). Только для consumer-репо где `methodology_path` указывает на внешний клон.

**Определить consumer_root:** корень текущего репо (где запущен `/sync-audit`).
```bash
consumer_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
```

**Прочитать версии:**
```bash
# Версия consumer (этот проект):
consumer_version=$(grep "^methodology:" "${consumer_root}/.claude/.version" 2>/dev/null | sed 's/methodology: //' | tr -d '[:space:]')

# Версия клона методологии (уже обновлённого в этом шаге):
clone_version=$(cat "<methodology_path>/VERSION" 2>/dev/null | tr -d '[:space:]')
```

**По результату:**

**Если `.claude/.version` отсутствует** → ⚠️ bootstrap не выполнен, пропустить этот подшаг (Шаг 0 п.3 поймает).

**Если `consumer_version == clone_version`:**
```
✅ Consumer актуален (соответствует клону методологии <clone_version>).
```
→ продолжить.

**Если `consumer_version != clone_version` → АВТО-APPLY (self-heal, без вопроса, closes G-107):**
```
🔄 Consumer устарел относительно клона методологии:
   consumer: <consumer_version> → клон: <clone_version>
   Применяю sync-methodology.sh...
```

Выполнить:
```bash
bash "<methodology_path>/scripts/sync-methodology.sh" "<consumer_root>"
```

- ✅ **Успех** → сообщить:
  ```
  ✅ Consumer синхронизирован: <consumer_version> → <clone_version>
     Новые команды, хуки и skills применены.

  ⚠️ ПЕРЕЗАПУСТИ СЕССИЮ Claude Code — иначе НЕ вступит в силу:
     Команды (/sync-audit, /plan, /code, …) загружаются в контекст ОДИН РАЗ при старте сессии.
     ТЕКУЩАЯ сессия держит СТАРЫЕ версии команд. Всё что ты увидишь до рестарта —
     поведение СТАРОЙ версии, не обновлённой.
     Файлы на диске уже новые — но активная сессия их перечитает только после рестарта.
  ```
  Установить флаг `consumer_auto_synced = true` (используется в Шаге 1b для verdict).

- ❌ **Ошибка** → показать:
  ```
  ❌ Авто-sync упал. Запусти вручную:
     bash <methodology_path>/scripts/sync-methodology.sh <consumer_root>
  ```
  → продолжить (не блокировать), пометить `consumer_auto_synced = false`.

**Если `clone_version` не прочитан** (клон недоступен / скрипт не найден):
```
⚠️ Не удалось прочитать VERSION из клона методологии (<methodology_path>/VERSION).
   Убедись что клон скачан: git clone https://github.com/cait-solutions/it-dev-methodology.git <methodology_path>
   Или укажи правильный путь в CLAUDE.local.md ## Auto-update → methodology_path
```
→ продолжить.

> **Реальный инцидент (G-107, client-matz 2026-06-11):** clone v4.60.0, upstream v5.33.0, `/sync-audit` сказал «актуальна». После ручного pull клона до v5.33.0 — consumer остался на v4.60.0 (73 версии позади, 20+ команд и все skills отсутствовали). Этот подшаг детектирует и устраняет такое рассогласование автоматически.

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
- **И verdict Шага -0.5 = `up-to-date` И `consumer_auto_synced = false`** → "✅ Версия актуальна (подтверждено живым ls-remote, consumer синхронизирован)".
- **И `consumer_auto_synced = true`** → "✅ Consumer синхронизирован автоматически в этом запуске: было `<old_consumer_version>`, стало `<current_version>`. Delta analysis: изменения уже применены, дополнительных действий не требуется."
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

## Шаг 1 — Inventory gaps (15 проверок)

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
   Скрипт автоматически определяет тип репо (single / two-repo) через `doc_repo_path` из `CLAUDE.local.md`:
   ```bash
   # Универсальный вызов — работает для single-repo и two-repo автоматически:
   bash scripts/validate-lar.sh
   ```
   Переопределение при нестандартных путях (необязательно при стандартной структуре):
   ```bash
   bash scripts/validate-lar.sh --root . --lar <path/to/LIVING-ARTIFACTS.md> --doc-root <doc_repo_path>
   ```
   - Если `validate-lar.sh` отсутствует → авто-sync `bash <methodology_path>/scripts/sync-methodology.sh .`, затем повторить
   - `WARN-SKIP` (LAR не найден) → нет LAR → 🟡 Medium (создать из шаблона)
   - `MISSING_FILE` → 🟡 Medium: пути в LAR не существуют на диске (обновить LAR или создать файлы)
   - `OK` → проверить количество строк: `grep -c "^| \`" <LAR_PATH>`
     - 0 строк → 🟡 Medium: LAR пуст

4. Output:
   - Файл отсутствует → 🟡 **Medium severity** — lifecycle-реестр не создан; создать из `templates/LIVING-ARTIFACTS.template.md`. Без LAR /plan Шаг -1.3 Adjacent Impact неполон.
   - Файл есть, `validate-lar.sh` → MISSING_FILE → 🟡 **Medium severity** — LAR содержит несуществующие пути.
   - Файл есть, таблица заполнена, все пути существуют → 🟢 OK

### Gap 11: CLAUDE.local.md config-recommendations (v5.35.0)

**Цель:** проверить что ключевые конфигурационные поля `CLAUDE.local.md` соответствуют рекомендациям методологии. `CLAUDE.local.md` — project-owned (PRESERVE-семантика, не перезаписывается sync) → изменения только через `/plan` по решению владельца. Этот gap показывает отклонения и предлагает `/plan` на каждое.

⛔ **НЕ дублирует Gap 2** (`## Sync validators` presence). Gap 2 = «секция существует?»; Gap 11 = «значения в `## Branching` и `## Auto-update` соответствуют рекомендациям?». Разные оси.

**Эталон методологии (v5.35.0):**

| Секция | Поле | Рекомендация | Severity при отклонении |
|---|---|---|---|
| `## Branching` | `worktree_isolation` | `auto` при параллельной / multi-session работе | 🟡 Medium |
| `## Auto-update` | `enabled` | `true` | 🟡 Medium |
| `## Auto-update` | `interval_hours` | `≤ 4` (default 2) | 🟢 Low |

> **Sustainment:** при добавлении новой рекомендованной конфиг-секции в `templates/CLAUDE_LOCAL.template.md` или смене дефолтов — обновить таблицу эталонов выше и список проверок ниже. Связь: `templates/CLAUDE_LOCAL.template.md ## Branching` + `## Auto-update`.

1. Проверить наличие `CLAUDE.local.md`:
   - Отсутствует → 🟢 N/A (bootstrap не выполнен, шаг 0 п.3 поймает)

2. Проверить `worktree_isolation`:
   ```bash
   grep "worktree_isolation" CLAUDE.local.md
   ```
   - Найдено `off` или поле отсутствует → 🟡 **Medium**: рекомендовать `/plan` для оценки (владелец сам решает — `off` правильно если заведомо одна сессия)
   - Найдено `auto` → 🟢 OK

3. Проверить `## Auto-update`:
   ```bash
   grep "enabled:" CLAUDE.local.md | head -1
   grep "interval_hours:" CLAUDE.local.md | head -1
   ```
   - `enabled: false` → 🟡 **Medium**: auto-update выключен
   - `interval_hours` > 4 → 🟢 **Low**: интервал длиннее рекомендованного
   - Секция `## Auto-update` отсутствует → 🟡 **Medium** (Gap 3 уже фиксирует это; дублировать не нужно — указать что покрыто Gap 3)

4. Output:
   - Всё соответствует → 🟢 OK (конфиг актуален)
   - Есть отклонения → перечислить с рекомендацией:
     ```
     🟡 worktree_isolation: off — рекомендовать /plan: оценить включение auto
        (если у проекта есть / планируются параллельные сессии)
     🟡 enabled: false — рекомендовать /plan: включить auto-update
     🟢 interval_hours > 4 — рекомендовать /plan: снизить до 2
     ```

---

### Gap 12: ROADMAP.Done vs DEVLOG milestone sync (v5.37.0)

**Цель:** обнаружить methodology milestone'ы задеплоенные через reactive path (gap → /plan → /code) которые не попали в `ROADMAP.md ## Done`. Реактивные milestone'ы не проходят через `## Now` → ROADMAP Done-trigger исторически их не захватывал (P-008).

⛔ **Report-only** — не self-heal. Backfill ROADMAP.Done требует решения владельца (формулировка строки).

1. Определить path к ROADMAP.md и DEVLOG.md через `CLAUDE.local.md → doc_repo_path`:
   ```bash
   # two-repo: ROADMAP.md в doc_repo_path; single-repo: локально
   ```
   Если файлы отсутствуют → 🟢 N/A (gap culture не используется).

2. Извлечь дату последней записи в `## Done` из ROADMAP.md:
   ```bash
   grep -m1 "|" ROADMAP.md  # первая строка таблицы Done → год
   ```

3. Найти `[milestone]` теги в DEVLOG.md ПОСЛЕ этой даты:
   ```bash
   grep "\[milestone\]" DEVLOG.md | head -20
   ```

4. Для каждого найденного milestone — проверить есть ли соответствующая строка в `## Done`:
   - grep по version / task_id в таблице Done
   - Если отсутствует → кандидат для backfill

5. Output:
   - Все milestone'ы присутствуют в Done → 🟢 OK (ROADMAP.Done синхронен)
   - N milestone'ов в DEVLOG без записи в Done → 🟡 **Medium**: перечислить с рекомендацией backfill через `/code` (следующий /code Шаг 5 reactive path)
   - `[milestone]` тегов нет в DEVLOG → 🟢 N/A (methodology milestone tracking не используется)

> **Sustainment:** если формат `[milestone]` тега в DEVLOG изменится — обновить grep-паттерн в п.3. Связь: CLAUDE.md DEVLOG теги секция.

---

### Gap 13: Branch protection on main (v5.43.0)

**Цель:** обнаружить если branch protection на `integration_branch` (default: `main`) отключена — риск прямого push в main открыт.

⛔ **WARN-only** (не self-heal, не block). Применимо только для GitHub-репо с доступным `gh` CLI. Graceful skip при GitLab / отсутствии `gh` / недостатке прав — **без ошибки и без WARN**.

**Scope:** только `mode: team` репо с `integration_branch` настроенным. Solo-mode: прямой push в main is expected → skip (Gap 13 только про team-guard). Если `CLAUDE.local.md` отсутствует или `mode` не `team` → 🟢 N/A.

1. Читать `mode` и `integration_branch` из `CLAUDE.local.md ## Branching`. Если `mode != team` → 🟢 N/A.
2. Определить owner/repo из `git remote get-url origin`. Если не `github.com` → 🟢 N/A (GitLab и другие — graceful skip).
3. Проверить что `gh` CLI доступен: `command -v gh`. Если нет → 🟢 N/A.
4. Inline verify (НЕ вызывать `scripts/setup-branch-protection.sh` — скрипт не синхронизируется консьюмерам, delivery-drift класс):
   ```bash
   gh api "repos/${owner}/${repo}/branches/${integration_branch}/protection" \
     -q '.enforce_admins.enabled // "false"' 2>/dev/null
   ```
   - Exit 0 + enforce_admins = true → 🟢 OK (protection active)
   - Exit 0 + enforce_admins = false → 🟡 **Medium** WARN (protected but admin bypass allowed)
   - Exit 1 (404 / Branch not protected) → 🔴 **High** WARN: protection отсутствует
   - Exit 403 (нет прав читать protection) → 🟢 N/A (нет доступа — нельзя вынести вердикт)
   - Другая ошибка (network, etc.) → 🟢 N/A (graceful skip)

5. При 🔴 WARN — output:
   ```
   ⚠️ Gap 13 [High]: Branch protection НЕ активна на ${owner}/${repo}:${integration_branch}.
      Прямой push в main возможен (HIGH риск — CLAUDE.md § Security).
      Включить: bash scripts/setup-branch-protection.sh
      Verify:   bash scripts/setup-branch-protection.sh --verify
   ```

6. При 🟡 WARN — output:
   ```
   ℹ️ Gap 13 [Medium]: Protection active but enforce_admins=false — admin bypass возможен.
      Включить enforce: bash scripts/setup-branch-protection.sh (re-apply)
   ```

> **Sustainment:** GitHub branch protection API endpoint стабилен; если owner/repo переехал → `git remote get-url origin` автоматически даёт новый адрес. Связь: `scripts/setup-branch-protection.sh` · ADR-002 Amendment v3 · CLAUDE.md § Security.

---

### Gap 14: [no-marker] consumer initialization (v5.46.0)

**Цель:** обнаружить workspace repos без инициализированной методологии и предложить bootstrap через `scripts/new-project-init.sh`.

⛔ **Gap 14 — единственный gap `/sync-audit` который записывает файлы** (только на явный `init` ответ пользователя). Gaps 1-13 — диагностика. Gap 14 — диагностика + условный write. Commit в consumer repo остаётся за пользователем.

**Scope:** только если workspace_file найден (Режим A в `/pull-consumers` discovery). Если нет workspace_file или все `[no-marker]` repos уже в `exclude_paths` → 🟢 N/A.

1. Определить `workspace_file` из `CLAUDE.local.md ## Consumers`. Если отсутствует → 🟢 N/A.
2. Прочитать `exclude_paths` из `CLAUDE.local.md ## Consumers` (defensive: `.get('exclude_paths') or []`).
3. Извлечь все `folders[].path` из workspace-файла, резолвить относительно папки workspace-файла.
4. Для каждого пути проверить: `[ -f "<path>/.claude/.version" ]`
   - Есть `.version` → `[marker]`, пропустить.
   - Нет `.version` И путь в `exclude_paths` → молча пропустить (владелец выбрал `never`).
   - Нет `.version` И путь не в `exclude_paths` → добавить в список `[no-marker]`.
5. Если список `[no-marker]` пустой → 🟢 OK.
6. Вывести список найденных `[no-marker]` repos и для каждого задать вопрос (по одному):
   ```
   ❔ Gap 14: <repo-name> не инициализирован методологией.
      Инициализировать? (init / skip / never)
        init  — запустить scripts/new-project-init.sh (создаст .claude/ структуру)
        skip  — пропустить этот запуск (спросит снова при следующем /sync-audit)
        never — добавить в exclude_paths (не показывать больше)
   ```
7. **При `init`:**
   - Если `<path>/.claude/` существует → предупредить: `⚠️ .claude/ уже есть в <repo-name> — new-project-init.sh может перезаписать файлы. Продолжить? (y/n)`
   - Pre-check: `[ -f scripts/new-project-init.sh ]`. Если нет → `⚠️ scripts/new-project-init.sh не найден — bootstrap недоступен в этом репо. Пропускаю.`
   - Запустить: `bash scripts/new-project-init.sh "<project_name>" "<abs_path>"` (пути в кавычках — Windows path с пробелами)
   - Сообщить результат. Commit остаётся за пользователем.
8. **При `never`:** добавить `abs_path` в `exclude_paths` в `CLAUDE.local.md ## Consumers` yaml-блок (append-only, не перезаписывать файл целиком).
9. **При `skip`:** ничего не записывать.

**Диагностика:**
- 🟢 Нет `[no-marker]` repos (или все в `exclude_paths`) → OK
- 🟡 Есть `[no-marker]` repos → предложить init/skip/never
- 🟢 Initialized: `new-project-init.sh` выполнен для X repo(s)

> **Sustainment:** discovery через workspace_file (актуальный список). `exclude_paths` пишется здесь при `never`. `scripts/new-project-init.sh` не синхронизируется консьюмерам (LOCAL в methodology-platform) — pre-check в п.7 защищает от `command not found`. Связь: `commands-local/pull-consumers.md` · `CLAUDE.local.md ## Consumers` · `scripts/new-project-init.sh`.

---

### Gap 15: Maps coverage (v5.47.0)

**Цель:** проверить что каждая команда, skill и скрипт упомянуты в living maps (USER-MAP, ARTIFACT-MAP, SYSTEM-MAP). L4-gate в methodology-platform, report для консьюмеров.

**Scope:** применимо к любому проекту с `docs/product/USER-MAP.md` или `docs/architecture/SYSTEM-MAP.md`. Если карты отсутствуют → 🟢 N/A (consumer без карт — легитимно).

**Graceful skip:** если `scripts/validate-maps-coverage.sh` отсутствует → `⚠️ Gap 15: скрипт не найден — обновите методологию до v5.47.0+`. Не exit 1.

1. Если `[ -f scripts/validate-maps-coverage.sh ]`:
   - Запустить: `bash scripts/validate-maps-coverage.sh --report`
   - Вывести результат пользователю (mapped/unmapped counts per axis)
   - **Для консьюмеров:** показывать только counts, **без MISSING-вердиктов** по synced командам — consumer карты описывают их продукт, а не methodology commands (SYSTEM-MAP §11)
   - **Для methodology-platform:** вывести полный отчёт включая ROADMAP-ось
2. Если скрипт отсутствует → `⚠️ Gap 15 [Medium]: validate-maps-coverage.sh не найден — sync методологию до v5.47.0+`.

**Диагностика:**
- 🟢 0 errors, 0 warnings — все карты покрыты
- 🟡 Warnings (только WARN — скрипты или ROADMAP) — не блокируют deploy, информационно
- 🔴 Errors — команды/skills без строк в картах → deploy будет заблокирован

> **Sustainment:** `validate-maps-coverage.sh` вызывается в deploy-push.sh gate (methodology-platform) и здесь (report). Dual-copy: `scripts/` + `templates/scripts/` (G-103). При добавлении новой команды → deploy сам выявит пропуск.

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
| 11 | CLAUDE.local.md config-recommendations | 🟡/🟢 | [worktree_isolation / enabled / interval_hours] | `/plan`: оценить включение `auto` / `true` / `≤4` |
| 12 | ROADMAP.Done vs DEVLOG milestone sync | 🟡/🟢 | [N milestone'ов без Done-записи] | backfill через `/code` Шаг 5 reactive path |
| 13 | Branch protection on main | 🔴/🟡/🟢 | [статус из Gap 13] | `bash scripts/setup-branch-protection.sh` |
| 14 | [no-marker] consumer initialization | 🟡/🟢 | [N repos без методологии] | init / skip / never (в Gap 14 inline) |
| 15 | Maps coverage | 🔴/🟡/🟢 | [errors/warnings из Gap 15] | добавить строки в карты (USER-MAP/ARTIFACT-MAP/SYSTEM-MAP) |

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
