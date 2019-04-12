import Foundation
@testable import HSBitcoinKit

class DashTestData {
    static let zeroHash = Data(repeating: 0, count: 32)

    static func masternode(proRegTxHash: Data, confirmedHash: Data = Data(), isValid: Bool = true) -> Masternode {
        return Masternode(proRegTxHash: proRegTxHash, confirmedHash: confirmedHash, confirmedHashWithProRegTxHash: Data(), ipAddress: Data(), port: 0, pubKeyOperator: Data(), keyIDVoting: Data(), isValid: isValid)
    }

    static func coinbaseTransaction(transaction: FullTransaction = TestData.p2pkhTransaction, size: UInt32 = 0, merkleRootMNList: Data = Data()) -> CoinbaseTransaction {
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

    static func transactionLockVote(txHash: Data, inputTxHash: Data = Data()) -> TransactionLockVoteMessage {
        return TransactionLockVoteMessage(txHash: txHash, outpoint: Outpoint(txHash: inputTxHash, vout: 0),
                outpointMasternode: Outpoint(txHash: txHash, vout: 0), quorumModifierHash: Data(),
                masternodeProTxHash: Data(), vchMasternodeSignature: Data(), hash: Data())
    }

}
