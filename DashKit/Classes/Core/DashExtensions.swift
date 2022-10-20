extension Data: Comparable {

    public static func <(lhs: Data, rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return lhs.count < rhs.count
        }

        let count = lhs.count
        for index in 0..<count {
            if lhs[index] == rhs[index] {
                continue
            } else {
                return lhs[index] < rhs[index]
            }
        }
        return true
    }

}
