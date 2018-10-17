import Foundation
import Cuckoo
import RealmSwift
@testable import WalletKit
@testable import HSHDWalletKit

class MockWalletKit {

    let mockDifficultyEncoder: MockDifficultyEncoder
    let mockBlockHelper: MockBlockHelper
    let mockIBlockValidator: MockIBlockValidator
    let mockValidatorFactory: MockBlockValidatorFactory

    let mockNetwork: MockNetworkProtocol

    let mockRealmFactory: MockRealmFactory

    let mockHdWallet: HDWallet

    let mockStateManager: MockStateManager
    let mockApiManager: MockApiManager
    let mockAddressManager: MockAddressManager
    let mockPeerHostManager: MockPeerHostManager
    let mockBloomFilterManager: MockBloomFilterManager

    let mockPeerGroup: MockPeerGroup
    let mockFactory: MockFactory

    let mockInitialSyncer: MockInitialSyncer
    let mockProgressSyncer: MockProgressSyncer

    let mockBech32AddressConverter: MockBech32AddressConverter
    let mockAddressConverter: MockAddressConverter
    let mockScriptConverter: MockScriptConverter
    let mockTransactionProcessor: MockTransactionProcessor
    let mockTransactionExtractor: MockTransactionExtractor
    let mockTransactionLinker: MockTransactionLinker
    let mockTransactionSyncer: MockTransactionSyncer
    let mockTransactionCreator: MockTransactionCreator
    let mockTransactionBuilder: MockTransactionBuilder
    let mockBlockchain: MockBlockchain

    let mockInputSigner: MockInputSigner
    let mockScriptBuilder: MockScriptBuilder
    let mockTransactionSizeCalculator: MockTransactionSizeCalculator
    let mockUnspentOutputSelector: MockUnspentOutputSelector
    let mockUnspentOutputProvider: MockUnspentOutputProvider

    let mockBlockSyncer: MockBlockSyncer

    let realm: Realm

    public init() {
        let mockDifficultyEncoder = MockDifficultyEncoder()
        self.mockDifficultyEncoder = mockDifficultyEncoder
        let mockBlockHelper = MockBlockHelper()
        self.mockBlockHelper = mockBlockHelper

        let mockIBlockValidator = MockIBlockValidator()
        self.mockIBlockValidator = mockIBlockValidator

        mockValidatorFactory = MockBlockValidatorFactory(difficultyEncoder: mockDifficultyEncoder, blockHelper: mockBlockHelper)
        stub(mockValidatorFactory) { mock in
            when(mock.validator(for: any())).thenReturn(mockIBlockValidator)
        }

        mockNetwork = MockNetworkProtocol()
        mockRealmFactory = MockRealmFactory(configuration: Realm.Configuration())

        let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }
        self.realm = realm

        stub(mockNetwork) { mock in
            when(mock.checkpointBlock.get).thenReturn(TestData.checkpointBlock)
            when(mock.coinType.get).thenReturn(1)
            when(mock.dnsSeeds.get).thenReturn([""])
            when(mock.port.get).thenReturn(0)
            when(mock.xPrivKey.get).thenReturn(0x04358394)
            when(mock.xPubKey.get).thenReturn(0x043587cf)
        }

        mockHdWallet = HDWallet(seed: Data(),coinType: mockNetwork.coinType, xPrivKey: mockNetwork.xPrivKey, xPubKey: mockNetwork.xPubKey)

        mockStateManager = MockStateManager(realmFactory: mockRealmFactory)
        mockApiManager = MockApiManager(apiUrl: "")
        mockPeerHostManager = MockPeerHostManager(network: mockNetwork, realmFactory: mockRealmFactory)
        mockBloomFilterManager = MockBloomFilterManager(realmFactory: mockRealmFactory)

        stub(mockPeerHostManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
        }
        stub(mockBloomFilterManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
        }

        mockFactory = MockFactory()
        mockPeerGroup = MockPeerGroup(factory: mockFactory, network: mockNetwork, peerHostManager: mockPeerHostManager, bloomFilterManager: mockBloomFilterManager)

        mockBech32AddressConverter = MockBech32AddressConverter()
        mockAddressConverter = MockAddressConverter(network: mockNetwork, bech32AddressConverter: mockBech32AddressConverter)
        mockAddressManager = MockAddressManager(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, bloomFilterManager: mockBloomFilterManager, addressConverter: mockAddressConverter)
        mockInitialSyncer = MockInitialSyncer(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, stateManager: mockStateManager, apiManager: mockApiManager, addressManager: mockAddressManager, addressConverter: mockAddressConverter, factory: mockFactory, peerGroup: mockPeerGroup, network: mockNetwork)
        mockProgressSyncer = MockProgressSyncer(realmFactory: mockRealmFactory)

        mockInputSigner = MockInputSigner(hdWallet: mockHdWallet)
        mockScriptBuilder = MockScriptBuilder()

        mockTransactionSizeCalculator = MockTransactionSizeCalculator()
        mockUnspentOutputSelector = MockUnspentOutputSelector(calculator: mockTransactionSizeCalculator)
        mockUnspentOutputProvider = MockUnspentOutputProvider(realmFactory: mockRealmFactory)

        mockScriptConverter = MockScriptConverter()
        mockTransactionExtractor = MockTransactionExtractor(scriptConverter: mockScriptConverter, addressConverter: mockAddressConverter)
        mockTransactionLinker = MockTransactionLinker()
        mockTransactionProcessor = MockTransactionProcessor(realmFactory: mockRealmFactory, extractor: mockTransactionExtractor, linker: mockTransactionLinker, addressManager: mockAddressManager)
        mockTransactionSyncer = MockTransactionSyncer(realmFactory: mockRealmFactory, processor: mockTransactionProcessor)
        mockTransactionBuilder = MockTransactionBuilder(unspentOutputSelector: mockUnspentOutputSelector, unspentOutputProvider: mockUnspentOutputProvider, transactionSizeCalculator: mockTransactionSizeCalculator, addressConverter: mockAddressConverter, inputSigner: mockInputSigner, scriptBuilder: mockScriptBuilder, factory: mockFactory)
        mockTransactionCreator = MockTransactionCreator(realmFactory: mockRealmFactory, transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup, addressManager: mockAddressManager)
        mockBlockchain = MockBlockchain(network: mockNetwork, factory: mockFactory)

        mockBlockSyncer = MockBlockSyncer(realmFactory: mockRealmFactory, network: mockNetwork, progressSyncer: mockProgressSyncer, transactionProcessor: mockTransactionProcessor, blockchain: mockBlockchain, addressManager: mockAddressManager)
    }

}
