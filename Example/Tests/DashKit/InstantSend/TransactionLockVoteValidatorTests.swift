import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit

class TransactionLockVoteValidatorTests: QuickSpec {


    override func spec() {
        let mockStorage = MockIDashStorage()
        let mockHasher = MockIDashHasher()
        var validator: TransactionLockVoteValidator!

        let pubKeyOperator = Data(hex: "141d89e211c93bee9f4cb26e4bd1fa530798dc1cc27e545c0e096aec9d913ba2cae572b339aaab612a0bb2f60dd71ceb")!
        let signature = Data(hex: "0cace6526d0f27e7b969700877796fce5d0a441281d952197eee051385b22c7b9010981cecd19986fc185aa65ac8d82b0c8ba2e0f2cab703f4cd9c3079cc53b78d947bc6d8cc6b05f87fcffea778a05df53f0340d6d0c4f9de182016df8452fe")!
        let wrongSignature = Data(hex: "1cace6526d0f27e7b969700877796fce5d0a441281d952197eee051385b22c7b9010981cecd19986fc185aa65ac8d82b0c8ba2e0f2cab703f4cd9c3079cc53b78d947bc6d8cc6b05f87fcffea778a05df53f0340d6d0c4f9de182016df8452fe")!
        let hash = Data(hex: "764ffc3658c9e40ebed871d60eb92add480d437973d59038c37d6e55dda35461")!

        let masternode1 = Data(hex: "6c9d3670dcb8cdf88c61f911c4bf827465569972499d5d618053f972d80f9c4c")!
        let masternode3 = Data(hex: "55ee57cd126dc8e7ddc3c2672c6b1be2a47681f2dff01d8af14e49a5a35630c7")!

        let masternodes = [
            Masternode(proRegTxHash: masternode1, confirmedHash: Data(hex: "98a6b25a20fdebde7fec66abf24e8e541bb5d79f3284be0eca506c0400000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "35aed0ab243107f247a77fa73b9995d66d024610f175a87f8029a7adb7e60aaa")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: Data(),
                    keyIDVoting: Data(), isValid: true),
            Masternode(proRegTxHash: Data(hex: "d8101a45ed4d7a7e8e3e379995f8dcd2d5d53f72298d5b170758a69a64f42674")!, confirmedHash: Data(hex: "cab10f1838d26793b60bf594f8f320b1ea3d8e10fc64dd809d11051900000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "5f659ffee4637630bf4cb81ebcabadabb8483acad8ea8727f0724fa9cf5a3cb1")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: Data(),
                    keyIDVoting: Data(), isValid: true),
            Masternode(proRegTxHash: masternode3, confirmedHash: Data(hex: "cf49bf87be88ff1ce988d3473ba4b44bfc9325d12efa58bab80e900f00000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "81e4598cf34d177c426a90cce2d6e9db6f1f9258f7ab215cac93c90afaa621c9")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: pubKeyOperator,
                    keyIDVoting: Data(), isValid: true),
        ]
//        let scores = [
//            Data(hex: "bb72dd43e55a7e38864112a835bc52dab87a9c0e8c4c7feb2fcf53acfc015fc5")!,
//            Data(hex: "cf18a3a9f3504bb334744658f41d660088ae465db98165a554748e38b7577d7d")!,
//            Data(hex: "3f07de79bd32824b684388eaa35c06b8ad49df3990bb3bd82293f820e04de1d3")!,
//        ]
        let quorumModifierHash = Data(hex: "3b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000")!

        beforeEach {
            validator = TransactionLockVoteValidator(storage: mockStorage, hasher: mockHasher, totalSignatures: 2)
        }

        afterEach {
            reset(mockStorage)
            validator = nil
        }

        describe("#validate(lockVote:)") {
            beforeEach {
                stub(mockStorage) { mock in
                    when(mock.masternodes.get).thenReturn(masternodes)
                }
                stub(mockHasher) { mock in
                    when(mock.hash(data: equal(to: masternodes[0].confirmedHashWithProRegTxHash + quorumModifierHash))).thenReturn(Data(hex: "0101")!)
                    when(mock.hash(data: equal(to: masternodes[1].confirmedHashWithProRegTxHash + quorumModifierHash))).thenReturn(Data(hex: "0202")!)
                    when(mock.hash(data: equal(to: masternodes[2].confirmedHashWithProRegTxHash + quorumModifierHash))).thenReturn(Data(hex: "0303")!)
                }
            }
            it("throws masternodeNotFound") {
                do {
                    let lockVote = DashTestData.transactionLockVote(quorumModifierHash: quorumModifierHash, masternodeProTxHash: Data(hex: "000001")!, vchMasternodeSignature: signature, hash: hash)
                    try validator.validate(lockVote: lockVote)
                    XCTFail("Must throw error .masternodeNotFound ")
                } catch let error as DashKitErrors.LockVoteValidation {
                    expect(error).to(equal(DashKitErrors.LockVoteValidation.masternodeNotFound))
                } catch {
                    XCTFail("Wrong error!")
                }
            }
            context("found masternode") {
                it("throws masternodeNotInTop") {
                    do {
                        let lockVote = DashTestData.transactionLockVote(quorumModifierHash: quorumModifierHash, masternodeProTxHash: masternode1, vchMasternodeSignature: signature, hash: hash)
                        try validator.validate(lockVote: lockVote)
                        XCTFail("Must throw error .masternodeNotInTop ")
                    } catch let error as DashKitErrors.LockVoteValidation {
                        expect(error).to(equal(DashKitErrors.LockVoteValidation.masternodeNotInTop))
                    } catch {
                        XCTFail("Wrong error!")
                    }
                }
                context("found right masternode") {
                    it("throws signatureNotValid") {
                        do {
                            let lockVote = DashTestData.transactionLockVote(quorumModifierHash: quorumModifierHash, masternodeProTxHash: masternode3, vchMasternodeSignature: wrongSignature, hash: hash)
                            try validator.validate(lockVote: lockVote)
                            XCTFail("Must throw error .signatureNotValid ")
                        } catch let error as DashKitErrors.LockVoteValidation {
                            expect(error).to(equal(DashKitErrors.LockVoteValidation.signatureNotValid))
                        } catch {
                            XCTFail("Wrong error!")
                        }
                    }
                    it("success validated") {
                        do {
                            let lockVote = DashTestData.transactionLockVote(quorumModifierHash: quorumModifierHash, masternodeProTxHash: masternode3, vchMasternodeSignature: signature, hash: hash)
                            try validator.validate(lockVote: lockVote)
                        } catch {
                            XCTFail("Wrong error!")
                        }
                    }
                }
            }
        }

    }

}
