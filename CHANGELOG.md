# CHANGELOG — methodology-platform

Consumer migration guide. Каждый milestone = что добавилось + что нужно запустить.

---

## v5.23.1 — fix: /sync-audit явно предупреждает что команды stale до рестарта (2026-06-10, closes G-098)

**Что:** после auto-apply `/sync-audit` обновлял команды на диске, но restart-напоминание было одной строкой → пользователь не понимал что ТЕКУЩАЯ сессия держит СТАРЫЕ версии команд до рестарта. Реальный симптом: консьюмер на v5.22.0 показал старое auto_pull-поведение («не установлен → спрашивает»), хотя файл на диске уже имел новую семантику («не установлен → авто») — сессия читала старую команду из контекста. Усилено restart-предупреждение: явно «до рестарта всё поведение — СТАРОЙ версии, файлы новые но сессия перечитает только после рестарта».

**Priority:** 🟢 Low — UX/discovery, текст команды. Не меняет механику.

**NB:** это НЕ баг семантики auto_pull (инверсия v5.20.0 корректна и доехала) — про session-reload lifecycle Claude Code.

---

## v5.23.0 — fix: consumer-pull.sh interpreter-резолвер — больше не «пуллю вручную» на Windows (2026-06-10, closes G-097)

**Что:** `consumer-pull.sh` (за `/pull`) использовал голый `python3 -c` для парсинга `.code-workspace` → на Windows `python3` отсутствует (только `py`) → скрипт падал, `/pull` деградировал в «пуллю вручную». Рецидив G-081 (Windows python3 hardcode) — класс был решён в 6 скриптах резолвером `for _cmd in py python3 python`, но `consumer-pull.sh` (инлайн python) пропущен. Теперь резолвер выбирает `py` на Windows → workspace парсится → `/pull` работает автоматически.

**Actions:**
```
/sync-audit   # подтянуть исправленный consumer-pull.sh
```

**Priority:** 🟡 Medium — `/pull` на Windows-консьюмерах перестаёт деградировать в ручной режим.

**NB:** overlap `/pull` ↔ `consumer-pull.sh` (зачем тяжёлый multi-repo pull при простом /pull) — отдельный вопрос G-091, не закрыт этим фиксом.

---

## v5.22.0 — feat: secrets-manifest = single source of truth для git-remote (2026-06-09, closes P-006)

**Что:** методология теперь имеет SSOT для «куда пушить». Git-секрит в `secrets-manifest.yaml` можно пометить `git_remote: true` — его `service_url` становится каноническим адресом push/pull. Push-команды (`/push-merge`, `/deploy`) перед push сверяют `git remote origin` с manifest и при расхождении **предлагают выровнять** remote под manifest (`git remote set-url`, с подтверждением — не молча). Закрывает корень push-инцидентов (G-083/P-005/G-094 — все были симптомами «нет SSOT для remote»): агент теперь определяет target+auth из secrets детерминированно, не из возможно-неверного git remote.

**Авто-определение:** без флага, если ровно один `service_url` оканчивается на `.git` — он считается git-remote. Несколько → fallback на git remote (graceful). Старые manifest без поля работают без изменений.

**Actions:**
```
/sync-audit   # подтянуть обновлённые push-скрипты
# Пометь git-секрет в .claude/secrets-manifest.yaml:  git_remote: true
# (если используешь GitLab/иной хост — service_url должен быть ПОЛНЫМ repo URL с .git)
```

**Priority:** 🟡 Medium — устраняет класс «push стучится не туда»; агент определяет remote из secrets.

---

## v5.21.0 — feat: command-first позиционирование — AI engineer как первичная персона (2026-06-09, closes G-095)

**Что:** зафиксирована первичная персона методологии — **AI engineer** (оркеструет AI через команды/skills, не запускает скрипты руками). PRODUCT.md «Целевые пользователи» переписан (AI engineer 🥇 первичный, developer/team lead вторичные). CLAUDE.md ## Workflow rules — новый **Command-first invariant**: агент не рекомендует пользователю `bash scripts/...`, направляет на команду; новая consumer-операция обязана иметь command/skill точку входа. Скрипты **не скрыты** — остаются доступны как внутренняя реализация, просто не рекомендуются как пользовательский путь.

**Actions:** (поведенческое правило — sync подтягивает обновлённый CLAUDE.md banner)
```
/sync-audit   # подтянуть обновлённую методологию (command-first, не bash-скрипт!)
```

**Priority:** 🟢 Low — позиционирование/поведение агента; не меняет механику команд.

---

## v5.20.0 — fix: /sync-audit обновляется автоматически без вопроса (2026-06-09, closes G-094)

**Что:** `/sync-audit` Шаг -0.5 при обнаружении обновлений methodology больше **не спрашивает** «a/b/c» — делает `git pull --ff-only` + `sync-methodology.sh .` **автоматически по умолчанию**. Раньше pull был за вопросом (половинчатая автоматизация — G-092 авто-applied sync ПОСЛЕ pull, но pull оставался ручным). Pre-pull safety: проверяется `git status --porcelain` — если в клоне методологии есть незакоммиченные изменения, pull откладывается с инструкцией commit/stash (не трогает правки); diverged (non-ff) → явное сообщение; network/auth → verdict unverified.

**Семантика `auto_pull` инвертирована (⚠️ migration):** раньше `false` (default) спрашивал, `true` = авто. Теперь **не задан / `true`** = авто (default), **`false`** = вернуть вопрос y/n (opt-out для осторожных). Эффект для большинства: обновление стало автоматическим. Кто хочет ручной контроль — ставит `auto_pull: false`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # подтянуть обновлённую /sync-audit
# Хочешь подтверждать pull вручную? Добавь в CLAUDE.local.md ## Auto-update:
#   auto_pull: false
```

**Priority:** 🟡 Medium — UX: `/sync-audit` обновляет методологию одной командой без подтверждения.

---

## v5.19.0 — fix: push-диагностика различает 404/403/network + GITHUB_PAT не навязывается GitLab-проектам (2026-06-09, closes G-083 L4 + P-005)

**Что:** push-скрипты (`consumer-push.sh`, `consumer-push-only.sh`, `deploy-push.sh`) больше не печатают «403 / нужен PAT» при ЛЮБОМ провале. Теперь захватывают stderr (LC_ALL=C → детерминированные англ. маркеры), классифицируют причину — **404** (repo не существует → «создать?» или «remote указывает не на ту платформу» если remote-host ≠ secrets-manifest service_url), **403** (не тот gh-аккаунт → `gh auth switch`, а не PAT), **network** (хост недоступен — не credential). stderr sanitize маскирует `://user:token@`. В `deploy-push.sh` push был голым (без проверки exit) → шёл в `gh pr create` на непушнутой ветке — теперь прерывается. `secrets-manifest.yaml.template` больше не объявляет `GITHUB_PAT required:true` всем; `new-project-init.sh` определяет платформу из git remote и подсказывает нужный секрет.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # подтянуть обновлённые push-скрипты
# Если у тебя GitLab/иной remote и в .claude/secrets-manifest.yaml висит лишний
# GITHUB_PAT — удали его (он давал ложный "MISSING" в secrets-show).
```

**Priority:** 🟡 Medium — устраняет хроническую путаницу «нужен GitHub PAT» на не-GitHub remote; push-диагностика теперь self-explaining.

---

## v5.18.0 — feat: /sync-audit auto-apply после pull — одна команда вместо двух (2026-06-09, closes G-092)

**Что:** `/sync-audit` Шаг -0.5 делал `git pull` но не запускал `sync-methodology.sh` — консьюмер стягивал новые commits в methodology repo, но `.claude/commands/` оставались старыми. Теперь после успешного pull (варианты a и b, включая `auto_pull: true`) автоматически выполняется `bash scripts/sync-methodology.sh .` (self-heal, без вопроса). При ошибке sync-apply — показывает явное сообщение вместо молчания.

**Priority:** 🟡 Medium — UX: консьюмер получает актуальные команды сразу после `/sync-audit`, без второй команды.

**Actions:**
```bash
bash scripts/sync-methodology.sh .
```

---

## v5.17.0 — fix: /sync-audit pull без PAT — прямой git pull для публичного репо (2026-06-09, closes G-091)

**Что:** `/sync-audit` Шаг -0.5 предлагал `with-secret.sh GITHUB_PAT` как рекомендуемый вариант для pull обновлений methodology. Для публичного репо PAT не нужен — `git pull` работает анонимно с любым git-хостингом (GitHub, GitLab и др.). Новый вариант (a): прямой `git pull origin main --ff-only`; при auth-ошибке (прокси) — вариант (b) с `gh auth login`.

**Priority:** 🟢 Low — улучшение UX для консьюмеров без PAT в `.env`; не ломает существующее поведение.

**Actions:**
```bash
bash scripts/sync-methodology.sh .
```

---

## v5.16.0 — feat: visual-parity pre-fix protocol — полное закрытие класса + стек-агностичность (2026-06-08, closes G-090)

**Что:** visual-parity задача («привести формы/окна к единому стандарту») разваливалась на рекурсивные частичные раунды — агент закрывал только видимое в текущем скриншоте, пропуск всплывал слоем глубже (одна ось → все оси → под-элемент → источник разметки). G-089 (v5.15.0) закрыл оси, но не под-элементы / эталон / источник.

Достройка `/code` Frontend DOM verification rule (G-089 блок → **visual-parity pre-fix protocol**), три обязательных измерения ДО первого фикса:
- **Эталон-как-артефакт:** зафиксировать целевые значения в артефакт, сравнивать с ним — не с памятью/скриншотом. Формат/место — на усмотрение проекта.
- **Полный чеклист под-элементов:** инвентаризация surface проходит фиксированный набор {заголовок · строки · поля · поиск · футер/пагинация · кнопки · скроллбар · границы}, матрица surface×под-элемент×ось.
- **Component-source check:** один ли компонент-генератор разметки производит сравниваемые surface; разные → стилевой паритет недостижим без per-source override или унификации компонента.

Плюс: блок очищен от framework/проект-частностей (стек-агностичный) — применим на любом UI-стеке.

**Priority:** 🟢 Low — расширение поведенческого правила агента для visual-задач, не ломает существующее, не требует config-изменений.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Срабатывает только для visual-parity задач (≥2 surface, «привести к стандарту»). Не-frontend проекты — правило не активируется.

---

## v5.15.0 — feat: pre-fix baseline measurement — превентивный слой против visual iterative-thrash (2026-06-08, closes G-089)

**Что:** при visual-задаче «выровнять/сделать одинаковым» (CSS/Vue) агент чинил по ОДНОЙ оси различия за итерацию (letter-spacing → font-weight → background), коммитя после каждой — 3-4 итерации с «готово»/«ничего не изменилось» вместо одной. Проблема multi-source: несколько компонентов, у каждого своя ось. Существующие слои (iteration-watchdog, reasoning-ось) — реактивные, ловят ПОСЛЕ залипания; `reset_on_commit: true` делает watchdog слеп к commit-per-iteration.

Превентивный фикс (L3, встроен в существующий Frontend DOM verification ⛔-gate):
- **`/code` Frontend DOM verification rule:** новый **pre-fix baseline** блок — при visual-alignment задаче с ≥2 элементами ОБЯЗАТЕЛЕН один runtime-замер ВСЕХ осей (font-size/weight/letter-spacing/color/background/height/padding) у ВСЕХ элементов в таблицу → все расхождения видны до первого фикса → один фикс закрывает все. Ordering: measure → fix → verify.
- **CLAUDE.local.md `## Iteration watchdog`:** рекомендация frontend-heavy проектам ставить `reset_on_commit: false` (восстанавливает reactive backstop для commit-per-iteration). Default `true` не меняется.

