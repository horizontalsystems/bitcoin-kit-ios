import Foundation
import RealmSwift

class HeaderHandler {

    enum HandleError: Error {
        case emptyHeaders
    }

    private let realmFactory: RealmFactory
    private let validateBlockFactory: ValidatedBlockFactory
    private let peerGroup: PeerGroup

    init(realmFactory: RealmFactory, validateBlockFactory: ValidatedBlockFactory, peerGroup: PeerGroup) {
        self.realmFactory = realmFactory
        self.validateBlockFactory = validateBlockFactory
        self.peerGroup = peerGroup
    }

    func handle(headers: [BlockHeader]) throws {
        var headers = headers
        let realm = realmFactory.realm

        guard !headers.isEmpty else {
            throw HandleError.emptyHeaders
        }

        var blocks = [Block]()

        // Find diversion point if given blocks list is a new leaf of detected fork
        var diversionPointBlock: Block?
        while let firstHeader = headers.first {
            let headerHash = Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: firstHeader))

            if let existingBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", headerHash.reversedHex).first {
                diversionPointBlock = existingBlock
                headers.removeFirst()
            } else {
                break
            }
        }

        defer {
            if let lastNewBlock = blocks.last {
                try? realm.write {
                    if let diversionPointBlock = diversionPointBlock {
                        let existingLeafBlocks = realm.objects(Block.self).filter("height > %@", diversionPointBlock.height).sorted(byKeyPath: "height")
                        if let lastExistingBlock = existingLeafBlocks.last, lastNewBlock.height > lastExistingBlock.height {
                            // Remove old leaf if shorter than new one
                            realm.delete(existingLeafBlocks)
                            // Add new blocks to chain
                            realm.add(blocks)
                        }
                    } else {
                        realm.add(blocks)
                    }
                }

                if !blocks.isEmpty {
                    peerGroup.syncBlocks(hashes: blocks.map {
                        $0.headerHash
                    })
                }
            }
        }

        // Validate and chain new blocks
        var previousBlock: Block? = diversionPointBlock
        for header in headers {
            let block = try validateBlockFactory.block(fromHeader: header, previousBlock: previousBlock)
            blocks.append(block)
            previousBlock = block
        }
    }

}
