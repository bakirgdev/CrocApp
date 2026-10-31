#if os(macOS)
import Darwin
import Foundation

/// This Mac's addresses on its active network interfaces: what another device
/// types to reach a relay running here.
enum LocalAddresses {
    struct Address: Equatable {
        /// The interface name, such as `en0`.
        let interface: String
        let ip: String
        let isIPv6: Bool
    }

    /// IPv4 and IPv6 addresses of interfaces that are up and running, never
    /// loopback. IPv6 link-local (`fe80::`) is left out: it only works with an
    /// interface scope (`fe80::1%en0`) that a relay setting cannot hold. IPv4
    /// comes first, each version in the system's interface order.
    static func current() -> [Address] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        var found: [Address] = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0,
                let sa = entry.pointee.ifa_addr
            else { continue }
            let family = Int32(sa.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard
                getnameinfo(
                    sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
                    NI_NUMERICHOST) == 0
            else { continue }
            let ip = String(
                decoding: host.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
            if family == AF_INET6, ip.lowercased().hasPrefix("fe80") { continue }
            found.append(
                Address(
                    interface: String(cString: entry.pointee.ifa_name), ip: ip,
                    isIPv6: family == AF_INET6))
        }
        return found.filter { !$0.isIPv6 } + found.filter(\.isIPv6)
    }

    /// `host:port` as another device's relay setting takes it; IPv6 in brackets.
    static func relayAddress(_ address: Address, port: Int) -> String {
        address.isIPv6 ? "[\(address.ip)]:\(port)" : "\(address.ip):\(port)"
    }
}
#endif
