import RxSwift

class TransactionMetadataExtractor {
    private let myOutputsCache: IOutputsCache
    private let storage: IOutputStorage

    init(storage: IOutputStorage) {
        myOutputsCache = MyOutputsCache.instance(storage: storage)
        self.storage = storage
    }

}

extension TransactionMetadataExtractor: ITransactionExtractor {

    func extract(transaction: FullTransaction) {
        var myInputsTotalValue: Int = 0
        var myOutputsTotalValue: Int = 0
        var myChangeOutputsTotalValue: Int = 0
        var outputsTotalValue: Int = 0
        var allInputsMine = true

        for input in transaction.inputs {
            if let value = myOutputsCache.valueSpent(by: input) {
                myInputsTotalValue += value
            } else {
                allInputsMine = false
            }
        }

        for output in transaction.outputs {
            guard output.value > 0 else {
                continue
            }

            outputsTotalValue += output.value

            if output.publicKeyPath != nil {
                myOutputsTotalValue += output.value
                if output.changeOutput {
                    myChangeOutputsTotalValue += output.value
                }
            }
        }

        guard myInputsTotalValue > 0 || myOutputsTotalValue > 0 else {
            return
        }

        transaction.header.isMine = true
        if myInputsTotalValue > 0 {
            transaction.header.isOutgoing = true
        }

        var amount = myOutputsTotalValue - myInputsTotalValue
        var fee: Int? = nil

        if allInputsMine {
            fee = myInputsTotalValue - outputsTotalValue
            amount += fee!
        } else {
            var inputsTotalValue = 0
            var allInputsHaveValue = true
            for input in transaction.inputs {
                if let previousOutput = storage.previousOutput(ofInput: input) {
                    inputsTotalValue += previousOutput.value
                } else {
                    allInputsHaveValue = false
                    break
                }
            }

            fee = allInputsHaveValue ? inputsTotalValue - outputsTotalValue : nil
        }

        if amount > 0 {
            transaction.metaData.amount = amount
            transaction.metaData.type = .incoming
        } else if amount < 0 {
            transaction.metaData.amount = abs(amount)
            transaction.metaData.type = .outgoing
        } else {
            transaction.metaData.amount = abs(myOutputsTotalValue - myChangeOutputsTotalValue)
            transaction.metaData.type = .sentToSelf
        }
        transaction.metaData.fee = fee

        if myOutputsTotalValue > 0 {
            myOutputsCache.add(outputs: transaction.outputs)
        }
    }

}
