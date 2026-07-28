# 0030. `ITSAppUsesNonExemptEncryption` is true

Status: accepted
Date: 2026-07-28

## Context

Both `Info.plist` sources (`app/Config/CrocApp-Info.plist`, `CrocApp-macOS-Info.plist`) declared `ITSAppUsesNonExemptEncryption=false`. That is Apple's exemption for apps whose only encryption use is HTTPS/TLS via Apple's own frameworks, or that limit encryption to authentication.

CrocApp embeds croc as a linked Go library (ADR 0006), and croc implements its own transfer encryption in Go — AES-256-GCM and ChaCha20-Poly1305, via `crypto/aes` and `cipher.NewGCM` — rather than calling `CryptoKit`/`Security.framework`. That encryption secures file contents end-to-end, not just a connection to an Apple service, and is not limited to authentication. Neither condition for the exemption holds.

## Decision

`ITSAppUsesNonExemptEncryption=true` in both plists, with a comment at the key recording why. This is a factual declaration about what the binary does, not a policy choice — it has to match what's actually linked in, or the declaration is false regardless of what the App Store Connect questionnaire says separately.

## Consequences

- The App Store Connect submission questionnaire still has to be answered at upload time; this plist key does not skip it, it only stops the answer from contradicting the binary.
- No annual self-classification report is expected to be needed under the mass-market/publicly-available-software exemptions most consumer crypto apps use, but that determination is made at submission, against Apple's current guidelines, not fixed by this ADR.
- If croc ever moves to calling platform crypto instead of its own, this key and its comment need re-checking, not just its own review — the fact would have changed under it.
