# CHANGELOG — methodology-platform

Consumer migration guide. Каждый milestone = что добавилось + что нужно запустить.

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
