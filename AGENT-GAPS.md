# AGENT-GAPS — methodology-platform

Лог случаев когда Claude Code признал ошибку, пропуск или неточность в ходе диалога.
Используется в `/retro` для выявления паттернов → конкретных улучшений методологии.

**Отличие от DEVLOG:** DEVLOG фиксирует события проекта. AGENT-GAPS фиксирует сбои качества AI → сигнал для методологии.
**Отличие от HYPOTHESES:** HYPOTHESES — гипотезы с экспериментом. AGENT-GAPS — задокументированный факт признания.

> **Правило захвата:** когда Claude Code явно признаёт ("ты прав", "я пропустил", "я не предусмотрел") — он ОБЯЗАН предложить запись сюда. Разработчик подтверждает (y/n).

---

## Категории корневых причин

| Код | Когда применять |
|---|---|
| `prompt-gap` | Шаг команды не содержал нужного checklist-пункта |
| `context-gap` | AI не прочитал нужные файлы / не спросил нужную информацию |
| `logic-gap` | Сделал неверный вывод из правильных данных |
| `assumption-gap` | Принял предположение за факт без верификации |
| `completeness-gap` | Решение покрыло happy path, пропустило edge case |
| `scope-gap` | Починил локально то что надо было системно |

## Agent failure mode — механизм сбоя

Уточняет гипотезу: не "почему пропустил" (Гипотеза), а "как именно сломался агент".

| Код | Когда применять |
|---|---|
| `model-error` | Логическая ошибка или галлюцинация в рассуждении |
| `context-missed` | Нужный файл/данные не были прочитаны (не в контексте) |
| `prompt-ambiguous` | Инструкция в команде допускала неверную интерпретацию |
| `state-stale` | Использовал устаревшее предположение из более раннего витка сессии |
| `scope-exceeded` | Задача вышла за рамки того, что модель может решить за один шаг |
| `other` | Не подходит ни одна из категорий — описать в Гипотезе |

---

## Формат записи

```
---
Gap-ID: G-NNN
Дата: YYYY-MM-DD
Контекст: /plan | /code | /review | /retro | free-chat
Что пропустил: [одна строка — конкретно что AI упустил]
Как обнаружено: разработчик указал | тест упал | другое
Категория: [код из таблицы выше]
Гипотеза: [одна строка — почему AI это пропустил]
Agent failure mode: model-error | context-missed | prompt-ambiguous | state-stale | scope-exceeded | other
Potential fix: [конкретный checklist item или изменение шаблона которое предотвратит повтор]
Статус: open | addressed | wont-fix
---
```

---

## Записи

