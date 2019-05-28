import BitcoinCore

class ISLockParser: IMessageParser {
    var id: String { return "islock" }

    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let inputsCount = Int(byteStream.read(VarInt.self).underlyingValue)

        var outpoints = [Outpoint]()
        for _ in 0..<inputsCount {
            outpoints.append(Outpoint(byteStream: byteStream))
        }

        let txHash = byteStream.read(Data.self, count: 32)
        let sign = byteStream.read(Data.self, count: 96)

        let hash = hasher.hash(data: data)
        return ISLockMessage(inputs: outpoints, txHash: txHash, sign: sign, hash: hash)

    }

}
