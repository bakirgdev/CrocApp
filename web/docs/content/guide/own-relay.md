---
sidebar_position: 9
title: Run your own relay
description: Run a croc relay on your Mac so devices on your network can transfer through it, and check that a relay is reachable and accepts your password.
---

# Run your own relay

A relay is the server two devices meet at when they cannot connect directly. It passes encrypted data and cannot read it. CrocApp normally uses croc's public relays. On a Mac you can run a relay yourself, so devices on your home or office network use it instead.

## Run a relay on your Mac

Open **Settings** (⌘,) and choose the **Relay** tab, or use the **Run a Relay** switch in the [menu bar window](menu-bar.md).

- **Run a Relay** starts and stops the relay. It is off by default and never starts by itself.
- **Port** is the first of four ports. croc's default is 9009, so the relay uses 9009 to 9012. Change it while the relay is stopped. If a port is taken, CrocApp says "That port is already in use": choose another or quit the app that uses it.
- **Password** is optional, but set one. The relay listens on every network connection of your Mac. Leave the password blank and it uses croc's default, which is public, so anyone who can reach your Mac can use it, over the internet too if your router or IPv6 firewall lets them in. A password you set is kept in the Keychain and shown only as dots.
- **Start Relay at Launch** (off by default) starts the relay each time CrocApp opens. The relay stops when you quit CrocApp.

While it runs, **Use on the other device** lists this Mac's addresses, such as `192.168.1.20:9009`. On the other device, enter one as the relay in CrocApp's [Settings](settings.md#relay), with the same password. IPv6 addresses go in **IPv6 Address**. With the croc command line, use `croc --relay 192.168.1.20:9009 --pass <password> ...`. Both devices must use the same relay. If a device cannot connect, allow ports 9009 to 9012 in the Mac's firewall.

The relay works for the Mac App Store and the direct-download builds alike. Only devices that can reach your Mac can connect, and CrocApp does not open a port on your router.

## Check a relay

On every platform, **Settings** has **Check Relay…**. It tests the relay your transfers use: the address and IPv6 address you set, or croc's four public relays if you set none. For each address it shows, for IPv4 and for IPv6:

| Result | What it means | What to change |
|---|---|---|
| Reachable in 12 ms, password accepted | The relay answered and accepted the password | Nothing |
| No address of this kind | The name has no IPv4 or no IPv6 address | Nothing, if the other version works |
| Can't connect | Nothing answered on that address and port | Check your internet connection, the address and port, and that the relay is running |
| Reachable, password rejected | The relay is there but refused the password | Fix the relay password in Settings |
| Reachable, but the relay is busy | The relay took the password but turned this check away for now | Try again in a minute |
| Reachable, but not a croc relay | Something answers, but it is not a croc relay | Check the address and port |

The screen also shows whether CrocApp may use the local network, and how to turn it on if it is off. The check connects and joins the relay the way a transfer does, without sending anything. It connects directly and does not use the proxies in Advanced, so every relay it tries sees this device's own address. If you set a proxy, the screen warns you and waits until you tap **Check Anyway**. Your password never leaves your device except to the relay you check. With **Local Network Only** on, transfers use no relay, so there is nothing to check.
