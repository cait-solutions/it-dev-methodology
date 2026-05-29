# CLAUDE.md — {{Project Name}}

Operational rules. Short form. For rationale and history — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:** CLAUDE.md = WHAT (rules). CLAUDE_LONG.md = WHY (rationale, edge cases, examples).

**Project type:** `methodology-platform` — особый. Это продукт методологии для других проектов. Runtime-проверки неприменимы. Применимы: контракты команд, валидность скриптов, кросс-ссылки артефактов.

---

## Read before work

1. [VISION.md](VISION.md) перед каждым `/plan`
2. [PRODUCT.md](PRODUCT.md) — что методология обещает консьюмерам
3. [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md) — связи компонентов
4. [USER-MAP.md](docs/product/USER-MAP.md) — пользовательские потоки и capabilities
5. [ARTIFACT-MAP.md](docs/product/ARTIFACT-MAP.md) — артефакты и их владельцы

---

## Architecture invariants (MUST / MUST NOT)

Методология = 5 слоёв (см. [SYSTEM-MAP.md](docs/architecture/SYSTEM-MAP.md)): команды / шаблоны / хуки / агенты-скелеты / скрипты.

**MUST:**
- `commands/`, `templates/`, `templates/.claude/hooks/`, `templates/.claude/agents/` — единственный источник правды (синхронизируется консьюмерам)
- `commands-local/` — methodology-only команды (НЕ синхронизируется консьюмерам; пример: `/pull-consumers`)
- Любая правка синхронизируемого артефакта → bump VERSION
- При изменении схемы `triggers.json.template` → мажор bump

**MUST NOT:**
- ❌ Редактировать `.claude/commands/*.md` напрямую — это банер-prefixed копии; канон в `commands/`
- ❌ Удалять команды без мажор bump VERSION + migration инструкция (breaking)
- ❌ Использовать bash 4-features (`${var,,}`, associative arrays) — Git Bash на Windows ставит 3.2
- ❌ Дублировать контент между шаблонами
- ❌ Класть команду которая должна попадать к консьюмерам в `commands-local/` (правило: shared → `commands/`, methodology-only → `commands-local/`)
- ❌ Менять `sync-methodology.sh` / `new-project-init.sh` итерацию команд на recursive (`find`, `**/*.md`) без явного exclude `commands-local/`

Rationale: [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md).

---

## Stack

- **Скрипты:** Bash 3.2+ (Git Bash on Windows)
- **Хуки:** Python 3.10+
- **Шаблоны:** Markdown + JSON + YAML
- **CI/CD:** ручной push в GitHub
- **Деплой:** `git push origin main`; consumers подтягивают через `sync-methodology.sh`

---

## Data ownership (short)

| Слой | Источник правды | Кто пишет | Инвалидация |
|---|---|---|---|
| `commands/*.md` | да | владелец | при правке + push |
| `templates/*.md` | да | владелец | при правке + push |
| `templates/.claude/hooks/*.py` | да | владелец | при правке + push |
| `templates/.claude/agents/*.template.md` | да | владелец (структура); консьюмер (тело) | при правке + push |
| `VERSION` | да | владелец | при ручном bump |
| `.claude/` (этот репо) | нет (производное) | `sync-methodology.sh .` | при self-sync |
| Консьюмер `.claude/commands/*.md` | нет (производное) | `sync-methodology.sh` | при sync |

Full table with examples and trade-offs: [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная).

---

## Don'ts

- ❌ Не редактировать `.claude/commands/*.md` напрямую (банер-prefixed копии)
- ❌ Не удалять команды без мажор bump + migration
- ❌ Не ломать `{{Project Name}}` плейсхолдер
- ❌ Не использовать bash 4+
- ❌ Не коммитить `.claude/settings.local.json`
- ❌ Не дублировать контент между шаблонами
- ❌ Не использовать project-specific имена в templates (canon + consumers должны быть абстрактны; примеры в comments только)

---

## Workflow rules

**Implementation through /code:** после `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена.

**Deploy branch tracing (F5):** Деплой через `/deploy` команду выполняется на ветке `agent_branch` из [CLAUDE.local.md](CLAUDE.local.md) → `## Branching` (default: `ai-dev`). Это позволяет различить agent-automated от manual human work. Team collaboration: git log показывает "commit by Claude on {agent_branch}" vs "commit by John on feature/auth". Важно для audit trail и regression tracking. Различение doc-репо vs code-репо обеспечивается изоляцией репозитория, не именем ветки.

