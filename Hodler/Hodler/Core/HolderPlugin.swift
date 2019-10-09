import BitcoinCore
import HSCryptoKit

public class HodlerPlugin: IPlugin {
    enum HodlerPluginError: Error {
        case unsupportedAddress
    }
    
    public init() {}

    public func processOutputs(mutableTransaction: MutableTransaction, extraData: [String: [String: Any]], addressConverter: IAddressConverter) throws {
        guard let hodlerData = extraData["hodler"], let timeLockParam = hodlerData["locked_until"], let unlockTime = timeLockParam as? Int else {
            return
        }

        guard let recipientAddress = mutableTransaction.recipientAddress, recipientAddress.scriptType == .p2pkh else {
            throw HodlerPluginError.unsupportedAddress
        }

        let unlockTimeData = Data(from: UInt32(unlockTime))
        let redeemScript = OpCode.push(unlockTimeData) + Data([OpCode.checkLockTimeVerify, OpCode.drop]) + recipientAddress.lockingScript
        let scriptHash = CryptoKit.sha256ripemd160(redeemScript)
        let newAddress = try addressConverter.convert(keyHash: scriptHash, type: .p2sh)

        mutableTransaction.recipientAddress = newAddress
        mutableTransaction.add(extraData: OpCode.push(unlockTimeData) + OpCode.push(recipientAddress.keyHash), pluginId: 1)
    }

}
