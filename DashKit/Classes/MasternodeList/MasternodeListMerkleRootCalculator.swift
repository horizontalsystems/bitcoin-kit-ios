//https://github.com/dashpay/dips/blob/master/dip-0004.md

// #Masternodes in array comes sorted by proRegTxHash already

//To calculate the merkle root:
//
//01. Get the full masternode list (including PoSe-banned) of the current block. This list must also include all the updates which would have been performed by the data (DIP3 special transactions, PoSe verification, etc.) in the current block.
//02. Sort this list in ascending order by the hash of the ProRegTx of each entry.
//03. For each entry in the list, create a SML entry and calculate the hash of this entry and add the hash into a new list.
//04. Calculate the merkle root from this list of hashes in the same way it is done when calculating the merkle root of the block transactions.

import BitcoinCore

class MasternodeListMerkleRootCalculator: IMasternodeListMerkleRootCalculator {
    private let masternodeSerializer: IMasternodeSerializer
    private let masternodeMerkleRootCreator: IMerkleRootCreator
    private let masternodeHasher: IDashHasher

    init(masternodeSerializer: IMasternodeSerializer, masternodeHasher: IDashHasher, masternodeMerkleRootCreator: IMerkleRootCreator) {
        self.masternodeSerializer = masternodeSerializer
        self.masternodeHasher = masternodeHasher
        self.masternodeMerkleRootCreator = masternodeMerkleRootCreator
    }

    func calculateMerkleRoot(sortedMasternodes: [Masternode]) -> Data? {
        var hashList = [Data]()

        sortedMasternodes.forEach { masternode in
            let serialized = masternodeSerializer.serialize(masternode: masternode)
            hashList.append(masternodeHasher.hash(data: serialized))
        }

        return masternodeMerkleRootCreator.create(hashes: hashList)
    }

}
