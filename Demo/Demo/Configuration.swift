import BitcoinCore

class Configuration {
    static let shared = Configuration()

    let minLogLevel: Logger.Level = .error
    let testNet = true
    let syncMode = BitcoinCore.SyncMode.api
    let defaultWords = [
        "used ugly meat glad balance divorce inner artwork hire invest already piano",
        "razor noodle horse vital dilemma drum civil account grow turn genre turtle",
        "current force clump paper shrug extra zebra employ prefer upon mobile hire",
        "popular game latin harvest silly excess much valid elegant illness edge silk",
    ]

}
