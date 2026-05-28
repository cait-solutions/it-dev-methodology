# Threat Model — {{Project Name}} {{Component / Feature}}

> **Назначение:** Шаблон модели угроз для конкретного сервиса или фичи.
> Скопируй этот файл → `threat-model-{component}-{YYYY-MM}.md` и заполни.
>
> **Методология:** STRIDE — Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege.
>
> **Когда заполнять:** создание нового сервиса, добавление аутентификации / авторизации, интеграция с внешним API, работа с PII-данными, любая `[security]` задача в `/plan`.

---

## Контекст

**Сервис / фича:** <название>
**Дата:** YYYY-MM-DD
**Автор:** <имя>
**Связанные ADR:** [ADR-NNN], [...]

---

## Границы системы (Trust Boundary Diagram)

```
[Описать словами или ASCII-диаграммой: кто вызывает что через какие границы]

Пример:
Browser (untrusted) → [Auth Provider] → Frontend → [API Gateway] → Service A (internal)
                                                                  ↓
                                                             Database (trusted)
```

---

## Активы — что защищаем

| Актив | Ценность | Где хранится | Кто имеет доступ |
|---|---|---|---|
| <Персональные данные пользователей> | Высокая | <таблица / сервис> | <роли> |
| <API-ключи внешних сервисов> | Критическая | `.env` (canonical) / `~/.config/it-dev/secrets.env` (shared) / external manager (Vault/AWS/etc.) — см. [skills/secrets-management/SKILL.md](../skills/secrets-management/SKILL.md) | <окружения> |
| <JWT / session tokens> | Высокая | <client storage> | <issuer + verifier> |
| | | | |

> **v4.34.0+ note:** methodology platform даёт 4-слойную защиту для секретов в `.env`: (1) `settings.json` Read+Bash deny (L5 tool permission), (2) `bash_protect.py` env-dump patterns (L4), (3) `secrets-guard.py` commit-time hook (L4), (4) `/review` token detector (L4). См. CLAUDE.md секцию Secrets & Credentials и ADR-001.

---

## Угрозы по STRIDE

### S — Spoofing (подмена identity)

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| <Запрос с подделанным user_id хедером> | <внутренняя сеть> | <JWT-валидация>(ADR-NNN) | ✅ / ⚠️ Открыта |
| | | | |

### T — Tampering (изменение данных в transit или at rest)

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| | | | |

### R — Repudiation (отказ от действий)

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| <Нет аудит-лога для критичных операций> | <внутренняя> | <Audit log> | |
| | | | |

### I — Information Disclosure (утечка данных)

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| <PII в логах> | <внутренняя> | <масштабирование PII в логах> | |
| <Утечка API-ключей через error responses> | <внешний> | | |
| | | | |

### D — Denial of Service

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| <Тяжёлые отчёты деградируют OLTP> | <legitimate traffic> | <Read replica> | |
| <Flood входящих запросов без rate limit> | <внешний> | <rate limit> | |
| | | | |

### E — Elevation of Privilege

| Угроза | Вектор | Мера защиты | Статус |
|---|---|---|---|
| | | | |

---

## Принятые риски

Угрозы которые осознанно не закрываются сейчас. Каждая со ссылкой на RISKS.md и условием пересмотра.

| Угроза | Причина принятия | Условие пересмотра | RISKS ref |
|---|---|---|---|
| | | | R-NN |

---

## Действия по результатам

| Действие | Приоритет | Ответственный | Срок |
|---|---|---|---|
| | | | |

---

## Проверка модели угроз

После заполнения — пройди чеклист:

- [ ] Каждый актив в таблице "Активы" имеет хотя бы одну меру защиты в STRIDE
- [ ] Каждая ⚠️ Открыта угроза — либо в "Принятые риски" (с условием пересмотра), либо в "Действия" (с конкретным сроком)
- [ ] Trust Boundary Diagram охватывает все интеграции из SYSTEM-MAP
- [ ] При наличии PII — есть строка в "I — Information Disclosure"
- [ ] При наличии финансово-значимых операций — есть строка в "R — Repudiation"
