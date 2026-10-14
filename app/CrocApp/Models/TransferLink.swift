import Foundation

/// R22: the one grammar for everything that can start a receive (QR scan,
/// paste, URL open, App Intents). Parsing only classifies; nothing here
/// connects, and the key of a stored link never leaves the URL.
enum TransferLink: Equatable {
    case code(String)
    /// A stored-transfer link. The Go engine checks id and key lengths; this
    /// validates the shape and, per R12e, the scheme (ATS does not cover Go).
    case stored(URL)

    static let webHost = "crocapp.dev"
    static let browserReceiveHost = "getcroc.com"
    static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1"]

    static func parse(_ raw: String) -> TransferLink? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard text.contains("://") else { return validCode(text).map(TransferLink.code) }
        // 0.9.9 QR payload. Everything after the prefix is the code, so it is
        // not run through URLComponents.
        if text.hasPrefix("croc://") {
            return validCode(String(text.dropFirst("croc://".count))).map(TransferLink.code)
        }
        guard let parts = URLComponents(string: text), let scheme = parts.scheme?.lowercased(),
            parts.user == nil, parts.password == nil
        else { return nil }
        // URLComponents keeps the brackets of an IPv6 literal.
        let host = (parts.host?.lowercased() ?? "").trimmingCharacters(in: ["[", "]"])
        switch scheme {
        case "crocapp":
            guard host == "receive" else { return nil }
            return validCode(parts.queryItems?.first { $0.name == "code" }?.value)
                .map(TransferLink.code)
        case "https", "http":
            if let stored = storedLink(parts, text: text, scheme: scheme, host: host) {
                return .stored(stored)
            }
            guard scheme == "https" else { return nil }
            let path = parts.path
            if host == webHost, path == "/r/" || path == "/r" {
                return validCode(parts.fragment).map(TransferLink.code)
            }
            if host == browserReceiveHost, path.isEmpty || path == "/" {
                return validCode(parts.queryItems?.first { $0.name == "code" }?.value)
                    .map(TransferLink.code)
            }
            return nil
        default:
            return nil
        }
    }

    /// What the waiting screen's QR and Share encode (R23). The code sits in
    /// the fragment, which browsers never send to a server.
    static func webURL(forCode code: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = webHost
        parts.path = "/r/"
        parts.fragment = code
        return parts.url
    }

    private static func validCode(_ candidate: String?) -> String? {
        guard let candidate, candidate.count >= EngineConstraints.minCodeLength,
            !candidate.contains(where: { $0.isWhitespace || $0.isNewline })
        else { return nil }
        return candidate
    }

    private static func storedLink(
        _ parts: URLComponents, text: String, scheme: String, host: String
    ) -> URL? {
        guard !host.isEmpty, parts.query == nil else { return nil }
        guard scheme == "https" || loopbackHosts.contains(host) else { return nil }
        let segments = parts.percentEncodedPath.trimmingCharacters(in: ["/"])
            .split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 2, segments[0] == "s", !segments[1].isEmpty else { return nil }
        guard let fragment = parts.fragment, fragment.hasPrefix("v1."),
            fragment.count > "v1.".count
        else { return nil }
        return URL(string: text)
    }
}