**Priority:** 🟢 Low — поведенческое правило агента для frontend, не ломает существующее, не требует config-изменений.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Frontend-heavy проекты дополнительно: рассмотреть `reset_on_commit: false` в `CLAUDE.local.md ## Iteration watchdog` (опционально, см. секцию). Non-frontend проекты — правило не срабатывает (триггер по visual-alignment + ≥2 элемента).

---

## v5.14.0 — feat: delivery-consistency gate в /review — структурный фикс review-blindness (2026-06-08, R-029)

**Что:** `/review` был на 100% статическим — проверял что НАПИСАНО (hook wired в template), не что РАБОТАЕТ (sync доставит). v5.12.0 прошёл review «0 critical», но `merge_settings_json` не доставлял `.sh`-wiring → поймал только /deploy dogfood post-merge → re-release v5.12.1. Класс «фикс не доезжает молча» (G-087→G-088) ×3, review ни разу не ловил доставку. `[fix:command]×17` за период — command-churn как производное.

Структурный фикс (architecture-audit R-029, L4 не L3 — prose-защита провалилась 3 раза):
- **`scripts/validate-delivery.sh` (новый):** статический delivery-consistency validator. Для каждого hook-ref в `settings.template.json` проверяет (а) файл есть в `templates/.claude/hooks/` (б) `sync-methodology.sh hook_name()` его распознаёт → реально доедет до консьюмера. Рассогласование template↔sync-parser = FAIL. Зеркалит дуальный regex sync (менять синхронно).
- **`validate-template-format.sh` Check 6:** вызывает validate-delivery — **L4 enforcement** через уже-обязательный validator-прогон (/code Шаг 11), не новая prose-инструкция.
- **`/review` Шаг 3 delivery-gate:** PR трогает hooks/settings-template/sync → `validate-delivery.sh` обязателен, FAIL = 🔴 fix now. **N/A escape запрещён** для этого класса.
- **`/code` Шаг 11:** документирован Check 6 delivery-consistency.

Верификация: validator PASS на текущем состоянии; negative-test (sync regex .py-only = v5.12.0 баг) → корректно FAIL «wiring не доедет, ровно v5.12.0 баг». Поймал бы v5.12.0 pre-merge.

**Priority:** 🟡 Medium — усиление review-gate, не ломает существующее.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Для большинства consumers validate-delivery — no-op (нет methodology-internal delivery-поверхности, graceful skip exit 0).

---

## v5.13.1 — fix: /sync-audit live upstream check — больше не врёт "актуальна" на stale клоне (2026-06-08)

**Что:** `/sync-audit` Шаг -0.5 молча рапортовал «версия актуальна» когда локальный клон методологии отставал от upstream (реальный инцидент: ERP-клон v4.68.0, upstream v5.13.0 → «актуальна»). Причина: `git fetch --dry-run` мог тихо упасть/быть пропущен → Шаг 1b сравнивал локальный stale VERSION с `.claude/.version` (оба совпадали т.к. оба stale) → ложное «актуальна».

Изменения (`commands/sync-audit.md` Шаг -0.5 + Шаг 1b):
- `git fetch --dry-run` → **`git ls-remote origin -h refs/heads/main`** — живой upstream HEAD, не зависит от того когда последний раз делали fetch, работает на shallow-клонах.
- Три явных verdict: `up-to-date` (HEAD совпал) / `stale` (upstream впереди) / `unverified` (ls-remote failed). **Только `up-to-date` даёт право написать «актуальна».**
- fetch-fail → «НЕ смог проверить upstream» (не тихий фолбэк на «актуальна»).
- Шаг 1b: `consumer_version = current_version` больше не значит «актуальна» автоматически — гейтится verdict'ом Шага -0.5 (это значит лишь что consumer синхронен СО СВОИМ клоном, не что клон актуален vs upstream).

**Priority:** 🟡 Medium — поведенческий фикс детектора, не ломает существующее.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
**NB (мета-парадокс):** этот фикс доедет до консьюнера только ПОСЛЕ обновления его клона методологии. Если консьюмер на сильно старой версии (как ERP v4.68) — сначала **один раз вручную**: `git -C <methodology_clone> pull origin main`, затем `sync-methodology.sh .`. Дальше Шаг -0.5 будет ловить устаревание сам.

---

## v5.13.0 — feat: escalation layers 2+3 — reset_on_commit flag + session gap counter (2026-06-08)

**Что:** завершение escalation-механизма (слой 1 = v5.12.0/1 hook-liveness). Два слоя real-time эскалации на reasoning-залипание.

Изменения:
- **Слой 2 — `reset_on_commit` флаг** в `iteration-watchdog.py` (config в `CLAUDE.local.md ## Iteration watchdog`). Default `true` = текущее поведение (счётчик обнуляется на commit, RPN-150-safe). `false` (opt-in) = счётчик переживает коммиты в пределах сессии → ловит **commit-per-iteration** reasoning-залипание (агент коммитит после каждого фикса одного бага → при `true` ступень-1 N=3 недостижима — ровно CSS-placeholder инцидент).
- **Слой 3 — `session_gap_counter`** в `triggers.json` (новое поле: `session_marker` + `counts`). `/plan` Шаг D + `/diagnose` 6.3.5 инкрементируют счётчик однотипных gap'ов; на пороге (`gap_escalation_threshold`, default 3) — one-shot real-time эскалация «SESSION GAP PATTERN: 3-й <категория> gap за сессию — смени подход». Session-boundary через timestamp-прокси (`gap_session_window_hours`, default 6ч — нет явного session-id в Claude Code). Ловит серию в моменте, в отличие от `recurrence_rate` пост-фактум в `/architecture-audit`.

