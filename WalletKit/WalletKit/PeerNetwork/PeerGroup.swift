import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    enum Status {
        case connected, disconnected
    }

    var statusSubject: PublishSubject<Status> = PublishSubject()
    weak var delegate: PeerGroupDelegate?

    private let realmFactory: RealmFactory

    private let peer: Peer

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

    func peer(_ peer: Peer, didReceiveHeaders headers: [BlockHeader]) {
        delegate?.peerGroupDidReceive(headers: headers)
    }

    func peer(_ peer: Peer, didReceiveMerkleBlock merkleBlock: MerkleBlock) {
        delegate?.peerGroupDidReceive(blockHeader: merkleBlock.header, withTransactions: merkleBlock.transactions)
    }

    func peer(_ peer: Peer, didReceiveTransaction transaction: Transaction) {
        delegate?.peerGroupDidReceive(transaction: transaction)
    }

    func shouldRequest(inventoryItem: InventoryItem) -> Bool {
        return delegate?.shouldRequest(inventoryItem: inventoryItem) ?? false
    }

}
