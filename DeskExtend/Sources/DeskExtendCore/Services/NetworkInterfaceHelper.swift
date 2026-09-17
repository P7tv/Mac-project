import Foundation

public enum NetworkType: String, Sendable {
    case wifi = "Wi-Fi"
    case ethernet = "Direct Cable / Ethernet"
    case linkLocal = "Direct Link (169.254.x.x)"
    case localhost = "Localhost"
}

public struct NetworkAddress: Identifiable, Sendable {
    public var id: String { ip }
    public let name: String
    public let ip: String
    public let type: NetworkType
    public let port: UInt16

    public var urlString: String {
        "http://\(ip):\(port)"
    }
}

public struct NetworkInterfaceHelper {
    public static func getLocalIPAddresses(port: UInt16 = 8080) -> [NetworkAddress] {
        var addresses: [NetworkAddress] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return [NetworkAddress(name: "Localhost", ip: "127.0.0.1", type: .localhost, port: port)]
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee

            // Check if interface is UP, RUNNING, and not LOOPBACK (unless nothing else exists)
            guard (flags & (IFF_UP | IFF_RUNNING)) != 0 else { continue }
            guard addr.sa_family == UInt8(AF_INET) else { continue } // IPv4 only for clarity

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                ptr.pointee.ifa_addr,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                let ip = withUnsafePointer(to: &hostname[0]) { String(cString: $0) }
                let ifName = String(cString: ptr.pointee.ifa_name)

                if ip == "127.0.0.1" { continue }

                let type: NetworkType
                if ip.hasPrefix("169.254.") {
                    type = .linkLocal
                } else if ifName.hasPrefix("en0") {
                    type = .wifi
                } else {
                    type = .ethernet
                }

                addresses.append(NetworkAddress(
                    name: "\(type.rawValue) (\(ifName))",
                    ip: ip,
                    type: type,
                    port: port
                ))
            }
        }

        // Always include localhost as fallback
        addresses.append(NetworkAddress(name: "Localhost", ip: "127.0.0.1", type: .localhost, port: port))

        // Sort so Wi-Fi and direct cable are at the top
        return addresses.sorted { (a, b) -> Bool in
            if a.type == .wifi { return true }
            if b.type == .wifi { return false }
            if a.type == .ethernet { return true }
            if b.type == .ethernet { return false }
            return a.ip < b.ip
        }
    }
}