**Deploy rule:** "деплой" = `git push origin main`. Перед каждым push:
1. `/review` если не запускался
2. DEVLOG запись `[deploy]` / `[feat:X]` / `[fix:X]` / `[methodology]`
3. Bump VERSION если изменены команды / шаблоны / хуки

**Architecture decision rule:** новая команда / шаблон / изменение `triggers.json` схемы → запустить `architect` sub-agent. Сначала собственная рекомендация, потом architect.

**Fix rule:**
- Симптом или причина? Симптом → найди причину
- Локальный или системный? Локальный без обоснования = красный флаг

**Completeness rule:**
Каждое решение (в /plan, /code, /review, /deploy) ДОЛЖНО явно указать:
- Что закрывается (main path, happy cases)
- Что НЕ закрывается (gaps, edge cases, параллельные пути)
- Почему эти gaps OK или требуют дополнительных шагов
Без этого анализа → план не утверждён, код не merged, деплой не выполнен.

Rationale and historical examples: [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md).

---

## Regulator levels (Level-4 framework)

Strong → weak: Schema constraint > No alternative path > Input structure > Few-shot > Description > Prompt rule.

При добавлении правила → спросить "есть ли level-4+ структурный фикс?". Если да — primary, правило secondary.

Пример: defensive `triggers.json` чтение в командах = level-1. Level-4 — единая схема в `templates/triggers.json.template`.

Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md).

---

## Model tier rule

Каждая команда методологии MUST содержать секцию `## Рекомендуемая модель` (5 полей: Default tier / Upgrade / Downgrade / Mid-task escalation / Pre-flight model check).

Канон: [.claude/model-tiers.md](.claude/model-tiers.md). При добавлении новой команды → добавь строку в матрицу + секцию в command-файл; `/review` блокирует merge без обеих.

Pre-flight check **спрашивает пользователя** о текущей модели (не self-detect — system prompt unreliable). Подтверждённое значение переиспользуется в сессии.

Когда Anthropic переименовывает модели — обнови **только** Mapping таблицу в `model-tiers.md`.

Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md).

---

## Mermaid link rule

При каждой записи или обновлении ` ```mermaid ` блока в артефакте — обновить ссылку над блоком:
```
> 🔗 [Открыть в Mermaid Live](<url>)
> _(обновить ссылку: `py scripts/mermaid-link.py <file>`)_
```
Сгенерировать URL: `py scripts/mermaid-link.py <file>` (скрипт в `scripts/`). Ссылка — дополнение к коду диаграммы, не замена. Self-hosted: изменить `BASE_URL` в `scripts/mermaid-link.py`.

**Валидация (two-repo):** для methodology-platform — выполни ОБЕ команды:
- `bash scripts/validate-mermaid-links.sh` — methodology repo (commands/, templates/, scripts/)
- `bash scripts/validate-mermaid-links.sh --root ../it-dev-methodology-documentation` — documentation repo (USER-MAP, SYSTEM-MAP, ARTIFACT-MAP)

Exit 1 = MISSING_LINK или STALE_LINK. Для single-repo проектов — только первая команда.

---

## Documentation map rule

**SYSTEM-MAP и USER-MAP MUST содержать Mermaid-диаграмму.** Замена на ASCII art или plain text запрещена — в больших проектах только Mermaid обеспечивает читаемый обзор.

**Гибридный язык (EN + RU):**
- Технические термины, имена файлов/команд — EN: `commands/`, `triggers.json`, `/plan → /code`
- Описания поведения, аннотации, метки на русском: `"анализ накопленного"`, `"единственный источник правды"`
- Пример корректного node: `Workflow["🔄 Workflow Cycle<br/>/plan → /code → /review → /deploy"]`

**Repo / setup контекст обязателен в USER-MAP.** Если проект использует внешний methodology-repo или infrastructure-repo — добавить `subgraph` или аннотацию, показывающую откуда берутся команды/шаблоны. Без этого новый разработчик не поймёт структуру.

`/review` блокирует merge если: (1) SYSTEM-MAP или USER-MAP изменены и Mermaid удалён; (2) новый разработчик не сможет понять repo-структуру из диаграммы.

---

## DEVLOG теги

`[fix:component]` `[feat:command]` `[feat:template]` `[feat:hook]` `[feat:script]` `[methodology]` `[process:X]` `[milestone]`

Phase-теги: `[phase-a]` … — milestone history.

Команды методологии: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`

