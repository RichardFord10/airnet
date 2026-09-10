import Foundation
import Security

public enum KeychainIdentity {
    public static func loadOrCreate(service: String = "org.airnet.identity") throws -> Identity {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: "ed25519-v1"]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data else { throw AirnetError.keychain(errSecDecode) }
            return try Identity(rawRepresentation: data)
        }
        // Never silently replace an identity when the Keychain is locked or inaccessible.
        guard status == errSecItemNotFound else { throw AirnetError.keychain(status) }
        let identity = Identity()
        var insert = query
        insert[kSecValueData as String] = identity.rawRepresentation
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let saved = SecItemAdd(insert as CFDictionary, nil)
        if saved == errSecDuplicateItem { return try loadOrCreate(service: service) }
        guard saved == errSecSuccess else { throw AirnetError.keychain(saved) }
        return identity
    }
}
