import DBUS
import CryptoSwift
import Foundation

struct IETF1024DH: Sendable {
    static let p : [UInt8] = [255, 255, 255, 255, 255, 255, 255, 255, 201, 15, 218, 162, 33, 104, 194, 52, 196, 198, 98, 139, 128, 220, 28, 209, 41, 2, 78, 8, 138, 103, 204, 116, 2, 11, 190, 166, 59, 19, 155, 34, 81, 74, 8, 121, 142, 52, 4, 221, 239, 149, 25, 179, 205, 58, 67, 27, 48, 43, 10, 109, 242, 95, 20, 55, 79, 225, 53, 109, 109, 81, 194, 69, 228, 133, 181, 118, 98, 94, 126, 198, 244, 76, 66, 233, 166, 55, 237, 107, 11, 255, 92, 182, 244, 6, 183, 237, 238, 56, 107, 251, 90, 137, 159, 165, 174, 159, 36, 17, 124, 75, 31, 230, 73, 40, 102, 81, 236, 230, 83, 129, 255, 255, 255, 255, 255, 255, 255, 255]
    
    private let privateKey: [UInt8]
    let publicKey: [UInt8]
    
    init() {
        self.privateKey = AES.randomIV(20)
        
        self.publicKey = FastCrypto.powMod(
            base: [2],
            exp: privateKey,
            modulus: Self.p
        )
    }
    
    func aesKey(with otherPublicKey: [UInt8]) throws(SecSError) -> [UInt8] {
        guard isValidPublicKey(otherPublicKey, p: Self.p) else {
            throw .diffieHellmanFailed(Error.recievedPublicKeyInsecure)
        }
        
        let sharedSecret = FastCrypto.powMod(
            base: otherPublicKey,
            exp: privateKey,
            modulus: Self.p
        )
        
        
        do {
            return try HKDF(
                password: sharedSecret,
                salt: nil,
                info: nil,
                keyLength: 16,
                variant: .sha2(.sha256)
            ).calculate()
        } catch {
            throw .diffieHellmanFailed(error)
        }
    }
    
    private func isValidPublicKey(_ otherPublicKey: [UInt8], p: [UInt8]) -> Bool {
        // Normalize by removing leading zeros
        let pk = otherPublicKey.drop(while: { $0 == 0 })
        let mod = p.drop(while: { $0 == 0 })
        
        // 1. Must be greater than 1
        // pk > [1] check
        guard pk.count > 1 || (pk.first ?? 0 > 1) else {
            return false
        }
        
        // 2. Must be less than p - 1
        // Construct p - 1 (Assuming p is odd, so last byte is > 0)
        var pMinusOne = Array(mod)
        if let lastByte = pMinusOne.last {
            pMinusOne[pMinusOne.count - 1] = lastByte - 1
        }
        
        return isLessThan(Array(pk), pMinusOne)
    }
    
    private func isLessThan(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        if lhs.count != rhs.count {
            return lhs.count < rhs.count
        }
        for (l, r) in zip(lhs, rhs) {
            if l < r { return true }
            if l > r { return false }
        }
        return false
    }
    
    enum Error: Swift.Error {
        case recievedPublicKeyInsecure
    }
}
