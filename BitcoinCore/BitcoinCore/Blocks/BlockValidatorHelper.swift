class BlockValidatorHelper: IBlockValidatorHelper {
    let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func previous(for block: Block, count: Int) -> Block? {
        let previousHeight = block.height - count
        guard let previousBlock = storage.block(byHeight: previousHeight) else {
            return nil
        }
        return previousBlock
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        let firstIndex = block.height - count
        let blocks = storage.blocks(from: firstIndex, to: block.height - 1, ascending: true)
        guard blocks.count == count else {
            return nil
        }
        return blocks
    }

}
