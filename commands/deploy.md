# /deploy — Деплой с safety checks

> **Цель:** безопасно опубликовать изменения (push в production_branch или PR в integration_branch per branching mode) + обязательная DEVLOG запись + smoke test + after-effects check. НЕ для разработки или диагностики — только release step.

**ОБЯЗАТЕЛЬНО:** код в правильной ветке, PR создан/одобрен.

---

## Рекомендуемая модель

**Default tier:** **Fast tier** (см. `.claude/model-tiers.md`) — деплой это чек-листы, structured smoke test, обновление DEVLOG
**Upgrade to Default tier if:** smoke test failed → нужен диагностический анализ; regression detected at after-effects check
**Downgrade:** (всегда Fast — это минимально допустимый)
**Mid-task escalation:** нет (если failed → обычно прерывается и идёт в `/diagnose`)
**Pre-flight model check:** **да — при старте команды** спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии). Если используется Capable (Opus) tier — это over-powered для deploy → пауза + рекомендация Fast/Default для cost-savings.

---

## Навигационная карта шагов

Оси: **project_type** (ai-agent / web-app / api-service / cli-tool / library / methodology-platform) × **наличие миграций** × **наличие selftest** × **затрагиваются ли хранилища**.

| Шаг | ai-agent | web-app | api-service | cli-tool | library | methodology |
|-----|----------|---------|-------------|----------|---------|-------------|
| 0 Review обязателен | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 0.5 Hard blocker на повторный деплой | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 0.7 Pre-flight warnings (triggers.json) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1 Pre-flight check (ветка, коммиты, tests) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 1.5 Branch tracing (F5: agent vs human) | ✓ | ✓ | ✓ | ✓ | — | — |
| 2 DEVLOG.md запись | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 Деплой (procedure-specific) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (git push) |
| 3.1 Selftest (если есть в проекте) | ✓ | ✓ | ✓ | ✓ | — | — |
| 3.5 Инвалидация после деплоя (если меняются данные) | ✓ | ✓ | ✓ | — | — | — |
| 4 Smoke test — happy path | ✓ | ✓ | ✓ | ✓ | — | — |
| 4 Smoke test — data smoke (если данные) | ✓ | ✓ | ✓ | — | — | — |
| 4 Smoke test — after-effects check (только ai-agent) | ✓ | — | — | — | — | — |
| 5 Обновить triggers.json (last_deploy) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Прочитай таблицу ПЕРВЫМ. Пропускай шаги не отмеченные для project_type. Для methodology-platform "деплой" = `git push origin main`; smoke test = ручной запуск `new-project-init.sh` + `sync-methodology.sh` на тестовом target.

---

## Шаг 0 — Review обязателен

Запусти `/review` если не запускался в этой сессии. Деплой без review запрещён.

---

## Шаг 0.5 — Hard blocker на повторный деплой

`git log --oneline -5` — сколько деплоев одного компонента за 24 часа?

Если N ≥ 2 → ⛔ ПОЛНЫЙ СТОП.

Чтобы разблокировать — напиши следующее своими словами (шаблон):
> "Деплой №N для [компонент]. Новые данные: [что именно узнали — конкретно, не "посмотрел ещё раз"]."

Пример: "Деплой №2 для sync-methodology.sh. Новые данные: воспроизвёл на реальном clone, обнаружил что проблема в порядке шагов, а не в условии if."

Без этого признания деплой не выполняется.

---

## Шаг 0.7 — Pre-flight warnings

Прочитать `.claude/state/triggers.json`:

1. `last_product_check.plans_since` ≥ 5 → 🟡 "PRODUCT.md мог разойтись"
2. Дней с `last_deploy.date` ≥ 7 → 🟡 "Накопились изменения с прошлого деплоя"

После успешного деплоя обновить `last_deploy.date`.

---

## Шаг 1 — Pre-flight check

- [ ] Текущая ветка = `agent_branch` ИЛИ `{agent_branch}/<task>` (namespaced при `worktree_isolation: auto`) из `CLAUDE.local.md ## Branching` (default: `ai-dev`) — см. Шаг 1.5 для деталей и исключений
- [ ] Все изменения закоммичены
- [ ] Self-review пройден
- [ ] Tests зелёные
- [ ] SYSTEM-MAP / data-map / ADR обновлены если применимо
- [ ] Если коммит затрагивает ARTIFACT-MAP → `bash scripts/validate-artifact-map.sh` прошёл (или кандидаты рассмотрены вручную)
- [ ] **Shared-state race guard** (closes G-052) — если деплой меняет файлы которые другие сессии тоже могут менять одновременно (`VERSION`, lockfiles, `triggers.json`, migration sequence): прежде чем финализировать bump/коммит —
  ```bash
  git fetch origin {current_branch}
  git diff origin/{current_branch} -- VERSION   # и другие shared-state файлы
  ```
  Если diff ≠ 0 (remote опередил локальный) → ⛔ СТОП: другая сессия/разработчик изменил shared-state. `git rebase origin/{current_branch}`, перечитать значение (напр. VERSION), пересчитать bump, затем продолжить. Не перезаписывать чужой bump.
