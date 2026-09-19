package repository

import (
	"errors"

	sqlite "modernc.org/sqlite"
	sqlite3 "modernc.org/sqlite/lib"
)

// ErrAlreadyExists — запись нарушает уникальное ограничение (например,
// email/имя уже занято). Хендлеры матчат её через errors.Is и отвечают 409,
// вместо того чтобы разбирать текст ошибки драйвера.
var ErrAlreadyExists = errors.New("запись уже существует")

// isUniqueConstraintErr детектит нарушение UNIQUE/PRIMARY KEY ограничения
// на уровне кода ошибки sqlite-драйвера (modernc.org/sqlite), а не по
// подстроке в тексте — так проверка не ломается при смене формулировки
// ошибки в новой версии драйвера. При переходе на Postgres сюда
// достаточно добавить ветку для *pq.Error с Code == "23505".
func isUniqueConstraintErr(err error) bool {
	var sqliteErr *sqlite.Error
	if errors.As(err, &sqliteErr) {
		switch sqliteErr.Code() {
		case sqlite3.SQLITE_CONSTRAINT_UNIQUE, sqlite3.SQLITE_CONSTRAINT_PRIMARYKEY:
			return true
		}
	}
	return false
}
