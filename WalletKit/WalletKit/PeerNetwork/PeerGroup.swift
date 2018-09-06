import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    struct PendingBlock {
        let header: BlockHeader
        var pendingTransactionHashes: [Data]
        var transactions: [Transaction]
    }

    enum Status {
        case connected, disconnected
    }

    var statusSubject: PublishSubject<Status> = PublishSubject()
    weak var delegate: PeerGroupDelegate?

    private let realmFactory: RealmFactory

    private let peer: Peer

    private let validator = MerkleBlockValidator()
    private var pendingBlocks: [PendingBlock] = []

    init(realmFactory: RealmFactory, network: NetworkProtocol) {
        self.realmFactory = realmFactory
        self.peer = Peer(network: network)

        peer.delegate = self
    }

    func connect() {
        peer.connect()
    }

    func requestHeaders(headerHashes: [Data]) {
        peer.sendGetHeadersMessage(headerHashes: headerHashes)
    }

    func requestMerkleBlocks(headerHashes: [Data]) {
        peer.requestMerkleBlocks(headerHashes: headerHashes)
    }

    func relay(transaction: Transaction) {
        peer.relay(transaction: transaction)
    }

    func addPublicKeyFilter(pubKey: PublicKey) {
        peer.addFilter(filter: pubKey.keyHash)
        peer.addFilter(filter: pubKey.raw!)
    }

}

extension PeerGroup: PeerDelegate {

    func peerDidConnect(_ peer: Peer) {
        let realm = realmFactory.realm
        let pubKeys = realm.objects(PublicKey.self)
        let filters = Array(pubKeys.map { $0.keyHash }) + Array(pubKeys.map { $0.raw! })

        peer.load(filters: filters)
        peer.sendMemoryPoolMessage()

        statusSubject.onNext(.connected)

        delegate?.peerGroupReady()
    }

    func peerDidDisconnect(_ peer: Peer) {
    }

    func peer(_ peer: Peer, didReceiveAddressMessage message: AddressMessage) {
    }

    func peer(_ peer: Peer, didReceiveHeadersMessage message: HeadersMessage) {
        delegate?.peerGroupDidReceive(headers: message.blockHeaders)
    }

    func peer(_ peer: Peer, didReceiveMerkleBlockMessage message: MerkleBlockMessage) {
        do {
            let hashes = try validator.validateAndGetTxHashes(message: message)

            if hashes.isEmpty {
                delegate?.peerGroupDidReceive(blockHeader: message.blockHeader, withTransactions: [])
            } else {
                pendingBlocks.append(PendingBlock(header: message.blockHeader, pendingTransactionHashes: hashes, transactions: []))
                print("TX COUNT: \(hashes.count)")
            }
        } catch {
            print("MERKLE BLOCK MESSAGE ERROR: \(error)")
        }
    }

    func peer(_ peer: Peer, didReceiveTransactionMessage message: TransactionMessage) {
        let txHash = Crypto.sha256sha256(TransactionSerializer.serialize(transaction: message.transaction))

        if let index = pendingBlocks.index(where: { $0.pendingTransactionHashes.contains(txHash) }) {
            pendingBlocks[index].transactions.append(message.transaction)

            if pendingBlocks[index].transactions.count == pendingBlocks[index].pendingTransactionHashes.count {
                let block = pendingBlocks.remove(at: index)
                delegate?.peerGroupDidReceive(blockHeader: block.header, withTransactions: block.transactions)
            }

        } else {
            delegate?.peerGroupDidReceive(transaction: message.transaction)
        }
    }

    func shouldRequest(inventoryItem: InventoryItem) -> Bool {
        return delegate?.shouldRequest(inventoryItem: inventoryItem) ?? false
    }

}