**Priority:** 🟡 Medium — поведенческое улучшение escalation, backward compatible. `session_gap_counter` — аддитивное поле (merge_triggers_json дозаливает, graceful read), не breaking → minor bump (CLAUDE.md schema-rule уточнён: major только для breaking).

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `triggers.json` получит `session_gap_counter`; `iteration-watchdog.py` поддержит `reset_on_commit`. Опционально настрой пороги в `CLAUDE.local.md ## Iteration watchdog` (см. template). `reset_on_commit: false` рекомендуется для frontend-тяжёлых проектов где commit-per-iteration частый паттерн.

---

## v5.12.1 — fix: merge_settings_json wires direct .sh hooks (hook-liveness delivery) (2026-06-08)

**Что:** критический follow-up к v5.12.0. `merge_settings_json` `hook_name()` распознавал только `.py` хуки в прямых вызовах (`.claude/hooks/X.py`) — новый `hook-liveness.sh` (прямой вызов без run-hook.sh) не распознавался → его SessionStart wiring **не доезжал** до консьюмера при sync (файл копировался, но не wired). Без этого фикса весь v5.12.0 inert на delivery-пути.

Изменения:
- **`sync-methodology.sh` `hook_name()`:** regex `\.py` → `\.(?:py|sh)` — распознаёт прямые `.sh` вызовы. Зеркалит уже-изменённый missing_hooks detection (консистентность всех detection-sites).

**Priority:** 🔴 High — без этого hook-liveness.sh копируется но не активируется у консьюмера.

**Actions:** уже включено в `sync-methodology.sh .` — консьюмеры получат wiring при следующем sync.

**Обнаружено:** dogfood-верификацией в /deploy — own settings.json не получил wiring после self-sync v5.12.0.

---

## v5.12.0 — fix: hook-liveness detector — разрыв рекурсивной дыры доставки хуков (2026-06-08)

**Что:** закрыта рекурсивная дыра G-087 (повтор 3-й раз). Если у консьюмера `settings.json` ссылается на хуки, но сами файлы (в т.ч. `run-hook.sh` — раннер ВСЕХ хуков) отсутствуют на диске → все хуки молча падают, а детектор этой проблемы (`check_hook_health`) сам недоступен, потому что запускается через отсутствующий `run-hook.sh`. Детектор отсутствующих хуков сам отсутствовал.

Изменения:
- **`templates/.claude/hooks/hook-liveness.sh` (новый):** pure-POSIX-sh детектор, вызывается из SessionStart **напрямую** (`sh .claude/hooks/hook-liveness.sh`), БЕЗ `run-hook.sh`. Проверяет физическое наличие каждого hook из settings.json — включая `run-hook.sh`. Способен сообщить об отсутствии `run-hook.sh` не используя его. Рекурсия разорвана.
- **`settings.template.json`:** `hook-liveness.sh` добавлен первым в SessionStart (перед `auto-update-watchdog`).
- **`/plan` Подшаг -0.4:** предикат сменён с «SessionStart wired?» на физическое наличие каждого referenced hook-файла + `run-hook.sh` на диске (always-read floor, ловит когда hook-подсистема мертва целиком).
- **`sync-methodology.sh`:** missing_hooks detection расширен на direct `.sh` вызовы (был только `.py`) — чтобы `hook-liveness.sh` сам верифицировался при доставке.
- **`/pull-consumers` Шаг 3.5 (новый):** cross-consumer детект HOOK-DRIFT после pull — видит все репо разом.

Три fate-independent детектора: `hook-liveness.sh` (SessionStart, без run-hook.sh) → `check_hook_health` (runtime, когда хуки живы) → `/plan` -0.4 (always-read, когда подсистема мертва). Разные failure modes.

**Priority:** 🔴 High — без этого фикса escalation-механизм + защитные хуки могут быть молча мертвы у консьюмера.

**Actions (для консьюмеров — особенно если хуки не срабатывали):**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `hook-liveness.sh` появится в `.claude/hooks/`, settings.json получит SessionStart wiring. Перезапусти сессию Claude Code. Если видишь `⚠️ HOOK DRIFT` при старте — значит хуки были мертвы, sync их восстановил.

**Проверка:** `grep -c hook-liveness .claude/settings.json` (должно быть ≥1) и `ls .claude/hooks/run-hook.sh .claude/hooks/hook-liveness.sh` (оба должны существовать).

---

## v5.11.0 — feat: auto-gap-capture — gap'ы записываются без подтверждения (2026-06-08)

**Что:** убран friction при захвате gap'ов в `/plan` Шаг -4 и `/diagnose` Шаг 6. Ранее агент спрашивал `(a/p/n)` — gap'ы терялись на практике. Теперь auto-write + opt-out.

Изменения:
- **`/plan` Шаг -4:** при обнаружении коррекции — дедуп-grep → auto-write → одна строка: `📝 Записано: G-NNN — ... Отменить: 'нет'`
- **`/diagnose` Шаг 6.3-6.4:** reinforced "без подтверждения", добавлен opt-out в Шаге 6.4
- **`AGENT-GAPS.md.template` правило захвата:** обновлено — "записывает автоматически"
- **`CLAUDE.template.md` Agent self-reporting rule:** переписан — auto-write flow с примерами

**Priority:** 🟡 Medium — поведенческое изменение, backward compatible.

**Actions (для консьюмеров на v5.10.x и ниже):**
```bash
bash <methodology-path>/scripts/sync-methodology.sh
```
После sync: `/plan` Шаг -4 и `/diagnose` Шаг 6 автоматически пишут gap без вопроса.

**Примечание:** если в вашем `AGENT-GAPS.md` нет секции `## Записи` с маркером `<!-- новые — сверху -->` — агент не сможет вставить запись (упадёт gracefully). Проверить: `grep "новые" AGENT-GAPS.md`.

---

## v5.10.1 — fix: consumer-pull.sh REPO_ROOT path (2026-06-08)

**Что:** исправлен баг в `templates/scripts/consumer-pull.sh` — `REPO_ROOT` вычислялся некорректно при запуске из `scripts/`. Теперь `cd "$SELF_DIR/.." && pwd` — детерминировано независимо от CWD.

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
Скрипт перезапишется автоматически.

---

## v5.10.0 — feat: /pull workspace-wide — все repos кроме it-dev-methodology (2026-06-08)

**Что:** `/pull` расширен до workspace-wide режима — тянет все repos из `.code-workspace` кроме `it-dev-methodology`.

