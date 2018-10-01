import Foundation

protocol NetworkProtocol: class {
    var name: String { get }
    var pubKeyHash: UInt8 { get }
    var privateKey: UInt8 { get }
    var scriptHash: UInt8 { get }
    var pubKeyPrefixPattern: String { get }
    var scriptPrefixPattern: String { get }
    var bech32PrefixPattern: String { get }
    var xPubKey: UInt32 { get }
    var xPrivKey: UInt32 { get }
    var magic: UInt32 { get }
    var port: UInt32 { get }
    var dnsSeeds: [String] { get }
    var genesisBlock: Block { get }
    var checkpointBlock: Block { get }
    var coinType: UInt32 { get }
    var maxBlockSize: UInt32 { get }

    // difficulty adjustment params
    var maxTargetBits: Int { get }                                      // Maximum difficulty.

    var targetTimeSpan: Int { get }                                     // seconds per difficulty cycle, on average.
    var targetSpacing: Int { get }                                      // 10 minutes per block.
    var heightInterval: Int { get }                                     // Blocks in cycle

    func validate(block: Block, previousBlock: Block) throws
}

extension NetworkProtocol {
    var maxBlockSize: UInt32 { return 1_000_000 }

    var maxTargetBits: Int { return 0x1d00ffff }

    var targetTimeSpan: Int { return 14 * 24 * 60 * 60 }                // Seconds in Bitcoin cycle
    var targetSpacing: Int { return 10 * 60 }                           // 10 min. for mining 1 Block

    var heightInterval: Int { return targetTimeSpan / targetSpacing }   // 2016 Blocks in Bitcoin cycle

    func isDifficultyTransitionPoint(height: Int) -> Bool {
        return height % heightInterval == 0
    }

}
