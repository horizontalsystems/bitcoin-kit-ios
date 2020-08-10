import Foundation
import HdWalletKit
import HsToolKit

class PeerConnection: NSObject {
    enum PeerConnectionError: Error {
        case connectionClosedWithUnknownError
        case connectionClosedByPeer
    }

    private let bufferSize = 4096
    private let interval = 1.0

    let host: String
    let port: UInt32
    private let networkMessageParser: INetworkMessageParser
    private let networkMessageSerializer: INetworkMessageSerializer

    weak var delegate: PeerConnectionDelegate?

    private var readStream: Unmanaged<CFReadStream>?
    private var writeStream: Unmanaged<CFWriteStream>?
    private var timer: Timer?
    private weak var runLoop: RunLoop?
    private weak var inputStream: InputStream?
    private weak var outputStream: OutputStream?

    private var packets: Data = Data()

    private let logger: Logger?

    var connected: Bool = false

    var logName: String {
        let index = abs(host.hash) % WordList.english.count
        return "[\(WordList.english[index])]".uppercased()
    }

    init(host: String, port: UInt32, networkMessageParser: INetworkMessageParser, networkMessageSerializer: INetworkMessageSerializer, logger: Logger? = nil) {
        self.host = host
        self.port = port
        self.networkMessageParser = networkMessageParser
        self.networkMessageSerializer = networkMessageSerializer

        self.timer = nil
        self.logger = logger
    }

    deinit {
        disconnect()
    }

    private func connectAsync() {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, host as CFString, port, &readStream, &writeStream)
        inputStream = readStream!.takeUnretainedValue()
        outputStream = writeStream!.takeUnretainedValue()

        weak var weakSelf = self
        inputStream?.delegate = weakSelf
        outputStream?.delegate = weakSelf

        inputStream?.schedule(in: .current, forMode: .common)
        outputStream?.schedule(in: .current, forMode: .common)

        inputStream?.open()
        outputStream?.open()

        let timer = Timer(timeInterval: interval, repeats: true, block: { [weak self] _ in self?.delegate?.connectionTimePeriodPassed() })
        self.timer = timer

        RunLoop.current.add(timer, forMode: .common)
        RunLoop.current.run()
    }

    private func readAvailableBytes(stream: InputStream) {
        delegate?.connectionAlive()

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

            while packets.count >= NetworkMessage.minimumLength {
                guard let networkMessage = networkMessageParser.parse(data: packets) else {
                    break
                }

                packets = Data(packets.dropFirst(NetworkMessage.minimumLength + Int(networkMessage.length)))
                let message = networkMessage.message

                guard !(message is UnknownMessage) else {
                    continue
                }

                log("<- \(type(of: message)): \(message.description)")
                delegate?.connection(didReceiveMessage: message)
            }
        }
    }

    private func log(_ message: @autoclosure () -> Any, level: Logger.Level = .debug) {
        logger?.log(level: level, message: message(), context: [logName])
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
        guard readStream != nil && writeStream != nil else {
            return
        }

        if let runLoop = self.runLoop {
            inputStream?.remove(from: runLoop, forMode: .common)
            outputStream?.remove(from: runLoop, forMode: .common)
            timer?.invalidate()

            CFRunLoopStop(runLoop.getCFRunLoop())
        }

        inputStream?.delegate = nil
        outputStream?.delegate = nil
        inputStream?.close()
        outputStream?.close()
        readStream?.release()
        writeStream?.release()

        timer = nil
        readStream = nil
        writeStream = nil
        inputStream = nil
        outputStream = nil
        connected = false

        delegate?.connectionDidDisconnect(withError: error)

        log("DISCONNECTED")
    }

    func send(message: IMessage) {
        log("-> \(type(of: message)): \(message.description)")
        do {
            let data = try networkMessageSerializer.serialize(message: message)
            guard !data.isEmpty else {
                return
            }
            _ = data.withUnsafeBytes {
                outputStream?.write($0.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: data.count)
            }
        } catch {
            log("Connection can't send message \(message) with error \(error)", level: .error) //todo catch error when try send message not registered in serializers
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
                delegate?.connectionReadyForWrite()
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
    func connectionAlive()
    func connectionTimePeriodPassed()
    func connectionReadyForWrite()
    func connectionDidDisconnect(withError error: Error?)
    func connection(didReceiveMessage message: IMessage)
}
