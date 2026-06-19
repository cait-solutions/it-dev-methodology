# USER-MAP — negative-fixture (scripts/fixtures/validators/)
# Назначение: намеренно содержит .sh-ноду в mermaid-блоке.
# Трипает: validate-maps-coverage.sh _check_user_map_no_scripts (USER_MAP_NO_SCRIPTS=gate) → exit 1.
# Ожидаемый exit: 1 (ERROR: script-node нарушает command-first инвариант).
# НЕ является реальной картой — только proof-of-rejection fixture.

https://mermaid.live/edit#pako:eNolzb8KwjAQBvBXCTe3ugdxcnHWzTjE5rSVtinpBZEiiIuzk68hiAjin1e4vJFBp_v4fR9cB5k1CBKWpd1kuXYkpiNVCzGuC5opqHGTNs6uMaO0iNRr88HC9Yd85ks48o2fUiyspZacbv7NKepd8CueK7_lL4WD4E_Y8zviIxz4omAOCVToKl2Y-L5TQDlWqEAqMLjUviQFu7jRnuxkW2cgyXlMwDdGE44KvXK6-uPuC3hDVTQ

```mermaid
flowchart TD
  Init["new-project-init.sh<br/>Зачем: bootstrap<br/>Без него: нет проекта"]
```
