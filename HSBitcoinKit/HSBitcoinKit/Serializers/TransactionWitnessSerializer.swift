import Foundation
import RealmSwift

class TransactionWitnessSerializer {

    static func serialize(witnessData: List<Data>) -> Data {
        var data = Data()
        data += VarInt(witnessData.count).serialized()
        for witness in witnessData {
            data += VarInt(witness.count).serialized() + witness
        }
        return data
    }

    static func deserialize(byteStream: ByteStream) -> List<Data> {
        let data = List<Data>()
        let count = byteStream.read(VarInt.self)
        for _ in 0..<Int(count.underlyingValue) {
            let dataSize = byteStream.read(VarInt.self)
            data.append(byteStream.read(Data.self, count: Int(dataSize.underlyingValue)))
        }

        return data
    }

}