**Semantic tagging rule (D6):** Проблемы categorize семантически, не по surface name.

Одна проблема — один semantic indicator, даже если люди называют по-разному:
- `[git-failure]` — не `[git_push-failed]` ИЛИ `[github-error]` ИЛИ `[branch-push-issue]` (все sync failures)
- `[async-failure:operation]` — не `[vault-sync-error]` И `[queue-dropped]` (оба fire-and-forget failures)
- `[state-pollution]` — не `[history-leak]` И `[cache-contamination]` (оба внутренние состояния)

**Reason:** Regex-based detection fails когда люди называют одно разными именами. Semantic category stays stable.

---

## Security: real threats

**Утечка токенов (was High → Mitigated, v4.34.0):** Структурно закрыто секцией [Secrets & Credentials](#secrets--credentials) ниже. Defense layers: L5 tool permission (`settings.json` Read+Bash deny на `.env`), L4 commit-time hook (`secrets-guard.py`), L4 PR review detector, L2 rotation discipline.

**Прямой push в main (High):** Branch protection не настроен. Будущая задача — required PR + review.

**Drift между методологией и консьюмерами (Med):** Sync ручной. Будущая задача — auto version-drift check в `/plan` Шаг -3.

**Sync overwrites local fills (Low):** `docs_reminder.py` LIBS заполняется per-project. Будущая задача — поддержка `*.local.py` соседних файлов.

Details with mitigation scenarios: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md).

---

## Secrets & Credentials

### Canonical storage (single source of truth per project)

| Источник | Назначение | Приоритет |
|---|---|---|
| `./.env` | per-project секреты (gitignored, chmod 600) | 1 |
| `~/.config/it-dev/secrets.env` | cross-project shared (опционально) | 2 |
| process env vars | CI/CD compatibility | 3 |

Декларация **какие** секреты нужны проекту: `.claude/secrets-manifest.yaml` (committed, без значений).

**Schema v2 (v4.41.0+):** каждая запись имеет `service_name` / `service_url` / `login` (optional) / `expires_at` (optional) / `last_rotated` (auto-managed) / `how_to_obtain_verified_at` (optional) / `scope_note` (optional). `git-credential-from-env.sh` использует `service_url` hostname для **multi-host routing** (один GitHub + один GitLab self-hosted → правильный токен per host). v1 entries backward-compat. Per-developer hygiene thresholds в `CLAUDE.local.md ## Secrets` (rotation_warn_days, expiry_warn_days, etc.).

### MUST (обязательные правила для агентов)

- ✅ Использовать `bash scripts/with-secret.sh KEY -- <command>` для передачи секрета subprocess'у. Значение **не попадает** в stdout агента → не в transcript → не в API.
- ✅ Использовать `bash scripts/check-secret.sh KEY` для boolean проверки (exit 0/1, без значения).
- ✅ Использовать `bash scripts/set-secret.sh KEY value` для one-time добавления (пользователь запускает, не агент).
- ✅ Для git HTTPS — `scripts/git-credential-from-env.sh` как credential helper (git сам читает токен, агент не в цепочке).
- ✅ При отсутствии required секрета → HARD BLOCK + показать `how_to_obtain` из manifest. **Не запрашивать токен через chat** — only one-time setup через `set-secret.sh`.
- ✅ Для аудита/scrub — команда `/secrets` (audit / setup / list / scrub).

### MUST NOT (запреты — закрыто структурно)

- ❌ Агент НЕ ЧИТАЕТ `.env` напрямую — заблокировано `settings.json` `Read(./.env)` + `Bash(cat .env*)` deny rules (L5 tool permission).
- ❌ Агент НЕ ВЫПОЛНЯЕТ `env`, `printenv`, `set | grep`, `echo $SECRET_VAR`, `source .env` — блокируется `bash_protect.py` (L4 hook).
- ❌ Агент НЕ ВПИСЫВАЕТ значения секретов в chat / DEVLOG / commit messages / любые файлы. Если случилось — `bash scripts/secrets-scrub.sh` (cleanup transcripts) + **немедленно rotate token** у провайдера.
- ❌ Не хранить `sensitivity: high` ключи в `--shared` scope (блокируется manifest-ом).
- ❌ Не bypass-ить pre-commit hook через `--no-verify` без записи в DEVLOG (`/review` всё равно catch-ит leak).
- ❌ Не editить `templates/.claude/hooks/secrets-guard.py` / `bash_protect.py` без понимания whitelist semantics — false negative = утечка.

