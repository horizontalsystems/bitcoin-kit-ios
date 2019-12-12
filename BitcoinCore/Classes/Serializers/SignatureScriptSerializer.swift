import Foundation

public class SignatureScriptSerializer {

    static func deserialize(byteStream: ByteStream) -> [Data] {
        var data = [Data]()

        while byteStream.availableBytes > 0 {
            let dataSize = byteStream.read(VarInt.self)

            switch dataSize.underlyingValue {
            case 0x00:
                data.append(Data())
            case 0x01...0x4b:
                data.append(byteStream.read(Data.self, count: Int(dataSize.underlyingValue)))
            case 0x4c:
                let dataSize2 = byteStream.read(UInt8.self).littleEndian
                data.append(byteStream.read(Data.self, count: Int(dataSize2)))
            case 0x4d:
                let dataSize2 = byteStream.read(UInt16.self).littleEndian
                data.append(byteStream.read(Data.self, count: Int(dataSize2)))
            case 0x4e:
                let dataSize2 = byteStream.read(UInt32.self).littleEndian
                data.append(byteStream.read(Data.self, count: Int(dataSize2)))
            case 0x4f:
                data.append(Data(from: Int8(-1)))
            case 0x51:
                data.append(Data([UInt8(0x51)]))
            case 0x52...0x60:
                data.append(Data([UInt8(dataSize.underlyingValue - 0x50)]))
            default:
                ()
            }
        }

        return data
    }

    public static func deserialize(data: Data) -> [Data] {
        return deserialize(byteStream: ByteStream(data))
    }

}
