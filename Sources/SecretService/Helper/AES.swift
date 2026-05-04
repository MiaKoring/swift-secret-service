import CryptoSwift

extension AES {
    /// Decrypt a message
    static func decryptAES128PKCS7(
        encryptedData: [UInt8],
        iv: [UInt8],
        key: [UInt8]
    ) throws(SecSError) -> String {
        do {
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let decryptedBytes = try aes.decrypt(encryptedData)
            
            return String(bytes: decryptedBytes, encoding: .utf8) ?? ""
        } catch {
            throw .secretDecryptionFailed(error)
        }
    }
    
    /// Encrypt a message
    static func encryptAES128PKCS7(
        data: [UInt8],
        key: [UInt8]
    ) throws(SecSError) -> (encrypted: [UInt8], iv: [UInt8]) {
        do {
            let iv = AES.randomIV(16)
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let encrypted = try aes.encrypt(data)
            
            return (encrypted: encrypted, iv: iv)
        } catch {
            throw .secretEncryptionFailed(error)
        }
    }
}
