# Validator Negative Fixtures

Намеренно-сломанные входы для proof-of-rejection harness (`test-validators.sh`).
Каждый фикстур доказывает что его целевой валидатор **реально отклоняет** плохой ввод (не молчит с exit 0).

Закрывает: G-112 (false-green / SKIP-masquerades-as-PASS).

---

## Реестр фикстуров

| Фикстур | Целевой валидатор | Трипает строку | Ожидаемый exit | Wave |
|---|---|---|---|---|
| `triggers-duplicate-key.json` | `validate-triggers.sh` | `:67-71` — дубль-ключ global.X + top-level X | 1 | wave-1 |
| `usermap-with-script-node.md` | `validate-maps-coverage.sh` | `:850-915` `_check_user_map_no_scripts` (USER_MAP_NO_SCRIPTS=gate) | 1 | wave-1 |
| `mermaid-missing-link.md` | `validate-mermaid-links.sh` | `:115-126` MISSING_LINK → errors += 1 | 1 | wave-1 |
| `parity-divergent/` sandbox | `validate-script-parity.sh` | `:36` `diff -q` → exit 1 при drift | 1 | wave-1 |
| `delivery-empty-settings/` | `validate-delivery.sh` | `:77-83` 0 hook-refs detection-guard | 1 | wave-1 |
| `delivery-orphan/` | `validate-consumer-delivery.sh` | orphan-скрипт без consumer-ссылки (severity=error) | 1 | wave-1 |
| `delivery-clean/` | `validate-consumer-delivery.sh` | `delivery-allow:` маркер → не флагуется (positive control) | 0 | wave-1 |
| `mermaid-missing-annotation.md` | `validate-maps-coverage.sh` | `:465-466` `_freshness_finding` нет аннотации | 0 (WARN) | wave-2 |
| `work-home-stray/` | `validate-work-home.sh` | stray `_tmp_*` в корне fixture-дерева → exit 1 | 1 | wave-1 |

**wave-1:** активные assertions в `test-validators.sh` (assert_exit 1/0).
**wave-2:** фикстур готов, harness assertion отложена (WARN-severity → нельзя assert_exit 1 без изменения DIAGRAM_FRESHNESS_SEVERITY; расширить в отдельном /plan).

---

## Структура parity-divergent sandbox

```
parity-divergent/
  commands/             ← пустой маркер для [ -d commands ] guard в validate-script-parity.sh
  scripts/
    _fixture_pair.sh    ← VERSION A
  templates/
    scripts/
      _fixture_pair.sh  ← VERSION B (отличается 1 строкой — намеренный drift)
```

**⚠️ ВАЖНО:** `parity-divergent/` НЕ дублируется в `templates/scripts/fixtures/validators/` (CLAUDE.md ADR-014 dual-copy parity checklist §7). Если скопировать его туда — `validate-script-parity.sh` (первый gate в deploy) увидит файлы только в `templates/scripts/` без пары в `scripts/` → exit 0 (intersection-only) — но `_fixture_pair.sh` существует в обеих сторонах sandbox-поддерева что создаст parity-drift detection. Sandbox CWD изолирует.

---

## Добавление нового фикстура

1. Создать файл в `scripts/fixtures/validators/` (и в `templates/scripts/fixtures/validators/` — dual-copy).
2. Добавить `assert_exit <N> "<label>" -- bash scripts/<validator>.sh ...` в `test-validators.sh`.
3. Добавить строку в таблицу выше.
4. Добавить dual-copy строку в `templates/scripts/fixtures/validators/README.md`.
5. Bump VERSION (minor если новый артефакт consumer-facing, patch если internal).
