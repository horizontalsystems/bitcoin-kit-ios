import BitcoinCore

extension Block: Equatable {

    public static func ==(lhs: Block, rhs: Block) -> Bool {
        return lhs.headerHash == rhs.headerHash
    }

}

extension TransactionDataSortType: Equatable {

    public static func ==(lhs: TransactionDataSortType, rhs: TransactionDataSortType) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.shuffle, .shuffle), (.bip69, .bip69): return true
        default: return false
        }
    }

}