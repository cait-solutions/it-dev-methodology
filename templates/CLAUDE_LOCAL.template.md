# CLAUDE.local.md — {{Project Name}} Project Configuration

Project-specific rules and configuration for AI agents.
This file supplements [CLAUDE.md](CLAUDE.md) (methodology canonical rules — auto-updated by sync).

> **Convention:**
> - [CLAUDE.md](CLAUDE.md) = methodology rules. Auto-updated by `sync-methodology.sh`. **Do NOT edit.**
> - This file (CLAUDE.local.md) = project-specific config. **Edit freely.**

**Project type:** `<choose: ai-agent | web-app | api-service | cli-tool | library | multi-service-platform>` — used by `/review` and `/deploy` for additional checks.

---

## Architecture invariants (MUST / MUST NOT)

See [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md).

**MUST:**
- `<invariant 1 — e.g. all external API calls via single adapter>`
- `<invariant 2>`

**MUST NOT:**
- `<anti-pattern 1 — e.g. business logic in controllers>`
- `<anti-pattern 2>`

For rationale of each invariant — see [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md#архитектура-расширенно).

---

## Stack

- **Language / framework / DB / queues / testing / CI / deploy:** `<one-line each>`

---

## Data ownership (short)

| Storage | Source of truth | Writers | Invalidation |
|---|---|---|---|
| | yes/no (cache) | | |

Full details in [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная) or [`docs/data-map.md`](docs/data-map.md).

---

## Project-specific Don'ts

- ❌ Don't edit `.env`, secrets, deploy files (`_deploy.*`, `_update.*`).
- ❌ Don't add packages without updating `requirements.txt` / `package.json`.
- ❌ Don't call external APIs directly — only via single adapter.
- ❌ `<project-specific don't>`

---

## Security: real threats only

Before proposing security measure — check it closes a concrete threat from project threat-list:

- **Secret leak (High):** `<project-specific tokens / where they may leak>`
- **Data loss (High):** `<storages without backup>`
- **Access compromise (High):** `<auth attack vectors>`
- **Financial (Med):** `<billing-affecting>`
- **Operational (Med):** `<monitoring gaps>`

**Rule:** if proposed measure closes ZERO threats from this list → it's security theater. Justify or skip.

Details: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md#реальные-угрозы-безопасности-расширенно).

---

## Key entry points

- `<main / index>`
- `<router / dispatcher>`
- `<config loader>`
- `<data layer entry>`

---

## Branching

```yaml
mode: solo                          # solo | team
production_branch: main             # protected — agent never commits here directly
agent_branch: ai-dev                # AI branch (single source of truth, enforced by /code and /deploy).
                                    # Applies to all repo types — doc-repos and code-repos use the same name.
                                    # Differentiation comes from repo isolation, not branch naming.
```

- **solo** (default): agent pushes `{agent_branch} → production_branch` directly. For single-owner projects.
- **team**: agent pushes `{agent_branch}` to remote, `/deploy` outputs PR creation URL. Human reviews and merges.

Switch to `team` when the project has >1 developer or requires a review gate.
See [ADR-002](docs/adr/ADR-002-branching-mode-contract.md) for rationale.

---

## Remotes

```yaml
origin_url: https://github.com/<owner>/<repo>.git   # canonical remote URL for this repo
push_token_owner: <github-username-with-write-access>  # who must have write access for git push to succeed
```

Used by `sync-methodology.sh` (auto-corrects `git remote set-url origin` if mismatch) and `/deploy` (validates before push).
**Tokens:** store in OS credential manager (`gh auth login` / `git credential manager`). Never put tokens in this file.

**`push_token_owner`:** при 403/credential failure агент выведет это имя в сообщении пользователю чтобы было понятно какой аккаунт нужно авторизовать.

> **Existing projects (migration):** если CLAUDE.local.md уже создан без этого поля — добавь вручную:
> ```yaml
> push_token_owner: <github-username-with-write-access>
> ```

---

## Artifact budgets

Лимиты размера для артефактов-инструкций. Используется `scripts/validate-artifact-size.sh`
(вызывается из `/code` Шаг 4 и `/review`). Формат: `- <glob-pattern>: <max-символов>`.

```
- agents/*.py: 4000
- prompts/*.md: 3500
- src/**/system-prompt.*: 4000
```

**Зачем:** раздутые артефакты-инструкции вредят двумя способами:
1. **Размер** — агент скимит длинный текст, теряется сигнал.
2. **Плотность запретов** — обилие «ЗАПРЕЩЕНО/СТОП/NEVER» в runtime-промпте **подавляет tool invocation** (модель тонет в ограничениях и перестаёт звать инструменты). Скрипт считает это отдельной осью (`PROMPT_BLOAT`) — даже промпт в пределах размера флагается если плотность запретов высокая.

**Что указывать:** glob-паттерны к твоим **runtime-промптам** (системные промпты ботов/агентов, MISSION-файлы) — методология не знает где они лежат в твоём продукте. Методологические артефакты (CLAUDE.md, USER-MAP, SYSTEM-MAP, PRODUCT.md) имеют встроенные дефолты — указывать не обязательно, но можно переопределить.

Превышение → 🔵 Recommendation (не блок): размер сам по себе не приговор, агент разбирает в `/review` «раздутие или контент оправдан».

> **Existing projects (migration):** добавь секцию вручную с glob-паттернами своих runtime-промптов. Без неё проверяются только методологические артефакты по дефолтам.

---

## Sync validators

Конфиг для `/review` sync validators framework — config-driven L3 проверки что doc-артефакты обновлены вместе с изменениями кода. При каждом `/review` агент проходит по validators: если `trigger_paths` совпадают с изменёнными файлами (`git diff main..HEAD --name-only`) но `required_artifact` НЕ в diff → выдаёт 🔵 **Recommendation** с disposition (fix now / deferred / backlog / irrelevant).

**Опт-ин:** если эта секция отсутствует — validators не запускаются (нет config = нет validation). Существующие subjective checks в `/review` Документация продолжают работать.

```yaml
- name: PRODUCT-whole
  trigger_paths: ["src/**", "lib/**", "app/**", "services/**"]
  required_artifact: PRODUCT.md
  reason: "Поведение продукта изменилось — PRODUCT.md описание актуально?"

- name: PRODUCT-components
  trigger_paths: ["src/**", "lib/**", "app/**", "services/**"]
  required_artifact: PRODUCT.md
  required_section: "## Логика компонентов"
  reason: "Изменён код компонента — секция в PRODUCT.md ## Логика компонентов обновлена (Покрывает / НЕ покрывает / Ключевые правила)?"

- name: USER-MAP
  trigger_paths: ["src/api/**", "src/cli/**", "commands/**", "src/ui/**"]
  required_artifact: docs/product/USER-MAP.md
  reason: "Изменилась user-facing capability / workflow — USER-MAP обновлён?"

- name: SYSTEM-MAP
  trigger_paths: ["src/services/**", "src/components/**", "src/integrations/**"]
  required_artifact: docs/architecture/SYSTEM-MAP.md
  reason: "Новый компонент / связь / интеграция — SYSTEM-MAP обновлён?"

- name: ARTIFACT-MAP
  trigger_paths: ["commands/**", "templates/**", "scripts/**"]
  required_artifact: docs/product/ARTIFACT-MAP.md
  reason: "Новая команда / артефакт / read-write pattern — ARTIFACT-MAP обновлён?"

- name: ADR-status
  trigger_paths: ["src/**", "lib/**"]
  required_artifact: docs/adr/
  optional: true
  reason: "Реализуется ADR — статус ADR обновлён (Proposed → Accepted)? Запускается только если PR commit message упоминает ADR-NNN."
```

**Поля:**
- `name` — идентификатор validator (для disposition tracking)
- `trigger_paths` — glob patterns кода, изменение которого требует обновления `required_artifact`. Адаптируй под структуру проекта (если у вас `apps/` или `packages/*/src/**` — переопредели)
- `required_artifact` — путь к артефакту относительно корня проекта
- `required_section` (опционально) — конкретная подсекция артефакта которая должна быть в diff (для tightening)
- `optional: true` (опционально) — validator запускается только при специальных условиях (см. ADR-status)
- `reason` — текст Recommendation, конкретный вопрос пользователю

**Добавить новый validator:** дополни list — `/review` автоматически подхватит. Удалить — удали блок.

**Existing projects (migration):** добавь секцию с default validators выше. Path patterns могут потребовать tuning под структуру проекта.

---

## Auto-update

Конфиг для `auto-update-watchdog.py` SessionStart hook — авто-pull методологии + bootstrap detection. При каждом запуске Claude Code hook проверяет интервал и при необходимости запускает `sync-methodology.sh`.

```yaml
enabled: true
interval_hours: 2
on_failure: notify
methodology_path: ../it-dev-methodology
audit_threshold: 3
```

**Поля:**
- `enabled` — `true` / `false`. Отключить для offline-окружений или CI/CD где sync управляется внешним процессом.
- `interval_hours` — частота проверки (часы). Default `2` — баланс актуальности и шума. Можно ставить `0.5` для max-fresh или `24` для daily.
- `on_failure` — поведение при ошибке (нет интернета, GitHub down, sync fail):
  - `notify` — warning в чат, агент продолжает работать (рекомендуется)
  - `silent` — игнорировать тихо
  - `block` — exit 1 (hook fail; не рекомендуется кроме CI/CD)
- `methodology_path` — путь к склонированному `it-dev-methodology` относительно корня проекта. Default `../it-dev-methodology`.
- `audit_threshold` — minor version delta после auto-pull при котором hook рекомендует запустить `/sync-audit` (default `3`). Например, sync с `v4.18.0` на `v4.22.0` = delta 4 ≥ 3 → recommendation. Major bump (`v4.X.Y` → `v5.X.Y`) → forced trigger независимо от threshold.

**Bootstrap mode:** если `.claude/.version` отсутствует — методология не была инициализирована в этом проекте. Hook печатает рекомендацию для агента, агент в первом ответе предложит запустить `new-project-init.sh`.

---

## External links

- Runbooks: `<link>`
- Wiki: `<link>`
- Monitoring: `<link>`
- Incident response: `<link>`
