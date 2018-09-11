import Foundation
import RealmSwift
import RxSwift

class ProgressSyncer {
    private let realmFactory: RealmFactory
    private let queue: DispatchQueue

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
                print("PROGRESS SYNCER ERROR: \(error)")
            }
        }
    }

    private func run() throws {
        let realm = realmFactory.realm

        let allBlocksCount = realm.objects(Block.self).count
        let syncedBlocksCount = realm.objects(Block.self).filter("synced = %@", true).count

        progress = allBlocksCount == 0 ? 0 : Double(syncedBlocksCount) / Double(allBlocksCount)
    }

}
