import Foundation
@testable import DashKit
@testable import BitcoinCore

class DashTestData {
    static let zeroHash = Data(repeating: 0, count: 32)

    static func masternode(proRegTxHash: Data, confirmedHash: Data = Data(), isValid: Bool = true) -> Masternode {
        return Masternode(proRegTxHash: proRegTxHash, confirmedHash: confirmedHash, confirmedHashWithProRegTxHash: Data(), ipAddress: Data(), port: 0, pubKeyOperator: Data(), keyIDVoting: Data(), isValid: isValid)
    }

    static func coinbaseTransaction(transaction: FullTransaction = DashTestData.transaction, size: UInt32 = 0, merkleRootMNList: Data = Data()) -> CoinbaseTransaction {
        return CoinbaseTransaction(transaction: transaction, coinbaseTransactionSize: Data(from: size), version: 0, height: 0, merkleRootMNList: merkleRootMNList)
    }

    static func masternodeListDiffMessage(baseBlockHash: Data = zeroHash, blockHash: Data,
                                          totalTransactions: UInt32 = 0, merkleHashesCount: UInt32 = 0, cbTx: CoinbaseTransaction = coinbaseTransaction(),
                                          deletedMNsCount: UInt32 = 0, deletedMNs: [Data] = [],
                                          mnListCount: UInt32 = 0, mnList: [Masternode] = []) -> MasternodeListDiffMessage {

        return MasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash,
                totalTransactions: totalTransactions, merkleHashesCount: merkleHashesCount, merkleHashes: [],
                merkleFlagsCount: 0, merkleFlags: Data(), cbTx: cbTx, deletedMNsCount: deletedMNsCount,
                deletedMNs: deletedMNs, mnListCount: mnListCount, mnList: mnList)
    }

    static func transactionLockVote(txHash: Data = Data(), inputTxHash: Data = Data(), quorumModifierHash: Data = Data(), masternodeProTxHash: Data = Data(), vchMasternodeSignature: Data = Data(), hash: Data = Data()) -> TransactionLockVoteMessage {
        return TransactionLockVoteMessage(txHash: txHash, outpoint: Outpoint(txHash: inputTxHash, vout: 0),
                outpointMasternode: Outpoint(txHash: txHash, vout: 0), quorumModifierHash: quorumModifierHash,
                masternodeProTxHash: masternodeProTxHash, vchMasternodeSignature: vchMasternodeSignature, hash: hash)
    }

    static var transaction: FullTransaction {
        let transaction = Transaction(version: 1, lockTime: 0)

        for _ in 0..<32 { transaction.dataHash.append(UInt8.random(in: 0...255)) }

        let inputs = [
            Input(
                    withPreviousOutputTxHash: Data(hex: "a6d1ce683f38a84cfd88a9d48b0ba2d7a8def00f8517e3da02c86fce6c7863d7")!, previousOutputIndex: 0,
                    script: Data(hex: "4730440220302e597d74aebcb0bf7f372be156252017af190bd586466104b079fba4b7efa7022037ebbf84e096ef3d966123a93a83586012353c1d2c11c967d21acf1c94c45df001210347235e12207d21b6093d9fd93a0df4d589a0d44252b98b2e934a8da5ab1d1654")!,
                    sequence: 4294967295
            )
        ]
        let outputs = [
            Output(withValue: 10792000, index: 0 , lockingScript: Data(hex: "76a9141ec865abcb88cec71c484d4dadec3d7dc0271a7b88ac")!, type: .p2pkh, keyHash: Data()),
            Output(withValue: 0, index: 0, lockingScript: Data(hex: "6a4c500000b919000189658af37cd16dbd16e4186ea13c5d8e1f40c5b5a0958326067dd923b8fc8f0767f62eb9a7fd57df4f3e775a96ca5b5eabf5057dff98997a3bbd011366703f5e45075f397f7f3c8465da")!, type: .p2pk, keyHash: Data()),
        ]

        return FullTransaction(header: transaction, inputs: inputs, outputs: outputs)
    }

    static func unspentOutput(output: Output) -> UnspentOutput {
        return UnspentOutput(output: output, publicKey: PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()), transaction: Transaction(), blockHeight: nil)
    }

}
