# External Knowledge Sources — {{Project Name}}

Список внешних источников специфичных для домена этого проекта.
Пополняется через `/retro` Шаг 5.6 при накоплении ≥2 связанных сигналов.

---

## Назначение

Добавляй ТОЛЬКО источники специфичные для **домена этого проекта** (не методологии).

❌ Не добавлять: Anthropic GitHub, Claude Code releases, anthropic-cookbook — это методологические источники, они в `external-sources.md` methodology-platform.

✅ Добавлять: changelog основного технического стека, professional community repo, domain-specific knowledge base, актуальные best-practice репозитории для домена.

---

## Your Domain Sources

| # | Source | URL | Что ловить | Частота | last_scanned |
|---|---|---|---|---|---|
| <!-- Add your domain sources here — up to 5 rows. Example: --> | | | | | |
| 1 | Название источника | https://... | Что именно ловить (паттерны/релизы/идеи) | каждый /retro / ежеквартально | — |

> **`last_scanned`** — дата последнего скана через `/scan-sources` (watermark «что нового»). `—` = ещё не сканировался. Управляется командой `/scan-sources` (добавить/сканировать/убрать источник) — руками таблицу править не обязательно.

---

## Когда обновлять

- **Добавить:** `/retro` Шаг 5.6 предложил нового кандидата (y) — заполнить строку
- **Удалить:** источник устарел, изменил тип, стал нерелевантным домену
- **Не добавлять:** методологические источники (Anthropic/Claude Code) — те в methodology repo

---

## Refresh Policy

| Trigger | Частота |
|---|---|
| `/scan-sources` (ручной) | сканирует источники + add/list/remove; пишет `last_scanned` |
| `/retro` Шаг 5.6 (опциональный шаг) | каждый /retro при ≥2 сигналах |
| Domain shift (смена технологического стека) | ручной пересмотр |
