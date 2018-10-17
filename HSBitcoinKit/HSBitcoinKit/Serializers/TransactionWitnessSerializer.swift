import Foundation

class TransactionWitnessSerializer {

    static func serialize(witnessData: [Data]) -> Data {
        var data = Data()
        data += VarInt(witnessData.count).serialized()
        for witness in witnessData {
            data += VarInt(witness.count).serialized() + witness
        }
        return data
    }

    static func deserialize(byteStream: ByteStream) -> [Data] {
        var data = [Data]()
        let count = byteStream.read(VarInt.self)
        for _ in 0..<Int(count.underlyingValue) {
            let dataSize = byteStream.read(VarInt.self)
            data.append(byteStream.read(Data.self, count: Int(dataSize.underlyingValue)))
        }

        return data
    }

}
