import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit

class TransactionLockVoteValidatorTests: QuickSpec {


    override func spec() {
        let mockStorage = MockIDashStorage()
        var validator: TransactionLockVoteValidator!
        let masternodes = [
            Masternode(proRegTxHash: Data(hex: "6c9d3670dcb8cdf88c61f911c4bf827465569972499d5d618053f972d80f9c4c")!, confirmedHash: Data(hex: "98a6b25a20fdebde7fec66abf24e8e541bb5d79f3284be0eca506c0400000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "35aed0ab243107f247a77fa73b9995d66d024610f175a87f8029a7adb7e60aaa")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: Data(),
                    keyIDVoting: Data(), isValid: true),
            Masternode(proRegTxHash: Data(hex: "d8101a45ed4d7a7e8e3e379995f8dcd2d5d53f72298d5b170758a69a64f42674")!, confirmedHash: Data(hex: "cab10f1838d26793b60bf594f8f320b1ea3d8e10fc64dd809d11051900000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "5f659ffee4637630bf4cb81ebcabadabb8483acad8ea8727f0724fa9cf5a3cb1")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: Data(),
                    keyIDVoting: Data(), isValid: true),
            Masternode(proRegTxHash: Data(hex: "55ee57cd126dc8e7ddc3c2672c6b1be2a47681f2dff01d8af14e49a5a35630c7")!, confirmedHash: Data(hex: "cf49bf87be88ff1ce988d3473ba4b44bfc9325d12efa58bab80e900f00000000")!,
                    confirmedHashWithProRegTxHash: Data(hex: "81e4598cf34d177c426a90cce2d6e9db6f1f9258f7ab215cac93c90afaa621c9")!, ipAddress: Data(),
                    port: 0, pubKeyOperator: Data(),
                    keyIDVoting: Data(), isValid: true),
        ]
//        let scores = [
//            Data(hex: "bb72dd43e55a7e38864112a835bc52dab87a9c0e8c4c7feb2fcf53acfc015fc5")!,
//            Data(hex: "cf18a3a9f3504bb334744658f41d660088ae465db98165a554748e38b7577d7d")!,
//            Data(hex: "3f07de79bd32824b684388eaa35c06b8ad49df3990bb3bd82293f820e04de1d3")!,
//        ]
        stub(mockStorage) { mock in
            when(mock.masternodes.get).thenReturn(masternodes)
        }


        beforeEach {
            validator = TransactionLockVoteValidator(storage: mockStorage, hasher: SingleHasher())
        }

        afterEach {
            reset(mockStorage)
            validator = nil
        }

        describe("#validate(lockVote:)") {

            it("") {
                try? validator.validate(quorumModifierHash: Data(hex: "3b3f11ecb0b38814dca71cd93e620c808ffe2dadbfcca1b446a8590900000000")!, masternodeProTxHash: Data(hex: "d8101a45ed4d7a7e8e3e379995f8dcd2d5d53f72298d5b170758a69a64f42674")!)
            }
        }

    }

}
