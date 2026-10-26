import CrocKit

/// Checks for the Settings fields the engine validates. The engine decides
/// (`EngineSetting`, `ValidateSetting` in `crocmobile/network.go`), so a field
/// shows an error exactly when a transfer would refuse the value, and this file
/// holds only the plain-words text for each. Every check returns that text, or
/// nil when the value is fine. Blank is fine for all but the link server: it
/// means croc's default. The text never repeats the value, which can carry
/// credentials.
extension AppSettings {
    nonisolated static func socks5ProxyError(_ text: String) -> String? {
        engineError(
            .socks5Proxy, text,
            "Enter host:port, or an address starting with socks5:// or socks5h://.")
    }

    nonisolated static func httpProxyError(_ text: String) -> String? {
        engineError(
            .httpProxy, text, "Enter host:port, or an address starting with http:// or https://.")
    }

    nonisolated static func multicastAddressError(_ text: String) -> String? {
        engineError(
            .multicastAddress, text,
            "Enter an IPv4 multicast address from 224.0.0.0 to 239.255.255.255.")
    }

    nonisolated static func senderIPError(_ text: String) -> String? {
        engineError(
            .peerIP, text,
            "Enter the sender's address and port, such as 192.168.1.20:9009. The port must be a number from 1 to 65535."
        )
    }

    nonisolated static func throttleError(_ text: String) -> String? {
        engineError(
            .throttleUpload, text,
            "Enter a speed such as 500k, 2m or 1g, or leave it blank for no limit.")
    }

    /// `message` when the engine refuses `text` for `setting`, else nil.
    nonisolated static func engineError(
        _ setting: EngineSetting, _ text: String, _ message: String
    ) -> String? {
        do {
            try setting.validate(text)
            return nil
        } catch {
            return message
        }
    }
}
