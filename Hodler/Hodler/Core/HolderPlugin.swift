import Foundation
import BitcoinCore
import HSCryptoKit

enum HodlerPluginError: Error {
    case unsupportedAddress
    case invalidHodlerData
}

public class HodlerPlugin {

    public let id: UInt8 = OpCode.push(1)[0]

    public init() {}

    private func cltvRedeemScript(lockedUntil: Data, publicKeyHash: Data) -> Data {
        OpCode.push(lockedUntil) + Data([OpCode.checkLockTimeVerify, OpCode.drop]) + OpCode.p2pkhStart + OpCode.push(publicKeyHash) + OpCode.p2pkhFinish
    }
}

extension HodlerPlugin: IPlugin {
    
    public func processOutputs(mutableTransaction: MutableTransaction, pluginData: [String: [String: Any]], addressConverter: IAddressConverter) throws {
        guard let hodlerData = pluginData["hodler"], let timeLockParam = hodlerData["locked_until"], let unlockTime = timeLockParam as? Int else {
            return
        }

        guard let recipientAddress = mutableTransaction.recipientAddress, recipientAddress.scriptType == .p2pkh else {
            throw HodlerPluginError.unsupportedAddress
        }

        let unlockTimeData = Data(from: UInt32(unlockTime))
        let redeemScript = cltvRedeemScript(lockedUntil: unlockTimeData, publicKeyHash: recipientAddress.keyHash)
        let scriptHash = CryptoKit.sha256ripemd160(redeemScript)
        let newAddress = try addressConverter.convert(keyHash: scriptHash, type: .p2sh)

        mutableTransaction.recipientAddress = newAddress
        mutableTransaction.add(pluginData: OpCode.push(unlockTimeData) + OpCode.push(recipientAddress.keyHash), pluginId: id)
    }

    public func processTransactionWithNullData(transaction: FullTransaction, nullDataChunks: inout IndexingIterator<[Chunk]>, storage: IStorage, addressConverter: IAddressConverter) throws {
        guard let lockedUntil = nullDataChunks.next()?.data, let publicKeyHash = nullDataChunks.next()?.data else {
            throw HodlerPluginError.invalidHodlerData
        }

        let redeemScript = cltvRedeemScript(lockedUntil: lockedUntil, publicKeyHash: publicKeyHash)
        let redeemScriptHash = CryptoKit.sha256ripemd160(redeemScript)

        guard let output = transaction.outputs.first(where: { $0.keyHash == redeemScriptHash }) else {
            return
        }

        let p2pkhAddress = try addressConverter.convert(keyHash: publicKeyHash, type: .p2pkh)
        let lockedUntilInt = lockedUntil.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Int32.self).pointee }

        output.pluginId = id
        output.pluginData = HodlerData(lockedUntilTimestamp: Int(lockedUntilInt), addressString: p2pkhAddress.stringValue).toString()

        if let publicKey = storage.publicKey(byRawOrKeyHash: publicKeyHash) {
            output.redeemScript = redeemScript
            output.publicKeyPath = publicKey.path
            transaction.header.isMine = true
        }
    }

    public func isSpendable(output: Output, medianTime: Int) throws -> Bool {
        try transactionLockTime(output: output) < medianTime
    }

    public func transactionLockTime(output: Output) throws -> Int {
        guard let pluginData = output.pluginData else {
            throw HodlerPluginError.invalidHodlerData
        }

        return try HodlerData.parse(serialized: pluginData).lockedUntilTimestamp
    }

}
