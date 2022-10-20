//import Foundation
//import XCTest
//import Quick
//import Nimble
//import Cuckoo
//@testable import BitcoinCore
//
//class MerkleBranchTests: QuickSpec {
//
//    override func spec() {
//        let hasher = MerkleRootHasher() // Must use real sha256sha256 hasher
//
//        var merkleBranch: MerkleBranch!
//
//        beforeEach {
//            merkleBranch = MerkleBranch(hasher: hasher)
//        }
//
//        afterEach {
//            merkleBranch = nil
//        }
//
//        describe("#calculateMerkleRoot(txCount:, hashes:, flags:") {
//            let totalTransactions = 309
//            let hashes = [
//                Data(hex: "c6232bba11b7b068995d7e26f59fb46403b9307886f0dfbeae01b075200a43c2")!,
//                Data(hex: "7d3543eb3166350dd495812c3fb4fb0febc0f3a862910e29d2045bea08f1de67")!,
//                Data(hex: "16b57ae681df96435c030f799317eab55deaf4258d4de629f18dbeb8534a6fa5")!,
//                Data(hex: "175041d97932180ab5c280f809a46049f4149f2539db80223ac132898de33e8c")!,
//                Data(hex: "68fc70737ef1a48ca9891aff40b5ce4d8f8013e1cc2371f96b3e628aa68651a8")!,
//                Data(hex: "24ebddeb692ab96a6542c421fb505c7243c61b77125c703be89a25f4e9a163ed")!,
//                Data(hex: "05e2281bb57a5f4d1e86d40cbafbc6911138113859799d293e031d335de82088")!,
//                Data(hex: "0353c6fc93463d35e6ed4292d5b6709414727a443f1a829a1dab4acb6a54de68")!,
//                Data(hex: "feaa4182afe5e1542a6a27a6a933c7c80471636aa9477685dcd7aa4f18722a35")!,
//                Data(hex: "8c6e45e3341a18c53b2f40ca31eb4f59ff43240ad6a9221743cf856cb015bfda")!
//            ]
//            let flags: [UInt8] = [223, 22, 0]
//
//            it("hashes value") {
//                let data = try! merkleBranch.calculateMerkleRoot(txCount: totalTransactions, hashes: hashes, flags: flags)
//                expect(data.matchedHashes.count).to(equal(1))
//                expect(data.matchedHashes[0]).to(equal(hashes[3]))
//            }
//
//            it("unnecessaryBits error") {
//                do {
//                    _ = try merkleBranch.calculateMerkleRoot(txCount: totalTransactions, hashes: hashes, flags: [223, 22, 0, 1])
//                    fail("Must have exception")
//                } catch let error as MerkleBlockValidator.ValidationError {
//                    expect(error).to(equal(MerkleBlockValidator.DashKitErrors.MasternodeListValidation.unnecessaryBits) )
//                } catch {
//                    XCTFail("Unknown Exception")
//                }
//            }
//
//            it("notEnoughHashes error") {
//                do {
//                    _ = try merkleBranch.calculateMerkleRoot(txCount: totalTransactions, hashes: hashes, flags: [223, 22, 5])
//                    fail("Must have exception")
//                } catch let error as MerkleBlockValidator.ValidationError {
//                    expect(error).to(equal(MerkleBlockValidator.DashKitErrors.MasternodeListValidation.notEnoughHashes) )
//                } catch {
//                    XCTFail("Unknown Exception")
//                }
//            }
//
//            it("notEnoughBits error") {
//                do {
//                    _ = try merkleBranch.calculateMerkleRoot(txCount: totalTransactions, hashes: hashes, flags: [223, 22])
//                    fail("Must have exception")
//                } catch let error as MerkleBlockValidator.ValidationError {
//                    expect(error).to(equal(MerkleBlockValidator.DashKitErrors.MasternodeListValidation.notEnoughBits) )
//                } catch {
//                    XCTFail("Unknown Exception")
//                }
//            }
//        }
//    }
//
//}
