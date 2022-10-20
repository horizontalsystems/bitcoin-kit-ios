import Foundation
import BitcoinCore
import OpenSslKit

public enum HodlerPluginError: Error {
    case unsupportedAddress
    case addressNotGiven
    case invalidData
    case lockedValueLimitExceeded
}

public class HodlerPlugin {
    public static let lockedValueLimit = 50_000_000 // 0.5 BTC

    public enum LockTimeInterval: UInt16, CaseIterable, Codable {
        case hour = 7           //  60 * 60 / 512
        case month = 5063       //  30 * 24 * 60 * 60 / 512
        case halfYear = 30881   // 183 * 24 * 60 * 60 / 512
        case year = 61593       // 365 * 24 * 60 * 60 / 512

        private static let sequenceTimeSecondsGranularity = 512
        private static let relativeLockTimeLockMask: UInt32 = 0x400000 // (1 << 22)

        var sequenceNumber: UInt32 {
            LockTimeInterval.relativeLockTimeLockMask | UInt32(self.rawValue)
        }

        public var valueInSeconds: Int {
            Int(self.rawValue) * LockTimeInterval.sequenceTimeSecondsGranularity
        }

        var valueInTwoBytes: Data {
            Data(from: self.rawValue)
        }

        var valueInThreeBytes: Data {
            Data(from: sequenceNumber).subdata(in: 0..<3)
        }
    }

    public static let id: UInt8 = OpCode.push(1)[0]
    public var id: UInt8 { HodlerPlugin.id }
    public var maxSpendLimit: Int? { HodlerPlugin.lockedValueLimit }

    private let addressConverter: IHodlerAddressConverter
    private let blockMedianTimeHelper: IHodlerBlockMedianTimeHelper
    private let publicKeyStorage: IHodlerPublicKeyStorage

    public init(addressConverter: IHodlerAddressConverter, blockMedianTimeHelper: IHodlerBlockMedianTimeHelper, publicKeyStorage: IHodlerPublicKeyStorage) {
        self.addressConverter = addressConverter
        self.blockMedianTimeHelper = blockMedianTimeHelper
        self.publicKeyStorage = publicKeyStorage
    }

    private func lockTimeIntervalFrom(data lockTimeIntervalData: Data) -> LockTimeInterval? {
        guard lockTimeIntervalData.count == 2 else {
            return nil
        }

        let int16 = lockTimeIntervalData.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee }
        return LockTimeInterval(rawValue: int16)
    }

    private func lockTimeIntervalFrom(output: Output) throws -> LockTimeInterval {
        try HodlerOutputData.parse(serialized: output.pluginData).lockTimeInterval
    }

    private func inputLockTime(unspentOutput: UnspentOutput) throws -> Int {
        // Use (an approximate medianTimePast of a block in which given transaction is included) PLUS ~1 hour.
        // This is not an accurate medianTimePast, it is always a timestamp nearly 7 blocks ahead.
        // But this is quite enough in our case since we're setting relative time-locks for at least 1 month
        let previousOutputMedianTime = unspentOutput.transaction.timestamp

        return previousOutputMedianTime + (try lockTimeIntervalFrom(output: unspentOutput.output)).valueInSeconds
    }

    private func csvRedeemScript(lockTimeInterval: LockTimeInterval, publicKeyHash: Data) -> Data {
        OpCode.push(lockTimeInterval.valueInThreeBytes) + Data([OpCode.checkSequenceVerify, OpCode.drop]) + OpCode.p2pkhStart + OpCode.push(publicKeyHash) + OpCode.p2pkhFinish
    }

}


extension HodlerPlugin: IPlugin {

    public func validate(address: Address) throws {
        if address.scriptType != .p2pkh {
            throw HodlerPluginError.unsupportedAddress
        }
    }

