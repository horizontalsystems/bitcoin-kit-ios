import Foundation

class PeerConnection: NSObject, StreamDelegate {
    private let bufferSize = 4096

    let host: String
    let port: UInt32
    private let network: NetworkProtocol

    weak var delegate: PeerConnectionDelegate?

    private let queue: DispatchQueue
    private var runLoop: RunLoop?

    private var readStream: Unmanaged<CFReadStream>?
    private var writeStream: Unmanaged<CFWriteStream>?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private var packets: Data = Data()

    init(host: String, network: NetworkProtocol = BitcoinTestNet()) {
        self.host = host
        self.port = UInt32(network.port)
        self.network = network

        queue = DispatchQueue(label: host, qos: .background)
    }

    deinit {
        disconnect()
    }

    func connect() {
        if runLoop == nil {
            queue.async {
                self.runLoop = .current
                self.connectAsync()
            }
        } else {
            log("ALREADY CONNECTED")
        }
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

        RunLoop.current.run()
    }

    func disconnect() {
        guard readStream != nil && readStream != nil else {
            return
        }

        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .current, forMode: .commonModes)
        outputStream?.remove(from: .current, forMode: .commonModes)
        readStream = nil
        writeStream = nil
        runLoop = nil

        delegate?.connectionDidDisconnect(self)

        log("DISCONNECTED")
    }

    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        switch stream {
        case let stream as InputStream:
            switch eventCode {
            case .openCompleted:
                log("CONNECTED")
                break
            case .hasBytesAvailable:
                readAvailableBytes(stream: stream)
            case .hasSpaceAvailable:
                break
            case .errorOccurred:
                log("IN ERROR OCCURRED")
                disconnect()
            case .endEncountered:
                log("IN CLOSED")
                disconnect()
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
                log("OUT ERROR OCCURRED")
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

    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        defer { buffer.deallocate() }

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
            guard let networkMessage = NetworkMessage.deserialize(data: packets) else {
                return
            }

            autoreleasepool {
                packets = Data(packets.dropFirst(NetworkMessage.minimumLength + Int(networkMessage.length)))
                delegate?.connection(self, didReceiveMessage: networkMessage.message)
            }
        }
    }

    func send(message: IMessage) {
        let message = NetworkMessage(network: network, message: message)

        let data = message.serialized()
        _ = data.withUnsafeBytes {
            outputStream?.write($0, maxLength: data.count)
        }
    }

    private func log(_ message: String) {
        Logger.shared.log(self, "\(host):\(port) \(message)")
    }
}

protocol PeerConnectionDelegate : class {
    func connectionReadyForWrite(_ connection: PeerConnection)
    func connectionDidDisconnect(_ connection: PeerConnection)
    func connection(_ connection: PeerConnection, didReceiveMessage message: IMessage)
}
