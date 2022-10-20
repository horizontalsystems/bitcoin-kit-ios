class BlockHashFetcherHelper: IBlockHashFetcherHelper {

    func lastUsedIndex(addresses: [[String]], outputs: [SyncTransactionOutputItem]) -> Int {
        guard addresses.count > 0 else {
            return -1
        }

        let searchAddressStrings = outputs.map { $0.address }
        let searchScriptStrings = outputs.map { $0.script }

        let lastIndex = addresses.count - 1
        for i in 0...lastIndex {
            for address in addresses[lastIndex - i] {
                if searchAddressStrings.contains(address) ||
                   searchScriptStrings.firstIndex(where: { script in script.contains(address) }) != nil {
                    return lastIndex - i
                }
            }
        }
        return -1
    }

}