### Threat model (по векторам, level-аннотированный)

| Вектор | Защита | Регулятор | Note |
|---|---|---|---|
| `git add .env` (случайный) | `.gitignore` excludes `.env`, `.env.*` (whitelist `.env.example`) | L4 | |
| `git add -f .env` (форсированный) | `secrets-guard.py` PreToolUse блокирует commit | L4 | |
| Token в коде (любом файле) | `secrets-guard.py` token-prefix + entropy на staged diff; `/review` detector на PR | L4 × 2 | |
| Агент `cat/grep/awk/sed/xxd/base64/python/node/perl/diff/iconv/tee/dd .env` | `settings.json` `permissions.deny` enumerated patterns (73 rules в v4.34.1+) | L5 — **common-paths** | Не universal: `bash -c '...'` wrapping, base64-encode-and-exfil, или unenumerated команды могут обходить. Rotation discipline = final safety net |
| Агент `env` / `printenv` / `echo $SECRET` | `bash_protect.py` `ENV_DUMP_PATTERNS` | L4 | Reliably detectable |
| Агент `Read` tool на `.env` | `settings.json` `Read(./.env)` deny | L5 | |
| Утечка через chat history | `/secrets scrub` cleanup в `~/.claude/projects/`; ротация токена | L2 (reactive) | |
| Compromise ноутбука | Out of scope — OS trust boundary | — | См. Scope limits |

### Scope limits (что Phase 1-5 НЕ закрывают)

Эти защиты **agent-mediated** (transcript, git, file system). Открыты и требуют OS/process-level mitigation:

- **`/proc/<pid>/environ` visibility** — другие процессы UID видят subprocess env. Mitigation: trust local OS boundary; full disk encryption.
- **Core dumps** — содержат full memory. Mitigation: `ulimit -c 0`.
- **Verbose process monitoring** (htop `-S`) — показывает env vars. Mitigation: не запускать с такими флагами.
- **Git history** — если секрет уже committed в прошлом, удаление из HEAD не очищает клоны. Mitigation: rotate token + `bash scripts/secrets-scrub.sh` + (manual) `git filter-repo` если критично. Phase 1-5 предотвращают **попадание** в commit, не лечат historical exposure.
- **CI/CD baking secrets в images/builds** — mount secrets at runtime, не at build. См. skill `secrets-management` Phase 5.
- **Determined adversarial prompt** — может построить bypass через base64 encode + remote send + reconstruct. Phase 1-5 поднимает barrier, не делает невозможным. **Rotation discipline** обязательна как defense-in-depth.
- **Windows NTFS chmod 600 не enforced** (v4.34.1+ explicit, closes G-016): Git Bash и WSL native applications не пробрасывают POSIX permissions через NTFS by default. `bash scripts/set-secret.sh` вызывает `chmod 600 .env` но реально файл остаётся `rw-r--r--` (читаемый all local users). На single-user dev машине — practical impact zero. На shared workstation — реальный риск. Mitigation: (1) single-user — assume trusted OS boundary; (2) shared workstation — manual restrict via PowerShell:
  ```powershell
  icacls .env /inheritance:r /grant:r "%USERNAME%:F"
  ```
  Это применяет ACL: только текущий пользователь имеет full access; все остальные denied. `set-secret.sh` warns при detection mismatch (v4.34.1+).

### Vault / external secret manager integration

`.env` — это **default**, не **mandate**. Consumer проекты с enterprise требованиями могут добавить Vault / AWS Secrets / Azure Key Vault через priority chain step 3 (process env):

```bash
# Pre-step: retrieve from external manager → export
export GITHUB_PAT=$(vault kv get -field=token kv/github)
# Methodology takes over via env
bash scripts/with-secret.sh GITHUB_PAT -- git push origin ai-dev
```

См. skill `secrets-management` для integration patterns с конкретными провайдерами.

### Token rotation workflow

Manual через `bash scripts/set-secret.sh KEY <new-value>` атомарно заменяет. Auto-rotation requires provider-specific adapters (out of methodology scope — каждый provider свой API). См. skill секцию "Rotation workflow per common providers" (GitHub, Anthropic, AWS).

### Compromise response

Если ты подозреваешь что секрет утёк:

