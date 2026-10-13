package crocmobile

import (
	"context"
	"strings"

	"github.com/bakirgdev/CrocApp/crocmobile/internal/relaycache"
	"github.com/schollz/croc/v11/src/codephrase"
	"github.com/schollz/croc/v11/src/models"
	"github.com/schollz/croc/v11/src/publicrelay"
)

// DefaultRelayAddress is croc's default IPv4 relay. A relay setting that is
// blank or equal to it is not custom, so the public relay pool applies.
func DefaultRelayAddress() string { return models.DEFAULT_RELAY }

// DefaultRelayAddress6 is croc's default IPv6 relay; see DefaultRelayAddress.
func DefaultRelayAddress6() string { return models.DEFAULT_RELAY6 }

// RelayForCode returns the public pool relay that code maps to, the one both
// peers use when neither sets a custom relay. Empty only if the pool is empty.
func RelayForCode(code string) string {
	relay, err := poolRelay(code)
	if err != nil {
		return ""
	}
	return relay
}

type relayRoute struct {
	v4, v6 string
	public bool
}

// resolveRelay is the v11 CLI's relay choice (cli.go usesPublicRelay,
// assignPublicRelayForCode), shared by send and receive. A peer on a stock CLI
// derives its relay from the code the same way, so any divergence here makes
// most codes miss the other side's room.
func resolveRelay(code string, o *Options) (relayRoute, error) {
	// A custom relay is passed as set, the other side blanked. Unlike the CLI,
	// which always blanks v6 when v4 is custom, a custom pair keeps both
	// (docs/known-issues.md, Accepted).
	if v4, v6 := customRelays(o); v4 != "" || v6 != "" {
		return relayRoute{v4: v4, v6: v6}, nil
	}
	if !usesPublicRelay(o) {
		return relayRoute{v4: models.DEFAULT_RELAY, v6: models.DEFAULT_RELAY6}, nil
	}
	relay, err := poolRelay(code)
	if err != nil {
		return relayRoute{}, err
	}
	return relayRoute{v4: relay, public: true}, nil
}

func usesPublicRelay(o *Options) bool {
	v4, v6 := customRelays(o)
	return v4 == "" && v6 == "" && !o.OnlyLocal
}

// customRelays returns each relay address set to something other than croc's
// default, or "" for that side.
func customRelays(o *Options) (v4, v6 string) {
	v4 = strings.TrimSpace(o.RelayAddress)
	if v4 == models.DEFAULT_RELAY {
		v4 = ""
	}
	v6 = strings.TrimSpace(o.RelayAddress6)
	if v6 == models.DEFAULT_RELAY6 {
		v6 = ""
	}
	return v4, v6
}

func poolRelay(code string) (string, error) {
	relays := publicrelay.Relays()
	index, err := codephrase.RelayIndex(code, len(relays))
	if err != nil {
		return "", err
	}
	return relays[index], nil
}

// generatePublicCode is the CLI's generated-code path for the public pool: the
// first relay to answer a ping wins, and the code is drawn so that it maps to
// that relay.
func generatePublicCode(probe publicrelay.Probe) (string, error) {
	index, err := selectPublicRelay(probe)
	if err != nil {
		return "", err
	}
	return codephrase.GenerateForRelay(index, len(publicrelay.Relays()))
}

// selectPublicRelay is the CLI's best-relay cache (cli.go selectPublicRelay).
func selectPublicRelay(probe publicrelay.Probe) (int, error) {
	return relaycache.Get(func() (int, error) {
		index, _, err := publicrelay.SelectFirst(context.Background(), publicrelay.Relays(), publicrelay.ProbeTimeout, probe)
		return index, err
	})
}

// forgetPublicRelay mirrors the CLI clearing its cache when a send on a
// generated public code cannot reach the relay.
func forgetPublicRelay() { relaycache.Forget() }
