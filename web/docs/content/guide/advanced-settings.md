---
sidebar_position: 5.5
title: Advanced Settings
description: Proxies, ports, encryption curve, upload speed limit and more, with each option's default, which device it affects, and whether the other device has to match.
---

# Advanced settings

**Advanced** holds the croc options most people never need: proxies, the encryption curve, an upload speed limit, ports and a few more. Every default is croc's own, so you can ignore this page unless you know you need something here.

On iOS, open **Settings** from the home toolbar and tap **Advanced**. On macOS, open Settings (⌘,) and choose the **Advanced** tab. **Reset to Defaults** at the bottom puts every setting back after a confirmation, and removes the saved proxies.

Each field checks what you type and shows a message under it. If a saved value is not usable, a transfer fails to start with "An Advanced setting can't be used" instead of falling back to something else.

## Who has to match

| Setting | Default | Affects | Other device must match? |
|---|---|---|---|
| Curve | P-256 | Receiving | No, the sender uses the receiver's choice |
| File hash | xxHash | Sending | No, the receiver uses the sender's choice |
| SOCKS5 proxy | None | This device | No |
| HTTP proxy | None | This device | No |
| Built-in DNS resolver | Off | This device | No |
| Multicast address (macOS only) | `239.255.255.250` | Both devices | Yes, the same address, to find each other on the local network |
| Sender IP | None | Receiving | No, but it must be the sender's address and base port |
| Upload speed limit | No limit | Sending | No |
| Base port | 9009 | Sending | A receiver that connects by sender IP must use it |
| Parallel connections | 4 | Sending | No |
| Multiplexing | On | Sending | No, the receiver follows |

"Sending" means the setting applies when this device sends; the receiving device follows what the sender does.

## Security

**Curve** picks the key-exchange curve: P-256 (the default), P-384, P-521, SIEC or Ed25519. The receiver's choice wins: the sender switches to it, so the two devices never have to match, and the setting only matters when this device receives.

**File hash** picks how the sender fingerprints files so the receiver can check them: xxHash (the default), imohash, MD5 or HighwayHash. Only the sender's choice matters.

## Network

**SOCKS5 proxy** and **HTTP proxy** send this device's connections through a proxy. Enter `host:port`, or an address such as `socks5://user:password@host:1080` (SOCKS5: `socks5://` or `socks5h://`; HTTP: `http://` or `https://`). If both are set, the SOCKS5 proxy is used. Connections to devices on your local network skip the proxy. The proxies also apply to [Send as link](stored-transfers.md) uploads, downloads and revokes.

A proxy address can contain a password, so CrocApp keeps both proxies in the Keychain, never in the settings file, and never shows them in an error message.

**Built-in DNS resolver** looks up relay names with croc's own resolver instead of the system's. It is off by default and only affects this device.

**Multicast address** is the group croc uses to find other devices on the local network. Both devices must use the same address, or they will not find each other locally (unless **Local network only** is on, they can still connect through a relay). It must be an IPv4 multicast address, from `224.0.0.0` to `239.255.255.255`. This setting is available on macOS only for now: iOS needs an Apple entitlement for multicast that CrocApp does not have, so iOS always uses the default address.

**Sender IP** is for receiving. Enter the sender's address and port, such as `192.168.1.20:9009` or `[fe80::1]:9009`, and CrocApp connects straight to the sender and skips relays and discovery. The port is the sender's **Base port**, 9009 unless they changed it. The sender must be reachable at that address, for example on the same network. If nothing answers there, the receive fails at once; it does not fall back to a relay. While it is set, the trust badge on a receive reads "Straight to the sender, no relay in between".

## Performance

**Upload speed limit** caps how fast this device sends, in bytes per second: digits with an optional `k`, `m` or `g`, such as `500k`, `2m` or `1g`. Leave it blank for no limit.

**Base port** and **Parallel connections** set the ports the sender's local relay listens on: the base port, then one more per connection. With the defaults that is 9009 to 9013. The last port must stay at or below 65535. They matter when a receiver connects by sender IP, or when something else on your device already uses those ports.

**Multiplexing** is on by default. Turning it off sends over one data connection. The receiving device follows.

## See also

- [Power options](power-options.md) for relay, connection, compression and confirmation settings.
- [Receiving files](receiving.md) for connecting by sender IP.
- [Settings and trust](settings-and-trust.md) for where settings are stored.
