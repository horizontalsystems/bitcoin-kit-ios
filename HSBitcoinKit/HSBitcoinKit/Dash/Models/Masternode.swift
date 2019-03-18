class Masternode {
    let proRegTxHash: Data
    let confirmedHash: Data
    let ipAddress: Data
    let port: UInt16
    let pubKeyOperator: Data
    let keyIDVoting: Data
    let isValid: Bool

    init(byteStream: ByteStream) {
        proRegTxHash = byteStream.read(Data.self, count: 32)
        confirmedHash = byteStream.read(Data.self, count: 32)
        ipAddress = byteStream.read(Data.self, count: 16)
        port = byteStream.read(UInt16.self)
        pubKeyOperator = byteStream.read(Data.self, count: 48)
        keyIDVoting = byteStream.read(Data.self, count: 20)
        isValid = byteStream.read(UInt8.self) != 0

    }

}
