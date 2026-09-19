#!/usr/bin/env bash
# Единая точка запуска всех Go-тестов бэкенда (юнит + интеграционные).
# Используется локально и в CI (.github/workflows/backend-tests.yml).
#
# ВАЖНО: при добавлении новых *_test.go — новый файл в уже
# зарегистрированной директории просто подхватится, а вот НОВУЮ
# директорию с тестами (internal/<pkg>/*_test.go, tests/<name>/*_test.go)
# нужно руками добавить в TEST_PATHS ниже. Если забыть — этот скрипт сам
# упадёт с понятной ошибкой (шаг "проверка регистрации тестовых директорий").
set -euo pipefail

cd "$(dirname "$0")/.." # -> backend/

TEST_PATHS=(
  "./internal/config/..."
  "./internal/pushjob/..."
  "./tests/integration/..."
)

echo "==> gofmt"
UNFORMATTED="$(gofmt -l .)"
if [ -n "$UNFORMATTED" ]; then
  echo "Не отформатировано (запустите gofmt -w):"
  echo "$UNFORMATTED"
  exit 1
fi

echo "==> go vet"
go vet ./...

echo "==> проверка: все директории с _test.go зарегистрированы в TEST_PATHS"
FAILED=0
while IFS= read -r dir; do
  dir="${dir#./}"
  found=0
  for tp in "${TEST_PATHS[@]}"; do
    tp_dir="${tp%/...}"
    tp_dir="${tp_dir#./}"
    if [ "$dir" = "$tp_dir" ] || [[ "$dir" == "$tp_dir"/* ]]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "Директория с тестами '$dir' не зарегистрирована в TEST_PATHS (backend/tests/RUN_ALL.sh)"
    FAILED=1
  fi
done < <(find . -name '*_test.go' -exec dirname {} \; | sort -u)

if [ "$FAILED" -eq 1 ]; then
  exit 1
fi

echo "==> go test"
go test "${TEST_PATHS[@]}"

echo ""
echo "OK: все проверки прошли"
