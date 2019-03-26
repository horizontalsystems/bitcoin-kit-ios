import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import HSBitcoinKit

class MerkleRootHasherTests: QuickSpec {

    override func spec() {
        var hasher: MerkleRootHasher!

        beforeEach {
            hasher = MerkleRootHasher()
        }

        afterEach {
            hasher = nil
        }

        let hash = Data(hex: "01020304")!
        let sha256sha256 = Data(hex: "8de472e2399610baaa7f84840547cd409434e31f5d3bd71e4d947f283874f9c0")!

        describe("#hash") {

            it("hashes value") {
                let sha256 = hasher.hash(data: hash)
                expect(sha256).to(equal(sha256sha256))
            }
        }

        describe("#hash(left:right:)") {
            it("hashes concated data") {
                let data1 = Data(hex: "0102")!
                let data2 = Data(hex: "0304")!

                let sha256 = hasher.hash(left: data1, right: data2)
                expect(sha256).to(equal(Data(sha256sha256)))
            }
        }
    }
}
