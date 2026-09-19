#!/usr/bin/env bash
# Проверяет, что у каждого изменённого файла под backend/internal/**/*.go
# (кроме самих *_test.go) в PR есть хотя бы один *_test.go рядом, в той же
# директории. Не проверяет, что конкретная новая функция протестирована —
# это эвристика уровня "директория с новым кодом не осталась без тестов".
#
# Используется в CI (.github/workflows/backend-tests.yml), можно гонять и
# локально перед пушем:
#   backend/tests/check_new_code_has_tests.sh origin/main HEAD
set -euo pipefail

BASE="${1:?usage: check_new_code_has_tests.sh <base-ref-or-sha> [<head-ref-or-sha>]}"
HEAD="${2:-HEAD}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CHANGED="$(git diff --name-only --diff-filter=ACMR "$BASE" "$HEAD" -- backend/internal | grep '\.go$' | grep -v '_test\.go$' || true)"

if [ -z "$CHANGED" ]; then
  echo "Изменённых файлов под backend/internal/ нет — проверка не нужна."
  exit 0
fi

FAILED=0
while IFS= read -r file; do
  dir="$(dirname "$file")"
  if ! ls "$dir"/*_test.go >/dev/null 2>&1; then
    echo "Нет тестов рядом с изменённым файлом: $file (ожидался хотя бы один *_test.go в $dir/)"
    FAILED=1
  fi
done <<<"$CHANGED"

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Директория с изменённым кодом под backend/internal/ должна содержать тесты."
  echo "См. docs/DevDocs/backend/backend.md, раздел 8 (Тестирование)."
  exit 1
fi

echo "OK: у всех изменённых файлов под backend/internal/ есть тесты рядом."
