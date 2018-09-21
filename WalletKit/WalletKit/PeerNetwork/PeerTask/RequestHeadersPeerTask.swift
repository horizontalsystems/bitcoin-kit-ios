import Foundation

class RequestHeadersPeerTask: PeerTask {

    private var hashes: [Data]
    var blockHeaders = [BlockHeader]()

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        requester?.requestHeaders(hashes: hashes)
    }

    override func handle(blockHeaders: [BlockHeader]) -> Bool {
        self.blockHeaders = blockHeaders
        completed = true

        delegate?.handle(task: self)

        return true
    }

}
