import Foundation
import HsToolKit

class ConnectionTimeoutManager: IConnectionTimeoutManager {

    enum TimeoutError: Error {
        case pingTimedOut
    }

    private var messageLastReceivedTime: Double? = nil
    private var lastPingTime: Double? = nil
    private let maxIdleTime = 60.0
    private let pingTimeout = 5.0

    private let logger: Logger?
    private let dateGenerator: () -> Date

    init(dateGenerator: @escaping () -> Date = Date.init, logger: Logger? = nil) {
        self.logger = logger
        self.dateGenerator = dateGenerator
    }

    func reset() {
        messageLastReceivedTime = dateGenerator().timeIntervalSince1970
        lastPingTime = nil
    }

    func timePeriodPassed(peer: IPeer) {
        if let lastPingTime = lastPingTime {
            if (dateGenerator().timeIntervalSince1970 - lastPingTime > pingTimeout) {
                logger?.error("Timed out. Closing connection", context: [peer.logName])
                peer.disconnect(error: TimeoutError.pingTimedOut)
            }

            return
        }

        if let  messageLastReceivedTime = messageLastReceivedTime {
            if (dateGenerator().timeIntervalSince1970 - messageLastReceivedTime > maxIdleTime) {
                logger?.debug("Timed out. Closing connection", context: [peer.logName])
                peer.sendPing(nonce: UInt64.random(in: 0..<UINT64_MAX))
                lastPingTime = dateGenerator().timeIntervalSince1970
            }
        }
    }

}