- [ ] **Concurrent-session claim cleanup** (если `worktree_isolation: auto` И `AGENTS.md` существует): после merge этой задачи — убрать свою строку из `AGENTS.md ## Active claims` (claim жил от Шага 0 /code до merge; теперь scope свободен).
- [ ] Remote URL: прочитать `origin_url` из `CLAUDE.local.md ## Remotes` (если секция есть) → сравнить с `git remote get-url origin` → если расходятся: `git remote set-url origin <origin_url>` до push

---

## Шаг 1.5 — Branch tracing (F5: AI-automated deploy clarity)

**Принцип:** Deploy через команду `/deploy` выполняется на ветке `agent_branch` (default `ai-dev`) или namespaced `{agent_branch}/<task>` (при `worktree_isolation: auto`) чтобы было явно видно что это agent-automated, не manual human work.

- [ ] Прочитать `branching.mode` (default: `solo`) и `worktree_isolation` (default: `off`) из `CLAUDE.local.md`
- [ ] Определить текущую ветку: `BR=$(git branch --show-current)`. Деплоим **текущую** ветку, не хардкод `agent_branch`.
  - `worktree_isolation: off` → ожидается `BR == agent_branch`. Если нет → checkout: `git checkout {agent_branch}` или `git checkout -b {agent_branch} origin/{production_branch}`
  - `worktree_isolation: auto` → допустимо `BR == agent_branch` ИЛИ `BR == {agent_branch}/<task>`. Деплоить `BR` как есть (мы в изолированном worktree этой задачи). НЕ делать checkout на общий `agent_branch` — это другой worktree.
- [ ] Если ветка diverged → rebase:
  - **solo:** `git rebase origin/{production_branch}`
  - **team:** `git rebase origin/{integration_branch}`

**Почему:** Team collaboration — люди видят разницу между agent-automated (`ai-dev` ветка) и manual human work (`feature/*`, `main`). Audit trail в git: "commit by Claude on ai-dev" vs "commit by John on feature/auth".

---

## Шаг 2 — DEVLOG.md

Формат записи:

```
YYYY-MM-DD — [тип: deploy|milestone|risk-change] — [компонент]
Что: одна строка
Зачем: одна строка
Решение: одна строка (если архитектурное)
Deferred: <пункт 1 ≤80 симв> · <пункт 2> · ...  (только если last_plan_session.deferred[] непустой)
```

- Строка `Deferred:` — прочитать `triggers.json → last_plan_session.deferred[]`; если непустой → одна строка через `·`; если пустой → строку не писать.
- Defensive: `.get('deferred') or []`; поле отсутствует у old consumer → строку пропустить.
- Затрагивает карту данных → обновить в этом же коммите
- Не затрагивает → явно "карта данных не изменилась"

---

## Шаг 3 — Деплой

Покажи что улетит: `git diff HEAD --stat`

### Шаг 3.0 — Прочитай mode (обязательно перед push)

```bash
grep -A10 '## Branching' CLAUDE.local.md | grep 'mode:'
```

Выведи значение явно — `solo` или `team` — прежде чем продолжить. Это обязательный шаг, не опциональный.

### Шаг 3.1 — Push

**Рекомендуется (если есть `scripts/deploy-push.sh`):**
```bash
bash scripts/deploy-push.sh
```
Скрипт читает mode из CLAUDE.local.md и запускает правильную команду. Вывод покажет mode, ветку и target.

**Вручную (если скрипта нет) — используй значение mode из Шага 3.0. `{branch}` = текущая ветка (`git branch --show-current`); при `worktree_isolation: auto` это namespaced `{agent_branch}/<task>`, иначе `{agent_branch}`:**

`solo` → push напрямую в production:
```bash
git push origin {branch}:{production_branch}
```

`team` → опубликовать ветку и создать PR (PR из текущей ветки в integration):
```bash
git push origin {branch}:{branch}
```
Затем создай PR (подставь значения из `git remote get-url origin`; `{branch}` = текущая ветка, при auto = `{agent_branch}/<task>`):
- **GitHub:** `https://github.com/<owner>/<repo>/compare/{integration_branch}...{branch}?expand=1`
- **GitLab:** `https://<host>/<namespace>/<repo>/-/merge_requests/new?merge_request[source_branch]={branch}&merge_request[target_branch]={integration_branch}`
- Или через CLI: `gh pr create --base {integration_branch} --head {branch} --title "[ai-dev] <DEVLOG summary>"`

