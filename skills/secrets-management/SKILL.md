---
name: secrets-management
description: Knowledge-domain skill для управления секретами проекта (API tokens, credentials, repo PATs). Активируй когда пользователь упоминает токены, secrets, утечку токена, ротацию, compromised credential, как добавить секрет, где хранятся ключи, как настроить Vault/keyring/AWS Secrets, что делать если ключ попал в commit, secrets-manifest, .env files, GitHub PAT, ANTHROPIC_API_KEY, OS keyring, credential helper, или связанные темы. Описывает 4-слойную защиту (gitignore + pre-commit hook + /review detector + tool deny), threat model, rotation workflow per provider, compromise response runbook, external secret manager integration (Vault/AWS/Azure), OS hardening recommendations. Не выполняет операции сам — направляет к scripts/with-secret.sh, scripts/set-secret.sh, /secrets команде. Требует наличия .claude/secrets-manifest.yaml в проекте.
metadata:
  version: 1.1.0
  type: knowledge-skill
  auto_generated: false
  methodology_version: v4.34.0
  synced_at: "{{SYNCED_AT}}"
  source: https://github.com/cait-solutions/it-dev-methodology
  banner: "Synced from methodology-platform v4.34.0 — DO NOT EDIT skill logic directly. Modify via PR to methodology repo."
---

# secrets-management — Управление секретами

Knowledge skill для всего что связано с tokens / credentials / API keys / .env / secret stores в проектах использующих it-dev-methodology.

> **Принцип:** ты направляешь пользователя к правильным методологическим инструментам. Ты НЕ выполняешь setup/rotation сам — это manual workflow с инструкциями.

---

## Архитектура защиты (4 слоя)

| Уровень | Слой | Что закрывает | Регулятор |
|---|---|---|---|
| L5 | `settings.json` `permissions.deny` — `Read(./.env*)`, `Bash(cat .env*)`, etc. | Harness блокирует чтение `.env` до выполнения. Включает popular reader-команды (cat/grep/awk/sed/xxd/base64/etc) | Tool permission |
| L4 | `templates/.claude/hooks/secrets-guard.py` | Blocks `git commit` если staged `.env` или token-shaped string в diff | PreToolUse hook |
| L4 | `templates/.claude/hooks/bash_protect.py` | Blocks `env`, `printenv`, `echo $SECRET`, `source .env` (env-dump patterns с no legitimate use) | PreToolUse hook |
| L4 | `/review` token detector | Catches leaks at PR review stage | Manual review |
| L2 | Rotation discipline (this skill) | Reactive: when leak happens, rotate immediately | Documented runbook |

**Что важно понять:**

Bash regex filtering — **best-effort**, не airtight. Determined adversarial prompt может построить bypass через base64 encode + remote send + reconstruct. Защита поднимает barrier и catches obvious mistakes, не делает leak невозможным. **Rotation discipline обязательна** как defense-in-depth.

---

## Canonical storage

| Источник | Назначение | Priority |
|---|---|---|
| `./.env` | per-project секреты (gitignored, chmod 600) | 1 |
| `~/.config/it-dev/secrets.env` | cross-project shared (опционально) | 2 |
| process env vars | CI/CD compatibility | 3 |

Декларация: `.claude/secrets-manifest.yaml` (committed, без значений).

---

## Schema v2 (v4.41.0+) — per-entry metadata

Schema v1 хранила только key/purpose/required/how_to_obtain — это работало для single-host scenarios но не отвечало на "к чему этот токен относится" и не поддерживало multi-host routing.

Schema v2 добавляет per-entry поля:

| Поле | Назначение |
|---|---|
| `service_name` | Human-readable name (e.g. "GitHub cait-solutions", "GitLab Nexchance") |
| `service_url` | URL/hostname сервиса — используется git-credential-from-env.sh для routing |
| `login` | Optional username/email/account ID |
| `expires_at` | ISO date когда токен истекает — `/secrets --audit` warns в expiry_warn_days |
| `last_rotated` | Auto-managed timestamp — warns после rotation_warn_days (default 90) |
| `how_to_obtain_verified_at` | Когда последний раз проверял что `how_to_obtain` URL still works |
| `scope_note` | Free text re: permissions (e.g. "repo, workflow") — useful для rotation |