Изменения:
- `commands/pull.md` — уточнён scope (все workspace repos кроме methodology source)
- `templates/scripts/consumer-pull.sh` — discovery через `.code-workspace` (тот же механизм что `/pull-consumers`)

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```

---

## v5.9.0 — feat: /pull — consumer pull всех workspace repos (ff-only) (2026-06-08)

**Что:** новая consumer команда `/pull` — одной командой подтянуть все repos workspace с remote, без merge, ff-only, с preview входящих коммитов.

Изменения:
- **`commands/pull.md`** — новая команда (синхронизируется консьюмерам)
- **`templates/scripts/consumer-pull.sh`** — новый скрипт: fetch → preview incoming commits → `git pull --ff-only`. Skip при uncommitted changes или diverged history. Hook-safety guard.
- **`templates/model-tiers.md`** — строка `/pull` (Fast tier)

**Actions:**
```bash
bash <methodology-path>/scripts/sync-methodology.sh .
```
После sync: `bash scripts/consumer-pull.sh` доступен. Команда `/pull` появится в `.claude/commands/`.

---

## v5.8.0 — fix: SYSTEM-MAP шаблон — продуктовые компоненты первичны (2026-06-08)

**Что:** исправлен концептуальный дефект в `templates/SYSTEM-MAP.template.md` (P-004). Шаблон содержал только безликие `<service-1>` / `<service-2>` без примеров — консьюмер не понимал что в диаграмму должны идти компоненты его продукта (`OrderService`, `PartyService`, `CatalogService`), а не dev-инструменты.

Изменения:
- **Callout в начале:** «Это архитектура ТВОЕГО ПРОДУКТА» с примерами по 5 типам проектов (ERP, маркетплейс, бот, API-сервис, инструмент)
- **Bootstrap checklist:** 2 обязательных чекбокса (product components заполнены + у каждого есть назначение)
- **CLAUDE.md Maps Standard Rule:** уточнено что SYSTEM-MAP описывает продуктовые сервисы как первичный слой
- **methodology-platform SYSTEM-MAP:** добавлена note о special case (продукт = методология = слои репо)
- **PRODUCT-GAPS:** закрыт P-004 (resolved in v5.8.0)

**Migration note для консьюмеров bootstrap'нутых до v5.8.0:**

Если `docs/architecture/SYSTEM-MAP.md` в вашем проекте содержит только `<service-1>` / `<service-2>` без замены — карта не заполнена. Для исправления:

1. Открой `PRODUCT.md` → выпиши ключевые сервисы/модули продукта
2. Замени `<service-1>` / `<service-2>` на реальные компоненты (`OrderService`, `PartyService` и т.д.)
3. Заполни Bootstrap checklist в начале файла

**Что запустить:**
```bash
# Ничего — bootstrap-only артефакт, sync-methodology.sh его не трогает
# Изменения нужно внести вручную в docs/architecture/SYSTEM-MAP.md
```

---

## v5.7.0 — fix: ARTIFACT-MAP шаблон — продуктовые артефакты первичны (2026-06-08)

**Что:** исправлен концептуальный дефект в `templates/ARTIFACT-MAP.template.md`. Шаблон раньше направлял консьюмера описывать dev-артефакты (команды `/plan`, `/code`, DEVLOG) как центральный контент карты — вместо документов продукта (`orders.md`, `parties.md`, `invoice-flow.md`).

Изменения:
- **Два явных слоя:** "Продуктовые артефакты (заполнить!)" — новый subgraph первичен в диаграмме; "Методологические артефакты (стандартные)" — вторичный слой, не нужно изобретать
- **Callout в начале:** явное предупреждение "карта описывает артефакты ПРОДУКТА, не процесса разработки"
- **Bootstrap checklist:** 2 обязательных чекбокса при первом заполнении (product artifacts заполнены + у каждого есть триггер)
- **Секция "Продуктовые артефакты"** поднята выше "Методологических" — консьюмер видит что заполнять в первую очередь
- **CLAUDE.md Maps Standard Rule:** убрано `(methodology-specific)` из описания ARTIFACT-MAP viewpoint; уточнено что продуктовые артефакты первичны
- **methodology-platform ARTIFACT-MAP:** добавлена note о special case (продукт = методология = команды)
- **PRODUCT-GAPS:** закрыт P-003 (resolved in v5.7.0)

**Migration note для консьюмеров bootstrap'нутых до v5.7.0:**

Если `docs/product/ARTIFACT-MAP.md` в вашем проекте содержит только `/plan`, `/code`, DEVLOG и другие dev-артефакты без документов специфичных для вашего продукта — карта не заполнена правильно. Для исправления:

1. Открой `PRODUCT.md` → выпиши ключевые сущности продукта (orders, parties, invoices, contracts и т.д.)
2. Для каждой сущности создай или найди `docs/product/<entity>.md`
3. Добавь эти артефакты в секцию "Продуктовые артефакты" в ARTIFACT-MAP (таблица + ноды в диаграмме)
4. Заполни Bootstrap checklist в начале файла

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Шаблон `templates/ARTIFACT-MAP.template.md` обновлён — но уже bootstrap'нутые файлы не перезаписываются автоматически (bootstrap-only артефакт). Исправь вручную по migration note выше.

---

## v5.6.0 — feat: /scope-out — визуальный обзор отложенного / out-of-scope scope (2026-06-06)

**Что:** новая команда `/scope-out` + `scripts/scope-view.sh` — показывают **одной Mermaid-диаграммой** весь отложенный / непокрытый / out-of-scope scope проекта (PRODUCT-GAPS open/in-roadmap + AGENT-GAPS open + ROADMAP Considered/On-hold/Arch-review + triggers.json recommendations[] proposed*). Диаграмма **эфемерна** — генерируется из текстовых источников при каждом запуске, не сохраняется в файл → не дрейфит. Дефолт-фильтр High+in-roadmap (anti node-explosion), `--all` для полного backlog, `--print-only` для offline.

Сопутствующее:
- **Anchor-узел** `📋 Отложенный scope → /scope-out` (класс `affordance`) добавлен в living USER-MAP + ARTIFACT-MAP — навигация туда, куда владелец и так смотрит (карты).
- **Capture write-path:** `/plan` Шаг 99.3 + `/review` теперь пишут product-значимый out-of-scope в PRODUCT-GAPS (иначе `/scope-out` показывает пустую комнату).
- **`/architecture-audit` Шаг 3:** узлы класса `affordance` исключены из phantom-node сравнения (class-rule, не ID-whitelist) — anchor не флагается как ложный drift.
- **CLAUDE.md Maps Standard §3:** конвенция `classDef affordance` (навигационный узел ≠ scope-claim).

**Зачем:** отложенный scope жил только текстом в 5+ файлах; владелец, глядя на карты, его пропускал — «нет визуальности». Closes P-002.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
После sync доступна команда `/scope-out`. Для two-repo проектов передавай `--root <doc_repo_path>` (команда читает его из CLAUDE.local.md автоматически).

---

## v5.5.1 — fix: FMEA glossary inline — раздел понятен без внешнего контекста (2026-06-06)

**Что:** добавлена врезка-глоссарий прямо в `/plan` Шаг 1.5 блок A. Расшифровка FMEA / S / O / D / RPN на русском; явное предупреждение что D — обратная шкала (высокий = тихий провал). Заголовок таблицы обновлён (RU-суффиксы). Механика не менялась: шкалы 1-10, формула S×O×D, пороги RPN>200 и D≥7 — без изменений.

**Зачем:** до правки раздел был непонятен без знания промышленного стандарта FMEA — агент заполнял формально, владелец методологии не мог его интерпретировать.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```

---

## (unreleased — version aligned at merge) — feat: sync self-apply hook-wiring + watchdog liveness — mechanism #3 (2026-06-06)

**Что (закрывает «watchdog не запускался → sync/sync-audit спят»):**
- **`sync-methodology.sh` self-apply ветка** теперь вызывает `merge_settings_json` — методология dog-food'ит own hook-wiring (раньше merge был только в consumer-ветке → own settings без SessionStart → auto-update-watchdog мёртв).
- **`/plan` Шаг -3 liveness check** — детектит отсутствие SessionStart/auto-update-watchdog wiring → 🔵 предложить sync. Гарантированно-читаемое место (slash-команда), не рекурсивно-уязвимый рантайм-хук.
- **Bug fix:** `sys.stdout.reconfigure(utf-8)` в merge_settings_json + merge_triggers_json — Windows cp1252 крашил print на `↻`/`—`, маскируя успешный merge как «failed».

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Консьюмеры: liveness-check в /plan подскажет если SessionStart не wired. NB: первый merge переформатирует settings.json (inline→multi-line, функционально-нейтрально, единожды).

> ⚠️ VERSION выравнивается при финальном мерже (параллельно с v5.5.0).

---

## (unreleased — version aligned at merge) — feat: sync settings.json hooks merge — consumer wiring drift (2026-06-06)

