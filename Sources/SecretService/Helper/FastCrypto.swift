// CNIOBoringSSL is an internal module of swift-nio-ssl (not a public API).
// We use only stable BIGNUM primitives; review if swift-nio-ssl is upgraded.
import CNIOBoringSSL

struct FastCrypto {
    static func powMod(base: [UInt8], exp: [UInt8], modulus: [UInt8]) -> [UInt8]? {
        // Create a context for temporary variables used during calculation
        guard let ctx = CNIOBoringSSL_BN_CTX_new() else { return nil }
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
        
        // Validate BIGNUM allocations
        guard r != nil, b != nil, e != nil, m != nil else { return nil }
        
        // Convert byte arrays to BIGNUMs and verify success
        guard
            CNIOBoringSSL_BN_bin2bn(base, base.count, b) != nil,
            CNIOBoringSSL_BN_bin2bn(exp, exp.count, e) != nil,
            CNIOBoringSSL_BN_bin2bn(modulus, modulus.count, m) != nil
        else {
            return nil
        }
        
        // Optimized modular exponentiation: r = (b ^ e) % m (returns 1 on success)
        guard CNIOBoringSSL_BN_mod_exp_mont_consttime(r, b, e, m, ctx, nil) == 1 else {
            return nil
        }
        
        // Convert result back to bytes
        // Convert result back to bytes, left-padded to modulus length.
        var result = [UInt8](repeating: 0, count: modulus.count)
        let written = Int(CNIOBoringSSL_BN_num_bytes(r))
        result.withUnsafeMutableBufferPointer { buf in
            _ = CNIOBoringSSL_BN_bn2bin(r, buf.baseAddress!.advanced(by: modulus.count - written))
        }
        return result
    }
}
