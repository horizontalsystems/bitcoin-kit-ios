import Foundation
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class DashKit: AbstractKit {

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            guard let delegate = delegate else {
                return
            }
            bitcoinCore.add(delegate: delegate)
        }
    }

    private let storage: IDashStorage

    private var masternodeSyncer: MasternodeListSyncer?

    public init(withWords words: [String], walletId: String, testMode: Bool = false, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork = testMode ? DashTestNet() : DashMainNet()

        let databaseFileName = "\(walletId)-dash-\(testMode ? "test" : "")"

        let storage = DashGrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "dash", removeScheme: true)
        let addressSelector = BitcoinAddressSelector()
        let apiFeeRateResource = testMode ? "DASH/testnet" : "DASH"

        let bitcoinCore = try BitcoinCoreBuilder()
                .set(network: network)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(feeRateApiResource: apiFeeRateResource)
                .set(walletId: walletId)
                .set(peerSize: 1)
                .set(storage: storage)
                .set(newWallet: true)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        extend(bitcoinCore: bitcoinCore)
    }

    func extend(bitcoinCore: BitcoinCore) {
        bitcoinCore.add(delegate: self)

        let dashMessageParsers = SetOfResponsibility()
                .append(element: TransactionLockMessageParser())
                .append(element: TransactionLockVoteMessageParser())
                .append(element: MasternodeListDiffMessageParser())

        let dashMessageSerializers = SetOfResponsibility()
                .append(element: GetMasternodeListDiffMessageSerializer())

        bitcoinCore.add(messageParsers: dashMessageParsers)
        bitcoinCore.add(messageSerializers: dashMessageSerializers)

        let hasher = MerkleRootHasher()
        let merkleBranch = MerkleBranch(hasher: hasher)

        let masternodeSerializer = MasternodeSerializer()
        let coinbaseTransactionSerializer = CoinbaseTransactionSerializer()
        let masternodeCbTxHasher = MasternodeCbTxHasher(coinbaseTransactionSerializer: coinbaseTransactionSerializer, hasher: hasher)
        let masternodeMerkleRootCreator = MerkleRootCreator(hasher: hasher)

        let masternodeListMerkleRootCalculator = MasternodeListMerkleRootCalculator(masternodeSerializer: masternodeSerializer, masternodeHasher: hasher, masternodeMerkleRootCreator: masternodeMerkleRootCreator)
        let masternodeListManager = MasternodeListManager(storage: storage, masternodeListMerkleRootCalculator: masternodeListMerkleRootCalculator, masternodeCbTxHasher: masternodeCbTxHasher, merkleBranch: merkleBranch)
        let masternodeSyncer = MasternodeListSyncer(peerGroup: bitcoinCore.peerGroup, peerTaskFactory: PeerTaskFactory(), masternodeListManager: masternodeListManager)
        self.masternodeSyncer = masternodeSyncer

        bitcoinCore.add(peerTaskHandler: masternodeSyncer)

        let instantSendFactory = InstantSendFactory()
        let instantTransactionManager = InstantTransactionManager(storage: storage, instantSendFactory: instantSendFactory, transactionSyncer: bitcoinCore.transactionSyncer)
        let instantSend = InstantSend(instantTransactionManager: instantTransactionManager)

        bitcoinCore.add(peerTaskHandler: instantSend)
        bitcoinCore.add(inventoryItemsHandler: instantSend)
    }

}

extension DashKit: BitcoinCoreDelegate {

    public func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        if (bitcoinCore.syncState == BitcoinCore.KitState.synced) {
            if let hash = lastBlockInfo.headerHash.reversedData {
                masternodeSyncer?.sync(blockHash: hash)
            }
        }

    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        if (state == BitcoinCore.KitState.synced) {
            if let blockInfo = bitcoinCore.lastBlockInfo, let hash = blockInfo.headerHash.reversedData {
                masternodeSyncer?.sync(blockHash: hash)
            }
        }
    }

}

public protocol DashKitDelegate: BitcoinCoreDelegate {}
