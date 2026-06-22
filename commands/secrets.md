# /secrets — Управление секретами проекта

> **Цель:** unified UX для добавления / просмотра / редактирования / ротации / scrub секретов. Все секреты живут в `.env` (per-project) + опционально `~/.config/it-dev/secrets.env` (shared). Метаданные в `.claude/secrets-manifest.yaml` (schema v2 v4.41.0+).

> ⛔ **Агент НЕ вводит значения сам.** `--add` / `--update` / `--edit` показывают команду пользователю — пользователь сам запускает в терминале (значение через `read -s` не попадает в transcript).

---

## Рекомендуемая модель

**Extended (UI settings):** effort: **Low** · thinking: **OFF** — CLI wrapper над secrets-скриптами (mechanical). См. `.claude/model-tiers.md` § Effort & Thinking.

**Default tier:** **Fast tier** — простой CLI wrapper. **Upgrade:** нет. **Pre-flight check:** Capable (Opus) → 🟡 over-powered → рекомендация Fast.

---

## Dispatch rule (ПЕРВЫМ после вызова)

**До любых проверок — определить тип вызова:**

1. **`/secrets` (без аргументов) ИЛИ `/secrets --help`** → немедленно вывести **help screen** (секция `/secrets (без аргументов)` ниже). Context check **не нужен** — меню информационное, скриптов не запускает.

2. **Любой другой аргумент** (`--list`, `--audit`, `--add`, `--show`, `--edit`, `--update`, `--rollback`, `--scrub`, `--rotate`, `--delete`, `--verify-link`) → сначала Context check, затем подкоманда.

---

## Context check (только для подкоманд с аргументами)

Перед запуском любого `secrets-*.sh` скрипта агент ОБЯЗАН проверить контекст:

```
1. Есть ли .claude/secrets-manifest.yaml в текущем cwd?
   [[ -f ".claude/secrets-manifest.yaml" ]] — да/нет

2. Если НЕТ — найти репо в workspace где manifest присутствует:
   Просканировать sibling папки (рядом с текущим репо).
   Сообщить:
     ⚠️ Manifest не найден в <cwd>.
        Найден в: <path-to-repo-with-manifest>
        Запускать secrets-*.sh нужно из того репо.
        Переключись: cd <path> или открой репо в терминале.

3. Никогда не запускать secrets-*.sh из репо без manifest
   и не делать вывод "секреты отсутствуют" только потому что
   manifest не найден в текущем cwd.
```

**Почему это важно (G-065):** каждый репо имеет свой `.env` и manifest. `secrets-show.sh` ищет `.env` относительно `cwd` — если запустить из неправильного репо, покажет MISSING даже когда секреты реально установлены в другом репо.

---

## `/secrets` (без аргументов) — help screen

Меню с visual hierarchy для top use cases:

```
🔐 /secrets — Управление секретами проекта

Что нужно сделать?

  📝 Добавить новый секрет
     bash scripts/set-secret.sh KEY                  (interactive: service, URL, login, value)
     ▸ Запускай в ЛЮБОМ терминале — встроенный VSCode-терминал (Ctrl+`), Windows Terminal,
       git bash. Отдельный git bash открывать НЕ нужно. Через /secrets --add агент сам
       пишет manifest и даёт готовую строку — тебе остаётся только ввести значение.

     ⚠️  KEY — это имя которое ТЫ придумываешь для каждого сервиса (UPPER_SNAKE_CASE).
         Каждый сервис = отдельный вызов с уникальным именем:
           bash scripts/set-secret.sh GITHUB_PAT               # для GitHub
           bash scripts/set-secret.sh GITLAB_ERP_DOCS_PAT      # для GitLab ERP (read-only)
           bash scripts/set-secret.sh ANTHROPIC_API_KEY        # для Anthropic
         Один и тот же KEY дважды = перезапись предыдущего значения!

     📐 Рекомендуемый формат: ПРОВАЙДЕР_[ПРОЕКТ]_[ТИП]
           GITHUB_PAT                  # один GitHub аккаунт
           GITHUB_CAIT_PAT             # GitHub если несколько аккаунтов
           GITLAB_ERP_DOCS_PAT         # GitLab self-hosted, ERP docs, read-only
           GITLAB_ERP_PAT              # GitLab self-hosted, read-write
           ANTHROPIC_API_KEY           # Anthropic (стандартное имя)
           OPENAI_API_KEY              # OpenAI (стандартное имя)
         [ПРОЕКТ] добавляй только если один провайдер = несколько аккаунтов/проектов.

  👁  Посмотреть какие секреты есть/нужны
     bash scripts/secrets-show.sh                    (table, без значений)
     bash scripts/secrets-show.sh KEY                (детальный view, без значения)
     bash scripts/validate-secrets.sh                (audit + warnings)

  ✏️  Изменить metadata существующего секрета
     bash scripts/secrets-edit.sh KEY                (service_name/url/login/expires_at)

  🔄 Обновить значение (rotation)
     bash scripts/secrets-update.sh KEY              (interactive, with re-paste confirm)

  🗑️  Удалить секрет (сервис выведен из эксплуатации или ошибочно добавлен)
     bash scripts/secrets-delete.sh KEY                (удаляет из .env И manifest)
     bash scripts/secrets-delete.sh KEY --yes          (без подтверждения, CI/CD)
     bash scripts/secrets-delete.sh KEY --keep-manifest  (только из .env, запись в manifest сохранить)

     ⚠️  Если KEY = required: true в manifest — будет warning. Backup создаётся автоматически.

  ↩️  Восстановить из backup (если ошибся)
     bash scripts/secrets-rollback.sh                (latest backup)
     bash scripts/secrets-rollback.sh --list         (показать все backups)

  📥 Git over HTTPS без токена в URL (credential helper)
     git config credential.helper "$(pwd)/scripts/git-credential-from-env.sh"
     git clone / pull / push                          (токен берётся из .env, агент его не видит)

     ⚠️  НЕ делать: git clone https://token@github.com/...  (токен в URL → shell history leak!)
     ✅  Правильно: настроить git-credential-from-env.sh как helper — git сам читает токен.

  🧹 Поиск утечек в transcripts
     bash scripts/secrets-scrub.sh                   (read-only)
     bash scripts/secrets-scrub.sh --clean           (destructive, asks confirm)

  ✅ Verify how_to_obtain still valid (set last_verified_at)
     bash scripts/secrets-edit.sh KEY                (manual update field)

