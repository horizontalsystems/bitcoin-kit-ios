import Foundation
import Cuckoo
import RealmSwift
@testable import WalletKit

class MockWalletKit {

    let mockDifficultyEncoder: MockDifficultyEncoder
    let mockBlockHelper: MockBlockHelper
    let mockIBlockValidator: MockIBlockValidator
    let mockValidatorFactory: MockBlockValidatorFactory

    let mockNetwork: MockNetworkProtocol

    let mockRealmFactory: MockRealmFactory

    let mockHdWallet: MockHDWallet

    let mockStateManager: MockStateManager
    let mockApiManager: MockApiManager
    let mockAddressManager: MockAddressManager
    let mockPeerHostManager: MockPeerHostManager

    let mockPeerGroup: MockPeerGroup
    let mockFactory: MockFactory

    let mockInitialSyncer: MockInitialSyncer
    let mockProgressSyncer: MockProgressSyncer

    let mockValidatedBlockFactory: MockValidatedBlockFactory

    let mockAddressConverter: MockAddressConverter
    let mockScriptConverter: MockScriptConverter
    let mockTransactionProcessor: MockTransactionProcessor
    let mockTransactionExtractor: MockTransactionExtractor
    let mockTransactionLinker: MockTransactionLinker
    let mockTransactionSyncer: MockTransactionSyncer
    let mockTransactionCreator: MockTransactionCreator
    let mockTransactionBuilder: MockTransactionBuilder

    let mockInputSigner: MockInputSigner
    let mockScriptBuilder: MockScriptBuilder
    let mockTransactionSizeCalculator: MockTransactionSizeCalculator
    let mockUnspentOutputSelector: MockUnspentOutputSelector
    let mockUnspentOutputProvider: MockUnspentOutputProvider

    let mockHeaderSyncer: MockHeaderSyncer
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

        stub(mockNetwork) { mock in
            when(mock.coinType.get).thenReturn(1)
            when(mock.dnsSeeds.get).thenReturn([""])
            when(mock.port.get).thenReturn(0)
        }

        mockRealmFactory = MockRealmFactory(configuration: Realm.Configuration())

        mockHdWallet = MockHDWallet(seed: Data(), network: mockNetwork)

        mockStateManager = MockStateManager(realmFactory: mockRealmFactory)
        mockApiManager = MockApiManager(apiUrl: "")
        mockPeerHostManager = MockPeerHostManager(network: mockNetwork, realmFactory: mockRealmFactory)

        stub(mockPeerHostManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
        }

        mockPeerGroup = MockPeerGroup(network: mockNetwork, peerHostManager: mockPeerHostManager, bloomFilters: [Data]())
        mockFactory = MockFactory()

        mockInitialSyncer = MockInitialSyncer(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, stateManager: mockStateManager, apiManager: mockApiManager, factory: mockFactory, peerGroup: mockPeerGroup, network: mockNetwork)
        mockProgressSyncer = MockProgressSyncer(realmFactory: mockRealmFactory)
        mockAddressManager = MockAddressManager(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, peerGroup: mockPeerGroup)

        mockValidatedBlockFactory = MockValidatedBlockFactory(realmFactory: mockRealmFactory, factory: mockFactory, network: mockNetwork)

        mockInputSigner = MockInputSigner(hdWallet: mockHdWallet)
        mockScriptBuilder = MockScriptBuilder()

        mockTransactionSizeCalculator = MockTransactionSizeCalculator()
        mockUnspentOutputSelector = MockUnspentOutputSelector(calculator: mockTransactionSizeCalculator)
        mockUnspentOutputProvider = MockUnspentOutputProvider(realmFactory: mockRealmFactory)

        mockAddressConverter = MockAddressConverter(network: mockNetwork)
        mockScriptConverter = MockScriptConverter()
        mockTransactionExtractor = MockTransactionExtractor(scriptConverter: mockScriptConverter, addressConverter: mockAddressConverter)
        mockTransactionLinker = MockTransactionLinker()
        mockTransactionProcessor = MockTransactionProcessor(realmFactory: mockRealmFactory, extractor: mockTransactionExtractor, linker: mockTransactionLinker, addressManager: mockAddressManager)
        mockTransactionSyncer = MockTransactionSyncer(realmFactory: mockRealmFactory, processor: mockTransactionProcessor)
        mockTransactionBuilder = MockTransactionBuilder(unspentOutputSelector: mockUnspentOutputSelector, unspentOutputProvider: mockUnspentOutputProvider, transactionSizeCalculator: mockTransactionSizeCalculator, addressConverter: mockAddressConverter, inputSigner: mockInputSigner, scriptBuilder: mockScriptBuilder, factory: mockFactory)
        mockTransactionCreator = MockTransactionCreator(realmFactory: mockRealmFactory, transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup, addressManager: mockAddressManager)

        mockHeaderSyncer = MockHeaderSyncer(realmFactory: mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, network: mockNetwork)
        mockBlockSyncer = MockBlockSyncer(realmFactory: mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, processor: mockTransactionProcessor, progressSyncer: mockProgressSyncer)

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }
    }

}
