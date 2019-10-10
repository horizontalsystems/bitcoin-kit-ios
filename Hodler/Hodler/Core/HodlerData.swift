class HodlerData {
    let lockedUntilTimestamp: Int
    let addressString: String

    static func parse(serialized: String) throws -> HodlerData {
        let parts = serialized.split(separator: "|")

        guard parts.count == 2 else {
            throw HodlerPluginError.invalidHodlerData
        }

        let lockedUntilTimestampStr = String(parts[0])
        let addressString = String(parts[1])

        guard let lockedUntilTimestamp = Int(lockedUntilTimestampStr) else {
            throw HodlerPluginError.invalidHodlerData
        }


        return HodlerData(lockedUntilTimestamp: lockedUntilTimestamp, addressString: addressString)
    }

    init(lockedUntilTimestamp: Int, addressString: String) {
        self.lockedUntilTimestamp = lockedUntilTimestamp
        self.addressString = addressString
    }

    func toString() -> String {
        "\(lockedUntilTimestamp)|\(addressString)"
    }

}
