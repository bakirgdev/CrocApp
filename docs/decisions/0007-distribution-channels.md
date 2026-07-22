# 0007. Distribution channels

Status: accepted
Date: 2026-07-22

## Context

Free OSS app, adoption-first. Research: distribution breadth was LocalSend's growth engine; App Store precedent for croc/Go apps exists (iCroc, Destiny, LocalSend).

## Decision

All of: iOS App Store, Mac App Store, macOS direct download (notarized DMG, Developer ID), Homebrew cask, TestFlight for betas.

## Consequences

- Mac App Store build must be fully sandboxed (`network.client` + `network.server` entitlements); DMG build notarized + hardened runtime. Two mac build configs.
- Requires paid Apple Developer account; multicast entitlement (if pursued) must be enabled per profile type incl. TestFlight.
- App Store review notes must explain code-phrase transfers + default public relay.
- Post-launch: PR adding CrocApp to croc README GUI section = highest-leverage discovery channel.
