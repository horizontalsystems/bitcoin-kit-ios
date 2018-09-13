import Foundation

class Logger {
    static let shared = Logger()

    private init() {
    }

    private let allowedLogs = [
        String(describing: ApiManager.self),
        String(describing: TransactionProcessor.self),
        String(describing: Syncer.self),
        String(describing: PeerConnection.self),
        String(describing: Peer.self),
        String(describing: PeerGroup.self),
        String(describing: InitialSyncer.self),
        String(describing: ProgressSyncer.self),
        ""
    ]

    private lazy var dateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    func log<T>(_ namespace: T?, _ logString: String) {
        log(String(describing: T.self), logString)
    }

    func log(_ logTag: String, _ logString: String) {
        if allowedLogs.contains(logTag) {
            let timestamp = dateFormatter.string(from: Date())
            print("\(timestamp): \(logString)\n")
        }
    }

}
