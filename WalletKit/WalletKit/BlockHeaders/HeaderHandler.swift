import Foundation
import RealmSwift

class HeaderHandler {

    enum HandleError: Error {
        case emptyHeaders
    }

    private let realmFactory: RealmFactory
    private let validateBlockFactory: ValidatedBlockFactory
    private let blockSyncer: BlockSyncer

    init(realmFactory: RealmFactory, validateBlockFactory: ValidatedBlockFactory, blockSyncer: BlockSyncer) {
        self.realmFactory = realmFactory
        self.validateBlockFactory = validateBlockFactory
        self.blockSyncer = blockSyncer
    }

    func handle(headers: [BlockHeader]) throws {
        let realm = realmFactory.realm

        guard !headers.isEmpty else {
            throw HandleError.emptyHeaders
        }

        var blocks = [Block]()

        defer {
            try? realm.write {
                realm.add(blocks)
            }

            if !blocks.isEmpty {
                blockSyncer.enqueueRun()
            }
        }

        var previousBlock: Block?

        for header in headers {
            let block = try validateBlockFactory.block(fromHeader: header, previousBlock: previousBlock)
            blocks.append(block)
            previousBlock = block
        }
    }

}
