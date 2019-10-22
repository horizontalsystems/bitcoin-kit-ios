import BitcoinCore

public protocol IHodlerAddressConverter {
    func convert(keyHash: Data, type: ScriptType) throws -> Address
}

public protocol IHodlerPublicKeyStorage {
    func publicKey(byRawOrKeyHash hash: Data) -> PublicKey?
}

public protocol IHodlerBlockMedianTimeHelper {
    var medianTimePast: Int? { get }
}