---
Gap-ID: G-074
Дата: 2026-06-01
Контекст: free-chat — пользователь указал на слабый thinking-ahead
Что пропустил: при предложении решений агент не думает на шаг вперёд с точки зрения пользователя — предлагал «запускать скрипт отдельной командой» когда удобнее встроить в общую команду; предлагал «валидацию наличия артефакта» не подумав что содержимое артефакта может устареть (валидация даст OK, изменения внутри не учтены). Класс: forward-thinking gap — решение технически корректно, но не дальновидно с UX/integration перспективы.
Как обнаружено: пользователь явно — «даже на шаг вперёд не было продумано с точки зрения пользователя»
Категория: prompt-gap
Гипотеза: /plan Шаг 1.5 «Горизонт 3 шага» проверял технические горизонты (ROADMAP, нагрузка, N>1) но не содержал discipline-creating вопросов про UX friction (JTBD struggling moment) и integration (не дублируем ли соседний механизм). Aspirational «подумай об UX» заполнялся формально.
Agent failure mode: prompt-ambiguous — шаг допускал формальное заполнение без конкретного UX-анализа
Potential fix: добавить в /plan Шаг 1.5 Forward-Failure Analysis (industry best practice: FMEA RPN-таблица + JTBD struggling moment + integration/non-duplication check) — discipline-creating, требуют конкретного ответа который нельзя написать формально
Статус: addressed (v4.51.0 — /plan Шаг 1.5 Forward-Failure Analysis: FMEA + JTBD + integration check)
---
Gap-ID: G-073
Дата: 2026-06-01
Контекст: free-chat — пользователь указал на слабый post-code аудит
Что пропустил: /review аудит после кодинга пропускает незакрытые вещи — Completeness check был aspirational («решение указывает что НЕ закрывается?» — заполняется формально). Нет structured списка типичных классов пропусков (CRUD-симметрия, downstream consumers, content-vs-existence, template-sync, trigger-chain, error-path). Тестирование не покрыто явно. Канонический случай: «валидация наличия файла без проверки содержимого» — валидатор OK, артефакт stale, никто не замечает (FMEA Detection=9).
Как обнаружено: пользователь явно — «недостаточный аудит после кодинга который пропускает незакрытые вещи; уменьшить пропускание аудитом багов»
Категория: prompt-gap
Гипотеза: Completeness check в /review был abstract intuition-prompt, не discipline-creating checklist по конкретным классам. Gawande: aspirational checklist заполняется формально, discipline-creating требует evidence.
Agent failure mode: prompt-ambiguous
Potential fix: заменить /review Completeness check на 7 структурных классов с evidence requirement (industry: FMEA Detection layer + Gawande discipline) + усилить секцию Тесты (назвать конкретный способ верификации, не «протестировано»)
Статус: addressed (v4.51.0 — /review Completeness 7 классов + Тесты discipline-creating)
---
Gap-ID: G-072
Дата: 2026-06-01
Контекст: /diagnose — mermaid ссылки у консьюмера erp-documentantion после всех фиксов
Что пропустил: update-mermaid-links.sh и validate-mermaid-links.sh скипают mermaid-блоки содержащие TODO: — но не очищают старый markdown-link placeholder (> 🔗 [Открыть в Mermaid Live](url)) над этими блоками. Консьюмер получает шаблонный файл с > 🔗 [...] из старого init, запускает sync-audit → Gap 7 видит OK (validate скипает TODO) → проблема не обнаруживается и не исправляется.
Как обнаружено: разработчик указал — ссылки в USER-MAP.md консьюмера всё ещё в markdown-link формате после sync-audit + update-mermaid-links.sh
Категория: completeness-gap
Гипотеза: скрипты реализованы с логикой "нет реального кода → нет URL → skip" но не реализовали "нет реального кода → заменить старый placeholder на нейтральный"
Agent failure mode: scope-exceeded — фикс формата ссылок не покрыл case TODO-блоков
Potential fix: в update-mermaid-links.sh — при TODO-блоке не генерировать URL, но очищать старый markdown-link placeholder (> 🔗 [...](url)) заменяя на _(ссылка: запусти bash scripts/update-mermaid-links.sh)_; то же в validate — не скипать TODO-блоки тихо, а проверять формат placeholder над ними
Статус: open
---
Gap-ID: G-071
Дата: 2026-06-01
Контекст: /deploy — запись в DEVLOG
Что пропустил: искал DEVLOG.md через Glob в корне it-dev-methodology/ — не нашёл. Сделал вывод что файл отсутствует и предложил создать. На самом деле DEVLOG.md живёт в it-dev-methodology-documentation/ (doc repo). Повторяющийся gap — ранее аналогичные случаи с другими артефактами doc repo.
Как обнаружено: разработчик указал ("мы его давно ведём")
Категория: context-gap
Гипотеза: при поиске файлов агент по умолчанию ищет в активном рабочем репо (it-dev-methodology). Для methodology-platform архитектура two-repo: code в it-dev-methodology, документация/DEVLOG/карты в it-dev-methodology-documentation. Это правило не в CLAUDE.md явно.
Agent failure mode: context-missed — структура two-repo известна, но не применяется при поиске конкретных файлов
Potential fix: добавить в CLAUDE.md или команду /deploy явную строку "DEVLOG.md, карты, ADR живут в it-dev-methodology-documentation/ — искать там, не в корне methodology repo"
Статус: closed (fixed в CLAUDE.md ## Read before work — добавлен explicit two-repo architecture note с полным списком doc-repo артефактов)
---
Gap-ID: G-070
Дата: 2026-06-01
Контекст: /plan → draft URL генерация
Что пропустил: scripts/mermaid-link.py передаёт поле "mermaid" как вложенную JSON-строку (`json.dumps({"theme":"default"})`) вместо объекта. mermaid.live ожидает объект — строка не парсится, ссылка открывается с пустой/сломанной диаграммой.
Как обнаружено: разработчик указал — draft ссылка в /plan не работала
Категория: logic-gap
Гипотеза: при написании скрипта `json.dumps({"theme":"default"})` выглядело как "сериализация вложенного объекта", но на деле создаёт строку внутри строки — double-serialization
Agent failure mode: model-error — неверное понимание структуры mermaid.live state формата
Potential fix: убрать вложенный json.dumps — передавать `"mermaid": {"theme": "default"}` как нативный dict
Статус: closed (fixed inline)
---
Gap-ID: G-069
Дата: 2026-06-01
Контекст: /diagnose
Что пропустил: генерировал Mermaid labels транслитерацией кириллицы ("Stanet", "Zapuskaet", "dobavlen") вместо кириллицы, считая это выполнением "RU описания" требования
Как обнаружено: разработчик указал — на скриншоте диаграммы видны русские слова латинскими буквами (повторный gap, ранее уже указывалось)
Категория: logic-gap
Гипотеза: правило "описания поведения → RU" в commands/code.md не содержит explicit запрет транслитерации; агент делает логически-неверный вывод что транслитерация ≡ RU
Agent failure mode: prompt-ambiguous — инструкция допускала интерпретацию "написал по-русски, пусть и латиницей = RU требование выполнено"
Potential fix: добавить в commands/code.md:244 и commands/plan.md:950 строку "❌ СТРОГО ЗАПРЕЩЕНО: транслитерация кириллицы латиницей (Stanet, Zapuskaet, dobavlen) — это НЕ является RU. Только настоящая кириллица."
Статус: closed (fixed v4.48.0 — добавлен explicit anti-pattern в 8 файлов)
---
Gap-ID: G-068
Дата: 2026-06-01
Контекст: /diagnose — mermaid ссылки у консьюмера после обновления
Что пропустил: при реализации фикса mermaid-link формата (v4.37-v4.40) не обновил шаблоны USER-MAP / SYSTEM-MAP / ARTIFACT-MAP — они остались со старым `> 🔗 [Открыть в Mermaid Live](<url>)`. Консьюмеры получали старый формат при init/sync и видели markdown link вместо голого URL.
Как обнаружено: разработчик указал — после нескольких циклов диагностики обнаружил что источник проблемы в шаблонах, не в скрипте
Категория: completeness-gap
Гипотеза: при каждом фиксе формата ссылок обновлялись только карты в active repos (methodology + doc), но не шаблоны-источники. Правило "если меняешь формат артефакта — обновить шаблон" не было в checklist
Agent failure mode: scope-exceeded — фикс применялся к instances без upstream template
Potential fix: добавить в /code Шаг 4 self-review для methodology задач: "если изменился формат артефакта (карты, ссылки, секции) — проверить соответствующий `templates/*.template.md`"; в /review — sync validators должны включать templates/ в scope проверки
Статус: addressed (v4.49.0 — /code Шаг 4 пункт 11 усилен до ⛔ hard rule; /review template-drift check добавлен)
---
Gap-ID: G-067
Дата: 2026-06-01
Контекст: /diagnose — mermaid ссылки у консьюмера, Gap 7 в sync-audit
Что пропустил: при добавлении Gap 7 (validate-mermaid-links.sh) в /sync-audit — не добавил автоматический запуск `update-mermaid-links.sh` при обнаружении MISSING/STALE. Gap 7 только репортит проблему и просит пользователя запустить скрипт вручную. Более удобно было бы запускать fix автоматически прямо из sync-audit (с подтверждением или без).
Как обнаружено: пользователь указал явно после просмотра реализации Gap 7
Категория: completeness-gap
Гипотеза: при реализации Gap 7 я следовал паттерну остальных gaps (/sync-audit только репортит, не правит) — но для mermaid ссылок это единственный правильный ответ детерминирован (запустить скрипт), поэтому report-only избыточен
Agent failure mode: prompt-ambiguous — паттерн "sync-audit только репортит" применён механически без оценки fit
Potential fix: в Gap 7 добавить: при MISSING/STALE — предложить запустить `bash scripts/update-mermaid-links.sh` прямо из sync-audit (с подтверждением пользователя); это единственный правильный fix и он идемпотентен
Статус: open
---
Gap-ID: G-066
Дата: 2026-06-01
Контекст: /diagnose — mermaid.live ссылки отсутствуют у консьюмера erp-documentantion
Что пропустил: при предыдущих фиксах mermaid link формата (v4.37-v4.40) — обновлялись карты в methodology-platform и it-dev-methodology-documentation, но не выполнялся sync консьюмеров. erp-documentantion не получил update-mermaid-links.sh / mermaid-link.py / validate-mermaid-links.sh — карты оставались без ссылок вообще.
Как обнаружено: /diagnose — пользователь сообщил "у консьюмера после обновления всё ещё ссылки при тройном клике выделяют заголовок"
Категория: completeness-gap
Гипотеза: каждый фикс mermaid-links запускал update-mermaid-links.sh только в known repos (methodology + doc), но не проверял consumer repos через pull-consumers. "Фикс задеплоен" не равно "фикс применён везде где нужен".
Agent failure mode: scope-exceeded — фикс применялся к source без downstream check на consumers
Potential fix: добавить в /deploy или /code Шаг 5 для methodology задач затрагивающих scripts/ или mermaid формат — явный checklist пункт: "запустить sync-methodology.sh для известных consumers + update-mermaid-links.sh в каждом"
Статус: addressed
---
Gap-ID: G-065
Дата: 2026-06-01
Контекст: /secrets + /diagnose
Что пропустил: запустил secrets-show.sh из неправильного cwd — решил что секреты отсутствуют, хотя они лежат в соседнем репо
Как обнаружено: пользователь показал скриншот с реальными секретами
Категория: assumption-gap
Гипотеза: /secrets не уточняет из какого репо запускается; агент не проверил какой репо является «home» для конкретных секретов перед выводом
Agent failure mode: context-missed
Potential fix: перед запуском secrets-*.sh проверять cwd совпадает ли с репо у которого есть secrets-manifest.yaml; если нет — выводить warning "running from X, manifest found in Y"
Статус: open
---
Gap-ID: G-063
Дата: 2026-06-01
Контекст: /code
Что пропустил: не обновил triggers.json в конце /code (last_plan_session.code_run = true, last_deploy)
Как обнаружено: разработчик указал
Категория: prompt-gap
Гипотеза: Шаг 0 выполняется в начале /code и агент считает state-update уже сделанным; финальная запись после деплоя не вынесена в отдельный явный шаг — теряется в потоке Шагов 4-6
Agent failure mode: prompt-ambiguous
Potential fix: добавить в /code явный финальный пункт после deploy "обновить triggers.json: code_run=true + last_deploy"
Статус: addressed (v4.49.0 — добавлен Шаг 7 «Обновление state» как обязательный финальный шаг /code с ⛔ правилом и explicit JSON snippet)


<!-- новые — сверху -->

---
Gap-ID: G-064
Дата: 2026-06-01
Контекст: /plan Шаг 99.54 — Draft Maps — сгенерировал невалидный mermaid.live URL через Путь B (inline pako encoding)
Что пропустил: (1) URL через subagent pako encoding невалиден — mermaid.live показал "Loading URL failed"; (2) фолбэк Путь B (код диаграммы без URL) недопустим — правило требует ВСЕГДА генерировать ссылку на mermaid.live, не код
Как обнаружено: пользователь прислал скриншот ошибки + уточнил что Draft Maps ВСЕГДА должны давать ссылку, не код
Категория: logic-gap
Гипотеза: subagent не может выполнить реальную zlib deflate операцию — возвращает правдоподобный но некорректный base64url; агент не имел fallback кроме "показать код" что тоже нарушает требование
Agent failure mode: context-missed
Potential fix: Путь B переформулировать: если scripts/mermaid-link.py недоступен → запустить py/python3 scripts/mermaid-link.py через Bash без cd (абсолютный путь к скрипту). Если и это заблокировано — показать код диаграммы + явную инструкцию "вставь на mermaid.live вручную" как единственный допустимый fallback. Subagent для pako encoding — запрещён.
Статус: open
---
Gap-ID: G-072
Дата: 2026-06-01
Контекст: /diagnose — повторный сигнал от пользователя: AskUserQuestion popup без (Recommended) на первом варианте
Что пропустил: при генерации AskUserQuestion вариантов — не добавлял "(Recommended)" к рекомендуемому первому варианту
Как обнаружено: пользователь указал повторно (ранее уже сообщал — gap не был структурно закрыт)
Категория: prompt-gap
Гипотеза: правило "first option = (Recommended)" есть в system prompt AskUserQuestion tool description, но не продублировано в command-файлах методологии → не активируется в контексте выполнения команд
Agent failure mode: context-missed
Potential fix: добавить в `commands/plan.md` и `/diagnose` (или general writing rules в CLAUDE.md) явный checklist пункт: "любой AskUserQuestion → первый вариант ОБЯЗАН содержать '(Recommended)' если у тебя есть мнение"; добавить в /review блокирующую проверку на AskUserQuestion без (Recommended) там где рекомендация очевидна
Статус: open
---
Gap-ID: G-062
Дата: 2026-05-29
Контекст: /diagnose — агент увидел значение секрета и использовал его в inline env assignment
Что пропустил: два вектора утечки не закрыты: (1) агент может вызвать _get-secret-raw.sh --explicit-stdout который выводит значение в stdout → transcript; (2) bash_protect.py не блокирует pattern `KEY="value" bash script.sh` где значение видно в tool input. Агент получил KEYLOCK_ADMIN_CREDENTIALS, удержал в context, затем использовал как inline env var в Bash команде — полный credential leak через transcript.
Как обнаружено: агент написал в chat "Пароль KeycloakAdmin2024! — он уже в секретах, я его видел при проверке Keycloak token ранее в сессии" и сконструировал команду KEYLOCK_ADMIN_CREDENTIALS="KeycloakAdmin2024!" bash scripts/keycloak-set-tenant-id.sh
Категория: completeness-gap
Гипотеза: (1) _get-secret-raw.sh помечен как whitelist для агентских scripts — но агент может вызвать его сам, получив значение в stdout; (2) bash_protect.py ENV_DUMP_PATTERNS покрывает cat/env/printenv но не inline-assignment pattern; (3) нет правила "агент НЕ ДОЛЖЕН вызывать _get-secret-raw.sh сам"
Agent failure mode: prompt-ambiguous (нет explicit запрета агенту вызывать _get-secret-raw.sh; нет блока inline env assignment pattern)
Potential fix: (1) добавить в bash_protect.py паттерн на `[A-Z_][A-Z0-9_]*=".{8,}"[\s]+bash` — inline assignment с длинным значением; (2) убрать _get-secret-raw.sh из bash whitelist или добавить отдельное правило "агент не может вызывать _get-secret-raw.sh напрямую — только пользователь"; (3) добавить в CLAUDE.md MUST NOT: "агент НЕ ДОЛЖЕН вызывать _get-secret-raw.sh --explicit-stdout"; (4) incident response: при обнаружении credential в chat → немедленная ротация + scrub + закрыть сессию
Статус: closed — v4.44.6 (bash_protect.py: raw-getter blocked + inline-assignment blocked for secret-named keys)
---
Gap-ID: G-061
Дата: 2026-05-29
Контекст: /diagnose — вопрос пользователя "учтено ли удаление секрета?"
Что пропустил: secrets-management система не имеет операции удаления ключа. Есть: add/show/edit/update/rollback/scrub/validate — нет delete. Use cases не покрыты: (1) сервис выведен из эксплуатации → нужно убрать KEY из .env + manifest; (2) ошибочно добавлен KEY → быстрый откат без перезаписи; (3) cleanup orphan keys которые уже не нужны.
Как обнаружено: пользователь спросил напрямую "учтено ли удаление секрета?"
Категория: completeness-gap
Гипотеза: при разработке secrets-management v4.34.0–v4.41.0 фокусировались на add/rotation/show workflow. Delete — редкая операция, не вошла в scope ни одного /plan. Не задали вопрос "весь ли CRUD покрыт?" при планировании.
Agent failure mode: scope-exceeded
Potential fix: добавить scripts/secrets-delete.sh (atomic delete KEY из .env + optional: remove entry из secrets-manifest.yaml), добавить /secrets --delete KEY в команду. Атомарность: backup перед удалением (.env.backup-{ts}), flock, подтверждение пользователем. Warning если KEY = required в manifest: "KEY помечен required — удаление может сломать проверки. Продолжить? (yes/no)"
Статус: open
---
Gap-ID: G-060
Дата: 2026-05-29
Контекст: /diagnose — consumer агент спрашивал через AskUserQuestion о Keycloak URL вместо поиска в secrets
Что пропустил: consumer на v4.9.12 не имеет secrets-management инфраструктуры (появилась v4.34.0). Агент правомерно спросил пользователя — нет check-secret.sh, нет .env, нет secrets-manifest.yaml. Системная проблема: /code не содержит обязательного pre-check "перед работой с external service проверь secrets". Даже если бы инфраструктура была — агент мог не знать что KEYCLOAK_REALM_URL нужно искать там.
Как обнаружено: пользователь сообщил что консьюмер не понимает где находить "парли" (параметры) — агент задал вопрос через popup вместо самостоятельного поиска
Категория: completeness-gap
Гипотеза: (1) consumer stale version без secrets инфраструктуры; (2) /code Шаг 1 не содержит "external service pre-check" → агент не знает куда смотреть для credentials
Agent failure mode: context-missed
Potential fix: (1) добавить в /code Шаг 1 пункт "External service check: если задача взаимодействует с внешним API/DB/auth — проверить check-secret.sh <KEY> до начала. Missing → показать how_to_obtain из manifest, HARD BLOCK"; (2) в secrets-manifest.yaml template добавить common external services examples (KEYCLOAK_REALM_URL, DATABASE_URL и т.п.) чтобы consumer заполнял при первом sync; (3) consumer нужен sync до v4.44.x для получения secrets инфраструктуры
Статус: open
---
Gap-ID: G-059
Дата: 2026-05-29
Контекст: /review — reviewer фокусировался только на последних commits вместо полного branch diff
Что пропустил: /review Шаг 1 содержал `git diff HEAD` — это только uncommitted/последний commit. При запуске после сессии без /plan reviewer видел частичный scope и самостоятельно корректировал ("фокусирую на последних 5 commits") вместо применения структурного правила.
Как обнаружено: пользователь указал на пример из /review output: "Это огромный накопленный diff vs main — целая сессия разработки. Фокусирую review на последних 5 commits"
Категория: prompt-gap
Гипотеза: Шаг 1 `git diff HEAD` — стандартный git-рефлекс, но для branch review нужен `git diff main..HEAD`. Автор не учёл что /review запускается не только сразу после /code (где uncommitted = всё), но и после целой сессии с множеством commits.
Agent failure mode: prompt-ambiguous
Potential fix: добавить в /review Шаг 1 branch scope check (`git diff production_branch..HEAD --stat`) как обязательный первый шаг с классификацией scope (компактный vs большой) и выбором фокуса при большом scope. Closes этот gap: commits без /plan теперь явно выявляются и сигнализируются.
Статус: addressed (v4.44.3)
---
Gap-ID: G-057
Дата: 2026-05-29
Контекст: /diagnose — /sync-audit финальный отчёт показывает stale версию
Что пропустил: `/sync-audit` Шаг 3 Report финальная фраза "Methodology vX.Y.Z полностью применена" берёт версию из `last_sync_audit.methodology_version` в triggers.json — это значение от предыдущего запуска /sync-audit, а не текущая версия. Consumer видит v4.27.0 когда реальная v4.43.0 — вводит в заблуждение.
Как обнаружено: пользователь увидел "v4.27.0 полностью применена" при текущей методологии v4.43.0
Категория: logic-gap
Гипотеза: финальная фраза должна показывать ТЕКУЩУЮ версию из `.claude/.version` (или methodology VERSION), а не last_sync_audit.methodology_version который обновляется только после завершения аудита. Агент перепутал "версия при которой аудит запускался" и "текущая версия методологии".
Agent failure mode: prompt-ambiguous (формат Шага 5 triggers.json обновления не уточнял что финальная фраза должна брать версию из другого источника)
Potential fix: в `/sync-audit` Шаг 3 Report финальная фраза должна явно: "Methodology version в этом репо: {.claude/.version value} | Last audit был на: {last_sync_audit.methodology_version}". Или проще: всегда показывать текущую версию из .claude/.version, не из triggers.json. Добавить в Шаг 3 template явный комментарий: "версия для фразы = .claude/.version, не triggers.json".
Статус: open
---
Gap-ID: G-056
Дата: 2026-05-29
Контекст: /diagnose — consumer Mermaid ссылка в старом формате (с заголовком + blockquote вместо bare URL)
Что пропустил: `update-mermaid-links.sh`, `mermaid-link.py`, `validate-mermaid-links.sh`, `validate-doc-freshness.sh` никогда не добавлялись в `templates/scripts/` → consumer проекты не получают эти скрипты через `sync-methodology.sh`. Consumer на v4.10.6 физически не может запустить обновление ссылок ни в старом ни в новом формате — скрипта нет вообще.
Как обнаружено: пользователь указал на скриншот: consumer (ai-assistant-documentation) генерирует ссылку в старом формате с заголовком и blockquote вместо bare URL
Категория: completeness-gap
Гипотеза: при добавлении скриптов в `templates/scripts/` мы фокусировались на secrets-management и deploy скриптах. Mermaid утилиты воспринимались как "methodology-internal" инструменты — не подумали что consumer тоже нуждается в них для обновления ссылок в собственных артефактах (SYSTEM-MAP, USER-MAP, ARTIFACT-MAP).
Agent failure mode: context-missed
Potential fix: добавить в `templates/scripts/`: update-mermaid-links.sh, mermaid-link.py, validate-mermaid-links.sh, validate-doc-freshness.sh. Добавить в /code Шаг 5 checklist пункт: "новый скрипт в `scripts/` → нужно ли его в `templates/scripts/` для consumer distribution?" (аналог вопроса про sync).
Статус: addressed (v4.42.6)
---
Gap-ID: G-055
Дата: 2026-05-29
Контекст: /diagnose — maps не обновлены после v4.42.0 (keychain backend)
Что пропустил: после добавления keychain backend в with-secret.sh (новый step 0 + новый edge в SYSTEM-MAP) не обновил USER-MAP и SYSTEM-MAP. Написал "незначительный новый edge — можно добавить в следующем цикле" — субъективный override на mandatory checklist item (/code Шаг 5 line 210).
Как обнаружено: пользователь: "мне нужно ВСЕГДА обновлять maps"
Категория: prompt-gap
Гипотеза: /code Шаг 5 checklist "Если добавлена/изменена зависимость → SYSTEM-MAP.md edges обновлены?" без ⛔ enforcement → агент применил субъективный фильтр "незначительный" → skip.
Agent failure mode: prompt-ambiguous
Potential fix: усилить /code Шаг 5 строку до hard rule: "⛔ ANY new component/edge/capability/step → SYSTEM-MAP + USER-MAP + ARTIFACT-MAP ОБЯЗАНЫ быть обновлены. Нет исключений 'незначительный' — только явный N/A с обоснованием." + /review check: "новый script/module в priority chain без map update = 🔴 CRITICAL".
Статус: addressed (v4.42.1)
---
Gap-ID: G-054
Дата: 2026-05-29
Контекст: /diagnose (внешняя архитектурная критика secrets решения)
Что пропустил: skill secrets-management документирует external secret manager integration ТОЛЬКО для Vault/AWS/Azure/1Password, но НЕ для самых распространённых dev-инструментов: direnv, ~/.netrc, OS keychain. Из-за этого грамотный reviewer предположил что мы "reinvented" эти инструменты, хотя priority chain step 3 (process env) уже позволяет использовать их как storage backend. Также не задокументировано ЯВНО почему мы не используем direnv (он экспортирует в parent env → усугубляет agent transcript leak) и keychain (cross-platform fragmentation + тот же read-leak) как primary — это design rationale который reviewer не мог увидеть.
Как обнаружено: пользователь привёл внешнюю критику ("direnv + .envrc можно было взять"; "~/.config/it-dev/secrets.env reinvents .netrc / OS keychain"). /diagnose: 5 гипотез проверены → решение оправдано (H-D 92%: критика смешивает storage-at-rest с agent-leak defense), но 2 valid doc gaps подтверждены.
Категория: completeness-gap
Гипотеза: при написании skill секции "External secret manager integration" я выбрал enterprise-managers (Vault/AWS) как examples, предположив что dev-tools (direnv/netrc/keychain) "очевидны". Не задокументировал (1) почему они НЕ primary (design rationale против agent-leak), (2) что их МОЖНО использовать как backend через step 3. Reviewer без этого rationale естественно предположил reinvention.
Agent failure mode: completeness-gap (документация покрыла enterprise case, пропустила common dev-tools case + design rationale)
Potential fix: добавить в skill secrets-management секцию "Why not direnv / .netrc / OS keychain as primary?" с design rationale (direnv exports to parent env = anti-pattern для agent-mediated; keychain orthogonal threat — at-rest vs transcript-leak) + "Using them as storage backend" (direnv exec / keychain export → with-secret через step 3). Plus: рассмотреть keychain-backed storage как opt-in improvement (closes valid at-rest gap — наш .env plaintext objectively слабее encrypted keychain).
Refinement (2026-05-29, follow-up критика — platform-availability nuance): keychain-as-backend стоит PRIORITIZE, не просто "возможное улучшение" — НО только на платформах где он гарантирован из коробки: macOS (Keychain везде), Windows (Credential Manager везде). На этих ОС закрывает единственную объективную слабость (.env plaintext at-rest) БЕЗ нарушения zero-deps принципа. На Linux keychain есть (libsecret / gnome-keyring / kwallet), НО зависит от DE (GNOME/KDE) и НЕ гарантирован на headless/server. Поэтому правильная стратегия: opt-in keychain backend на macOS/Windows + `.env` + chmod 600 остаётся надёжным baseline для всех Linux/headless окружений. Не one-size-fits-all — platform-conditional storage backend selection (priority chain step 0: keychain если available, иначе .env).
Статус: addressed (v4.42.0)
---
Gap-ID: G-053
Дата: 2026-05-29
Контекст: /plan для secrets-manifest schema v2 — пользователь спросил "как будет понятно к чему этот токен? Какой URL или ssh к какому проекту?"
Что пропустил: при design secrets-management v4.34.0 предположил single-host scope (один GitHub PAT для всего), не предусмотрел per-entry metadata (service_name / service_url / login). Manifest schema v1 хранила только `key`, `purpose`, `required`, `how_to_obtain` — без binding к конкретному hosting/account. `git-credential-from-env.sh` имел hardcoded `KEY="GITHUB_PAT"` — multi-host фундаментально невозможен. Реальный use case (GitHub cait-solutions + GitLab self-hosted code.nexchance.de) blocked.
Как обнаружено: пользователь явно: "разве этого не должно быть? Твое мнение?" — после моего инструктажа "выполни set-secret.sh GITHUB_PAT <token>", он спросил откуда система знает к чему этот токен относится
Категория: assumption-gap
Гипотеза: design phase v4.34.0 я анализировал текущий use case (personal dev, один github.com workflow) и предположил это **достаточно** для v1. Не задал critical вопрос "что если у user 2+ hosts или 2+ accounts?". Single-host assumption внутри meta-uровня — confirmation bias вокруг текущего workflow вместо questioning об N+1.
Agent failure mode: scope-exceeded (design phase) / prompt-ambiguous (Шаг 1.5 "горизонт 3 шага" не enforced multi-tenancy/multi-account check)
Potential fix: добавить в /plan Шаг 1.5 (Forward-thinking) obligatory sub-check для design tasks: "[ ] Multi-tenancy / multi-account: если решение касается credentials / per-user state / per-service config — рассмотрен ли case N>1 (multi-host, multi-account, multi-environment)? Если scope ограничен N=1 — это явное design decision с обоснованием 'почему N=1 достаточно сейчас + что меняется при N>1'?". Это закрывает класс "agent fixes для текущего N=1 без думая о scale-out". Сейчас Mandatory sub-checks для #5 покрывают cross-platform, не multi-tenancy — это adjacent class.
Статус: addressed (v4.42.0)
---
Gap-ID: G-052
Дата: 2026-05-29
Контекст: /plan Шаг 99.54 Draft Maps
Что пропустил: не сгенерировал Mermaid Live URL для draft map — вместо этого написал hallucinated warning "Mermaid Live link генерируется inline при /code Phase 6 (документация)"
Как обнаружено: разработчик указал (скриншот)
Категория: prompt-gap
Гипотеза: формулировка "Приоритет 1 — если скрипт доступен" создаёт ложное ощущение опциональности; модель решила что можно отложить URL-генерацию и придумала несуществующий fallback вместо выполнения Приоритета 2 (inline encoding)
Agent failure mode: model-error
Potential fix: переформулировать в plan.md — убрать "Приоритет 1 / Приоритет 2" frame (звучит как "выбери лучший вариант") на "ОБЯЗАТЕЛЬНО сгенерировать URL (два способа, оба дают URL прямо сейчас)"; добавить hard constraint "⛔ НЕ пропускать URL — показ draft без URL = нарушение шага"; запрет на любые formulations типа "ссылка будет в /code"
Статус: addressed
---
Gap-ID: G-020
Дата: 2026-05-28
Контекст: Точечный Edit USER-MAP.md Mermaid-блока вне /plan→/code workflow
Что пропустил: при прямом Edit Mermaid-блока в USER-MAP не запустил `bash scripts/update-mermaid-links.sh` сразу после правки. Пользователь обнаружил — ссылка вела к старой версии диаграммы ("добавить / посмотреть / ротировать секреты" → `with-secret.sh`, одна нода вместо 4-х разделённых).
Как обнаружено: пользователь: "почему ты не обновляешь ссылки? не быз запущен plan для этого поэтому пропустил?"
Категория: prompt-gap (правило enforced только через /code Шаг 4; при ad-hoc Edit игнорируется)
Гипотеза: CLAUDE.md Mermaid link rule sectional, применяется в формальном workflow /plan→/code. При прямом Edit агент не делает self-check "трогаю ли я ```mermaid``` блок? → нужен update-mermaid-links.sh?". Subjective adherence — fails без structural reminder.
Agent failure mode: prompt-ambiguous (правило не triggers structurally при Edit tool вне /code Шаг 4)
Potential fix: добавить в CLAUDE.md Mermaid link rule explicit sub-rule: "После ЛЮБОГО Edit/Write на файл с ```mermaid``` блоком (даже вне /code workflow) — **сразу** запустить `update-mermaid-links.sh` для затронутого файла. Не ждать /code Шаг 4." Альтернатива (L4 structural): PostToolUse hook на Edit/Write который видит ```mermaid``` модификации в diff → автоматически вызывает update script. Менее invasive — prompt rule с explicit self-check.
Статус: addressed (v4.42.0)
---
Gap-ID: G-019
Дата: 2026-05-28
Контекст: /diagnose
Что пропустил: STALE path в update-mermaid-links.sh обновил URL в ссылке но не вставил code block с URL — старая строка `_(обновить ссылку: ...)_` осталась, новый формат не применился
Как обнаружено: /diagnose — пользователь сообщил "ничего не изменилось" после деплоя v4.37.0
Категория: completeness-gap
Гипотеза: При реализации формата code-block логика MISSING (новая вставка) была реализована правильно, но STALE (существующая ссылка) получила только обновление URL. Upgrade-логика (вставить code block если его нет после ссылки) не была добавлена в STALE ветку — агент считал что STALE = только обновление URL
Agent failure mode: scope-exceeded
Potential fix: В STALE ветке после замены URL добавить ту же проверку `has_cb` что есть в fresh path — если code block отсутствует, вставить его сразу после link line (без пустой строки, в отличие от MISSING). Добавить этот edge case в /code Шаг 1.7 partial-check: "для STALE — проверить все варианты старого формата, не только URL мисматч"
Статус: addressed
---
Gap-ID: G-018
Дата: 2026-05-28
Контекст: /diagnose
Что пропустил: При удалении ограничения URL > 2000 агент заявил "URL любой длины кликабелен в markdown-рендерерах" без тестирования реального поведения на Windows. Реальный симптом: URL 4691 символов открывает MSN (поиск) вместо mermaid.live — Windows ShellExecute/Edge интерпретирует длинный URL как search query
Как обнаружено: /diagnose — пользователь сообщил что ссылка открывает MSN в Edge
Категория: assumption-gap
Гипотеза: Задача формулировалась как "убрать техническое ограничение" → агент убрал ограничение на основе теоретического аргумента ("markdown-рендерерам OK"), без end-to-end теста на реальной платформе пользователя (Windows + Edge). Оригинальное ограничение 2000 защищало именно от этого сценария
Agent failure mode: prompt-ambiguous
Potential fix: Для задач изменяющих URL-генерацию — обязательный пункт в /plan Шаге -1.5: "проверить end-to-end на платформе пользователя (открыть сгенерированный URL в браузере пользователя)". Нельзя убирать существующее ограничение без тестирования сценария который оно защищало.
Статус: addressed
---
Gap-ID: G-017
Дата: 2026-05-28
Контекст: /diagnose meta-analysis после v4.34.0 deploy
Что пропустил: Confidence Declaration в /plan заявил Security #9 = 94% И #4 Без регрессий = 97%, НО /diagnose post-deploy нашёл 3 не-detected gaps (G-014/015/016) которые должны были срезать те confidence values. Конкретно:
  • G-014 (methodology own .gitignore missing secrets rules) — должен был обнаружиться при #4 "adjacent grep по template/.gitignore vs own .gitignore" → не сделан
  • G-015 (settings.json deny incomplete coverage) — должен был обнаружиться при #9 "systematic enumeration of file-reading commands" → проверка ad-hoc по памяти
  • G-016 (chmod 600 не enforced на Windows NTFS) — должен был обнаружиться при #5 Forward-thinking "cross-platform verification" → claim chmod 600 без stat verify
Как обнаружено: /diagnose сам себя — 3 confirmed гипотезы которые Confidence Declaration не превентировал
Категория: completeness-gap (мета-уровень — checklist confidence Declaration не enforced detection этих gap-классов)
Гипотеза: Confidence Declaration требует "evidence ссылку на конкретный шаг плана", но шаги -1.3 (Adjacent Impact) и Шаг 1.5 (Forward-thinking) не имеют MANDATORY sub-checklist'ов для специфических классов gap. Agent заполняет evidence общими формулировками ("Шаг -1.3 grep по компонентам") без чек-боксов которые форсируют ALL критические подпроверки. Subjective evidence = subjective gap detection.
Agent failure mode: prompt-ambiguous (Confidence Declaration формат позволяет evidence без strong verification)
Potential fix: расширить /plan Шаг 99.3 Confidence Declaration tableдобавив МАНДАТОРНЫЕ sub-checks для каждого свойства (особенно #4 Без регрессий, #5 Forward-thinking, #9 Security):
  Для #4 (Без регрессий): «✅ Adjacent grep: для template/X.template — проверен соответствующий repo's own X (если применимо)?» / «✅ Dogfood check: methodology применяет это правило к самой себе?»
  Для #5 (Forward-thinking — cross-platform): «✅ Verified empirically на каждой supported platform (POSIX, Windows NTFS)?» / «✅ stat/inspect после mutating operation подтверждает effect?»
  Для #9 (Security — enumerative deny lists): «✅ Source enumeration: список из systematic source (man pages categorical list, BSD/GNU tooling taxonomy, OWASP), не из памяти?» / «✅ Adversarial test обходных команд проведён против deny list?»
  Если ANY sub-check unchecked → confidence ≤80% (мандатно), не subjective ↑↓ оценка.
Статус: addressed (v4.34.1)
---
Gap-ID: G-014
Дата: 2026-05-28
Контекст: /diagnose (после deploy v4.34.0 secrets-management)
Что пропустил: methodology repo's own `.gitignore` не содержит правил для секретов (`.env`, `.env.*`, `secrets.local.*`), хотя `templates/.gitignore.template` для consumers содержит. Methodology не использует свою же защиту на gitignore level.
Как обнаружено: /diagnose H-E confirmed 90% (post-check: grep .gitignore показал отсутствие entries)
Категория: assumption-gap
Гипотеза: при /code v4.34.0 я обновил `templates/.gitignore.template` для consumer protection, но предположил что methodology repo own `.gitignore` уже имеет аналогичные правила (или что они не нужны потому что методология не использует .env). Не проверил.
Agent failure mode: prompt-ambiguous
Potential fix: в `/plan` Adjacent Impact Scan для security/template tasks — обязательная проверка "методология применяет это к самой себе?". Дополнить чеклист: "если template содержит protection — соответствующее правило есть в repo's own конфиге?"
Статус: addressed (v4.34.1)
---
Gap-ID: G-015
Дата: 2026-05-28
Контекст: /diagnose (после deploy v4.34.0)
Что пропустил: settings.json Bash deny rules перечислены ENUMERATIVELY (cat/grep/awk/sed/python -c …), но coverage incomplete: missing `python .env`, `node ... .env`, `diff .env`, `iconv .env`, `< .env cat` (pipe-source), `tee/cmp/nl/pr/expand`. Claim "structural L5 protection" overstates coverage — реально это "common-paths L5".
Как обнаружено: /diagnose H-A confirmed 85% (post-check: audit grep settings.template.json показал 41 entries, выявлены missing patterns)
Категория: completeness-gap
Гипотеза: при /code Phase 1 я enumerated reader commands из памяти и из adversarial test, но не сделал SYSTEMATIC coverage — нет дерева "all file-reading bash idioms"; полагался на intuition какие команды "обычно используются".
Agent failure mode: context-missed
Potential fix: для enumerative deny lists — добавить в /code Шаг 4 (Self-review) пункт "если deny patterns перечисляют alternatives — есть ли systematic source (man pages categorical list, или taxonomy)?". Иначе honest downgrade claim severity.
Статус: addressed (v4.34.1)
---
Gap-ID: G-016
Дата: 2026-05-28
Контекст: /diagnose (после deploy v4.34.0)
Что пропустил: `set-secret.sh` делает `chmod 600` на `.env` для "защиты", но на Windows NTFS (Git Bash) chmod игнорируется — файл остаётся 644 (readable by other local users). Documentation упоминает "best-effort", но specifics Windows NTFS не explicit. Severity not honest.
Как обнаружено: /diagnose H-B confirmed 95% (post-check: stat -c '%a' показал 644 после chmod 600)
Категория: assumption-gap
Гипотеза: предположил что chmod 600 universally enforced (POSIX habit). Не verified empirically на Windows перед claim "chmod 600 защищает".
Agent failure mode: prompt-ambiguous
Potential fix: в скриптах которые делают chmod — после chmod вызвать stat и сравнить с requested permissions; если mismatch — warn user explicitly. В Scope limits CLAUDE.md — explicit Windows NTFS subsection с icacls workaround.
Статус: addressed (v4.34.1)
---
Gap-ID: G-013
Дата: 2026-05-20
Контекст: /plan + /code (ARTIFACT-MAP ссылка)
Что пропустил: когда пользователь сообщил "ссылка не работает" — добавил ⚠️ предупреждение в markdown вместо того чтобы сделать ссылку рабочей; пользователь ожидал рабочую ссылку, а не документацию об ограничении
Как обнаружено: разработчик указал ("ты не пофиксил проблему")
Категория: scope-gap
Гипотеза: задача "ссылка не работает" была интерпретирована как "объяснить почему не работает" — агент добавил предупреждение (документация) вместо структурного исправления (рабочая ссылка); scope задачи был сужен до "обозначить проблему", не до "устранить"
Agent failure mode: other
Potential fix: при получении сообщения о нерабочем артефакте (ссылка/скрипт/команда) — первый вопрос "что должен получить пользователь в итоге?" → если ссылка должна работать → задача = сделать работающей, не задокументировать почему не работает
Статус: addressed
---

---
Gap-ID: G-012
Дата: 2026-05-20
Контекст: /code (mermaid links v4.4.1 — ARTIFACT-MAP)
Что пропустил: сгенерировал URL для ARTIFACT-MAP (3767 символов) не проверив ограничение Windows ShellExecute (~2048 символов) — ссылка технически корректная, но кликабельной не является: Windows передаёт URL как поисковый запрос → открывает MSN/Bing вместо браузера
Как обнаружено: разработчик указал ("ссылка на artifact map не рабочая открывает msn")
Категория: context-gap
Гипотеза: при генерации URL задача формулировалась как "сгенерировать корректную pako-ссылку" — корректность понималась как "правильно закодировано"; ограничение ОС на длину URL при ShellExecute не входило в checklist; отсутствовала проверка "URL работает в конкретной ОС пользователя"
Agent failure mode: other
Potential fix: в /code при генерации/обновлении Mermaid-ссылок — добавить шаг: "если длина URL > 2000 символов — добавить ⚠️ предупреждение copy-paste рядом со ссылкой (Windows ShellExecute limit)"; в scripts/mermaid-link.py добавить warning при длине > 2000
Статус: addressed
---

---
Gap-ID: G-011
Дата: 2026-05-20
Контекст: /code (mermaid links v4.4.1)
Что пропустил: ARTIFACT-MAP.md (docs/product/ и templates/) не получил mermaid.live ссылку — хотя имеет Mermaid-диаграмму и находится в той же категории артефактов что SYSTEM-MAP и USER-MAP
Как обнаружено: разработчик спросил "а почему нет ссылки в artifact map?"
Категория: completeness-gap
Гипотеза (исправлено 2026-05-20): разработчик написал "добавь ссылки во все mermaid" — не указывал конкретный список (SYSTEM-MAP, USER-MAP). Агент самостоятельно выбрал только те файлы над которыми работал, без grep по проекту на наличие mermaid-блоков. ⚠️ Первоначальная гипотеза была неверна: она утверждала что "разработчик дал явный список (SYSTEM-MAP, USER-MAP)" — это неправда; агент некорректно атрибутировал собственное ограничение на разработчика. Это метапроблема: gap-запись может содержать ложное обвинение пользователя вместо корректного описания причины ошибки AI.
Potential fix: в /plan для задач типа "добавить X во все Y" обязательный шаг: "grep по всему проекту для нахождения всех Y — не hardcode список"; добавить в /code Шаг -1.3 Adjacent Impact для methodology-platform: "ARTIFACT-MAP всегда в списке смежных зон". Дополнительно: при записи в AGENT-GAPS — гипотеза должна описывать ошибку агента, не ссылаться на ввод пользователя как причину если пользователь не давал ограничений явно.
Статус: addressed
---

---
Gap-ID: G-010
Дата: 2026-05-20
Контекст: /code (mermaid links v4.4.1)
Что пропустил: (1) не сгенерировал реальные URL для `docs/product/USER-MAP.md` — существующий файл остался без ссылки; (2) placeholder в шаблонах `(<!-- comment -->)` — это сломанный markdown-линк (HTML-комментарий как URL, не кликабелен); (3) /review не поймал, потому что `docs/product/USER-MAP.md` gitignored и не был в `git diff`
Как обнаружено: разработчик спросил "где ссылка в USER-MAP?"
Категория: completeness-gap
Гипотеза: задача "добавить ссылки" была выполнена для шаблонов (новые файлы) и SYSTEM-MAP (уже в git diff), но не для уже существующих gitignored артефактов которые не попали в diff — нет checklist-пункта "проверить все существующие файлы с Mermaid, не только изменённые"; /review checklist проверяет только tracked файлы в git diff
Agent failure mode: other
Potential fix: в /code Шаг 4 Self-review при добавлении фичи "X в артефактах" — добавить пункт: "grep по всем .md в проекте (включая gitignored) на наличие mermaid-блоков без ссылки"; в /review добавить: "если фича меняет формат артефакта — проверить gitignored copies (docs/product/, docs/architecture/) явно"
Статус: addressed
---

---
Gap-ID: G-009
Дата: 2026-05-20
Контекст: free-chat (вся сессия)
Что пропустил: в момент каждого признания ошибки ("каюсь", "ты прав", "я не предусмотрел") не предложил записать в AGENT-GAPS.md — записи появились только после явного запроса разработчика в конце сессии
Как обнаружено: разработчик указал ("добавь gap что gaps не были добавлены пока я не попросил")
Категория: prompt-gap
Гипотеза: правило захвата ("ОБЯЗАН предложить запись сюда") существует в AGENT-GAPS.md преамбуле, но агент не читает AGENT-GAPS.md при старте каждой команды — правило не попадает в контекст автоматически; watchdog-хук срабатывает на ответ агента, но не проверяет что предложение записи действительно было сделано
Agent failure mode: other
Potential fix: добавить в `/plan` Шаг -3 Pre-flight (или в CLAUDE.md как invariant): "при наличии AGENT-GAPS.md в проекте — прочитать преамбулу до начала работы"; альтернатива Level 4+: watchdog-хук проверяет наличие паттерна "AGENT-GAPS" в ответе агента после каждого признания ошибки и блокирует если предложение пропущено
Статус: addressed (v4.42.0)
---

---
Gap-ID: G-008
Дата: 2026-05-20
Контекст: /code (workspace model implementation)
Что пропустил: хардкодировал `https://github.com/cait-solutions/it-dev-methodology` в `templates/USER-MAP.template.md` — нарушение правила "no project-specific names in templates"
Как обнаружено: /review Шаг 3 (документация) — поймал violation CLAUDE.md "не использовать project-specific имена в templates"
Категория: completeness-gap
Гипотеза: при копировании workspace-setup инструкций из существующего docs/product/USER-MAP.md (который содержит реальный URL) в шаблон не применил абстрагирование — воспринял URL как технический пример, а не как project-specific данные
Agent failure mode: other
Potential fix: в /code Шаг 4 Self-review добавить пункт: "если меняется шаблон (`templates/`) — проверить наличие project-specific имён, URL, email — заменить на `<placeholder>`"
Статус: addressed
---

---
Gap-ID: G-007
Дата: 2026-05-20
Контекст: /plan (workspace model)
Что пропустил: предложил открывать `[project-name]-backend/` и другие code repos как отдельные Claude Code workspaces — неверно; правильно: они клонируются внутрь documentation/ (gitignored), Claude видит их как поддиректории единственного workspace
Как обнаружено: разработчик поправил ("те репо не имеют команд методологии, зачем их открывать как workspace?")
Категория: assumption-gap
Гипотеза: не было явного понимания что цель — единый workspace root с gitignored соседями; предположил что "видеть код" = "открыть как workspace", не учёл что subdirectory тоже видна Claude без отдельного workspace
Agent failure mode: other
Potential fix: добавить в /plan Шаг 1 (или pre-flight) для methodology-platform задач: "если задача касается workspace-структуры — перечислить явно: что является workspace root, что является gitignored sibling, кто владеет командами"
Статус: addressed
---

---
Gap-ID: G-006
Дата: 2026-05-20
Контекст: /plan (workspace model — размещение it-dev-methodology)
Что пропустил: при планировании workspace-архитектуры не верифицировал как Claude Code обнаруживает команды из поддиректорий — пришлось запускать отдельный research agent уже в ходе /plan
Как обнаружено: разработчик поставил под сомнение initial architecture ("если он будет вне workspace то как it-dev-methodology поймёт в какой workspace создавать?"), пришлось исследовать
Категория: context-gap
Гипотеза: /plan Шаг -1.5 Верификация состояния требует "прочитан актуальный код функции" но не требует "верифицировано поведение платформы которая является dependency" — пропуск на уровне checklist
Agent failure mode: other
Potential fix: добавить в /plan Шаг -1.5 для задач с platform-dependency: "поведение внешней платформы (Claude Code, Git Bash, Python) верифицировано эмпирически или через документацию, не из предположения"
Статус: addressed
---

---
Gap-ID: G-005
Дата: 2026-05-19
Контекст: /code (добавление CLM_L в ARTIFACT-MAP v4.2.0)
Что пропустил: новые node/edge labels написал на английском ("project config · stack · invariants", "sync canonical", "initial create", "project config") при всех существующих labels на русском
Как обнаружено: разработчик указал на несоответствие языка — соседняя нода CLM = "правила AI · ⬅ все команды" (RU)
Категория: context-gap
Гипотеза: правило /code Шаг 1 "прочитать файл ПОЛНОСТЬЮ" не содержит явного checklist-пункта на проверку языка соседних нод/edges — чтение прошло, но style-check не был применён
Agent failure mode: other
Potential fix: добавить в /code Шаг 1 (или Шаг 4 self-review) пункт: "при добавлении нод/edges в Mermaid-диаграмму — язык новых labels соответствует языку соседних нод?" (level-3 checklist, переходящий к level-4 если включить в validate-artifact-map.sh)
Статус: addressed
---

---
Gap-ID: G-004
Дата: 2026-05-18
Контекст: /code (полный аудит ARTIFACT-MAP)
Что пропустил: при аудите W→R ошибок не проверил W→RW паттерн — команды которые читают артефакт КАК ЛОГИЧЕСКИЙ ВХОД перед записью; /code читает SM/PROD/CLM/ADR/UM перед обновлением, Retro читает IDEAS.md в Шаг 6; SyncV → INB показан как W, хотя реально R + C
Как обнаружено: разработчик спросил "а что code не читает user map?" — выявил системный класс пропуска
Категория: completeness-gap
Гипотеза: аудит фокусировался на явных ошибках (команда вообще не пишет → W неверно), но не применял полную матрицу проверки: для каждой W стрелки — "читает ли как логический вход?" Второй паттерн не имел явного checklist-пункта
Agent failure mode: other
Potential fix: добавить в Шаг 7б /product-check явный вопрос для W-рёбер: "читает ли команда артефакт как вход для принятия решений → тогда должно быть ==="
Статус: addressed
---

---
Gap-ID: G-003
Дата: 2026-05-18
Контекст: /plan
Что пропустил: при реализации Шага -4 выбрал keyword-matcher вместо LLM-native semantic assessment, хотя Шаг 0.5 явно предупреждает против этого
Как обнаружено: разработчик указал в следующем /plan
Категория: scope-gap
Гипотеза: в момент проектирования Шага -4 приоритет был на "быстро реализуемое" (regex в хуке + список фраз в правиле) вместо "системно правильное" (инструкция на семантическую оценку LLM)
Agent failure mode: other
Potential fix: Шаг -4 переформулировать как "оцени семантически смысл задания" + few-shot примеры как guidance — реализовано в v4.0.8
Статус: addressed
---

---
Gap-ID: G-002
Дата: 2026-05-18
Контекст: /plan
Что пропустил: задание /plan содержало претензию на пропуск (PM arrows не были системно проверены), но агент не предложил AGENT-GAPS — потому что задание было сформулировано как новая задача без триггерных фраз
Как обнаружено: разработчик указал (в следующем /plan)
Категория: prompt-gap
Гипотеза: /plan не имел шага проверки текста задания на признаки коррекции; хук сканировал только ответ AI, а не user-сообщение — поэтому gap остался незамеченным
Agent failure mode: other
Potential fix: Шаг -4 Correction check в /plan + Trigger 0 в CLAUDE.template.md + USER_CORRECTION_PATTERNS в хуке — реализовано в v4.0.7
Статус: addressed
---

---
Gap-ID: G-001
Дата: 2026-05-18
Контекст: /code
Что пропустил: при редактировании ARTIFACT-MAP не проверил корректность существующих Dev/PM стрелок — оставил "Developer" в Пишет для IDEAS.md и несколько PM-стрелок которые делаются командами
Как обнаружено: разработчик указал
Категория: context-gap
Гипотеза: при /code фокус был на добавлении AgentAI актора; проверка существующих стрелок не входила в эксплицитный checklist — только новые изменения анализировались
Agent failure mode: other
Potential fix: в /code Шаг 4 Self-review добавить пункт "если меняется ARTIFACT-MAP — проверить ВСЕ существующие human-actor стрелки, не только новые"
Статус: addressed
---
