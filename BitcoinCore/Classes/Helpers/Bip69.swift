class Bip69 {

    static var outputComparator: ((Output, Output) -> Bool) = { o, o1 in
        if o.value != o1.value {
            return o.value < o1.value
        }

        guard let keyHash1 = o.keyHash else {
            return false
        }
        guard let keyHash2 = o1.keyHash else {
            return true
        }

        return compare(data: keyHash1, data2: keyHash2)
    }

    static var inputComparator: ((UnspentOutput, UnspentOutput) -> Bool) = { o, o1 in
        let result = Bip69.compare(data: o.output.transactionHash, data2: o1.output.transactionHash)

        return result || o.output.index < o1.output.index
    }

    private static func compare(data: Data, data2: Data) -> Bool {
        guard data.count == data2.count else {
            return data.count < data2.count
        }

        let count = data.count
        for index in 0..<count {
            if data[index] == data2[index] {
                continue
            } else {
                return data[index] < data2[index]
            }
        }
        return false
    }

}
