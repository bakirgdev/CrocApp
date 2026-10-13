package crocmobile

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"sync/atomic"
	"testing"
	"time"
)

// The pool and its order are protocol: a croc bump that changes them must fail here.
var wantPool = []string{
	"1.getcroc.com:9009",
	"2.getcroc.com:9009",
	"3.getcroc.com:9009",
	"4.getcroc.com:9009",
}

// oracleIndex computes the pool index without croc's code: SHA-256 as a
// big-endian integer mod 4 is its last byte mod 4, since 256 is a multiple of 4.
func oracleIndex(code string) int {
	sum := sha256.Sum256([]byte(code))
	return int(sum[len(sum)-1] % 4)
}

// customCodes returns one custom code per pool index.
func customCodes(t *testing.T) [4]string {
	t.Helper()
	var codes [4]string
	found := 0
	for i := 0; found < 4 && i < 1000; i++ {
		code := fmt.Sprintf("custom-code-%d", i)
		if idx := oracleIndex(code); codes[idx] == "" {
			codes[idx] = code
			found++
		}
	}
	if found < 4 {
		t.Fatalf("found codes for %d of 4 indices", found)
	}
	return codes
}

func TestRelayForCode(t *testing.T) {
	for idx, code := range customCodes(t) {
		if got := RelayForCode(code); got != wantPool[idx] {
			t.Errorf("RelayForCode(%q) = %q, want %q", code, got, wantPool[idx])
		}
	}
}

func TestBuildCrocOptionsPublicPool(t *testing.T) {
	defaults := []*Options{
		{},
		{RelayAddress: DefaultRelayAddress(), RelayAddress6: DefaultRelayAddress6()},
		{RelayAddress: " " + DefaultRelayAddress() + " ", RelayAddress6: "  "},
	}
	for idx, code := range customCodes(t) {
		for _, o := range defaults {
			for _, sender := range []bool{true, false} {
				c := mustBuildCrocOptions(t, sender, code, o)
				if c.RelayAddress != wantPool[idx] || c.RelayAddress6 != "" || !c.PublicRelay {
					t.Errorf("code %q, options %+v, sender=%v: relay (%q, %q, public=%v), want (%q, \"\", public=true)",
						code, *o, sender, c.RelayAddress, c.RelayAddress6, c.PublicRelay, wantPool[idx])
				}
				if c.RelayPassword != "pass123" {
					t.Errorf("blank password = %q, want croc's default", c.RelayPassword)
				}
			}
		}
	}
}

func TestBuildCrocOptionsPoolOff(t *testing.T) {
	tests := []struct {
		name   string
		o      Options
		v4, v6 string
	}{
		{"local only", Options{OnlyLocal: true}, "croc.schollz.com:9009", "croc6.schollz.com:9009"},
		{"custom v4", Options{RelayAddress: " relay.example:9009 "}, "relay.example:9009", ""},
		{"custom v4, default v6", Options{RelayAddress: "relay.example:9009", RelayAddress6: DefaultRelayAddress6()}, "relay.example:9009", ""},
		{"custom v6", Options{RelayAddress6: "[::1]:9009"}, "", "[::1]:9009"},
		{"custom v6, default v4", Options{RelayAddress: DefaultRelayAddress(), RelayAddress6: "[::1]:9009"}, "", "[::1]:9009"},
		{"custom pair", Options{RelayAddress: "relay.example:9009", RelayAddress6: "[::1]:9009"}, "relay.example:9009", "[::1]:9009"},
		{"custom pair, local only", Options{RelayAddress: "relay.example:9009", RelayAddress6: "[::1]:9009", OnlyLocal: true}, "relay.example:9009", "[::1]:9009"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if usesPublicRelay(&tt.o) {
				t.Error("usesPublicRelay = true, want false")
			}
			for _, code := range customCodes(t) {
				c := mustBuildCrocOptions(t, false, code, &tt.o)
				if c.RelayAddress != tt.v4 || c.RelayAddress6 != tt.v6 || c.PublicRelay {
					t.Errorf("code %q: relay (%q, %q, public=%v), want (%q, %q, public=false)",
						code, c.RelayAddress, c.RelayAddress6, c.PublicRelay, tt.v4, tt.v6)
				}
			}
		})
	}
}

// probeOnly answers only for the relay at index and counts every call.
func probeOnly(index int, calls *atomic.Int32) func(context.Context, string, time.Duration) (time.Duration, error) {
	return func(_ context.Context, address string, _ time.Duration) (time.Duration, error) {
		calls.Add(1)
		if address == wantPool[index] {
			return time.Millisecond, nil
		}
		return 0, errors.New("unreachable")
	}
}

func TestGeneratePublicCodeMapsToProbedRelay(t *testing.T) {
	t.Cleanup(forgetPublicRelay)
	for idx := range wantPool {
		forgetPublicRelay()
		var calls atomic.Int32
		code, err := generatePublicCode(probeOnly(idx, &calls))
		if err != nil {
			t.Fatalf("index %d: %v", idx, err)
		}
		if got := oracleIndex(code); got != idx {
			t.Errorf("generated %q maps to index %d, want %d", code, got, idx)
		}
		c := mustBuildCrocOptions(t, true, code, &Options{})
		if c.RelayAddress != wantPool[idx] || c.RelayAddress6 != "" || !c.PublicRelay {
			t.Errorf("generated %q: relay (%q, %q, public=%v), want %q", code, c.RelayAddress, c.RelayAddress6, c.PublicRelay, wantPool[idx])
		}
	}
}

func TestSelectPublicRelayCachesUntilForgotten(t *testing.T) {
	t.Cleanup(forgetPublicRelay)
	forgetPublicRelay()
	var first, cached, after atomic.Int32
	if idx, err := selectPublicRelay(probeOnly(2, &first)); err != nil || idx != 2 {
		t.Fatalf("first select = %d, %v; want 2", idx, err)
	}
	if idx, err := selectPublicRelay(probeOnly(3, &cached)); err != nil || idx != 2 {
		t.Fatalf("cached select = %d, %v; want 2", idx, err)
	}
	if n := cached.Load(); n != 0 {
		t.Errorf("cached select probed %d relays, want 0", n)
	}
	forgetPublicRelay()
	if idx, err := selectPublicRelay(probeOnly(3, &after)); err != nil || idx != 3 {
		t.Errorf("select after forget = %d, %v; want 3", idx, err)
	}
}

func TestSelectPublicRelayFailureIsNotCached(t *testing.T) {
	t.Cleanup(forgetPublicRelay)
	forgetPublicRelay()
	down := func(context.Context, string, time.Duration) (time.Duration, error) {
		return 0, errors.New("unreachable")
	}
	if _, err := generatePublicCode(down); err == nil {
		t.Fatal("generatePublicCode with every relay down: want error")
	}
	var calls atomic.Int32
	if idx, err := selectPublicRelay(probeOnly(1, &calls)); err != nil || idx != 1 {
		t.Errorf("select after failure = %d, %v; want 1", idx, err)
	}
}