**Все поля optional** — v1 entries без них продолжают работать. Schema migration "lazy" — fields populate'ятся при следующем `set-secret KEY`.

### Multi-host scenario (real use case)

Personal GitHub PAT + work GitLab self-hosted в одном проекте:

```yaml
secrets:
  - key: GITHUB_PAT
    service_name: "GitHub (cait-solutions)"
    service_url: "https://github.com"
    login: "oauth2"
    # ...

  - key: GITLAB_NEXCHANCE
    service_name: "GitLab Nexchance"
    service_url: "https://code.nexchance.de"
    login: "vb@nexchance.de"
    # ...
```

`git-credential-from-env.sh` extracts request host from git stdin → matches first manifest entry where `service_url` hostname matches → returns that entry's value. **Multi-host routing работает automatically.**

### Known limitation: multi-account same host

Если у тебя 2 GitHub accounts (личный + work) на одном `github.com` — schema v2 first-match wins (warning при multi-match). Workaround:
- Используй distinct hostnames через `~/.ssh/config` или `/etc/hosts` aliases (e.g. `github-work.com`)
- ИЛИ wait для schema v3 с `account_filter` field (future)

### `gh_account` + `keychain_backend` — два опциональных поля

- **`gh_account`** (per-entry, optional) — имя `gh` CLI аккаунта, требуемого для репо (github.com remotes через gh credential helper). `/pull-consumers` pre-flight: если активный `gh` аккаунт ≠ этому значению → warning + команда `gh auth switch`. Multi-account сценарий (личный + work на одном github.com). Omit для не-GitHub / PAT-only. Пример: `gh_account: "cait-solutions"`.
- **`keychain_backend`** (config-блок, optional, default `false`) — opt-in OS keychain как at-rest-encrypted storage ПЕРЕД `.env`. `with-secret.sh` сначала смотрит keychain: macOS `security` (из коробки), Linux `secret-tool` (libsecret, DE-dependent), Windows DPAPI (ограниченно). Fall-through на `.env` если keychain недоступен/пуст. Рекомендуется на macOS/Windows; на Linux headless — `false`. Store (macOS): `security add-generic-password -s it-dev-methodology -a KEY -w VALUE`.

### `git_remote: true` — SSOT для git-remote (v5.22.0, closes P-006)

**Проблема:** `git remote origin` и manifest — два источника правды о том «куда пушить». При bootstrap remote мог быть выставлен дефолтным github-паттерном, а реальный repo — на другом хосте (GitLab). Push стучался по неверному remote (404), хотя manifest содержал правильный `service_url`.

**Решение:** пометить git-секрет `git_remote: true` — он становится **источником правды** для git-remote:
```yaml
  - key: GITLAB_NEXCHANCE
    service_url: "https://code.nexchance.de/team/repo.git"  # полный repo URL
    git_remote: true                                         # ← SSOT для push/pull
    login: "you@org.com"
```

**Как работает:**
- Push-команды (`/push-merge`, `/deploy`) перед push сверяют `git remote origin` с `service_url` секрета у которого `git_remote: true`.
- Расхождение → команда **предлагает выровнять** remote под manifest (`git remote set-url`, с подтверждением — не молча меняет git config).
- `service_url` авторитетнее `git remote`: его ввёл пользователь осознанно при добавлении секрета (тот же URL что для clone/workspace).

**Авто-определение без флага:** если `git_remote: true` не стоит ни у одного секрета, но ровно один `service_url` оканчивается на `.git` — он считается git-remote автоматически. Несколько `.git` без флага → неоднозначно, fallback на текущий `git remote` (graceful). Ставь флаг у ОДНОГО секрета (того что для push).

**Актуальность источника:** manifest ведущий, remote выравнивается под него при каждом push-расхождении → SSOT не устаревает (рассинхрон ловится в момент push, предлагается фикс).

---

## File-type secrets — credential-файлы (v6.4.7+, GCP/Vertex/AWS)

**Когда:** секрет — это **файл на диске**, а не строка-токен. Типичный случай: GCP service account JSON (Vertex AI, Gemini через Vertex, n8n GCP-нодa), TLS-сертификат, AWS credentials-файл. UI таких сервисов часто не принимает credential как строку — нужен путь к файлу.

**Механизм — поле `type` в manifest-записи:**

