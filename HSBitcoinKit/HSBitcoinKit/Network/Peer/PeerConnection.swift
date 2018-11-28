import Foundation
import HSHDWalletKit

class PeerConnection: NSObject {
    enum PeerConnectionError: Error {
        case connectionClosedWithUnknownError
        case connectionClosedByPeer
    }

    private let bufferSize = 4096

    let host: String
    let port: UInt32
    private let network: INetwork

    weak var delegate: PeerConnectionDelegate?

    private var runLoop: RunLoop?

    private var readStream: Unmanaged<CFReadStream>?
    private var writeStream: Unmanaged<CFWriteStream>?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var peerTimer: PeerTimer

    private var packets: Data = Data()

    private let logger: Logger?

    var connected: Bool = false

    var logName: String {
        let index = abs(host.hash) % WordList.english.count
        return "[\(WordList.english[index])]".uppercased()
    }

    init(host: String, network: INetwork, logger: Logger? = nil) {
        self.host = host
        self.port = UInt32(network.port)
        self.network = network
        self.peerTimer = PeerTimer(logger: logger)

        self.logger = logger
    }

    deinit {
        disconnect()
    }

    private func connectAsync() {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, port, &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream?.delegate = self
        outputStream?.delegate = self

        inputStream?.schedule(in: .current, forMode: .commonModes)
        outputStream?.schedule(in: .current, forMode: .commonModes)

        inputStream?.open()
        outputStream?.open()

        peerTimer.peerConnection = self
        RunLoop.current.add(peerTimer.timer, forMode: .commonModes)
        RunLoop.current.run()
    }

    private func readAvailableBytes(stream: InputStream) {
        peerTimer.reset()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        defer {
            buffer.deallocate()
        }

        while stream.hasBytesAvailable {
            let numberOfBytesRead = stream.read(buffer, maxLength: bufferSize)
            if numberOfBytesRead <= 0 {
                if let _ = stream.streamError {
                    break
                }
            } else {
                packets += Data(bytesNoCopy: buffer, count: numberOfBytesRead, deallocator: .none)
            }
        }

        while packets.count >= NetworkMessage.minimumLength {
            guard let networkMessage = NetworkMessage.deserialize(data: packets, network: network) else {
                return
            }

            packets = Data(packets.dropFirst(NetworkMessage.minimumLength + Int(networkMessage.length)))
            delegate?.connection(self, didReceiveMessage: networkMessage.message)
        }
    }

    private func log(_ message: String, level: Logger.Level = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        logger?.log(level: level, message: message, file: file, function: function, line: line, context: logName)
    }
}

extension PeerConnection: IPeerConnection {

    func connect() {
        if runLoop == nil {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runLoop = .current
                self.connectAsync()
            }
        } else {
            log("ALREADY CONNECTED")
        }
    }

    func disconnect(error: Error? = nil) {
        guard readStream != nil && readStream != nil else {
            return
        }

        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .current, forMode: .commonModes)
        outputStream?.remove(from: .current, forMode: .commonModes)
        peerTimer.timer.invalidate()
        readStream = nil
        writeStream = nil
        runLoop = nil
        connected = false

        delegate?.connectionDidDisconnect(self, withError: error)

        log("DISCONNECTED")
    }

    func send(message: IMessage) {
        let message = NetworkMessage(network: network, message: message)

        let data = message.serialized()
        _ = data.withUnsafeBytes {
            outputStream?.write($0, maxLength: data.count)
        }
    }

}

extension PeerConnection: StreamDelegate {

    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        switch stream {
        case let stream as InputStream:
            switch eventCode {
            case .openCompleted:
                log("CONNECTION ESTABLISHED")
                connected = true
                break
            case .hasBytesAvailable:
                readAvailableBytes(stream: stream)
            case .hasSpaceAvailable:
                break
            case .errorOccurred:
                log("IN ERROR OCCURRED", level: .warning)
                if connected {
                    // If connected, then error is related not to peer, but to network
                    disconnect()
                } else {
                    disconnect(error: PeerConnectionError.connectionClosedWithUnknownError)
                }
            case .endEncountered:
                log("IN CLOSED")
                disconnect(error: PeerConnectionError.connectionClosedByPeer)
            default:
                break
            }
        case _ as OutputStream:
            switch eventCode {
            case .openCompleted:
                break
            case .hasBytesAvailable:
                break
            case .hasSpaceAvailable:
                delegate?.connectionReadyForWrite(self)
            case .errorOccurred:
                log("OUT ERROR OCCURRED", level: .warning)
                disconnect()
            case .endEncountered:
                log("OUT CLOSED")
                disconnect()
            default:
                break
            }
        default:
            break
        }
    }

}

protocol PeerConnectionDelegate: class {
    func connectionReadyForWrite(_ connection: IPeerConnection)
    func connectionDidDisconnect(_ connection: IPeerConnection, withError error: Error?)
    func connection(_ connection: IPeerConnection, didReceiveMessage message: IMessage)
}
