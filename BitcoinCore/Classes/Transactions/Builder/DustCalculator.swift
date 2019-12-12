class DustCalculator {

    private let minFeeRate: Int
    private let sizeCalculator: ITransactionSizeCalculator

    init(dustRelayTxFee: Int, sizeCalculator: ITransactionSizeCalculator) {
        // https://github.com/bitcoin/bitcoin/blob/94d6a18f23ec1add600f04fc7bd0808b7384d829/src/policy/feerate.cpp#L28
        minFeeRate = dustRelayTxFee / 1000

        self.sizeCalculator = sizeCalculator
    }

}

extension DustCalculator: IDustCalculator {

    func dust(type: ScriptType) -> Int {
        // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.cpp#L18

        var size = sizeCalculator.outputSize(type: type)

        if type.witness {
            size += sizeCalculator.inputSize(type: .p2wpkh) + sizeCalculator.witnessSize(type: .p2wpkh) / 4
        } else {
            size += sizeCalculator.inputSize(type: .p2pkh)
        }

        return size * minFeeRate
    }

}