| `type` | Что в `.env` | Пример |
|---|---|---|
| `value` (default) | сам секрет (токен/пароль/API-key) | `GITHUB_PAT=ghp_xxx` |
| `file` | **путь к файлу** с credentials (не содержимое) | `GOOGLE_APPLICATION_CREDENTIALS=.gcp/proj-abc.json` |

При `type: file` `validate-secrets.sh` проверяет **две** вещи: (1) env-var задан в `.env`, (2) файл существует по этому пути. Содержимое файла НЕ матчится token-detector'ом (`token_pattern: null`).

**Канонический workflow (GCP/Vertex service account JSON):**

```yaml
# 1. Объявить в .claude/secrets-manifest.yaml (раскомментировать GCP-группу из template):
secrets:
  - key: GOOGLE_CLOUD_PROJECT          # type: value (default) — это просто project id
    purpose: "GCP project id"
    # ...
  - key: GOOGLE_APPLICATION_CREDENTIALS
    type: file                          # ← значение в .env = ПУТЬ, не содержимое
    purpose: "Path to GCP service account JSON (Application Default Credentials)"
    sensitivity: high
    token_pattern: null
  - key: GOOGLE_CLOUD_LOCATION         # type: value — регион (europe-west1 и т.п.)
```

```bash
# 2. Положить JSON в .gcp/ — директория УЖЕ в .gitignore (доставляется sync'ом, zero-config):
#    .gcp/<project>-<hash>.json
#    (если файл был staged до обновления .gitignore: git rm --cached .gcp/<file>.json)

# 3. Записать ПУТЬ (не содержимое) — пользователь запускает сам:
bash scripts/set-secret.sh GOOGLE_APPLICATION_CREDENTIALS
#    На запрос значения ввести путь: .gcp/<project>-<hash>.json

# 4. Проверить:
bash scripts/validate-secrets.sh        # type:file → 📄 ... ✓ если файл на месте

# 5. Использовать (agent-safe): SDK сам читает путь из env-var, агент не видит содержимое:
bash scripts/with-secret.sh GOOGLE_APPLICATION_CREDENTIALS -- py gen.py
#    google-cloud-aiplatform / любой Google SDK подхватывает GOOGLE_APPLICATION_CREDENTIALS
#    как Application Default Credentials автоматически.
```

**⛔ Безопасность — то же что для value-секретов, плюс file-специфика:**
- Агент НЕ читает JSON напрямую (`cat .gcp/*.json` → попадёт в transcript). Путь в `.env` — ОК (не секрет); содержимое файла — секрет.
- `.gcp/` gitignored by-construction → JSON не коммитится. Не класть credential-файлы вне gitignored директорий.
- `with-secret.sh GOOGLE_APPLICATION_CREDENTIALS -- cmd` инжектит **путь** в env subprocess — SDK сам открывает файл, путь в stdout не утекает как секрет (это и не секрет — секрет внутри файла).

**Few-shot:**
✅ Vertex AI image-gen: объявить `GOOGLE_APPLICATION_CREDENTIALS` с `type: file`, JSON в `.gcp/`, запуск через `with-secret.sh ... -- py script.py`.
❌ Класть JSON вне репо и хардкодить абсолютный путь в коде — теряется validate-secrets проверка + не переносимо между машинами. Канон: `.gcp/` внутри проекта (gitignored).
❌ Просить пользователя вставить содержимое JSON в чат / в `.env` как строку — это file-секрет, хранится файлом, в `.env` только путь.

---

## Configurable values (v4.41.0+)

Defaults в `.claude/secrets-manifest.yaml` config block; per-developer overrides в `CLAUDE.local.md ## Secrets`:

| Value | Default | Override причина |
|---|---|---|
| `expiry_warn_days` | 7 | Production: 30+ |
| `rotation_warn_days` | 90 | High-security: 30 |
| `how_to_obtain_warn_days` | 180 | Low-churn services: 365 |
| `backup_retention_hours` | 24 | Compliance: 168 (7d) |
| `default_url_scheme` | https | Internal: http |
| `strict_schema` | false | Enterprise: true (enforce v2 fields) |

---

## User workflows (v4.41.0+ subcommands)

### Add new secret (one-time)
```bash
bash scripts/set-secret.sh GITHUB_PAT
# Interactive: prompts service_name, URL, login, expires_at, value (read -s), re-paste
```

