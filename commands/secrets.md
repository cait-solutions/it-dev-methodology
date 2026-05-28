# /secrets — Управление секретами проекта

> **Цель:** unified UX для setup / audit / list / scrub секретов. Все секреты живут в `.env` (per-project) + опционально `~/.config/it-dev/secrets.env` (shared). Декларация — `.claude/secrets-manifest.yaml`.

> ⛔ **Агент НЕ вызывает `/secrets setup` сам.** Пользователь запускает one-time для каждого нового ключа. Агент только запускает `--audit` / `--list` / `--scrub` диагностические подкоманды.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — простой CLI wrapper над скриптами, deterministic
**Upgrade:** нет
**Downgrade:** нет
**Mid-task escalation:** нет
**Pre-flight model check:** **да** — если используется Capable (Opus) tier — это 🟡 over-powered → пауза + рекомендация Fast.

---

## Подкоманды

### `/secrets` (без флага) или `/secrets --audit`

Полный аудит состояния:
1. Запустить `bash scripts/validate-secrets.sh` — сравнение manifest vs `.env`
2. Показать вывод пользователю:
   - ✅ required keys present
   - ❌ required keys missing (с `how_to_obtain`)
   - ⚠️ placeholder values
   - ⚠️ orphan keys в `.env` без декларации в manifest
   - ⚠️ permission warnings
3. **Не показывать значения** — только имена + статус.

### `/secrets --setup KEY`

Показать пользователю инструкцию для one-time добавления:
1. Прочитать manifest → найти `key: KEY`
2. Вывести:
   ```
   To add KEY, run this command yourself (do not paste value into chat):
       bash scripts/set-secret.sh KEY <value>

   How to obtain:
   <how_to_obtain block from manifest>
   ```
3. **СТОП.** Не запрашивать значение через chat — пользователь сам выполнит команду.

### `/secrets --list`

Список **имён** секретов в `.env` (без значений) + scope (per-project / shared):
1. `awk -F= '/^[A-Z_][A-Z0-9_]*=/{print $1}' .env`
2. Также показать `~/.config/it-dev/secrets.env` если существует.
3. Для каждого — match с manifest (required / optional / orphan).

### `/secrets --scrub`

Поиск исторических утечек в transcripts/logs:
1. Запустить `bash scripts/secrets-scrub.sh`
2. Скрипт grep'ает `~/.claude/projects/` на token patterns (ghp_, sk-ant-, AKIA, etc.) + custom patterns из manifest.
3. Если match найдены — показать список файлов + предупреждение:
   ```
   ⚠️ Found N potential token exposures in ~/.claude/projects/
   Files: <list>
   
   Action required:
   1. ROTATE these tokens at provider IMMEDIATELY
   2. Re-run /secrets --scrub --clean to overwrite matches (destructive, asks confirm)
   ```
4. **Default — read-only.** `--clean` flag deletes/overwrites only after explicit user confirm.

### `/secrets --rotate KEY`

Показать rotation workflow для конкретного ключа:
1. Прочитать manifest → найти `rotation_url` (если задан в config) или общую инструкцию из `how_to_obtain`.
2. Вывести checklist:
   ```
   Rotation workflow for KEY:
   1. Open <rotation_url> in browser
   2. Revoke old token (NOTE the old token in 1Password/notes for forensics)
   3. Generate new token
   4. Run: bash scripts/set-secret.sh KEY <new-value>
   5. Run: bash scripts/secrets-scrub.sh  (cleanup transcripts)
   6. If KEY was ever committed to git → check `git log -p --all -S "<old-prefix>"` + filter-repo
   ```
3. **СТОП.** Не выполнять — это manual process.

---

## Output rules (always)

- ✅ Имена ключей выводить можно
- ❌ **НИКОГДА** не выводить значения секретов в stdout (это команда чтения для агента → попадает в transcript → leak)
- ✅ `how_to_obtain` блоки выводить можно (там нет значений, только инструкции)
- ✅ Exit codes: 0 = OK, 1 = required missing, 2 = manifest error, 3 = script unavailable

---

## Examples

```
$ /secrets
Secrets manifest validation:
  Manifest: .claude/secrets-manifest.yaml
  Per-project .env: present
  Shared ~/.config/it-dev/secrets.env: absent

  ✅ GITHUB_PAT                    (.env)
  ◯  ANTHROPIC_API_KEY             (optional, not set)

✅ All required secrets present.
```

```
$ /secrets --setup ANTHROPIC_API_KEY
To add ANTHROPIC_API_KEY, run this command yourself (do not paste value into chat):
    bash scripts/set-secret.sh ANTHROPIC_API_KEY <value>

How to obtain:
  1. Open https://console.anthropic.com/settings/keys
  2. Create Key → copy sk-ant-... value
  3. Run the command above
```

```
$ /secrets --scrub
Scanning ~/.claude/projects/ for token-shaped strings...
No exposures found. ✅
```

---

⛔ Не запрашивай значения через chat. Не выводи значения. Используй `with-secret.sh` для всех операций требующих секрет.
