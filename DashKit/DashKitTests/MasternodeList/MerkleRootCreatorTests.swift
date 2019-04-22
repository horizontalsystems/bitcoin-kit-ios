import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit
@testable import BitcoinCore

class MerkleRootCreatorTests: QuickSpec {

    override func spec() {
        let mockHasher = MockIDashHasher()

        var creator: MerkleRootCreator!

        beforeEach {
            creator = MerkleRootCreator(hasher: mockHasher)
        }

        afterEach {
            reset(mockHasher)
            creator = nil
        }

        describe("#create(hashes:)") {
            let hash1 = Data(repeating: 1, count: 2)
            let hash2 = Data(repeating: 2, count: 2)
            let hash3 = Data(repeating: 3, count: 2)

            it("calculates hash for empty list") {
                let merkle = creator.create(hashes: [])

                verifyNoMoreInteractions(mockHasher)
                expect(merkle).to(beNil())
            }

            it("calculates for 1 value") {
                let result = Data(repeating: 5, count: 4)
                stub(mockHasher) { mock in
                    when(mock.hash(data: equal(to: hash1 + hash1))).thenReturn(result)
                }
                let merkle = creator.create(hashes: [hash1])

                verify(mockHasher).hash(data: equal(to: hash1 + hash1))
                expect(merkle).to(equal(result))
            }

            it("calculates in 2 rounds") {
                let result = Data(repeating: 1, count: 4)

                let result1 = Data(repeating: 5, count: 4)
                let result2 = Data(repeating: 7, count: 4)

                stub(mockHasher) { mock in
                    when(mock.hash(data: equal(to: hash1 + hash2))).thenReturn(result1)
                    when(mock.hash(data: equal(to: hash3 + hash3))).thenReturn(result2)
                    when(mock.hash(data: equal(to: result1 + result2))).thenReturn(result)
                }

                let merkle = creator.create(hashes: [hash1, hash2, hash3])

                verify(mockHasher).hash(data: equal(to: hash1 + hash2))
                verify(mockHasher).hash(data: equal(to: hash3 + hash3))
                verify(mockHasher).hash(data: equal(to: result1 + result2))
                expect(merkle).to(equal(result))
            }
            it("calculates with real data and real creator!") {
                let realCreator = MerkleRootCreator(hasher: DoubleShaHasher())

                let hashes = [
                    "f170489c8719a85b783615f43bbe5c9c748ac5d7047b4db0f7d880639f543b37",
                    "c1906b0f275e88a25a4f51a1733b969b0bbfe6ce6b29e56085552682e210103a",
                    "846814313bd5a90c6f7772639b7b442f00e56a701da4f3da289168283bd9d385",
                    "f968e3016a409dc92cfcad590e28120ac0749fb7df0e09a771792ebde6ee3089",
                    "c2585f7e8f7237450533d59a8cdd3349bd410653a940cff5e897efa0ca692edc",
                    "46cbc796ee9fdbcb3837a40b7dd1501fe27d04e31d2227fa97d32e0d0a0e4a3e",
                    "8c4bdc67b917a744e1e8ca839d676a8cb71433d94d1d2b91cbe196146a4718eb",
                    "5621856c0fa94e361bfd603fdfe4f7832c63f52bcdfa23b5d711ac40fa010d6c",
                    "685d8108da6a141ada88dd89fa2046cf14e13f5902e10a285be9e6549de6e3c9",
                    "e69a9915da9d3e136b4facfe90179b618974a1e783f0d503948e5e737ff62310",
                    "aa7a2f8a4c49f1213595d0544d1447a9b9c760f4baa536f22dc7f74479c75f5d",
                    "df77d2d009e1e34db7dfdb6a7cf2c56ae352d35f41c6f806753cde2068b67dac",
                    "019918e3301654b92fe9147413e2a02627eeb896d7c1fda169fad065a95cc2cb",
                    "276ab1d198157413b67fdb8b74cea558a559967e8eb31fd452e99a04c43499ac",
                    "d0298ee4b268c51c350169f346fe703a0f5e0347055f6ec5b80b4514eb7711a6",
                ]
                let expectedMerkleRoot = "95a17f38e57519d7a5e1f4b16d8aa89f86578fb5442e881c09e27a67ca3a30b2"

                let merkle = realCreator.create(hashes: hashes.map { Data(hex: $0)! })

                expect(merkle).to(equal(Data(hex: expectedMerkleRoot)!))
            }

        }
    }

}
