import Foundation
import ObjectMapper

open class SyncTransactionItem: ImmutableMappable {
    public let blockHash: String?
    public let blockHeight: Int?
    public let txOutputs: [SyncTransactionOutputItem]

    public init(hash: String?, height: Int?, txOutputs: [SyncTransactionOutputItem]) {
        self.blockHash = hash
        self.blockHeight = height
        self.txOutputs = txOutputs
    }

    required public init(map: Map) throws {
        blockHash = try? map.value("block")
        blockHeight = try? map.value("height")
        txOutputs = (try? map.value("outputs")) ?? []
    }

    static func ==(lhs: SyncTransactionItem, rhs: SyncTransactionItem) -> Bool {
        lhs.blockHash == rhs.blockHash && lhs.blockHeight == rhs.blockHeight
    }

}

open class SyncTransactionOutputItem: ImmutableMappable {
    public let script: String
    public let address: String?

    public init(script: String, address: String?) {
        self.script = script
        self.address = address
    }

    required public init(map: Map) throws {
        script = try map.value("script")
        address = try map.value("address")
    }
}
