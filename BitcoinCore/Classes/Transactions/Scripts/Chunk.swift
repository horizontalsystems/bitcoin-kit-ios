import Foundation

public class Chunk: Equatable {
    let scriptData: Data
    let index: Int
    let payloadRange: Range<Int>?

    public var opCode: UInt8 { return scriptData[index] }
    public var data: Data? {
        guard let payloadRange = payloadRange, scriptData.count >= payloadRange.upperBound else {
            return nil
        }
        return scriptData.subdata(in: payloadRange)
    }

    public init(scriptData: Data, index: Int, payloadRange: Range<Int>? = nil) {
        self.scriptData = scriptData
        self.index = index
        self.payloadRange = payloadRange
    }

    static public func ==(lhs: Chunk, rhs: Chunk) -> Bool {
        return lhs.scriptData == rhs.scriptData && lhs.opCode == rhs.opCode && lhs.payloadRange == rhs.payloadRange
    }

}
