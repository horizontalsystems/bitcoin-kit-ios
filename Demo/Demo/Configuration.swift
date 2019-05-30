import BitcoinCore

class Configuration {
    static let shared = Configuration()

    let minLogLevel: Logger.Level = .verbose
    let testNet = true
    let defaultWords = "used ugly meat glad balance divorce inner artwork hire invest already piano"
}
