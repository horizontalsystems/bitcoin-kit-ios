import Foundation
import CryptoKit
import RealmSwift

class HeaderSyncer {

    private let realmFactory: RealmFactory
    private let validateBlockFactory: ValidatedBlockFactory
    private let network: NetworkProtocol
    private let hashCheckpointThreshold: Int

    init(realmFactory: RealmFactory, validateBlockFactory: ValidatedBlockFactory, network: NetworkProtocol, hashCheckpointThreshold: Int = 100) {
        self.realmFactory = realmFactory
        self.validateBlockFactory = validateBlockFactory
        self.network = network
        self.hashCheckpointThreshold = hashCheckpointThreshold
    }

}

extension HeaderSyncer: IHeaderSyncer {

    func getHashes() -> [Data] {
        let realm = realmFactory.realm
        realm.refresh()

        let blocksInChain = realm.objects(Block.self).filter("previousBlock != nil").sorted(byKeyPath: "height")

        var blocks = [Block]()

        if let lastBlockInDatabase = blocksInChain.last {
            blocks.append(lastBlockInDatabase)

            if let thresholdBlock = blocksInChain.filter("height = %@", lastBlockInDatabase.height - hashCheckpointThreshold).first {
                blocks.append(thresholdBlock)
            } else if let firstBlock = blocksInChain.filter("height <= %@", lastBlockInDatabase.height).first, let checkpointBlock = firstBlock.previousBlock {
                blocks.append(checkpointBlock)
            }
        } else {
            blocks.append(network.checkpointBlock)
        }

        return blocks.map { $0.headerHash }
    }

    func handle(headers: [BlockHeader]) throws {
        guard !headers.isEmpty else {
            return
        }

        var headers = headers
        let realm = realmFactory.realm
        realm.refresh()

        var blocks = [Block]()

        // Find diversion point if given blocks list is a new leaf of detected fork
        var diversionPointBlock: Block?
        while let firstHeader = headers.first {
            let headerHash = CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: firstHeader))

            if let existingBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", headerHash.reversedHex).first {
                diversionPointBlock = existingBlock
                headers.removeFirst()
            } else {
                break
            }
        }

        defer {
            if let lastNewBlock = blocks.last {
                var syncBlocks = false

                try? realm.write {
                    if let diversionPointBlock = diversionPointBlock {
                        let existingLeafBlocks = realm.objects(Block.self).filter("height > %@", diversionPointBlock.height).sorted(byKeyPath: "height")
                        if let lastExistingBlock = existingLeafBlocks.last, lastNewBlock.height > lastExistingBlock.height {
                            // Remove old leaf if shorter than new one
                            realm.delete(existingLeafBlocks)
                            // Add new blocks to chain
                            realm.add(blocks)
                            syncBlocks = true
                        }
                    } else {
                        realm.add(blocks)
                        syncBlocks = true
                    }
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

protocol IHeaderSyncer: class {

    func getHashes() -> [Data]
    func handle(headers: [BlockHeader]) throws

}