**Что (закрывает mechanism #2 silent-fail: новое hook-wiring не доезжало до существующих консьюмеров):**
- **`sync-methodology.sh` — `merge_settings_json()`** заменяет add-only-if-missing для `settings.json`. При sync дозаливает отсутствующие `run-hook.sh X.py` из `settings.template.json` в существующий consumer `settings.json`. permissions и существующие matcher-группы не трогаются. Идемпотентно (presence-check), graceful (невалидный JSON / нет Python → preserve).
- Дополняет hook-wiring parity gate (/review, v5.3.0): parity ловит на dev-стороне, merge доставляет к консьюмеру. Теперь settings.json = MERGE как triggers.json.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .
```
Существующие консьюмеры впервые получат недостающее hook-wiring (напр. iteration-watchdog, secrets-guard если их settings отстал). Намеренно удалённые хуки вернутся — methodology-хуки обязательны.

> ⚠️ VERSION bump выравнивается при финальном мерже (изменение делалось параллельно с v5.5.0).

---

## v5.5.0 — feat: commit-discipline + verify-gate — unplanned parallelism at isolation:off (2026-06-06)

**Что (закрывает index-capture класс: 2 сессии при `worktree_isolation: off` → `git commit` захватывает чужой staged-индекс; инцидент a17ecc1):**
- **`/code` Шаг 2 — commit-discipline:** коммить через explicit pathspec (`git commit <пути> -m`), НЕ `git add`+bare `git commit` (последний коммитит весь индекс, включая staged другой сессией). + **verify-before-commit gate:** `git diff --cached --name-only` → staged ⊆ `/plan` Шаг 1 file-scope. Few-shot антипример a17ecc1.
- **`CLAUDE.md` Workflow rules** — короткое правило commit-discipline (discoverability).
- **ADR-002** — субсекция «Index-capture at isolation:off»: документирует что `off` шарит один индекс, регулятор там = commit-discipline (не worktrees), rejected детектор, deferred L4 hook с измеримым trigger.

**Чем дополняет v4.59.0:** v4.59.0 закрывал ЗАПЛАНИРОВАННЫЙ параллелизм (`auto`+AGENTS.md+worktree). Это — НЕЗапланированный (`off` default + фактически 2 сессии). При `auto` баг невозможен (отдельный индекс per worktree); при `off` pathspec — единственная защита.

**Что запустить:**
```bash
bash scripts/sync-methodology.sh .   # получить обновлённый /code + CLAUDE.md
```

**Что отложено:** L4 PreToolUse commit-scope hook (warn если staged вне scope) — trigger: следующий index-capture инцидент ИЛИ /retro ≥1 [git-failure] scope-capture.

**Приоритет:** 🟡 Medium — поведенческое правило коммита (не breaking), но предотвращает потерю чужой работы. Действие: один `sync-methodology.sh`.

---

## v5.3.0 — feat: /review hook-wiring parity gate — dev-side «hook доехал, но не активировался» (2026-06-06)

**Что (закрывает класс тихого провала: fix есть в методологии, но hook мёртв у консьюмера):**
- **`/review` Шаг 3 (methodology-platform)** — новый hard-check **Hook-wiring parity**: PR трогает `templates/.claude/hooks/` → каждый entry-point hook ОБЯЗАН быть wired через `run-hook.sh <name>.py` в `templates/settings.template.json`, иначе 🔴 блок merge. Прямое направление (file→no wiring); комплементарно runtime `check_hook_health` (settings→missing file).
- Helper-исключение через маркер `# NOT-WIRED:`; detection-guard на 0 совпадений (closes G-073-класс).

**Что запустить (получить обновлённый /review):**
```bash
bash scripts/sync-methodology.sh .
```
Поведение для консьюмеров не меняется автоматически — gate применяется при разработке самой методологии. Консьюмеры получают обновлённый текст команды `/review`.

---

## v5.1.0 — feat: testing layer Phase 1 — /test + testing-strategy skill + CODE-GAPS (2026-06-05)

**Что (методология начинает ВЕСТИ тестирование разрабатываемых приложений — обнаружение FE/BE багов: технических, логических, визуальных):**
- **`skills/testing-strategy/SKILL.md`** (новый knowledge-domain) — tiered pyramid (L0 verify / L1 focused / L2 regression «тяжёлая артиллерия»), инструменты per стек (Playwright/Cypress + visual diff, Schemathesis/Pact contract+API, property-based для логики), как ловить логические+визуальные баги не только краши.
- **`/test`** (новая команда) — оркестратор-навигатор (по запросу, как `/marketing`): выбирает уровень по project_type, генерирует+запускает тесты **в консьюмер-проекте**, найденное → CODE-GAPS.md. **Advisory** — вердикт о корректности кода за разработчиком (Граница 12: методология ведёт тестирование, не исполняет движок и не судит код).
- **`templates/CODE-GAPS.md.template`** (новый consumer-owned артефакт) — регистр product-багов со статусом open/fixed/regression-guard; категории открытым списком (frontend-visual/logic, backend-contract/crash, regression, perf). Не агрегируется методологией (G-032).
- **DEVLOG-тег `[test-found:category]`** — указатель на CODE-GAPS; fix-событие остаётся `[fix:X]` (QB3).
- Bootstrap создаёт `CODE-GAPS.md`; sync добавляет если отсутствует; `/pull-consumers` читает read-only для cross-domain pattern detection.

**Что запустить:**
```bash
# Получить новый skill + команду /test + CODE-GAPS.md:
bash scripts/sync-methodology.sh .
```

**Что отложено (Phase 2-4, named re-trigger):** блокирующий L2 regression gate в `/deploy`, test-watchdog hook, `--with-testing` bootstrap флаг, VISION QB11 + Граница 12 (фиксация через `/product-vision`). Разблокировать при: консьюмер пропустил regression-баг в prod который L1 поймал бы, ИЛИ ≥2 AGENT-GAPS completeness-gap по test-coverage.

**Приоритет:** 🟢 Low — additive (новый skill/команда/template), не breaking. Действие: один `sync-methodology.sh`.

---

## v5.0.0 — BREAKING: plan→code→review traceability — commitments[] в triggers.json schema (2026-06-05)

**Что (закрывает class «/plan обещал → /code забыл → /review не поймал», симптом: mermaid-ссылки в map-артефактах создаются/обновляются непоследовательно):**
- **Schema change (BREAKING):** `templates/triggers.json.template` → `last_plan_session` получил поле `commitments: []`. Каждая запись: `{text, status, skip_reason, carried_over?}`. Durable контракт обязательств задачи.
- **`/plan` Шаг 100** — финализирует список «📋 В /code будет реализовано» (Шаг 99.3) в `commitments[]` (status:pending). Под-шаг 0.5: carry-over `status:done` записей при re-plan (не теряем сделанное).
- **`/code` Шаг 7** — отмечает каждый commitment `done` / `skipped`+`skip_reason` по факту реализации. `pending` без причины при завершённой работе запрещён.
- **`/review` Шаг 3 Completeness** — новый класс: читает `commitments` (`.get('commitments') or []` — graceful на отсутствие), сверяет каждый против diff. `pending` без причины ИЛИ `done` без следа в diff → 🔴 fix now (блок merge, disposition за пользователем).

**Почему MAJOR:** изменение схемы `triggers.json` — мажор bump по инварианту CLAUDE.md (структурное правило, не зависит от back-compat механики). **Фактически back-compat:** `deep_merge` в `sync-methodology.sh` авто-добавляет `commitments: []` в существующий `last_plan_session`, сохраняя текущие значения. Старые планы без поля → `/review` graceful skip (🔵, не 🔴).

**Что запустить:**
```bash
# Подтянуть новую схему triggers.json (deep_merge добавит commitments[], значения сохранятся):
bash scripts/sync-methodology.sh .
```
Ручных правок triggers.json не требуется — merge идемпотентен. До запуска sync `/review` работает в graceful-режиме (commitments не сверяются, 🔵 уведомление).

**Приоритет:** 🟡 Medium — schema-breaking по правилу, но фактически back-compat через merge. Действие: один `sync-methodology.sh`.

---

## v4.60.0 — feat: S-026/S-027/S-028 structural gap fixes — template-format validator + few-shot examples + mandatory adjacent output (2026-06-03)

**Что:**
- **`scripts/validate-template-format.sh`** (новый, consumer-distributed) — L4 автопроверка формата templates/*.template.md: required sections, no stale mermaid link format, no unresolved placeholders. Запускается в `/code` Шаг 4 п.11 после любого изменения команд/templates. Закрывает [fix:template]×4 паттерн + G-068 recurrence.
- **`/code` Шаг 1.7** — mandatory output table: агент обязан написать таблицу grep-результатов до первой строки кода (если grep нашёл ≥1 результат). Закрывает completeness-gap класс «adjacent output необязателен».
- **`/plan` Шаг 99.54** — few-shot URL примеры: правильный (голый URL от скрипта) vs неправильный (markdown-link, subagent-generated). Закрывает logic-gap G-064 recurrence.
- **`/sync-audit` Шаг 3** — few-shot финальная фраза: правильная (версия + счётчик gaps) vs неправильная («полностью применена» без данных). Закрывает G-057.

**Что запустить:**
```bash
# 1. Синхронизировать новый скрипт:
bash scripts/sync-methodology.sh .

# 2. Проверить текущие templates:
bash scripts/validate-template-format.sh
```

**Приоритет:** 🟡 Medium — structural improvements, не breaking changes.

---

## v4.59.0 — feat: concurrent-session isolation — worktree + AGENTS.md (multi-dev / multi-session safety, closes P-001) (2026-06-02)

**Что (industry-стандартная 4-слойная модель безопасной параллельной работы):**
- **Новая ось branching contract — isolation (ортогональна mode):** `worktree_isolation: off|auto` + `branch_namespace: ai-dev/<task>` в `CLAUDE.local.md ## Branching`. НЕ третий mode — все 4 комбинации (solo/team × off/auto) валидны.
- **Новый артефакт `AGENTS.md`** (template + synced, project-owned) — task-ownership доска «one file, one owner» (encapsulation): claim file-scope перед правкой, cleanup после merge. Закрывает file-conflict *до* того как случится.
- **`/code` Шаг 5.5** (новый, при `auto`): читает `AGENTS.md ## Active claims` → пересечение file-scope с активным claim → ⛔ СТОП. Branch check теперь принимает namespaced `{agent_branch}/<task>`.
- **`/deploy`:** worktree-aware push (деплоит **текущую** ветку, не хардкод `agent_branch`) + **VERSION/shared-state race guard** (`git fetch && git diff origin/{branch}` перед bump — closes G-052) + claim cleanup после merge.
- **`scripts/deploy-push.sh` (+ template copy):** читает `worktree_isolation` → при `auto` пушит current branch (`$PUSH_BRANCH`), не хардкод `agent_branch`.
- **ADR-002 v2:** снят «multi-agent deferred», добавлена секция Concurrent-Session Isolation (4 слоя: isolation/ownership/staging/merge-gate) + temporal precondition (claim ДО edit).
- **Back-compat:** `worktree_isolation: off` = default → существующие consumers без изменений. `auto` = opt-in после локальной проверки `git worktree add` (Git Bash/Windows: git ≥ 2.5).

**Actions для consumers:**
```bash
bash /path/to/it-dev-methodology/scripts/sync-methodology.sh .   # добавит AGENTS.md, обновит code/deploy/deploy-push, CLAUDE.local fields
# Для concurrent work: в CLAUDE.local.md ## Branching → worktree_isolation: auto (после git worktree add self-check)
```

**Priority:** 🟡 Medium — нужно только проектам с >1 разработчиком или несколькими параллельными сессиями. Solo-single-session не затронут (default off).

---

## v4.58.0 — feat: migration registry — /sync-audit как единая точка обновления consumer'ов (2026-06-01)

**Что (структурное решение, Flyway/Alembic pattern):**
- **`scripts/migrations/`** — версионированные format-миграции. Каждое изменение формата заполненного артефакта = файл `v<X.Y.Z>-<id>.sh` с контрактом: `migration_detect` (нужна ли) + `migration_apply` (idempotent transform) + `MIGRATION_MODE` (auto self-heal / report).
- **`scripts/migrations/_runner.sh`** — прогоняет миграции новее consumer-версии. Source of truth = `.claude/state/migrations-applied.txt` (per-consumer, gitignored) → решает erp-класс «synced to latest, но старый transform не прогонялся».
- **`/sync-audit` Шаг 1.5** — вызывает runner автоматически. `HEALED` (авто) / `REPORT` (нужно решение). **Consumer запускает ТОЛЬКО `/sync-audit`** — миграции форматов применяются сами (user-friendly).
- **Первая миграция `v4.37.0-mermaid-bare-url`** — чинит старый `> 🔗 [Открыть](url)` → голый URL (closes G-072: stale-консьюмер больше не застревает; триплклик выделяет только ссылку).
- **Расширяемость:** новое format-улучшение = новый migration-файл, команда `/sync-audit` НЕ меняется.
- **Bonus fix:** `update-mermaid-links.sh` cross-drive bug (`os.path.relpath` ValueError при `--root` на другом диске) → `_safe_relpath` fallback.

**Actions для consumers (одна команда):**
```bash
/sync-audit          # синкнет migrations + применит все нужные format-миграции автоматически
```

**Priority:** 🟡 Medium — структурная основа для авто-обновления consumer-артефактов при эволюции методологии.

---

## v4.57.0 — security: close confirmed git-https token-leak vector (S0-S3) (2026-06-01)

**Что (security-аудит → 4 структурных фикса; подтверждённая утечка из transcript):**
- **S1 (G-077):** `bash_protect.py` новые `SECRET_EXFIL_PATTERNS` — блокирует (a) token-in-URL `https://user:TOKEN@host` (`git remote set-url`/`push`/`clone`), (b) `.env` reads через cat/grep/sed/awk/head/tail/... Закрывает confirmed leak-вектор (агент читал токен → вставлял в git URL → transcript). **11/11 adversarial-тестов**: 5 leak блокируются, 6 легитимных (вкл. `grep ".env" file`, `cat .env.example`, `git push`) разрешены.
- **S2 (G-078):** `.env` deny-правила добавлены в methodology own `.claude/settings.json` (раньше были только в template — dogfood-нарушение, methodology была уязвима).
- **S3 (G-079):** `deploy-push.sh` auto-wire credential helper перед push (idempotent: skip если gh уже настроен / SSH / helper отсутствует). Агент делает plain `git push` — токен via helper stdin, НЕ argv.
- **S0 (G-077):** `git-credential-from-env.sh` routing по host (service_url + service-field token match), НЕ по имени ключа. User-defined имена (напр. `GITHUB_AI_ASSISTANT_DOCUMENTATION_FULL`) работают без переименования в `GITHUB_PAT`. Actionable stderr hint вместо молчаливого падения.

**Actions для consumers:**
```bash
bash scripts/sync-methodology.sh .   # получить bash_protect.py + git-credential-from-env.sh + deploy-push.sh
# .env deny-правила в settings.json применяются при init; existing consumers — sync обновит hook (L4),
# для L5 denies проверь .claude/settings.json permissions.deny содержит .env правила.
```

**Принцип (industry):** агент структурно НЕ может назвать значение секрета в команде — auth через side-channel (helper stdin / ssh-agent) который агент не читает. Detection — последняя линия, не первая.

**Priority:** 🔴 High — закрывает подтверждённую (не теоретическую) утечку токенов в transcript.

---

## v4.56.0 — fix: Maps Standard — C4→arc42 claim correction + 6-views рамка + ADR-catalog (2026-06-01)

**Что (PR G из методологического аудита — точность модели карт):**
- **C4 claim исправлен:** CLAUDE.md + 2 templates заявляли «основан на C4 Model» — неверно. Три карты это **arc42 viewpoints** (ортогональные плоскости), не C4 zoom levels (один axis granularity). C4 оставлен только для дисциплины диаграмм. Источник: methodology-audit (4+1/arc42 mapping).
- **«3 карты» → «6 views» рамка:** living maps (SYSTEM/USER/ARTIFACT) + supporting views (data-map / ADR catalog / threat-model) явно названы в CLAUDE.md Maps Standard.
- **Слепое пятно задокументировано:** Temporal/Sequence viewpoint (порядок команд + хуков) — отсутствует, ordering-баги невидимы. Кандидат на 7-й view, активируется при первом ordering-инциденте (anti-over-engineering).
- **ADR-catalog drift исправлен** (doc-repo): каталог содержал 1 из 3 ADR. Добавлены ADR-002 (branching) + ADR-003 (secrets).

**Actions:** нет (документация/claim). `bash scripts/sync-methodology.sh .` для обновлённого CLAUDE template.

**Priority:** 🟢 Low — точность стандарта (consumer думал что следует C4, а это arc42).

---

## v4.55.0 — feat: validate-links.sh — Docs-as-Code internal link-check (2026-06-01)

**Что добавилось (PR B из методологического аудита):**
- `scripts/validate-links.sh` (+ `templates/scripts/`) — проверяет что все markdown-ссылки `[...](path)` на локальные файлы резолвятся. `BROKEN_LINK` = битая навигация. Пропускает: external URL, anchors, glob/placeholder, `.claude/` (derived copies), template-файлы, cross-repo sibling (если отсутствует).
- Gate в `/review` (BROKEN_LINK = 🔴 CRITICAL) + `/sync-audit` Gap 8.
- **Эмпирически нашёл 8 реальных битых ссылок** в README.md/PRODUCT.md (class G-076: code-repo ссылался на VISION/ROADMAP/DEVLOG/maps локально, а они в doc-repo) — исправлены на `../it-dev-methodology-documentation/...`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .       # получить validate-links.sh
bash scripts/validate-links.sh           # проверить свои артефакты
```

**Priority:** 🟡 Medium — Docs-as-Code gate, ловит навигационные дыры.

---

## v4.54.0 — fix: universality — de-hardcode two-repo paths + hook-consistency check (2026-06-01)

**Что добавилось (эмпирический consumer-аудит → 2 реальных фикса):**
- **PR A (G-076):** убраны hardcoded `../it-dev-methodology-documentation` из `/code`, `/review`, `/retro`. Новое поле `doc_repo_path` в `CLAUDE.local.md ## Auto-update`: `null` = single-repo (артефакты локальны), путь = two-repo. Команды читают config вместо hardcode. Закрывает leak который видели single-repo consumers (erp: 47 methodology-ссылок, путь к несуществующему sibling-репо).
- **PR H (G-075):** `sync-methodology.sh` после синка hooks проверяет что каждый hook упомянутый в `settings.json` реально присутствует в `.claude/hooks/`. Отсутствует → `⚠️ HOOK-MISMATCH` (fail loud). Закрывает silent-fail найденный в ai-assistant (auto-update-watchdog.py в settings.json но файла нет → hook падал молча → consumer навсегда stale без предупреждения).

**Actions для consumers:**
```bash
bash scripts/sync-methodology.sh .   # получить обновлённые команды + hook-check
# Затем в CLAUDE.local.md ## Auto-update установить doc_repo_path:
#   single-repo проект → doc_repo_path: null  (default, ничего не менять)
#   two-repo проект → doc_repo_path: ../<your-doc-repo>
```

**Priority:** 🔴 High — закрывает реальные consumer-leaks (эмпирически подтверждены на erp + ai-assistant).

---

## v4.53.0 — feat: discipline-creating финализация — /architecture-audit + /diagnose + /sync-audit + /product-check (2026-06-01)

**Что добавилось (PR3 of 3 — завершение трансформации всех 9 команд):**
- `/architecture-audit` 6.3 — recurrence_rate = open/(open+addressed) формула (FMEA Detection logic): ≥0.4 → Level 4+ обязателен.
- `/diagnose` Шаг 2 — таблица гипотез с исполнимой командой + различающим output (Popper falsifiability). «Посмотреть код» = не зачтено.
- `/sync-audit` Gap 1 — PRODUCT coverage через `grep -c` + `find | wc -l` (два числа), не «< 50% на глаз». methodology-platform → N/A.
- `/product-check` п.1-2-6 — команды (`ls`, `git log -1 --format=%ad`) вместо чтения на глаз; дата сверяется с git-историей.

**Actions:** нет (behavior change в commands/).

**Priority:** 🟡 Medium — завершает discipline-creating трансформацию (3-PR серия v4.51-v4.53).

---

## v4.52.0 — feat: discipline-creating classification в /code + /retro (2026-06-01)

**Что добавилось (PR2 of 3 — продолжение FMEA/Gawande трансформации):**
- `/code` Шаг 0.5 (Local/Systemic) — классификация **по числу** через `grep -c` + `git log -S`, не по интуиции. ≥2 места → системный → архитектурный фикс. «Локальный» без показанного grep = не зачтено.
- `/retro` Шаг 2 (Pattern detection) — обязательный `grep -oE "\[fix:...\]" | uniq -c | sort -rn` frequency-замер ДО интерпретации. Таблица из чисел grep, не «на глаз». Ловит semantic-дубли (один баг под разными тегами).

**Actions:** нет (behavior change в commands/).

**Priority:** 🟡 Medium — усиливает точность классификации, не breaking.

---

## v4.51.0 — feat: Forward-Failure Analysis (FMEA+JTBD) + discipline-creating Completeness audit (2026-06-01)

**Что добавилось (industry best practices применены к методологии):**
- `/plan` Шаг 1.5 — **Forward-Failure Analysis**: (A) FMEA RPN-таблица (Severity × Occurrence × Detection, RPN>200 → mitigation, D≥7 → detection-шаг); (B) JTBD struggling-moment (где пользователь скажет «проще руками»); (C) integration/non-duplication check (closes G-074).
- `/plan` Шаг 98 Pre-Mortem — категории усилены до discipline-creating: каждая требует **конкретного механизма** (тип данных, операция, сервис), не абстрактной категории. Klein-грамматика «уже провалилось, почему».
- `/review` Completeness check — заменён aspirational вопрос на **7 структурных классов пропусков** с evidence requirement (CRUD-симметрия, downstream consumers, content-vs-existence, template-sync, trigger-chain, error-path, +open) (closes G-073).
- `/review` Тесты — discipline-creating (назвать конкретный способ верификации + smoke-test для methodology).

**Actions:** нет (behavior change в commands/, не новые файлы).

**Priority:** 🟡 Medium — усиливает качество планирования и аудита, не breaking.

**Trade-off:** plan.md вырос ~+3700 chars (1.1x→1.2x budget). Оправдано новым классом (прямой запрос + G-073/G-074). Кандидат на структурное сжатие plan.md в отдельном /plan.

---

## v4.49.0 — fix: /code Шаг 4 пункт 11 hard rule + Шаг 7 triggers.json + /review template-drift check (2026-06-01)

**Что добавилось:**
- `/code` Шаг 4 пункт 11 усилен до ⛔ hard rule: «нет понятия "незначительный" для format changes» — блок при несоответствии templates/*.template.md (closes G-068).
- `/code` новый Шаг 7 (обязательный финальный): обновление triggers.json после каждого deploy — code_run=true + last_deploy (closes G-063).
- `/review` новый check «Template-drift»: если PR менял формат артефакта — проверить templates/*.template.md, несоответствие = 🔴 CRITICAL.

**Actions:** нет (behavior change в commands/, не новые файлы).

**Priority:** 🟡 Medium — структурная hygiene, не breaking change.

---

## v4.47.7 — feat: post-edit-watchdog PostToolUse hook (2026-06-01)

**Что добавилось:**
- `post-edit-watchdog.py` — новый PostToolUse hook: после каждого Edit/Write проверяет изменённый текст на паттерны из конфига и автоматически запускает скрипт. L4 фикс для G-020 (mermaid ссылки не обновлялись при прямом Edit вне /code workflow).
- Дефолтное правило: ` ```mermaid ` в изменённом тексте → `bash scripts/update-mermaid-links.sh <file>`.
- Конфигурируется через `CLAUDE.local.md ## Post-edit hooks` (YAML rules) — новые автоматизации без правки кода.
- Path validation против traversal атак.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить hook + обновлённые settings.json + CLAUDE_LOCAL.template.md
# Добавить в CLAUDE.local.md секцию ## Post-edit hooks (или использовать дефолтное правило mermaid)
```

**Priority:** 🟡 Medium — рекомендуется для проектов с Mermaid-диаграммами.

---

## v4.46.0 — feat: /marketing команда-навигатор + слоевая модель (2026-06-01)

**Что добавилось:**
- `/marketing` — slash-команда навигатор: читает MARKETING.md, показывает прогресс Foundation + Execution skills, рекомендует следующий skill в правильном порядке.
- Слоевая модель задокументирована: PRODUCT/VISION = внутренний слой, MARKETING = внешний. Marketing skills читают PRODUCT/VISION как вход, пишут только в MARKETING.md.
- Порядок Foundation block зафиксирован: `product-marketing` (breadth V1) → `define-positioning` → `customer-research` → `competitor-profiling`.
- Исправлен overlap: `define-positioning` больше не claims "первый" — теперь "второй (после product-marketing)". `product-marketing` уточнён как breadth-старт только на новом MARKETING.md.
- `MARKETING.md` ресинхронизирован с template (добавлена секция `## Product Context`).
- `model-tiers.md` расширен строкой `/marketing` (Fast tier, upgrade to Default при первом запуске).

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить /marketing команду + обновлённые skills
```

**Priority:** 🟢 Optional (новая UX-возможность, не breaking)

---

## v4.45.0 — feat: 8 новых marketing skills (2026-06-01)

**Что добавилось:** 8 новых skills в слой `skills/` вдохновлённых репозиторием coreyhaines31/marketingskills:
- `product-marketing` — foundation skill: маркетинговый контекст продукта (читается всеми остальными)
- `copywriting` — маркетинговые тексты для страниц
- `content-strategy` — контент-стратегия и планирование
- `pricing` — стратегия ценообразования и монетизации
- `launch` — запуск продукта и фич (фреймворк ORB + 5 фаз)
- `emails` — email-последовательности и lifecycle emails
- `cro` — оптимизация конверсии
- `seo-audit` — SEO аудит и диагностика

Все скиллы адаптированы под нашу систему: читают `MARKETING.md` вместо `.agents/product-marketing.md`, документация на русском, artефакт — `MARKETING.md`. `MARKETING.template.md` расширен секцией `## Product Context`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .   # получить новые skills
```

**Доступность:** Все проекты с `--with-marketing` или после `sync-methodology.sh` автоматически получают новые скиллы. `product-marketing` — новый foundation skill (запускать первым).

**Priority:** 🟢 Optional (новые capabilities, не breaking)

---

## v4.44.6 — G-062: закрыты два leak-вектора через bash_protect.py (2026-06-01)

**Что добавилось:** два новых блокирующих паттерна в `bash_protect.py`:
1. `_get-secret-raw.sh` — полностью заблокирован для агентов (был escape-hatch с `--explicit-stdout`, теперь блокируется любой вызов). Агент не может вывести секрет в stdout.
2. Inline env assignment вида `SECRET_KEY="value" bash script.sh` — заблокирован для ключей с секрет-индикаторами (TOKEN, SECRET, PASS, KEY, CRED, PAT, AUTH, ADMIN, PRIVATE, CERT, BEARER). Легитимные `ENV=dev bash cmd.sh` разрешены.

**Triggered by:** инцидент — агент увидел `KeycloakAdmin2024!` через stdout (Vector 2: inline assignment не был заблокирован).

**Security confidence:** 99.9%+ для agent-mediated leak vectors (stdout/transcript path). OS-level vectors (proc/environ, core dumps) documented в CLAUDE.md § Scope limits остаются open per design.

**Actions:**
```bash
bash scripts/sync-methodology.sh .    # получить обновлённые hooks
```

Если у вас уже были секреты которые агент потенциально видел — rotate их немедленно.

**Priority:** 🔴 CRITICAL (security patch, immediate sync recommended)

---

## v4.44.1 — auto_pull: полностью автоматический flow (2026-05-29)

**Что добавилось:** явное объяснение почему `auto_pull: true` нужен для полного авто-flow. Watchdog обновляет `.claude/` но НЕ `it-dev-methodology/` source — без `auto_pull: true` при автозапуске `/sync-audit` source может быть stale.

**Actions:**
```yaml
# Добавь в CLAUDE.local.md ## Auto-update:
auto_pull: true   # для полностью автоматического flow
```

**Priority:** 🟡 Recommended если используешь watchdog auto-trigger (раз в 2 часа).

---

## v4.44.0 — /sync-audit делает pull перед анализом (2026-05-29)

**Что добавилось:** `/sync-audit` теперь начинает с Шага -0.5 — проверяет есть ли обновления в локальной `it-dev-methodology/` и предлагает pull перед delta analysis. Без этого delta analysis мог сравнивать с устаревшей локальной версией и говорить "всё актуально" хотя на remote уже v4.43.x. Добавлено поле `auto_pull: true/false` в `CLAUDE.local.md ## Auto-update`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить обновлённую команду /sync-audit
```

После этого при запуске `/sync-audit` он сам предложит обновить `it-dev-methodology/`. Для автоматического pull без вопросов добавь в `CLAUDE.local.md ## Auto-update`:
```yaml
auto_pull: true
```

**Priority:** 🟡 Recommended — делает `/sync-audit` честным (не сравнивает со stale локальной копией).

> **Читается `/sync-audit` автоматически** для delta analysis.
> Записи в формате: версия → title → actions (ordered).
> При добавлении нового feature → добавить запись сюда (см. /code Шаг 5 checklist).

---

## v4.42.6 — Mermaid scripts для consumers (2026-05-29)

**Что добавилось:** `update-mermaid-links.sh`, `mermaid-link.py`, `validate-mermaid-links.sh`, `validate-doc-freshness.sh` теперь попадают к consumers через sync.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить скрипты
bash scripts/update-mermaid-links.sh        # обновить ссылки в bare URL формат
bash scripts/validate-mermaid-links.sh      # проверить что все ссылки актуальны
```

---

## v4.41.0 — Secrets schema v2 + multi-host routing (2026-05-29)

**Что добавилось:** manifest schema v2 (service_name, service_url, login, expires_at). `set-secret.sh` интерактивный. `secrets-show.sh`, `secrets-update.sh`, `secrets-edit.sh`, `secrets-rollback.sh`. Multi-host git credential routing.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить новые скрипты
bash scripts/set-secret.sh KEY              # интерактивно обновить metadata секретов
bash scripts/validate-secrets.sh           # проверить состояние + hygiene warnings
```

**Priority:** 🟡 Recommended — добавляет удобство и multi-host support.

---

## v4.34.0 — Secrets management foundation (2026-05-28)

**Что добавилось:** система управления секретами — `.env`, `secrets-manifest.yaml`, `with-secret.sh`, `set-secret.sh`, `check-secret.sh`, `validate-secrets.sh`, `git-credential-from-env.sh`. Pre-commit hook `secrets-guard.py`. Settings.json deny rules для `.env`.

**Actions:**
```bash
bash scripts/sync-methodology.sh .                       # получить все secrets скрипты
cp .env.example .env                                      # создать .env из шаблона
bash scripts/set-secret.sh GITHUB_PAT                    # добавить токен (один раз)
bash scripts/validate-secrets.sh                         # проверить что всё на месте
```

**Priority:** 🔴 Critical — безопасность токенов. Без этого агент может запросить токен через chat.

---

## v4.28.0 — /pull-consumers command (2026-05-27)

**Что добавилось:** команда `/pull-consumers` (LOCAL-ONLY, только для methodology repo) — auto-discovery всех consumer repos + diff новых записей в methodology-tracked артефактах.

**Actions:** только для methodology repo maintainer, не для consumer projects.

**Priority:** 🟢 Optional — только если ты maintainer методологии.

---

## v4.24.0 — PRODUCT-GAPS.md (2026-05-26)

**Что добавилось:** отдельный файл для product gaps (отличие от AGENT-GAPS). Новые шаги в `/plan` Шаг -4 для классификации.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # обновить команды
# PRODUCT-GAPS.md создаётся автоматически sync если отсутствует
```

**Priority:** 🟡 Recommended — если у тебя есть product roadmap.

---

## v4.20.0 — Sync validators в CLAUDE.local.md (2026-05-24)

**Что добавилось:** секция `## Sync validators` в `CLAUDE.local.md` — config-driven L3 проверки в `/review`.

**Actions:**
```bash
# Добавить секцию вручную в CLAUDE.local.md:
# ## Sync validators
# validators:
#   - name: ...
```

**Priority:** 🟡 Recommended — усиливает /review проверки.

---

## v4.19.0 — PRODUCT.md ## Логика компонентов (2026-05-23)

**Что добавилось:** обязательная секция `## Логика компонентов` в `PRODUCT.md` — tripwire в /plan Шаг -1.3.

**Actions:**
```bash
# Добавить в PRODUCT.md секцию ## Логика компонентов
# с подсекциями для каждого компонента проекта
```

**Priority:** 🟡 Recommended — помогает агенту не менять компонент без понимания контракта.

---

## v4.18.0 — Auto-update hook + Mermaid hybrid language (2026-05-22)

**Что добавилось:** `auto-update-watchdog.py` hook (SessionStart) — автоматически предлагает sync когда methodology обновилась. Mermaid hybrid language rule (EN identifiers + RU descriptions).

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить новый hook
# Hook активируется автоматически при следующем SessionStart
```

**Priority:** 🔴 Critical — без hook ты не узнаешь об обновлениях методологии.

---

## v4.16.2 — Agent Skills (SKILL.md frontmatter spec) (2026-05-20)

**Что добавилось:** Agent Skills система — `skills/*/SKILL.md` с YAML frontmatter на строке 1. Auto-activation по keywords.

**Actions:**
```bash
bash scripts/sync-methodology.sh .          # получить skills если есть
# Проверить что .claude/skills/*/SKILL.md имеет frontmatter на строке 1
```

**Priority:** 🟢 Optional — только если используешь marketing skills или создаёшь свои.

---

## v4.10.x и ранее

Базовая методология: `/plan → /code → /review → /deploy` workflow, AGENT-GAPS, DEVLOG, triggers.json, branch check, pre-flight checks. Это foundation — всегда присутствует после `new-project-init.sh`.

---

## Как добавлять новые записи

При добавлении нового feature в методологию — добавить запись **сверху** в формате:

```markdown
## vX.Y.Z — Название feature (дата)

**Что добавилось:** одна строка описания.

**Actions:**
\`\`\`bash
bash scripts/sync-methodology.sh .   # если нужен sync
# дополнительные команды
\`\`\`

**Priority:** 🔴 Critical | 🟡 Recommended | 🟢 Optional
```
