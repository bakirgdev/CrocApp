# 0033. The relay password lives in the Keychain

Status: accepted
Date: 2026-07-30

## Context

`AppSettings` persisted every setting the same way: a `didSet` writing into `UserDefaults` under a `settings.` key. That is right for the transfer toggles and the relay addresses. It is wrong for `relayPassword`.

Stated plainly, because the commit and the docs both have to be honest about it: on iOS the container plist is not readable by another app absent a jailbreak, but it rides along in unencrypted device backups and in forensic extractions. On macOS it sits at `~/Library/Containers/com.bakirgdev.CrocApp/Data/Library/Preferences/com.bakirgdev.CrocApp.plist`, readable by any process running as the same user with a plain `defaults read`.

The blast radius is small. This password gates *usage* of a self-hosted relay; transfer secrecy comes from the code-phrase PAKE, not from it (ADR 0012). So this is hygiene, not a hole in the security model — worth fixing, not worth overstating.

## Decision

`Support/KeychainStore.swift`: a stateless `enum` namespace over Keychain Services, shaped like the existing `SecurityScopedBookmark`. `kSecClassGenericPassword`, keyed by `kSecAttrService` (the bundle ID) plus a per-item `kSecAttrAccount`. Writes use `kSecAttrAccessibleAfterFirstUnlock` so a background transfer can read the password without a biometric or passcode prompt. `SecItemAdd` first, falling back to `SecItemUpdate` on `errSecDuplicateItem`, so a failed write never leaves the account holding nothing. No new dependency.

Only `relayPassword` moves. Everything else stays on `UserDefaults`.

Migration runs on every `AppSettings` init and is idempotent: if the legacy `settings.relayPassword` key is present and non-empty, copy it into the Keychain and `removeObject(forKey:)` so no plaintext copy lingers. Once removed there is nothing left to migrate.

**Every Keychain write honours the existing `persist` gate.** `resetToDefaults()` assigns `relayPassword = ""`, and `AutoVerify` sets `persist = false` before calling it. An ungated write would therefore blank the real user's stored password on any machine that has ever run a verify script. This is the one way the change can destroy user data, and the gate is the whole defence.

`kSecUseDataProtectionKeychain` is deliberately **not** set, so macOS uses the file-based keychain. The data-protection keychain is Apple's recommendation for new code, but it resolves an app's keychain access group from the team ID in the signature, and this app ships ad-hoc signed (ADR 0032). An ad-hoc build has no team ID and would fail with `errSecMissingEntitlement`. iOS is unaffected — it only has the data-protection keychain.

## Consequences

- The password survives a reinstall differently than the rest of the settings do. Keychain items outlive an app deletion on macOS and can be restored from an encrypted backup on iOS, where the `UserDefaults` settings do not.
- No harness in this repo touches the Keychain, so the migration and the round-trip are manual QA. A verify run cannot catch a regression in either.
- Revisit `kSecUseDataProtectionKeychain` once a Developer ID certificate exists. Switching then moves existing items, so it needs its own migration.
