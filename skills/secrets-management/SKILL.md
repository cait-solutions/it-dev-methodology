---
name: secrets-management
description: Knowledge-domain skill для управления секретами проекта (API tokens, credentials, repo PATs). Активируй когда пользователь упоминает токены, secrets, утечку токена, ротацию, compromised credential, как добавить секрет, где хранятся ключи, как настроить Vault/keyring/AWS Secrets, что делать если ключ попал в commit, secrets-manifest, .env files, GitHub PAT, ANTHROPIC_API_KEY, OS keyring, credential helper, или связанные темы. Описывает 4-слойную защиту (gitignore + pre-commit hook + /review detector + tool deny), threat model, rotation workflow per provider, compromise response runbook, external secret manager integration (Vault/AWS/Azure), OS hardening recommendations. Не выполняет операции сам — направляет к scripts/with-secret.sh, scripts/set-secret.sh, /secrets команде. Требует наличия .claude/secrets-manifest.yaml в проекте.
metadata:
  version: 1.0.0
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

**Documentation:** [CLAUDE.md § Secrets & Credentials](../../CLAUDE.md#secrets--credentials)