Files:
  .env                                  per-project values (gitignored)
  ~/.config/it-dev/secrets.env          shared values (optional)
  .claude/secrets-manifest.yaml         declarations + metadata (committed)

See also: secrets-management — knowledge-skill (full runbook: threat-model, rotation,
         compromise-response, Vault/AWS, type:file). Активируется АВТОМАТИЧЕСКИ когда ты
         говоришь о секретах/утечке/ротации — вызывать её отдельно НЕ нужно. Для действий
         (add/list/rotate/scrub) — только эта команда /secrets.
```

---

## Подкоманды (slash interface)

### `/secrets` или `/secrets --help`
Показать help screen (выше).

### `/secrets --audit`
Запустить `bash scripts/validate-secrets.sh`. Audit table + warnings (expiry, rotation, how_to_obtain freshness, missing v2 fields). Для записей `type: file` (GCP/Vertex JSON, сертификаты) дополнительно проверяет что файл существует по пути из `.env` (`📄 ... ✓` / `❌ FILE NOT FOUND`). **Не показывает значения.**

### `/secrets --list`
Запустить `bash scripts/secrets-show.sh`. Tabular: KEY / SERVICE / URL / LOGIN / STATUS. **Не показывает значения.**

### `/secrets --show KEY`
Запустить `bash scripts/secrets-show.sh KEY`. Detailed view одного entry. **Не показывает значение.**

### `/secrets --add KEY` (или `/secrets --setup KEY`)

**Шаг 1 — агент делает САМ** (метаданные не секрет, Edit разрешён): записать/обновить декларацию KEY в `.claude/secrets-manifest.yaml` — `service_name`, `service_url`, `login`, `how_to_obtain`. Имя KEY агент **предлагает сам** по конвенции `PROVIDER_[PROJECT]_[TYPE]` (пользователю не держать в голове именование). Это снимает actor-burden: всё кроме значения готовит агент.

**Шаг 2 — показать пользователю готовую строку для ввода ТОЛЬКО значения:**
```
✅ Декларация KEY записана в manifest (service/url/login). Осталось ввести значение.

