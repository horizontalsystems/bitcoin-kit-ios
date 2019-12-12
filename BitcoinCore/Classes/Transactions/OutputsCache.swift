class OutputsCache {
    private var myOutputs = [Data: [Int]]()
}

extension OutputsCache: IOutputsCache {

    func add(fromOutputs outputs: [Output]) {
        for output in outputs {
            if output.publicKeyPath != nil {
                if myOutputs[output.transactionHash] != nil {
                    myOutputs[output.transactionHash]?.append(output.index)
                } else {
                    myOutputs[output.transactionHash] = [output.index]
                }
            }
        }
    }

    func hasOutputs(forInputs inputs: [Input]) -> Bool {
        for input in inputs {
            if let outputIndices = myOutputs[input.previousOutputTxHash], outputIndices.contains(input.previousOutputIndex) {
                return true
            }
        }

        return false
    }

    func clear() {
        myOutputs.removeAll()
    }

}

extension OutputsCache {

    static func instance(storage: IStorage) -> OutputsCache {
        let instance = OutputsCache()
        let outputs = storage.outputsWithPublicKeys()
        instance.add(fromOutputs: outputs.map { $0.output })

        return instance
    }

}
