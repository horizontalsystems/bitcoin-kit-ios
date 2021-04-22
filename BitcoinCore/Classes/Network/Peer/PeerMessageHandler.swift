import Foundation
import NIO

protocol PeerMessageHandlerDelegate: AnyObject {
    func onChannelActive()
    func onChannelInactive()
    func onChannelRead()
    func onMessageReceived(message: IMessage)
    func onErrorCaught(error: Error)
}

class PeerMessageHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private var bufferSize = 4096
    private var packets: Data = Data()


    private let networkMessageParser: INetworkMessageParser

    weak var delegate: PeerMessageHandlerDelegate?

    init(networkMessageParser: INetworkMessageParser) {
        self.networkMessageParser = networkMessageParser
    }

    func channelActive(context: ChannelHandlerContext) {
        delegate?.onChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        delegate?.onChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        delegate?.onChannelRead()

        var buffer = unwrapInboundIn(data)
        if let bytes = buffer.readData(length: buffer.readableBytes) {
            packets += bytes
        }

        while packets.count >= NetworkMessage.minimumLength {
            guard let networkMessage = networkMessageParser.parse(data: packets) else {
                break
            }

            packets = Data(packets.dropFirst(NetworkMessage.minimumLength + Int(networkMessage.length)))
            let message = networkMessage.message

            guard !(message is UnknownMessage) else {
                continue
            }

            delegate?.onMessageReceived(message: message)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        delegate?.onErrorCaught(error: error)
    }

}
