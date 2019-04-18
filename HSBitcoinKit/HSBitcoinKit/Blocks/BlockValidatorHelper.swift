class BlockValidatorHelper: IBlockValidatorHelper {
    let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func previous(for block: Block, count: Int) -> Block? {
        return previousWindow(for: block, count: count)?.first
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        guard count > 0 else {
            return nil
        }
        var blocks = [Block]()
        var block = block
        for _ in 0..<count {
            if let prevBlock = storage.block(byHashHex: block.previousBlockHashReversedHex) {
                block = prevBlock
                blocks.insert(block, at: 0)
            } else {
                return nil
            }
        }
        return blocks
    }

}
