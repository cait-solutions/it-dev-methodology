# /scan-sources-full — Полный сбор + анализ (TG + YouTube + публичные источники)

> **Это LOCAL-ONLY команда** (methodology-platform, не синкается консьюмерам).
> Оркестрирует account-bound fetcher'ы (tg-fetch.py, yt-fetch.py) ДО запуска /scan-sources.
> ADR-017 §3: fetcher'ы = локальные инструменты, имена файлов и ключи секретов НЕ входят в синкаемый core.

**Отличие от `/scan-sources`:**

| | `/scan-sources` | `/scan-sources-full` |
|---|---|---|
| Область | публичные URL + `file://`-дайджесты если есть | fetcher'ы → дайджесты → `/scan-sources` |
| Синкается | ✅ всем консьюмерам | ❌ только этот репо |
| Требует | нет | tg-fetch.py + yt-fetch.py + секреты |

---

## Рекомендуемая модель

**Default (Sonnet) · effort: High · thinking: ON** — cross-source synthesis.

---

## Шаг 1 — TG pre-fetch (если доступен)

Проверить наличие fetcher'а и секретов (boolean, без значений):

```bash
bash scripts/check-secret.sh TELEGRAM_SESSION
test -f tg-fetch.py
```

Если **оба условия выполнены** → запустить сбор приватных TG-каналов:

```bash
bash scripts/with-secret.sh TELEGRAM_API_ID TELEGRAM_API_HASH TELEGRAM_SESSION -- py tg-fetch.py --scan
```

- Дайджест пишется в `tg-digests/digest-YYYY-MM-DD.md`
- Если fetcher или секрет отсутствует → **silent skip**, перейти к Шагу 2
- Если subprocess завершился с ошибкой → показать `⚠️ tg-fetch.py вернул ошибку — TG-источники пропущены` и продолжить

---

## Шаг 2 — YouTube pre-fetch (если доступен)

```bash
bash scripts/check-secret.sh YOUTUBE_PROXY_URL
test -f yt-fetch.py
```

Если **оба условия выполнены** → запустить сбор YouTube-каналов:

```bash
bash scripts/with-secret.sh YOUTUBE_PROXY_URL -- py yt-fetch.py --scan
```

- Дайджест пишется в `yt-digests/digest-YYYY-MM-DD.md`
- Если fetcher или секрет отсутствует → **silent skip**
- Если subprocess с ошибкой → `⚠️ yt-fetch.py вернул ошибку — YouTube-источники пропущены`, продолжить

---

## Шаг 3 — Полный скан через /scan-sources

После выполнения Шагов 1-2 (или их graceful skip) — делегировать стандартной команде:

```
/scan-sources
```

`/scan-sources` Шаг 2 прочитает `file://`-записи в `external-sources.md` (TG-дайджесты, YT-дайджесты) как локальные файлы — статус `fetched` вместо `login-required`.

---

## Добавление источников в реестр

TG-каналы и YouTube-каналы регистрируются в `external-sources.md` как `file://`-источники:

```
| 6 | TG-digest | file://tg-digests/digest-{date}.md | AI/автоматизация паттерны | каждый /scan-sources-full | — |
| 7 | YT-digest  | file://yt-digests/digest-{date}.md  | YouTube транскрипты AI-каналов | каждый /scan-sources-full | — |
```

Дата `{date}` обновляется на актуальную при каждом запуске (агент подставляет today's date).

---

## Связь с реестрами fetcher'ов

- TG-каналы: `tg-sources.json` (корень репо, untracked)
- YouTube-каналы: `yt-sources.json` (корень репо, untracked)
- Добавить TG-канал: `bash scripts/with-secret.sh TELEGRAM_API_ID TELEGRAM_API_HASH TELEGRAM_SESSION -- py tg-fetch.py --init` (пересоздаёт реестр из аккаунта)
- Добавить YouTube-канал: вручную вписать строку в `yt-sources.json`
