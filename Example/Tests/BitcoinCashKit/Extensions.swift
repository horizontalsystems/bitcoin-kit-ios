import BitcoinCore

extension Block: Equatable {

    public static func ==(lhs: Block, rhs: Block) -> Bool {
        return lhs.headerHash == rhs.headerHash
    }

}
