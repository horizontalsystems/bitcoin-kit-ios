import Foundation
import BitcoinCore

class SpecialTransaction: FullTransaction {
    let extraPayload: Data

    init(transaction: FullTransaction, extraPayload: Data, forceHashUpdate: Bool = true) {
        self.extraPayload = extraPayload
        super.init(header: transaction.header, inputs: transaction.inputs, outputs: transaction.outputs, forceHashUpdate: forceHashUpdate)
    }
}
