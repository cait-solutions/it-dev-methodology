# CHANGELOG — methodology-platform

Consumer migration guide. Каждый milestone = что добавилось + что нужно запустить.

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
