import BitcoinCore

class TestData {

    static var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "cec100cc".reversedData!,
                        previousBlockHeaderHash: "00000000864b744c5025331036aa4a16e9ed1cbb362908c625272150fa059b29".reversedData!,
                        merkleRoot: "70d6379650ac87eaa4ac1de27c21217b81a034a53abf156c422a538150bd80f4".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 2391008772
                ),
                height: 2016)
    }

    static var firstBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "11b10ccc".reversedData!,
                        previousBlockHeaderHash: checkpointBlock.headerHash,
                        merkleRoot: "55de0864e0b96f0dff597b1c138de187dd8c40e859b01b4671f7a92ca1b7a9b9".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 1716024842
                ),
                previousBlock: checkpointBlock)
    }

    static var secondBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "22b10ccc".reversedData!,
                        previousBlockHeaderHash: firstBlock.headerHash,
                        merkleRoot: "9a342c0615d0e5a3256f5b9a7818abecc1c8722ab3a8db8df5595c8635cc11e1".reversedData!,
                        timestamp: 1337966314,
                        bits: 486604799,
                        nonce: 627458064
                ),
                previousBlock: firstBlock)
    }

}
