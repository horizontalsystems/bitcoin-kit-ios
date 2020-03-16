class Bip69Sorter: ITransactionDataSorter {

    func sort(outputs: [Output]) -> [Output] {
        outputs.sorted(by: Bip69.outputComparator)
    }

    func sort(unspentOutputs: [UnspentOutput]) -> [UnspentOutput] {
        unspentOutputs.sorted(by: Bip69.inputComparator)
    }

}

class ShuffleSorter: ITransactionDataSorter {

    func sort(outputs: [Output]) -> [Output] {
        outputs.shuffled()
    }

    func sort(unspentOutputs: [UnspentOutput]) -> [UnspentOutput] {
        unspentOutputs.shuffled()
    }

}

class StraightSorter: ITransactionDataSorter {

    func sort(outputs: [Output]) -> [Output] {
        outputs
    }

    func sort(unspentOutputs: [UnspentOutput]) -> [UnspentOutput] {
        unspentOutputs
    }

}