    public func processOutputs(mutableTransaction: MutableTransaction, pluginData: IPluginData, skipChecks: Bool = false) throws {
        guard let hodlerData = pluginData as? HodlerData else {
            throw HodlerPluginError.invalidData
        }

        guard let recipientAddress = mutableTransaction.recipientAddress else {
            throw HodlerPluginError.addressNotGiven
        }

        if !skipChecks {
            guard recipientAddress.scriptType == .p2pkh else {
                throw HodlerPluginError.unsupportedAddress
            }

            guard mutableTransaction.recipientValue <= HodlerPlugin.lockedValueLimit else {
                throw HodlerPluginError.lockedValueLimitExceeded
            }
        }

        let redeemScript = csvRedeemScript(lockTimeInterval: hodlerData.lockTimeInterval, publicKeyHash: recipientAddress.keyHash)
        let scriptHash = Kit.sha256ripemd160(redeemScript)
        let newAddress = try addressConverter.convert(keyHash: scriptHash, type: .p2sh)

        mutableTransaction.recipientAddress = newAddress
        mutableTransaction.add(pluginData: OpCode.push(hodlerData.lockTimeInterval.valueInTwoBytes) + OpCode.push(recipientAddress.keyHash), pluginId: id)
    }

    public func processTransactionWithNullData(transaction: FullTransaction, nullDataChunks: inout IndexingIterator<[Chunk]>) throws {
        guard let lockTimeIntervalData = nullDataChunks.next()?.data, let publicKeyHash = nullDataChunks.next()?.data,
              let lockTimeInterval = lockTimeIntervalFrom(data: lockTimeIntervalData) else {
            throw HodlerPluginError.invalidData
        }

        let redeemScript = csvRedeemScript(lockTimeInterval: lockTimeInterval, publicKeyHash: publicKeyHash)
        let redeemScriptHash = Kit.sha256ripemd160(redeemScript)

        guard let output = transaction.outputs.first(where: { $0.keyHash == redeemScriptHash }) else {
            return
        }

        output.pluginId = id
        output.pluginData = HodlerOutputData(
                lockTimeInterval: lockTimeInterval,
                addressString: (try addressConverter.convert(keyHash: publicKeyHash, type: .p2pkh).stringValue)
        ).toString()

        if let publicKey = publicKeyStorage.publicKey(byRawOrKeyHash: publicKeyHash) {
            output.redeemScript = redeemScript
            output.set(publicKey: publicKey)
        }
    }

    public func isSpendable(unspentOutput: UnspentOutput) throws -> Bool {
        guard let lastBlockMedianTime = blockMedianTimeHelper.medianTimePast else {
            return false
        }

        return try inputLockTime(unspentOutput: unspentOutput) < lastBlockMedianTime
    }

    public func inputSequenceNumber(output: Output) throws -> Int {
        Int((try lockTimeIntervalFrom(output: output)).sequenceNumber)
    }

    public func parsePluginData(from pluginData: String, transactionTimestamp: Int) throws -> IPluginOutputData {
        let hodlerOutputData = try HodlerOutputData.parse(serialized: pluginData)

        // When checking if UTXO is spendable we use the best block median time.
        // The median time is 6 blocks earlier which is approximately equal to 1 hour.
        // Here we add 1 hour to show the time when this UTXO will be spendable
        hodlerOutputData.approximateUnlockTime = transactionTimestamp + hodlerOutputData.lockTimeInterval.valueInSeconds + 3600

        return hodlerOutputData
    }

    public func keysForApiRestore(publicKey: PublicKey) throws -> [String] {
        try LockTimeInterval.allCases.map { lockTimeInterval in
            let redeemScript = csvRedeemScript(lockTimeInterval: lockTimeInterval, publicKeyHash: publicKey.keyHash)
            let redeemScriptHash = Kit.sha256ripemd160(redeemScript)

            return try addressConverter.convert(keyHash: redeemScriptHash, type: .p2sh).stringValue
        }
    }

}
