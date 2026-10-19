import Foundation
import Network

/// Checks for the Advanced fields. Each mirrors what the engine accepts
/// (`crocmobile/network.go`, and croc's own parsing for the upload limit) and
/// returns plain-words text, or nil when the value is fine. Blank is always
/// fine: it means croc's default. Proxy texts never repeat the value, which can
/// carry credentials.
extension AppSettings {
    nonisolated static func socks5ProxyError(_ text: String) -> String? {
        proxyError(
            text, defaultScheme: "socks5", schemes: ["socks5", "socks5h"],
            message: "Enter host:port, or an address starting with socks5:// or socks5h://.")
    }

    nonisolated static func httpProxyError(_ text: String) -> String? {
        proxyError(
            text, defaultScheme: "http", schemes: ["http", "https"],
            message: "Enter host:port, or an address starting with http:// or https://.")
    }

    nonisolated static func multicastAddressError(_ text: String) -> String? {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if address.isEmpty { return nil }
        guard let octets = ipv4Octets(address), (224...239).contains(octets[0]) else {
            return "Enter an IPv4 multicast address from 224.0.0.0 to 239.255.255.255."
        }
        return nil
    }

    /// `ip:port`, IPv4 or IPv6 in brackets.
    nonisolated static func senderIPError(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        let message = "Enter the sender's address and port, such as 192.168.1.20:9009."
        let host: Substring
        let port: Substring
        if value.hasPrefix("[") {
            guard let close = value.firstIndex(of: "]") else { return message }
            host = value[value.index(after: value.startIndex)..<close]
            let rest = value[value.index(after: close)...]
            guard rest.hasPrefix(":") else { return message }
            port = rest.dropFirst()
            guard !host.contains("%"), IPv6Address(String(host)) != nil else { return message }
        } else {
            guard let colon = value.lastIndex(of: ":") else { return message }
            host = value[..<colon]
            port = value[value.index(after: colon)...]
            guard ipv4Octets(String(host)) != nil else { return message }
        }
        guard isPort(port) else { return "The port must be a number from 1 to 65535." }
        return nil
    }

    /// The sender's local relay listens on `base` to `base + transfers`.
    nonisolated static func portsError(basePort: Int, transfers: Int) -> String? {
        if basePort < 1 || basePort > 65535 { return "The base port must be from 1 to 65535." }
        if transfers < 1 { return "Use at least 1 parallel connection." }
        if basePort + transfers > 65535 {
            return
                "The ports run from the base port up by the number of connections. Keep the last one at 65535 or lower."
        }
        return nil
    }

    /// croc's format: whole bytes per second, optionally with k, m or g
    /// (kilo-, mega-, gigabytes). A lone digit is refused: croc quietly ignores
    /// a one-character value, which would look like a limit that is not there.
    nonisolated static func throttleError(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        let digits =
            value.last.map { "kKmMgG".contains($0) } == true ? value.dropLast() : value[...]
        let message = "Enter a speed such as 500k, 2m or 1g, or leave it blank for no limit."
        guard value.count > 1, !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
            let amount = Int64(digits), amount > 0
        else { return message }
        return nil
    }

    // MARK: - Helpers

    private nonisolated static func isPort(_ text: Substring) -> Bool {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }),
            let number = Int(text)
        else { return false }
        return (1...65535).contains(number)
    }

    /// Four decimal octets without leading zeros, as Go's `net.ParseIP` reads them.
    private nonisolated static func ipv4Octets(_ text: String) -> [Int]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                part == "0" || !part.hasPrefix("0"), let n = Int(part), n <= 255
            else { return nil }
            octets.append(n)
        }
        return octets
    }

    /// host:port or `scheme://[user:password@]host:port[/...]` with one of
    /// `schemes`; a bare host:port takes `defaultScheme`, as in croc.
    private nonisolated static func proxyError(
        _ text: String, defaultScheme: String, schemes: [String], message: String
    ) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard !value.contains(where: { $0.isWhitespace || $0.isNewline }) else { return message }
        var scheme = defaultScheme
        if let range = value.range(of: "://") {
            scheme = value[..<range.lowerBound].lowercased()
            value = String(value[range.upperBound...])
        }
        guard schemes.contains(scheme) else { return message }
        let authority = value.prefix { !"/?#".contains($0) }
        let hostPort = authority.split(separator: "@", omittingEmptySubsequences: false).last ?? ""
        let host: Substring
        let port: Substring
        if hostPort.hasPrefix("[") {
            guard let close = hostPort.firstIndex(of: "]") else { return message }
            host = hostPort[hostPort.index(after: hostPort.startIndex)..<close]
            let rest = hostPort[hostPort.index(after: close)...]
            guard rest.hasPrefix(":") else { return message }
            port = rest.dropFirst()
        } else {
            guard let colon = hostPort.lastIndex(of: ":") else { return message }
            host = hostPort[..<colon]
            port = hostPort[hostPort.index(after: colon)...]
            guard !host.contains(":") else { return message }
        }
        return host.isEmpty || !isPort(port) ? message : nil
    }
}
