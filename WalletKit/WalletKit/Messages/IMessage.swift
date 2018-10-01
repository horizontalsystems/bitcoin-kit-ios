import Foundation

protocol IMessage {
    init(data: Data, network: NetworkProtocol)
    func serialized() -> Data
}