### View metadata (без значения)
```bash
bash scripts/secrets-show.sh                    # table
bash scripts/secrets-show.sh GITHUB_PAT         # detail
```

### Update value (rotation)
```bash
bash scripts/secrets-update.sh GITHUB_PAT
# Shows masked current → new value (read -s) → re-paste confirm → atomic backup + write
```

### Edit metadata (без значения)
```bash
bash scripts/secrets-edit.sh GITHUB_PAT
# Updates service_name / URL / login / expires_at; value untouched
```

### Rollback (если ошибся)
```bash
bash scripts/secrets-rollback.sh --list         # available backups
bash scripts/secrets-rollback.sh                # latest backup
bash scripts/secrets-rollback.sh .env.backup-20260529-143022   # specific
```

### Audit hygiene
```bash
bash scripts/validate-secrets.sh
# Shows missing required + expires_at warnings + rotation warnings + how_to_obtain freshness
```

---

## Onboarding new developer (team mode)

1. Clone repo → `bash scripts/sync-methodology.sh .`
2. `.claude/secrets-manifest.yaml` уже committed — список нужных secrets visible
3. `bash scripts/validate-secrets.sh` → shows missing keys + their `how_to_obtain`
4. Для each missing required: `bash scripts/set-secret.sh KEY` (interactive)
5. **Manifest shared, values per-developer** — each developer has own `.env`

---

## Migration from `gh auth login`

Если уже используешь `gh auth` для GitHub:

```bash
# 1. Check current token (manually copy from gh's storage)
gh auth status

# 2. Add to methodology canonical store
bash scripts/set-secret.sh GITHUB_PAT
#    Service: GitHub (cait-solutions)
#    URL: https://github.com
#    Login: oauth2
#    Value: paste from step 1

# 3. Optional: configure credential helper (recommended)
git config credential."https://github.com".helper \
  "!bash $(pwd)/scripts/git-credential-from-env.sh"

# 4. Optional cleanup: gh auth logout (gh CLI remains as fallback in priority chain)
```

`gh auth` остаётся как fallback если methodology helper не находит match (см. git credential helper chain).

---

## CI/CD usage (non-tty)

Interactive `read -s` зависает в CI. Use inline mode:

```bash
bash scripts/set-secret.sh GITHUB_PAT "$CI_GITHUB_PAT" \
  --service "GitHub CI" --url "https://github.com" --login "oauth2" --no-confirm
```

CI secret variable (`CI_GITHUB_PAT`) подставляется envvar — не в shell history.

---

## Workflow: добавить новый секрет (one-time setup)

Пользователь (НЕ агент) выполняет:

```bash
# 1. Добавить декларацию в .claude/secrets-manifest.yaml (если ещё нет):
#    - key: NEW_API_KEY
#      purpose: "Description"
#      required: true
#      scope: per-project
#      sensitivity: high
#      token_pattern: "<regex>"
#      how_to_obtain: |
#        <instructions>

# 2. Сохранить значение (атомарная запись в .env):
bash scripts/set-secret.sh NEW_API_KEY <value>

# 3. Проверить что всё корректно:
bash scripts/validate-secrets.sh
# Or via slash command:
# /secrets
```

**Агент НЕ просит значение через chat.** Если секрет нужен — show how_to_obtain из manifest, остановись, ждать пока пользователь сам выполнит `set-secret.sh`.

---

## Workflow: использовать секрет в команде (agent-safe)

```bash
# ✅ Правильно — injection pattern (значение в subprocess env, не в stdout):
bash scripts/with-secret.sh GITHUB_PAT -- git push origin ai-dev

# ✅ Boolean проверка (не нужно значение):
if bash scripts/check-secret.sh GITHUB_PAT; then
  echo "PAT present"
fi

# ❌ ЗАПРЕЩЕНО — value попадает в stdout агента → transcript → leak:
cat .env                          # blocked by settings.json + bash_protect
env | grep GITHUB                 # blocked by bash_protect
echo $GITHUB_PAT                  # blocked by bash_protect
python -c "print(open('.env').read())"  # best-effort blocked by settings.json
```

**Forcing function escape hatch** (raw value print, только для manual debugging — НЕ для agent):

