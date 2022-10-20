import BitcoinCore

class MasternodeParser: IMasternodeParser {
    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    func parse(byteStream: ByteStream) -> Masternode {
        let proRegTxHash = byteStream.read(Data.self, count: 32)
        let confirmedHash = byteStream.read(Data.self, count: 32)
        let ipAddress = byteStream.read(Data.self, count: 16)
        let port = byteStream.read(UInt16.self)
        let pubKeyOperator = byteStream.read(Data.self, count: 48)
        let keyIDVoting = byteStream.read(Data.self, count: 20)
        let isValid = byteStream.read(UInt8.self) != 0

        let confirmedHashWithProRegTxHash = hasher.hash(data: proRegTxHash + confirmedHash)

        return Masternode(proRegTxHash: proRegTxHash, confirmedHash: confirmedHash, confirmedHashWithProRegTxHash: confirmedHashWithProRegTxHash, ipAddress: ipAddress, port: port, pubKeyOperator: pubKeyOperator, keyIDVoting: keyIDVoting, isValid: isValid)
    }

}
