//
//  SHA256PortableTests.swift
//  SpockGenTests
//
//  El SHA-256 propio (sin CryptoKit) debe coincidir byte a byte con el estándar: de él dependen
//  la caché, la detección de desfase y los ids del project.pbxproj. Vectores de FIPS 180-4.
//

import Testing
import Foundation
@testable import SpockGenCore

@Suite("SpockGenCore - SHA256Portable")
struct SHA256PortableTests {

    private func hex(_ s: String) -> String {
        SHA256Portable.hexString(Data(s.utf8))
    }

    @Test("Vectores de prueba conocidos")
    func testKnownVectors() {
        #expect(hex("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
                == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test("Un mensaje largo (> 1 bloque) con relleno en la frontera")
    func testMultiBlockAndPaddingBoundary() {
        // 55 y 56 bytes cruzan el límite del relleno (56 mod 64).
        #expect(hex(String(repeating: "a", count: 55))
                == "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318")
        #expect(hex(String(repeating: "a", count: 56))
                == "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a")
        #expect(SHA256Portable.hexString(Data(String(repeating: "a", count: 1_000_000).utf8))
                == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test("digest devuelve 32 bytes y es determinista")
    func testDigestShape() {
        let d = SHA256Portable.digest(Data("spock".utf8))
        #expect(d.count == 32)
        #expect(d == SHA256Portable.digest(Data("spock".utf8)))
    }
}