```bash
bash scripts/_get-secret-raw.sh GITHUB_PAT --explicit-stdout
```

Без `--explicit-stdout` скрипт выводит инструкцию и exit 2. Это **forcing function** — нельзя случайно вытащить значение, нужен явный opt-in.

---

## Token rotation workflow

### Общий algorithm (per provider)

1. **Revoke at provider** — login → settings/tokens → revoke old. Это первый шаг чтобы compromised token стал invalid немедленно.
2. **Generate new token** — same settings page → create new with same scopes.
3. **Update local store** — `bash scripts/set-secret.sh KEY <new-value>` (atomic, no race window).
4. **Scrub transcripts** — `bash scripts/secrets-scrub.sh` чтобы убрать historical exposures из `~/.claude/projects/`.
5. **Check git history** — `git log -p --all -S "<old-token-prefix>"`. Если найден — `git filter-repo` + force push + notify contributors.
6. **Notify affected services** — если token использовался в CI/CD, мониторинге, internal tools — обновить везде.

### Per-provider URLs (актуально на v4.34.0)

| Provider | Token settings | Required scopes |
|---|---|---|
| GitHub | https://github.com/settings/tokens | `repo`, `workflow` (для CI changes) |
| Anthropic | https://console.anthropic.com/settings/keys | API access |
| OpenAI | https://platform.openai.com/api-keys | API access |
| AWS | https://console.aws.amazon.com/iam/home#/security_credentials | (depends on use case) |
| Slack | https://api.slack.com/apps → OAuth | Bot scopes |

### Auto-rotation

Methodology НЕ implementation auto-rotation. Причина: каждый provider свой rotation API (no universal contract). Manual через `set-secret.sh` остаётся single source of truth.

Если auto-rotation критичен — добавить provider-specific wrapper в проектные `scripts/`, который вызывает `set-secret.sh` после получения нового token от provider's API.

---

## Compromise response runbook

Если ты подозреваешь утечку (commit в public repo, leaked transcript, observed unauthorized API calls, etc.):

### Immediate (first 15 minutes)

1. **REVOKE at provider** — приоритет 1. Каждая минута между обнаружением и revoke = риск abuse.
2. **Generate new token** — same provider settings.
3. **Set new value locally** — `bash scripts/set-secret.sh KEY <new-value>`.

### Investigation (next hour)

4. **Run scrub** — `bash scripts/secrets-scrub.sh` чтобы найти exposures в `~/.claude/projects/` и configured paths.
5. **Check git history** на ВСЕХ ветках:
   ```bash
   git log -p --all -S "ghp_" | head -50   # adjust prefix to match leaked token
   ```
6. **Check shell history** — `history | grep "ghp_"` (или соответствующий prefix).
7. **Check CI logs / artifacts** — если token использовался в CI, проверить build logs, deployed images, cached artifacts.

### Cleanup (next day)

8. **Git filter-repo if needed** (only if token попал в git history):
   ```bash
   git filter-repo --replace-text <(echo "<leaked-token>==>[REDACTED]")
   git push --force origin <branch>  # WARNING: coordinate with all contributors
   ```
9. **Force-rotate related tokens** — если этот token открывал доступ к чему-то что выдаёт другие tokens (e.g., service account → child tokens), rotate cascade.
10. **Notify**:
    - Co-developers (если team mode)
    - Affected external services (provider security team если data breach)
    - GitHub Secret Scanning (если public repo — they may auto-detect)

### Post-mortem

11. **Document в DEVLOG**: `[security:leak] KEY rotated 2026-MM-DD. Source: <commit-hash> или <chat session>. Action: rotated + scrubbed + filter-repo.`
12. **Update methodology** — если root cause = methodology gap, открыть PROBLEMS-GAPS.md / AGENT-GAPS.md.

---

## External secret manager integration

`.env` — это **default**, не **mandate**. Enterprise проекты могут использовать external managers через priority chain step 3 (process env).

### HashiCorp Vault

```bash
# Pre-step: retrieve from Vault → export to current shell
export GITHUB_PAT=$(vault kv get -field=token kv/secrets/github)

# Methodology takes over via env var
bash scripts/with-secret.sh GITHUB_PAT -- git push origin ai-dev
```

Wrap in helper script для reuse:

