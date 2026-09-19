package config

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCheckSecrets(t *testing.T) {
	validSecret := strings.Repeat("a", minSecretLength)
	shortSecret := strings.Repeat("a", minSecretLength-1)

	cases := []struct {
		name    string
		cfg     Config
		wantErr bool
	}{
		{"valid jwt only, not self-hosted", Config{JWTSecret: validSecret}, false},
		{"default jwt secret", Config{JWTSecret: defaultJWTSecret}, true},
		{"short jwt secret", Config{JWTSecret: shortSecret}, true},
		{"exact min length is valid", Config{JWTSecret: strings.Repeat("a", minSecretLength)}, false},
		{"self-hosted with valid server secret", Config{JWTSecret: validSecret, SelfHosted: true, ServerSecret: validSecret}, false},
		{"self-hosted with short server secret", Config{JWTSecret: validSecret, SelfHosted: true, ServerSecret: shortSecret}, true},
		{"self-hosted with empty server secret", Config{JWTSecret: validSecret, SelfHosted: true}, true},
		{"not self-hosted, server secret irrelevant", Config{JWTSecret: validSecret, SelfHosted: false, ServerSecret: ""}, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := tc.cfg.checkSecrets()
			if tc.wantErr {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestResolveCORSAllowAll(t *testing.T) {
	cases := []struct {
		name          string
		selfHosted    bool
		explicitlySet bool
		value         bool
		want          bool
	}{
		{"self-hosted, not set -> true by default", true, false, false, true},
		{"self-hosted, explicitly false -> false wins", true, true, false, false},
		{"self-hosted, explicitly true -> true", true, true, true, true},
		{"shared, not set -> false by default", false, false, false, false},
		{"shared, explicitly true -> true", false, true, true, true},
		{"shared, explicitly false -> false", false, true, false, false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := resolveCORSAllowAll(tc.selfHosted, tc.explicitlySet, tc.value)
			require.Equal(t, tc.want, got)
		})
	}
}

func TestPushEnabled(t *testing.T) {
	require.False(t, (&Config{}).PushEnabled())
	require.False(t, (&Config{VAPIDPublicKey: "pub"}).PushEnabled())
	require.False(t, (&Config{VAPIDPrivateKey: "priv"}).PushEnabled())
	require.True(t, (&Config{VAPIDPublicKey: "pub", VAPIDPrivateKey: "priv"}).PushEnabled())
}
