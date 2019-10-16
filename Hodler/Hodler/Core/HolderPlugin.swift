import Foundation
import BitcoinCore
import HSCryptoKit

enum HodlerPluginError: Error {
    case unsupportedAddress
    case invalidHodlerData
}

public class HodlerPlugin {

    public enum LockTimeInterval: UInt16 {
        case hour = 7           //  60 * 60 / 512
        case month = 5063       //  30 * 24 * 60 * 60 / 512
        case halfYear = 30881   // 183 * 24 * 60 * 60 / 512
        case year = 61593       // 365 * 24 * 60 * 60 / 512
    }

    private let sequenceTimeSecondsGranularity = 512
    private let relativeLockTimeLockMask: UInt32 = 0x400000 // (1 << 22)
    public let id: UInt8 = OpCode.push(1)[0]

    public init() {}

    private func sequence(from lockTimeInterval: LockTimeInterval) -> UInt32 {
        relativeLockTimeLockMask | UInt32(lockTimeInterval.rawValue)
    }

    private func lockTimeIntervalFrom(data lockTimeIntervalData: Data) -> LockTimeInterval? {
        guard lockTimeIntervalData.count == 2 else {
            return nil
        }

        let int16 = lockTimeIntervalData.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee }
        return LockTimeInterval(rawValue: int16)
    }

    private func lockTimeIntervalFrom(output: Output) throws -> LockTimeInterval {
        guard let pluginData = output.pluginData else {
            throw HodlerPluginError.invalidHodlerData
        }

        return try HodlerData.parse(serialized: pluginData).lockTimeInterval
    }

    private func inputLockTime(output: Output, blockMedianTimeHelper: IBlockMedianTimeHelper) throws -> Int {
        guard let previousOutputMedianTime = blockMedianTimeHelper.medianTimePast(transactionHash: output.transactionHash) else {
            throw HodlerPluginError.invalidHodlerData
        }

        let lockTimeInterval = try lockTimeIntervalFrom(output: output)

        return previousOutputMedianTime + Int(lockTimeInterval.rawValue) * sequenceTimeSecondsGranularity
    }

    private func cltvRedeemScript(lockTimeInterval: LockTimeInterval, publicKeyHash: Data) -> Data {
        let sequenceData = Data(from: sequence(from: lockTimeInterval)).subdata(in: 0..<3)
        return OpCode.push(sequenceData) + Data([OpCode.checkSequenceVerify, OpCode.drop]) + OpCode.p2pkhStart + OpCode.push(publicKeyHash) + OpCode.p2pkhFinish
    }

}


extension HodlerPlugin: IPlugin {
    
    public func processOutputs(mutableTransaction: MutableTransaction, pluginData: [String: [String: Any]], addressConverter: IAddressConverter) throws {
        guard let hodlerData = pluginData["hodler"], let timeLockParam = hodlerData["lockTimeInterval"], let lockTimeInterval = timeLockParam as? LockTimeInterval else {
            return
        }

        guard let recipientAddress = mutableTransaction.recipientAddress, recipientAddress.scriptType == .p2pkh else {
            throw HodlerPluginError.unsupportedAddress
        }

        let redeemScript = cltvRedeemScript(lockTimeInterval: lockTimeInterval, publicKeyHash: recipientAddress.keyHash)
        let scriptHash = CryptoKit.sha256ripemd160(redeemScript)
        let newAddress = try addressConverter.convert(keyHash: scriptHash, type: .p2sh)

        mutableTransaction.recipientAddress = newAddress
        mutableTransaction.add(pluginData: OpCode.push(Data(from: lockTimeInterval.rawValue)) + OpCode.push(recipientAddress.keyHash), pluginId: id)
    }

    public func processTransactionWithNullData(transaction: FullTransaction, nullDataChunks: inout IndexingIterator<[Chunk]>, storage: IStorage, addressConverter: IAddressConverter) throws {
        guard let lockTimeIntervalData = nullDataChunks.next()?.data, let publicKeyHash = nullDataChunks.next()?.data,
              let lockTimeInterval = lockTimeIntervalFrom(data: lockTimeIntervalData) else {
            throw HodlerPluginError.invalidHodlerData
        }

        let redeemScript = cltvRedeemScript(lockTimeInterval: lockTimeInterval, publicKeyHash: publicKeyHash)
        let redeemScriptHash = CryptoKit.sha256ripemd160(redeemScript)

        guard let output = transaction.outputs.first(where: { $0.keyHash == redeemScriptHash }) else {
            return
        }

        output.pluginId = id
        output.pluginData = HodlerData(
                lockTimeInterval: lockTimeInterval,
                addressString: (try addressConverter.convert(keyHash: publicKeyHash, type: .p2pkh).stringValue)
        ).toString()

        if let publicKey = storage.publicKey(byRawOrKeyHash: publicKeyHash) {
            output.redeemScript = redeemScript
            output.publicKeyPath = publicKey.path
            transaction.header.isMine = true
        }
    }

    public func isSpendable(output: Output, blockMedianTimeHelper: IBlockMedianTimeHelper) throws -> Bool {
        guard let lastBlockMedianTime = blockMedianTimeHelper.medianTimePast else {
            return false
        }


        return try inputLockTime(output: output, blockMedianTimeHelper: blockMedianTimeHelper) < lastBlockMedianTime
    }

    public func inputSequence(output: Output) throws -> Int {
        Int(sequence(from: try lockTimeIntervalFrom(output: output)))
    }

}