```bash
# scripts/with-vault-secret.sh
#!/usr/bin/env bash
set -euo pipefail
KEY="$1"; shift
VAULT_PATH="$1"; shift
SEPARATOR="$1"  # should be --
[[ "$SEPARATOR" != "--" ]] && { echo "Usage: ... PATH -- cmd" >&2; exit 2; }
value=$(vault kv get -field=token "$VAULT_PATH")
exec env "${KEY}=${value}" "$@"
```

### AWS Secrets Manager

```bash
export GITHUB_PAT=$(aws secretsmanager get-secret-value \
                     --secret-id prod/github/pat \
                     --query SecretString --output text)
bash scripts/with-secret.sh GITHUB_PAT -- git push
```

### Azure Key Vault

```bash
export GITHUB_PAT=$(az keyvault secret show \
                     --vault-name prod-vault \
                     --name github-pat \
                     --query value -o tsv)
bash scripts/with-secret.sh GITHUB_PAT -- git push
```

### 1Password CLI

```bash
export GITHUB_PAT=$(op read "op://Production/GitHub PAT/token")
bash scripts/with-secret.sh GITHUB_PAT -- git push
```

**Key insight:** the methodology contract is just "secret available via env at moment of subprocess invocation." Anything that puts the value into env satisfies the contract. Manager choice is project policy decision.

---

## Why NOT direnv / .netrc / OS keychain as PRIMARY storage (design rationale)

Частый вопрос reviewer'ов: «почему не взяли стандартный direnv / `.netrc` / OS keychain вместо своего `.env` + `set-secret.sh`?». Краткий ответ: **они решают storage-at-rest, наш primary threat — agent transcript leak. Это ортогональные оси.** Каждый из них можно использовать как **backend** (см. ниже), но не как primary access mechanism.

### direnv — ❌ anti-pattern для agent-mediated security

direnv авто-экспортирует `.env` в **parent shell environment** на `cd`. Но Claude Code's Bash tool работает именно в этом parent shell → секрет становится видим агенту через `printenv VAR`, `echo $VAR`, `python -c "import os; os.environ"` и сотни других путей. Наш `bash_protect.py` блок `env`/`echo $SECRET` становится **бесполезен** — значение уже в окружении.

**Наш `with-secret.sh KEY -- cmd` делает обратное:** значение видит только subprocess `cmd`, parent shell агента — никогда. Это и есть differentiator. direnv — отличный developer-convenience tool, но его суть (экспорт в окружение) противоречит нашему требованию (скрыть от parent).

### .netrc — ограниченный scope, тот же read-leak

`.netrc` — стандарт для git/curl HTTPS credentials (`machine/login/password` triple). Но:
- Только git-style credentials — нет произвольных API keys (`sk-ant-...`), DB connection strings, и т.п.
- `cat ~/.netrc` → значение в transcript (тот же leak что `.env`, не безопаснее)
- Нет manifest declaration, нет metadata (service_name, expires_at)

Для **git-HTTPS-only** consumers `.netrc` — валидная альтернатива нашему `git-credential-from-env.sh` (git читает его нативно). Но наш scope шире.

### OS keychain — лучше at-rest, но ортогонально + fragmented

macOS Keychain / Windows Credential Manager / Linux libsecret — **encrypted at rest** (наш `.env` plaintext — здесь keychain объективно сильнее). НО:
- При **чтении** значение в stdout: `security find-generic-password -w` → leak идентичен `.env`. Keychain защищает at-rest, не at-read.
- Cross-platform fragmentation: 3 разных CLI API.
- Headless/CI: keychain недоступен (нет GUI unlock).

**Keychain решает другую угрозу** (украли диск → файл зашифрован), не нашу (значение → transcript → API). Ортогонально.

### Using them as a storage BACKEND (поверх нашего injection layer)

Priority chain **step 3 (process env)** позволяет любой из них как backend — наш injection layer берёт управление на этапе передачи subprocess'у:

```bash
# direnv as backend (не как primary — явный exec, не auto-export в agent shell):
direnv exec . bash scripts/with-secret.sh KEY -- cmd

# OS keychain as backend (macOS):
export GITHUB_PAT=$(security find-generic-password -w -s github)
bash scripts/with-secret.sh GITHUB_PAT -- git push

# OS keychain (Windows Credential Manager via PowerShell):
# $t = (cmdkey /list ...); export GITHUB_PAT=$t; with-secret ...

# .netrc — git читает нативно (parallel path, не через нас) — для git-only OK
```

