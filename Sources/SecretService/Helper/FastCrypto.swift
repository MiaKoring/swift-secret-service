import CNIOBoringSSL

struct FastCrypto {
    static func powMod(base: [UInt8], exp: [UInt8], modulus: [UInt8]) -> [UInt8] {
        // Create a context for temporary variables used during calculation
        let ctx = CNIOBoringSSL_BN_CTX_new()
        defer { CNIOBoringSSL_BN_CTX_free(ctx) }
        
        let r = CNIOBoringSSL_BN_new()
        let b = CNIOBoringSSL_BN_new()
        let e = CNIOBoringSSL_BN_new()
        let m = CNIOBoringSSL_BN_new()
        
        defer {
            CNIOBoringSSL_BN_free(r)
            CNIOBoringSSL_BN_free(b)
            CNIOBoringSSL_BN_free(e)
            CNIOBoringSSL_BN_free(m)
        }
        
        // Convert byte arrays to BIGNUMs
        CNIOBoringSSL_BN_bin2bn(base, base.count, b)
        CNIOBoringSSL_BN_bin2bn(exp, exp.count, e)
        CNIOBoringSSL_BN_bin2bn(modulus, modulus.count, m)
        
        // Optimized modular exponentiation: r = (b ^ e) % m
        CNIOBoringSSL_BN_mod_exp(r, b, e, m, ctx)
        
        // Convert result back to bytes
        let count = (CNIOBoringSSL_BN_num_bits(r) + 7) / 8
        var result = [UInt8](repeating: 0, count: Int(count))
        CNIOBoringSSL_BN_bn2bin(r, &result)
        
        return result
    }
}
