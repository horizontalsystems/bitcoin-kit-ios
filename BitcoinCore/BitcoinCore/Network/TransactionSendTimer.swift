import Foundation

class TransactionSendTimer {
    let interval: TimeInterval

    weak var delegate: ITransactionSendTimerDelegate?
    var runLoop: RunLoop?
    var timer: Timer?

    init(interval: TimeInterval) {
        self.interval = interval
    }

}

extension TransactionSendTimer: ITransactionSendTimer {

    func startIfNotRunning() {
        guard runLoop == nil else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            self.runLoop = .current

            let timer = Timer(timeInterval: self.interval, repeats: true, block: { [weak self] _ in self?.delegate?.timePassed() })
            self.timer = timer

            RunLoop.current.add(timer, forMode: .common)
            RunLoop.current.run()
        }
    }

    func stop() {
        if let runLoop = self.runLoop {
            timer?.invalidate()
            timer?.invalidate()

            CFRunLoopStop(runLoop.getCFRunLoop())
            timer = nil
            self.runLoop = nil
        }
    }

}
