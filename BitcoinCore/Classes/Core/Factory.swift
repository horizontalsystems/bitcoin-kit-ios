import HsToolKit
import NIO

class Factory: IFactory {
    private let network: INetwork
    private let networkMessageParser: INetworkMessageParser
    private let networkMessageSerializer: INetworkMessageSerializer

    init(network: INetwork, networkMessageParser: INetworkMessageParser, networkMessageSerializer: INetworkMessageSerializer) {
        self.network = network
        self.networkMessageParser = networkMessageParser
        self.networkMessageSerializer = networkMessageSerializer
    }

    func block(withHeader header: BlockHeader, previousBlock: Block) -> Block {
        Block(withHeader: header, previousBlock: previousBlock)
    }

    func block(withHeader header: BlockHeader, height: Int) -> Block {
        Block(withHeader: header, height: height)
    }

    func transaction(version: Int, lockTime: Int) -> Transaction {
        Transaction(version: version, lockTime: lockTime)
    }

    func inputToSign(withPreviousOutput previousOutput: UnspentOutput, script: Data, sequence: Int) -> InputToSign {
        let input = Input(
                withPreviousOutputTxHash: previousOutput.output.transactionHash, previousOutputIndex: previousOutput.output.index,
                script: script, sequence: sequence
        )

        return InputToSign(input: input, previousOutput: previousOutput.output, previousOutputPublicKey: previousOutput.publicKey)
    }

    func output(withIndex index: Int, address: Address, value: Int, publicKey: PublicKey?) -> Output {
        Output(withValue: value, index: index, lockingScript: address.lockingScript, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash, publicKey: publicKey)
    }

    func nullDataOutput(data: Data) -> Output {
        Output(withValue: 0, index: 0, lockingScript: data, type: .nullData)
    }

    func peer(withHost host: String, eventLoopGroup: MultiThreadedEventLoopGroup, logger: Logger? = nil) -> IPeer {
        let connection = PeerConnection(host: host, port: network.port, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer, eventLoopGroup: eventLoopGroup, logger: logger)

        return Peer(host: host, network: network, connection: connection, connectionTimeoutManager: ConnectionTimeoutManager(), logger: logger)
    }

    func blockHash(withHeaderHash headerHash: Data, height: Int, order: Int = 0) -> BlockHash {
        BlockHash(headerHash: headerHash, height: height, order: order)
    }

    func bloomFilter(withElements elements: [Data]) -> BloomFilter {
        BloomFilter(elements: elements)
    }

}