Запусти в ЛЮБОМ интерактивном терминале — отдельный git bash НЕ нужен:
встроенный терминал VSCode (Ctrl+`), Windows Terminal, или git bash:

    bash scripts/set-secret.sh KEY

Скрипт скрыто (read -s) спросит значение + re-paste confirm → атомарно запишет в .env
(метаданные уже в manifest — нажимай Enter чтобы оставить их как есть).

⛔ Значение НЕ вставляй в чат — только в скрытый prompt скрипта.

How to obtain value (from manifest):
<how_to_obtain content if KEY declared>
```
**Агент НЕ вводит значение** (для value-секретов) — оно не должно попасть в transcript. Но manifest + именование агент делает сам (Шаг 1).

⛔ **НЕ говорить «открой git bash»** — `set-secret.sh` это bash 3.2, работает в **любом TTY** включая встроенный терминал VSCode (Ctrl+\`). Боль «нужен именно git bash» — миф; реальное трение = переключение в отдельное окно, которого встроенный терминал не требует (closes G-122).

**Исключение — `type: file` секреты** (GCP/Vertex JSON, сертификаты): значение в `.env` = **путь** (не секрет) → **агент выполняет добавление САМ** (Edit manifest `type:file` → `set-secret.sh KEY .gcp/x.json` → check-ignore → validate), юзер только кладёт файл в `.gcp/`. Полная процедура — skill `secrets-management` § Agent procedure. Не печатать юзеру «запусти set-secret.sh» для file-кейса.

### `/secrets --edit KEY`
Показать пользователю:
```
To edit METADATA (not value) for KEY:
    bash scripts/secrets-edit.sh KEY

Скрипт interactively обновит service_name / service_url / login / expires_at.
Value в .env НЕ изменится — для value используй --update.
```

### `/secrets --update KEY`
Показать пользователю:
```
To update VALUE (rotation) for KEY:
    bash scripts/secrets-update.sh KEY

Скрипт покажет masked текущее value, запросит новое через read -s + re-paste confirm.
Атомарный backup создан в .env.backup-{timestamp} (24h retention).
Метаданные не изменятся.
```

### `/secrets --rollback`
Показать пользователю:
```
To restore .env from latest backup:
    bash scripts/secrets-rollback.sh                # latest
    bash scripts/secrets-rollback.sh --list         # list available
    bash scripts/secrets-rollback.sh FILE           # specific backup
```

### `/secrets --scrub`
Запустить `bash scripts/secrets-scrub.sh` (read-only). Показать findings. **`--clean` mode (destructive) — пользователь сам выполняет с confirmation.**

### `/secrets --rotate KEY`
Показать rotation workflow для конкретного ключа:
1. Прочитать manifest → `how_to_obtain` + `service_url` для KEY.
2. Вывести checklist:
   ```
   Rotation workflow for KEY:
   1. Open service URL: <service_url>
   2. Revoke old token (note last 4 chars: bash scripts/secrets-show.sh KEY)
   3. Generate new token (same scopes — see scope_note in manifest)
   4. Update locally: bash scripts/secrets-update.sh KEY
   5. Scrub transcripts: bash scripts/secrets-scrub.sh
   6. Check git history: git log -p --all -S "<old-prefix>"
      If found → git filter-repo + force-push + notify contributors
   ```
3. **Агент НЕ выполняет** — manual process.

### `/secrets --verify-link KEY`
Показать пользователю инструкцию verify что `how_to_obtain` URL still valid + обновить `how_to_obtain_verified_at`:
```
To verify how_to_obtain for KEY:
    1. Open URL from manifest: <extracted URL>
    2. Check that scopes / instructions still apply
    3. Run: bash scripts/secrets-edit.sh KEY
       → set "Expires at" (Enter to keep) → set "how_to_obtain_verified_at" via direct manifest edit
       OR: manually edit .claude/secrets-manifest.yaml → set how_to_obtain_verified_at to today's date
```

---

## Output rules (always)

- ✅ Имена ключей выводить можно
- ✅ Метаданные (service_name, URL, login) выводить можно — они **не секреты**
- ✅ Masked previews (first 4 + last 4 chars) при confirmation step
- ❌ **НИКОГДА** не выводить полные значения
- ✅ Exit codes: 0 = OK, 1 = required missing, 2 = manifest error, 3 = script error, 5 = user aborted

---

## Examples

### Multi-host setup (real use case v4.41.0+)
```
$ /secrets --add GITHUB_PAT
(пользователь запускает bash scripts/set-secret.sh GITHUB_PAT в терминале)
Service name: GitHub (cait-solutions)
Service URL: https://github.com
Login: oauth2
Expires at: 2026-12-01
Value: (hidden)
Re-paste: (hidden)
✅ Set GITHUB_PAT

$ /secrets --add GITLAB_NEXCHANCE
Service name: GitLab Nexchance
Service URL: https://code.nexchance.de
Login: vb@nexchance.de
Value: (hidden)
✅ Set GITLAB_NEXCHANCE

$ /secrets --list
KEY                  SERVICE                    URL                        LOGIN              STATUS
GITHUB_PAT           GitHub (cait-solutions)    https://github.com         oauth2             set (.env)
GITLAB_NEXCHANCE     GitLab Nexchance           https://code.nexchance.de  vb@nexchance.de    set (.env)

# git push to github.com → uses GITHUB_PAT
# git push to code.nexchance.de → uses GITLAB_NEXCHANCE
# multi-host routing работает через git-credential-from-env.sh
```

---

⛔ Не запрашивай значения через chat. Не выводи значения. Используй `with-secret.sh` для всех операций требующих секрет.
