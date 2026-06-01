# CHANGELOG — methodology-platform

Consumer migration guide. Каждый milestone = что добавилось + что нужно запустить.

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
