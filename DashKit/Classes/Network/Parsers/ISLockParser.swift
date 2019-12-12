import BitcoinCore

class ISLockParser: IMessageParser {
    let id = "islock"

    let hasher: IDashHasher

    init(hasher: IDashHasher) {
        self.hasher = hasher
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let inputCountVarInt = byteStream.read(VarInt.self)
        let inputsCount = Int(inputCountVarInt.underlyingValue)

        var outpoints = [Outpoint]()
        for _ in 0..<inputsCount {
            outpoints.append(Outpoint(byteStream: byteStream))
        }

        let txHash = byteStream.read(Data.self, count: 32)
        let sign = byteStream.read(Data.self, count: 96)

        let command = VarInt(id.count).data + (id.data(using: .ascii) ?? Data())

        // requestId - parameter to found quorum. 'islock' + count of inputs + each inputs(outpoint)
        var requestID = command + inputCountVarInt.data
        for outpoint in outpoints {
            requestID += outpoint.txHash + Data(from: outpoint.vout)    //todo: check little or big endian
        }
        requestID = hasher.hash(data: requestID)

        let hash = hasher.hash(data: data)
        return ISLockMessage(inputs: outpoints, txHash: txHash, sign: sign, hash: hash, requestID: requestID)

    }

}
