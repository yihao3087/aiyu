import UIKit
import CommonCrypto

struct DeviceIdProvider {
    private static let appSalt = "wP6vR9tN4kZ3sB8qF2xL1dH7"

    static func deviceHash() -> String {
        let uuid = KeychainHelper.loadOrCreateUUID()
        let brand = UIDevice.current.systemName
        let model = UIDevice.current.model
        let raw = "\(uuid)|\(brand)|\(model)|\(appSalt)"
        return raw.sha256()
    }
}

private extension String {
    func sha256() -> String {
        guard let data = data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
