# External Knowledge Sources — methodology-platform

Список надёжных внешних источников для отслеживания новых идей и паттернов.
Читается `/retro` Шаг 5.6 для предложения пополнения IDEAS.md и `external-sources.md` консьюмеров.

---

## Назначение

Это список **методологии** (не для консьюмеров). Ловит:
- Изменения в стеке методологии (Claude Code, Anthropic SDK, hooks API)
- Новые agent/skill/hook patterns
- Обновления marketing-skills и domain-skills библиотеки

Консьюмеры используют свой `external-sources.md` (создаётся через sync) для domain-specific источников.
Консьюмерские источники **не синхронизируются обратно** в методологию (Граница 1).

---

## Sources

| # | Source | URL | Что ловить | Частота | last_scanned |
|---|---|---|---|---|---|
| 1 | anthropic-cookbook | https://github.com/anthropics/anthropic-cookbook | multi-agent patterns, tool-use, agent skills examples | каждый /retro | — |
| 2 | anthropic-courses | https://github.com/anthropics/courses | структурированные гайды по Claude, prompt engineering best practices | ежеквартально | — |
| 3 | claude-code releases | https://github.com/anthropics/claude-code/releases | новые hooks API, slash-commands изменения, agent capabilities (CRITICAL: следить за breaking) | каждый /retro | — |
| 4 | marketingskills | https://github.com/coreyhaines31/marketingskills | новые marketing-skill patterns, структурные обновления skill-файлов | ежеквартально | — |
| 5 | mattpocock/skills | https://github.com/mattpocock/skills | engineering-discipline skill patterns (TDD, grill-me, architecture) — эталон для нашего engineering-skill layer | каждый /retro | — |
| 6 | TG-digest (приватные AI-каналы) | file://tg-digests/digest-2026-06-23.md | AI/автоматизация паттерны из 12 приватных TG-каналов (URAI @vdidreal) | каждый /scan-sources-full | 2026-06-23 |
| 7 | YT-digest (AI YouTube-каналы) | file://yt-digests/digest-2026-06-23.md | транскрипты 9 YouTube AI-каналов (NicholasPuru, DavidOndrej, VercelHQ, ALEKSEIULIANOV, VolchenkoAI, AIAutomation-n8n, krllmrzv, Zero2LaunchAI, SerhiiNemchynskyi) | каждый /scan-sources-full | 2026-06-23 |

> **`last_scanned`** — дата последнего скана через `/scan-sources` (watermark «что нового»). `—` = ещё не сканировался. Колонка опциональна: старый реестр без неё читается graceful (`/scan-sources` дополняет при первом скане).

> ⚠️ **Верифицируй URL перед использованием:** убедись что репо публичны и активны.
> При смене URL — обновить строку в таблице и добавить запись в DEVLOG `[fix:external-sources]`.

---

## Refresh Policy

| Trigger | Действие |
|---|---|
| `/scan-sources` (ручной) | сканирует источники, анализирует новое с `last_scanned` → `[research:X]` + IDEAS; add/list/remove источников |
| `/retro` Шаг 5.6 | агент анализирует [research:X] теги + AGENT-GAPS → предлагает IDEAS-кандидатов из источников |
| Источник устарел / удалён | удалить строку, DEVLOG `[fix:external-sources]` (или `/scan-sources убери`) |
| Новый надёжный источник найден (порог: ≥2 связанных сигнала из DEVLOG или AGENT-GAPS) | добавить строку (лимит 8) |
| Ни один источник не обновлялся 2+ /retro подряд | пересмотреть актуальность |
