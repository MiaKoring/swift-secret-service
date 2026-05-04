import DBUS
import CryptoSwift
import BigInt
import Foundation

struct IETF1024DH: Sendable {
    static let primeString = """
FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1
29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD
EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245
E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED
EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE65381
FFFFFFFF FFFFFFFF
"""
        .lowercased()
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    
    static let p = BigUInt(primeString, radix: 16)!
    static let g = BigUInt(2)
    
    private let privateKey: BigUInt
    let publicKey: [UInt8]
    
    init() {
        // Just using randomIV as RNG
        let hexPrivateKey = Data(AES.randomIV(128)).toHexString()
        
        // Should be safe to force unwrap, only returns nil on empty String
        let privateKey = BigUInt(hexPrivateKey, radix: 16)!
        self.privateKey = privateKey
        
        let publicKey = Self.g.power(privateKey, modulus: Self.p)
        self.publicKey = publicKey.serialize().byteArray
    }
    
    func aesKey(with otherPublicKey: [UInt8]) throws(SecSError) -> [UInt8] {
        let bobPublic = BigUInt(Data(otherPublicKey))
        
        guard isValidPublicKey(bobPublic, p: Self.p) else {
            throw .diffieHellmanFailed(Error.recievedPublicKeyInsecure)
        }
        
        let sharedSecret = bobPublic.power(privateKey, modulus: Self.p)
        
        do {
            return try HKDF(
                password: sharedSecret.serialize().byteArray,
                salt: nil,
                info: nil,
                keyLength: 16,
                variant: .sha2(.sha256)
            ).calculate()
        } catch {
            throw .diffieHellmanFailed(error)
        }
    }
    
    func isValidPublicKey(_ otherPublicKey: BigUInt, p: BigUInt) -> Bool {
        // 1. Must be greater than 1
        // 2. Must be less than p - 1
        let lowerBound = BigInt(1)
        let upperBound = p - 1
        
        return otherPublicKey > lowerBound && otherPublicKey < upperBound
    }
    
    enum Error: Swift.Error {
        case recievedPublicKeyInsecure
    }
}
