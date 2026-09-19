package auth

import (
	"errors"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const tokenTTL = 30 * 24 * time.Hour // 30 дней

// TokenCookieName — имя httpOnly cookie, которую веб-клиент может
// использовать вместо ручного хранения токена (например, в localStorage).
// iOS-клиент её игнорирует и продолжает работать через Authorization: Bearer.
const TokenCookieName = "subradar_token"

type Claims struct {
	UserID int64 `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken создаёт подписанный JWT для пользователя.
func GenerateToken(userID int64, secret string) (string, error) {
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(tokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// SetTokenCookie ставит JWT в httpOnly cookie в дополнение к токену в теле
// ответа — веб-клиент может использовать любой вариант, iOS продолжает
// работать через Authorization: Bearer как раньше.
//
// HttpOnly всегда true — иначе cookie можно украсть через XSS, что и было
// бы смыслом переезда с localStorage. Secure управляется конфигом
// (auth.cookie_secure): включать можно только за HTTPS — браузер не
// отправит Secure-cookie по обычному http://.
func SetTokenCookie(w http.ResponseWriter, token string, secure bool) {
	http.SetCookie(w, &http.Cookie{
		Name:     TokenCookieName,
		Value:    token,
		Path:     "/",
		MaxAge:   int(tokenTTL.Seconds()),
		HttpOnly: true,
		Secure:   secure,
		SameSite: http.SameSiteLaxMode,
	})
}

// ParseToken проверяет JWT и возвращает claims.
func ParseToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("неожиданный метод подписи")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("невалидный токен")
	}
	return claims, nil
}
