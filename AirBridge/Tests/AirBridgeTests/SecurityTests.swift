import XCTest
import CryptoKit
@testable import AirBridgeCore

final class SecurityTests: XCTestCase {
    func testPINValidation() {
        let security = SecurityManager()
        let pin = security.currentPIN
        XCTAssertEqual(pin.count, 4)

        XCTAssertTrue(security.validatePIN(pin))
        XCTAssertFalse(security.validatePIN("0000_wrong"))
        XCTAssertFalse(security.validatePIN("99999"))

        let newPIN = security.generateNewPIN()
        XCTAssertEqual(newPIN.count, 4)
        XCTAssertTrue(security.validatePIN(newPIN))
    }

    func testDeviceRegistrationAndTokenAuth() {
        let security = SecurityManager()
        let pin = security.currentPIN

        // Failed registration with wrong PIN
        let failResult = security.registerDevice(
            deviceName: "Attacker",
            deviceType: "Unknown",
            ipAddress: "10.0.0.99",
            pin: "1234" == pin ? "0000" : "1234"
        )
        XCTAssertFalse(failResult.authorized)
        XCTAssertNil(failResult.session)

        // Successful registration
        let successResult = security.registerDevice(
            deviceName: "My-Windows-PC",
            deviceType: "Windows",
            ipAddress: "192.168.1.100",
            pin: pin
        )
        XCTAssertTrue(successResult.authorized)
        XCTAssertNotNil(successResult.session)

        guard let token = successResult.session?.token else {
            XCTFail("Missing token")
            return
        }

        XCTAssertTrue(security.authorizeToken(token))
        XCTAssertFalse(security.authorizeToken("fake-random-token"))

        // Revoke token
        security.revokeToken(token)
        XCTAssertFalse(security.authorizeToken(token))
    }

    func testAESGCMEncryptionRoundtrip() throws {
        let key = SymmetricKey(size: .bits256)
        let message = "Confidential cross-platform clipboard payload"
        let data = Data(message.utf8)

        let encrypted = try SecurityManager.encrypt(data: data, key: key)
        XCTAssertNotEqual(encrypted, data)

        let decrypted = try SecurityManager.decrypt(combinedData: encrypted, key: key)
        XCTAssertEqual(decrypted, data)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), message)
    }
}
