import Foundation

class PeerTimer {

    enum PeerTimerError: Error {
        case pingTimedOut
    }

    private var messageLastReceivedTime: Double? = nil
    private var lastPingTime: Double? = nil
    private var interval = 1.0
    private var maxIdleTime = 60.0
    private var pingTimeout = 5.0

    private var logger: Logger?

    weak var peerConnection: PeerConnection?

    lazy var timer: Timer = {
        return Timer(timeInterval: interval, repeats: true, block: { self.timePeriodPassed($0) })
    }()

    init(logger: Logger? = nil) {
        self.logger = logger
    }

    func reset() {
        messageLastReceivedTime = CACurrentMediaTime()
        lastPingTime = nil
    }

    private func timePeriodPassed(_ timer: Timer) {
        if let lastPingTime = lastPingTime {
            if (CACurrentMediaTime() - lastPingTime > pingTimeout) {
                log("Timed out. Closing connection", level: .error)
                peerConnection?.disconnect(error: PeerTimerError.pingTimedOut)
            }
        }

        if let  messageLastReceivedTime = messageLastReceivedTime {
            if (lastPingTime == nil && CACurrentMediaTime() - messageLastReceivedTime > maxIdleTime) {
                log("In idle, sending Ping")
                pingPeer()
                lastPingTime = CACurrentMediaTime()
            }
        }
    }

    private func pingPeer() {
        let message = PingMessage(nonce: UInt64.random(in: 0..<UINT64_MAX))

        log("--> Ping: \(message.nonce)")
        peerConnection?.send(message: message)
    }

    private func log(_ message: String, level: Logger.Level = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        logger?.log(level: level, message: message, file: file, function: function, line: line, context: peerConnection?.logName ?? "")
    }

}
