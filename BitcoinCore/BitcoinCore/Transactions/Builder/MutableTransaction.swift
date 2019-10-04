class MutableTransaction {
    var transaction = Transaction(version: 1, lockTime: 0)
    var paymentOutput: Output!
    var changeOutput: Output? = nil
    var inputsToSign = [InputToSign]()

    var outputs: [Output] {
        var outputs: [Output] = [paymentOutput]

        if let changeOutput = changeOutput {
            outputs.append(changeOutput)
        }

        return outputs
    }

    var extraDataOutputSize: Int {
        0
    }

    func add(inputToSign: InputToSign) {
        inputsToSign.append(inputToSign)
    }

    func build() -> FullTransaction {
        FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
    }

    init() {
        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = true
    }

}
