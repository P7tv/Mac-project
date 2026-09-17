import Foundation
import CryptoKit

public final class SecurityManager: @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var currentPIN: String
    private var sessions: [UUID: DeviceSession] = [:]
    private var authorizedTokens: Set<String> = []
    private var tokenToSessionID: [String: UUID] = [:]

    public init() {
        self.currentPIN = String(format: "%04d", Int.random(in: 1000...9999))
    }

    public func generateNewPIN() -> String {
        lock.lock()
        defer { lock.unlock() }
        let pin = String(format: "%04d", Int.random(in: 1000...9999))
        self.currentPIN = pin
        return pin
    }

    public func validatePIN(_ input: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return constantTimeCompare(trimmed, currentPIN)
    }

    public func registerDevice(
        deviceName: String,
        deviceType: String,
        ipAddress: String,
        pin: String
    ) -> (authorized: Bool, session: DeviceSession?) {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard constantTimeCompare(trimmed, currentPIN) else {
            return (false, nil)
        }

        let session = DeviceSession(
            deviceName: deviceName,
            deviceType: deviceType,
            ipAddress: ipAddress,
            isAuthorized: true
        )

        sessions[session.id] = session
        authorizedTokens.insert(session.token)
        tokenToSessionID[session.token] = session.id

        return (true, session)
    }

    public func authorizeToken(_ token: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return authorizedTokens.contains(token)
    }

    public func revokeToken(_ token: String) {
        lock.lock()
        defer { lock.unlock() }
        authorizedTokens.remove(token)
        if let sessionID = tokenToSessionID.removeValue(forKey: token) {
            sessions.removeValue(forKey: sessionID)
        }
    }

    public func activeSessionsList() -> [DeviceSession] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sessions.values)
    }

    private func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }

    // AES-GCM local encryption helpers
    public static func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "SecurityManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
        }
        return combined
    }

    public static func decrypt(combinedData: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
