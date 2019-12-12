import BitcoinCore

// BitcoinCore Compatibility

protocol IBitcoinScriptConverter {
    func decode(data: Data) throws -> Script
}