PR title: взять последнюю строку DEVLOG (что: ...). Human reviews → merge в `integration_branch`.

**Credential failure protocol (при 403 / "Write access denied" / TTY error / "No such device"):**

⛔ **СТОП немедленно. НЕ пробовать другие токены из `.git-credentials` или других источников.**

Вывести пользователю:
```
git push failed: нет write-access для {origin_url}
Нужен токен с правами repo:write для {owner}/{repo}

Варианты (выберите согласно вашей настройке):
  a) gh auth login → повторить /deploy
  b) добавить токен вручную:
     git remote set-url origin https://<user>:<pat>@github.com/<owner>/<repo>.git
     затем повторить /deploy
  c) добавить агента как collaborator в GitHub Settings → Collaborators

push_token_owner (из CLAUDE.local.md): {push_token_owner или "не указан"}
```

Записать в DEVLOG: `[deploy-blocked:credentials] — push к {origin_url} заблокирован, нет write-access`

Ждать решения пользователя. Не переходить к smoke test. Не продолжать деплой.

---

## Шаг 3.1 — Selftest (если есть)

Если в проекте есть selftest — обязательно после перезапуска.
- Все [critical] должны быть ✅
- Если 🔴 — деплой failed, не продолжать

---

## Шаг 3.5 — Инвалидация после деплоя

- Изменился формат данных в хранилище? → миграция / реиндексация
- Изменилась структура состояния? → reset / cleanup
- Если ничего — явно "инвалидация не требуется"

---

## Шаг 4 — Smoke test (обязательно)

**Основной happy path:**
- [ ] Health check отвечает
- [ ] Основная функция работает согласно acceptance criteria
- [ ] Нет новых ошибок в логах (первые 5 минут)

**Data smoke test** (если менялась работа с хранилищами):
- [ ] Чтение данных работает корректно
- [ ] Запись работает корректно

**After-effects check** (только если `project_type: ai-agent` в CLAUDE.md):
После основного теста — запустить 3 несвязанных запроса:
1. Стандартный запрос
2. Простой вопрос
3. Любая команда не из теста

Что искать:
- Молчание / пустой ответ → ⚠️ возможна state pollution
- Ссылки на данные теста как актуальные → ⚠️ pollution подтверждена
- Странное поведение "из ниоткуда" → инвалидировать состояние

При обнаружении:
- Запись в DEVLOG `[regression:state-pollution]`
- Откатить если критично для UX
- Сценарий воспроизведения в HYPOTHESES.md

---

## Шаг 5 — Async operations healthcheck (D3: fire-and-forget visibility)

**Принцип:** Любая async операция (git push, CI/CD trigger, webhook) должна иметь observable outcome или retry сигнал.

### Подшаг 1 — Git push verification

- **solo:** `git log -1 --oneline origin/{production_branch}` — последний коммит совпадает с вашим?
- **team:** `git log -1 --oneline origin/{branch}` — опубликована текущая ветка (`{agent_branch}` или namespaced `{agent_branch}/<task>` при auto)?

Если ДА → ✅ push succeeded
Если НЕТ → ⚠️ push не прошёл:
  - Если причина **403 / TTY error** → это credential failure; протокол уже отработал в Шаг 3.1 (СТОП + сообщение пользователю). Здесь только подтвердить что коммит не ушёл.
  - Иные причины (network timeout, remote unavailable) → сохранить error в DEVLOG `[async-failure:git-push]`
  - ⛔ НЕ продолжать если git push failed

### Подшаг 2 — CI/CD trigger (если применимо)

Если проект имеет CI/CD:
- GitHub Actions / GitLab CI trigger начался? (проверить статус в UI)
- Если нет → trigger явно (webhook, API call)
- Записать status в DEVLOG: `[deploy:ci-triggered]` или `[async-failure:ci-trigger]`

---

## После деплоя

Обновить triggers.json:
- `last_deploy.date = <today>`
- Если были async failures → `last_deploy.status = "partial"` (git push OK но CI не started)

**Только для `methodology-platform`:**

Self-apply (`sync-methodology.sh .`) встроен в `deploy-push.sh` с guard'ом — выполняется автоматически в конце деплоя и для solo и для team режима. Guard: `[ -d commands ] && [ -f scripts/sync-methodology.sh ]` — срабатывает только в methodology-platform, consumers пропускают.

Ручной запуск нужен только если `deploy-push.sh` не использовался:
```
bash scripts/sync-methodology.sh .
```

Это обновляет `.claude/commands/`, `.claude/hooks/`, `.claude/skills/` до только что задеплоенной версии.

---

⛔ Если в review были 🔴 CRITICAL — не деплоить.

$ARGUMENTS