### Platform-conditional storage strategy (recommended)

| Платформа | Keychain availability | Рекомендация |
|---|---|---|
| **macOS** | Keychain — из коробки, всегда | keychain backend **приоритизировать** (закрывает at-rest gap, zero extra deps) |
| **Windows** | Credential Manager — из коробки | keychain backend **приоритизировать** |
| **Linux desktop** (GNOME/KDE) | libsecret/gnome-keyring — есть, но DE-dependent | `.env` baseline; keychain opt-in если DE present |
| **Linux headless/server/CI** | ❌ нет гарантии (no DE / GUI unlock) | **`.env` + chmod 600 — надёжный baseline** |

**Вывод:** `.env` остаётся universal baseline (works everywhere, zero deps). На macOS/Windows keychain backend — strict improvement at-rest без нарушения zero-deps. На Linux — conditional (см. `with-secret.sh` step 0 keychain detection, v4.42.0+).

---

## OS-level hardening recommendations

Phase 1-5 защиты — **agent-mediated**. Они НЕ закрывают OS-level compromise. Дополнительные recommendations:

### Mandatory

- **Full disk encryption** — FileVault (macOS), BitLocker (Windows), LUKS (Linux). Если ноутбук скомпрометирован физически — `.env` всё равно protected at rest.
- **`ulimit -c 0`** в shell init — disable core dumps (которые включают full memory с secrets).
- **chmod 600 `~/.config/it-dev/secrets.env`** — `set-secret.sh --shared` делает это автоматически, но проверь периодически.

### Recommended

- **Не запускать verbose process monitoring** на dev машине (htop с `-S` flag показывает env vars другим users).
- **OS account separation** — не работать с production credentials под admin/root account.
- **Audit shell history** — `histcontrol=ignoreboth:erasedups` чтобы не сохранять commands с pasted values (когда manually paste'ишь token).

### Advanced (если threat model требует)

- **Hardware security keys** для critical credentials (YubiKey FIDO2 для GitHub).
- **Separate VM / container** для работы с production secrets.
- **Audit log shipping** — local actions → SIEM (Splunk, Datadog, Loki) для anomaly detection.

---

## Известные ограничения (honest scope)

1. **Bash regex parsing leaks** — невозможно полностью filter shell commands регулярными выражениями. Mitigation: settings.json deny + commit-time guard + rotation discipline.
2. **Process env visibility** — `/proc/<pid>/environ` видим other UID processes. Mitigation: trust local OS boundary.
3. **Adversarial prompt injection** — determined attacker может построить bypass. Mitigation: rotation + audit.
4. **CI/CD secrets** — out of methodology scope. Recommendation: mount at runtime, не bake into images.
5. **Git history** — `secrets-guard.py` prevents commit, не cleans history. Mitigation: scrub + filter-repo if needed.

---

## Quick reference

```
ADD:        bash scripts/set-secret.sh KEY <value>
USE:        bash scripts/with-secret.sh KEY -- <command>
CHECK:      bash scripts/check-secret.sh KEY        # exit 0/1
AUDIT:      /secrets    OR   bash scripts/validate-secrets.sh
LIST:       /secrets --list
SCRUB:      bash scripts/secrets-scrub.sh
ROTATE:     /secrets --rotate KEY
EMERGENCY:  /secrets --scrub --clean   (destructive, asks confirm)
```

**Файлы canonical store:**
- `.env` — per-project
- `~/.config/it-dev/secrets.env` — cross-project shared
- `.claude/secrets-manifest.yaml` — declaration (committed)

**Hook layers:**
- `templates/.claude/hooks/protect.py` — blocks Edit/Write на secret files
- `templates/.claude/hooks/bash_protect.py` — blocks env dumps
- `templates/.claude/hooks/secrets-guard.py` — blocks git commit of secrets

**Documentation:** consumer's `CLAUDE.md § Secrets & Credentials` (created by `new-project-init.sh` from `templates/CLAUDE.template.md`). For methodology contributors: see `templates/CLAUDE-methodology.template.md § Secrets & Credentials` (the canonical version).
