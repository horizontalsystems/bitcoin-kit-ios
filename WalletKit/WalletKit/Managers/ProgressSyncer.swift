import Foundation
import RealmSwift
import RxSwift

class ProgressSyncer {
    private let realmFactory: RealmFactory
    private let queue: DispatchQueue
    var lastBlockHeight: Int = 0

    let subject = PublishSubject<Double>()

    var progress: Double = 0 {
        didSet {
            subject.onNext(progress)
        }
    }

    init(realmFactory: RealmFactory, queue: DispatchQueue = DispatchQueue(label: "ProgressManager", qos: .background)) {
        self.realmFactory = realmFactory
        self.queue = queue
    }

    func enqueueRun() {
        queue.async {
            do {
                try self.run()
            } catch {
                Logger.shared.log(self, "\(error)")
            }
        }
    }

    private func run() throws {
        let realm = realmFactory.realm
        let blocksCount = realm.objects(Block.self).count

        progress = lastBlockHeight == 0 ? 0 : Double(blocksCount) / Double(lastBlockHeight)
    }

}
