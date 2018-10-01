import Foundation

protocol Bech32AddressConverter {

    func convert(prefix: String, address: String) throws -> Address
    func convert(prefix: String, keyHash: Data, scriptType: ScriptType) throws -> Address

}
