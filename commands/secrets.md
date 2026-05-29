# /secrets — Управление секретами проекта

> **Цель:** unified UX для добавления / просмотра / редактирования / ротации / scrub секретов. Все секреты живут в `.env` (per-project) + опционально `~/.config/it-dev/secrets.env` (shared). Метаданные в `.claude/secrets-manifest.yaml` (schema v2 v4.41.0+).

> ⛔ **Агент НЕ вводит значения сам.** `--add` / `--update` / `--edit` показывают команду пользователю — пользователь сам запускает в терминале (значение через `read -s` не попадает в transcript).

---

## Рекомендуемая модель

**Default tier:** **Fast tier** — простой CLI wrapper. **Upgrade:** нет. **Pre-flight check:** Capable (Opus) → 🟡 over-powered → рекомендация Fast.

---

## `/secrets` (без аргументов) — help screen

Меню с visual hierarchy для top use cases:

```
🔐 /secrets — Управление секретами проекта

Что нужно сделать?

  📝 Добавить новый секрет
     bash scripts/set-secret.sh KEY                  (interactive: service, URL, login, value)

  👁  Посмотреть какие секреты есть/нужны
     bash scripts/secrets-show.sh                    (table, без значений)
     bash scripts/secrets-show.sh KEY                (детальный view, без значения)
     bash scripts/validate-secrets.sh                (audit + warnings)

  ✏️  Изменить metadata существующего секрета
     bash scripts/secrets-edit.sh KEY                (service_name/url/login/expires_at)

  🔄 Обновить значение (rotation)
     bash scripts/secrets-update.sh KEY              (interactive, with re-paste confirm)

  ↩️  Восстановить из backup (если ошибся)
     bash scripts/secrets-rollback.sh                (latest backup)
     bash scripts/secrets-rollback.sh --list         (показать все backups)

  🧹 Поиск утечек в transcripts
     bash scripts/secrets-scrub.sh                   (read-only)
     bash scripts/secrets-scrub.sh --clean           (destructive, asks confirm)

  ✅ Verify how_to_obtain still valid (set last_verified_at)
     bash scripts/secrets-edit.sh KEY                (manual update field)

Files:
  .env                                  per-project values (gitignored)
  ~/.config/it-dev/secrets.env          shared values (optional)
  .claude/secrets-manifest.yaml         declarations + metadata (committed)

See also: skills/secrets-management/SKILL.md (full runbook)
```

---

## Подкоманды (slash interface)

### `/secrets` или `/secrets --help`
Показать help screen (выше).

### `/secrets --audit`
Запустить `bash scripts/validate-secrets.sh`. Audit table + warnings (expiry, rotation, how_to_obtain freshness, missing v2 fields). **Не показывает значения.**

### `/secrets --list`
Запустить `bash scripts/secrets-show.sh`. Tabular: KEY / SERVICE / URL / LOGIN / STATUS. **Не показывает значения.**

### `/secrets --show KEY`
Запустить `bash scripts/secrets-show.sh KEY`. Detailed view одного entry. **Не показывает значение.**

### `/secrets --add KEY` (или `/secrets --setup KEY`)
Показать пользователю команду для interactive add:
```
To add KEY, run yourself (do not paste value into chat):
    bash scripts/set-secret.sh KEY

Скрипт спросит:
  - Service name (e.g. "GitHub", "GitLab Nexchance")
  - Service URL (e.g. https://github.com)
  - Login (optional username/email)
  - Expires at (optional ISO date)
  - Value (hidden via read -s, re-paste confirm)

How to obtain value (from manifest):
<how_to_obtain content if KEY declared>
```
**Агент НЕ выполняет** — only prints instruction.

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
