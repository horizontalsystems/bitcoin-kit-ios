import Foundation

class RequestHeadersPeerTask: PeerTask {

    private var hashes: [Data]

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        requester?.requestHeaders(hashes: hashes)
    }

    override func handle(blockHeaders: [BlockHeader]) -> Bool {
        delegate?.received(blockHeaders: blockHeaders)
        delegate?.completed(task: self)
        return true
    }

}