1. **Rotate at provider IMMEDIATELY** — revoke old token, generate new.
2. **`bash scripts/set-secret.sh KEY <new-value>`** — update local store.
3. **`bash scripts/secrets-scrub.sh`** — очистить transcripts в `~/.claude/projects/`.
4. **`git log -p | grep -i <key-name>`** — проверить historical exposure в git.
5. Если в git history → `git filter-repo --replace-text` + force-push + notify всех contributors.
6. Notify affected external services о возможной exposure.

См. skill `secrets-management/SKILL.md` для пошагового runbook.

---

## Key files

- [scripts/new-project-init.sh](scripts/new-project-init.sh) — bootstrap
- [scripts/sync-methodology.sh](scripts/sync-methodology.sh) — sync
- [scripts/deploy-push.sh](scripts/deploy-push.sh) — deploy push (reads mode from CLAUDE.local.md, enforces solo/team pattern)
- [scripts/migrate-claude-md.sh](scripts/migrate-claude-md.sh) — Phase G2 split migration helper
- [commands/plan.md](commands/plan.md) — workflow entry point
- [commands-local/pull-consumers.md](commands-local/pull-consumers.md) — **LOCAL-ONLY** команда: pull всех consumer repos из workspace + diff новых methodology-tracked записей. НЕ синхронизируется консьюмерам
- [templates/triggers.json.template](templates/triggers.json.template) — canonical state schema
- [templates/model-tiers.md](templates/model-tiers.md) — model recommendation registry
- [templates/AGENT-GAPS.md.template](templates/AGENT-GAPS.md.template) — AI gap capture (consumer artifact)
- [templates/.claude/hooks/agent-gaps-watchdog.py](templates/.claude/hooks/agent-gaps-watchdog.py) — Stop hook: admission detector
- [scripts/with-secret.sh](scripts/with-secret.sh) — **secrets injection** (primary tool): `with-secret.sh KEY -- cmd` — значение не в stdout
- [scripts/check-secret.sh](scripts/check-secret.sh) — boolean existence check (exit 0/1)
- [scripts/set-secret.sh](scripts/set-secret.sh) — atomic write в `.env` (one-time setup)
- [scripts/validate-secrets.sh](scripts/validate-secrets.sh) — manifest ↔ `.env` consistency
- [scripts/git-credential-from-env.sh](scripts/git-credential-from-env.sh) — git credential helper
- [scripts/secrets-scrub.sh](scripts/secrets-scrub.sh) — cleanup transcripts (`~/.claude/projects/`) от случайных утечек
- [scripts/clone-consumer.sh](scripts/clone-consumer.sh) — clone consumer репо без exposing tokens в URL
- [commands/secrets.md](commands/secrets.md) — `/secrets` команда: audit / setup / list / scrub
- [skills/secrets-management/SKILL.md](skills/secrets-management/SKILL.md) — knowledge: rotation, Vault integration, compromise response
- [templates/.env.example.template](templates/.env.example.template) — consumer template (commit-safe)
- [templates/secrets-manifest.yaml.template](templates/secrets-manifest.yaml.template) — declared-secrets schema
- [templates/.claude/hooks/secrets-guard.py](templates/.claude/hooks/secrets-guard.py) — PreToolUse: блок commit с token / staged .env
- [scripts/secrets-show.sh](scripts/secrets-show.sh) — **просмотр metadata** (v4.41.0+): table или single-entry view, без значений
- [scripts/secrets-update.sh](scripts/secrets-update.sh) — **rotation interactive** (v4.41.0+): value-only update, atomic backup, re-paste confirm
- [scripts/secrets-edit.sh](scripts/secrets-edit.sh) — **metadata edit** (v4.41.0+): service_name/url/login/expires_at, value untouched
- [scripts/secrets-rollback.sh](scripts/secrets-rollback.sh) — **restore .env** из .env.backup-{timestamp} (v4.41.0+)
- [scripts/secrets-cleanup-backups.sh](scripts/secrets-cleanup-backups.sh) — prune старые backup файлы (v4.41.0+)
- [VERSION](VERSION) — semver

---

## External links

- GitHub: {{github-url}}
- Примеры консьюмер-проектов:
  - **Single-developer project** (e.g., solo-dev consumer) — single-tier vision
  - **Multi-service platform** (e.g., team-based consumer) — multi-tier vision, per-service триггеры, inbox, ADR
