import Foundation
import HdWalletKit
import HsToolKit
import NIO
import NIOFoundationCompat

class PeerConnection: NSObject {
    enum PeerConnectionError: Error {
        case connectionClosedWithUnknownError
        case connectionClosedByPeer
    }

    let host: String
    let port: Int

    weak var delegate: PeerConnectionDelegate?

    private let networkMessageParser: INetworkMessageParser
    private let networkMessageSerializer: INetworkMessageSerializer
    private let logger: Logger?
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?

    private var waitingForDisconnect: Bool = false
    private let interval = TimeAmount.seconds(1)

    var logName: String {
        let index = abs(host.hash) % WordList.english.count
        return "[\(WordList.english[index])]".uppercased()
    }

    private var bootstrap: ClientBootstrap {
        ClientBootstrap(group: group)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { [weak self] channel in
                    self?.initializeChannel(channel: channel) ?? channel.eventLoop.makeSucceededVoidFuture()
                }
    }

    init(host: String, port: Int, networkMessageParser: INetworkMessageParser, networkMessageSerializer: INetworkMessageSerializer,
         eventLoopGroup: MultiThreadedEventLoopGroup, logger: Logger? = nil) {
        self.host = host
        self.port = port
        self.networkMessageParser = networkMessageParser
        self.networkMessageSerializer = networkMessageSerializer
        self.group = eventLoopGroup
        self.logger = logger
    }

    deinit {
        disconnect()
    }

    private func log(_ message: @autoclosure () -> Any, level: Logger.Level = .debug) {
        logger?.log(level: level, message: message(), context: [logName])
    }

    private func initializeChannel(channel: Channel) -> EventLoopFuture<Void> {
        let handler = PeerMessageHandler(networkMessageParser: networkMessageParser)
        handler.delegate = self

        return channel.pipeline.addHandler(handler)
    }

    private func onConnected(channel: Channel) {
        self.channel = channel

        channel.eventLoop.scheduleRepeatedTask(initialDelay: .zero, delay: interval, notifying: nil) { [weak self] task in
            guard !(self?.waitingForDisconnect ?? true) else {
                task.cancel()
                return
            }

            self?.delegate?.connectionTimePeriodPassed()
        }
    }

    private func onConnectFailure(error: Error) {
        disconnect(error: error)
    }

}

extension PeerConnection: IPeerConnection {

    func connect() {
        let connectFuture = bootstrap.connect(host: host, port: port)

        connectFuture.whenSuccess { [weak self] channel in
            self?.onConnected(channel: channel)
        }

        connectFuture.whenFailure { [weak self] error in
            self?.onConnectFailure(error: error)
        }
    }

    func disconnect(error: Error? = nil) {
        guard !waitingForDisconnect else {
            return
        }

        channel = nil
        waitingForDisconnect = true
        delegate?.connectionDidDisconnect(withError: error)
    }

    func send(message: IMessage) {
        log("-> \(type(of: message)): \(message.description)")
        do {
            let data = try networkMessageSerializer.serialize(message: message)
            guard !data.isEmpty, let channel = channel else {
                return
            }

            var buffer = channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)

            channel.writeAndFlush(buffer)
        } catch {
            log("Connection can't send message \(message) with error \(error)", level: .error) //todo catch error when try send message not registered in serializers
        }
    }

}

extension PeerConnection: PeerMessageHandlerDelegate {

    func onChannelActive() {
        delegate?.connectionReadyForWrite()
    }

    func onChannelInactive() {
        if !waitingForDisconnect {
            disconnect(error: PeerConnectionError.connectionClosedWithUnknownError)
        }
    }

    func onChannelRead() {
        delegate?.connectionAlive()
    }

    func onMessageReceived(message: IMessage) {
        log("<- \(type(of: message)): \(message.description)")
        delegate?.connection(didReceiveMessage: message)
    }

    func onErrorCaught(error: Error) {
        log("Error received: \(error)")
        disconnect(error: error)
    }

}

protocol PeerConnectionDelegate: class {
    func connectionAlive()
    func connectionTimePeriodPassed()
    func connectionReadyForWrite()
    func connectionDidDisconnect(withError error: Error?)
    func connection(didReceiveMessage message: IMessage)
}
