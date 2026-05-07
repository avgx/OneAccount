import CryptoKit
import Foundation

private let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

private func base32Decode(_ string: String) -> Data? {
    let cleaned = string.uppercased().filter { $0 != " " && $0 != "=" }
    var bits = 0
    var value = 0
    var out: [UInt8] = []
    for c in cleaned {
        guard let idx = base32Alphabet.firstIndex(of: c) else { return nil }
        value = (value << 5) | idx
        bits += 5
        if bits >= 8 {
            bits -= 8
            out.append(UInt8((value >> bits) & 0xff))
        }
    }
    return Data(out)
}

/// RFC 6238 TOTP (HMAC-SHA1, 30 s, 6 digits).
func totpCode(secretBase32: String, date: Date = .init(), period: TimeInterval = 30, digits: Int = 6) -> String? {
    guard let secret = base32Decode(secretBase32), !secret.isEmpty else { return nil }
    let counter = UInt64(date.timeIntervalSince1970 / period)
    var ctr = counter.bigEndian
    let counterBytes = Data(bytes: &ctr, count: 8)
    let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterBytes, using: SymmetricKey(data: secret))
    let hash = Array(mac)
    let offset = Int(hash[hash.count - 1] & 0x0f)
    guard offset + 3 < hash.count else { return nil }
    let bin = (UInt32(hash[offset] & 0x7f) << 24)
        | (UInt32(hash[offset + 1]) << 16)
        | (UInt32(hash[offset + 2]) << 8)
        | UInt32(hash[offset + 3])
    let mod = UInt32(pow(10, Float(digits)))
    let code = bin % mod
    return String(format: "%0*u", digits, code)
}
