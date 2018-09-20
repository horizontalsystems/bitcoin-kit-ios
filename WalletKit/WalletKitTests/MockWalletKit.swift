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
    let mockPeerIpManager: MockPeerIpManager

    let mockPeerGroup: MockPeerGroup
    let mockSyncer: MockSyncer
    let mockFactory: MockFactory

    let mockInitialSyncer: MockInitialSyncer
    let mockProgressSyncer: MockProgressSyncer

    let mockValidatedBlockFactory: MockValidatedBlockFactory

    let mockHeaderSyncer: MockHeaderSyncer
    let mockHeaderHandler: MockHeaderHandler

    let mockAddressConverter: MockAddressConverter
    let mockScriptConverter: MockScriptConverter
    let mockTransactionProcessor: MockTransactionProcessor
    let mockTransactionExtractor: MockTransactionExtractor
    let mockTransactionLinker: MockTransactionLinker
    let mockTransactionHandler: MockTransactionHandler
    let mockTransactionCreator: MockTransactionCreator
    let mockTransactionBuilder: MockTransactionBuilder

    let mockInputSigner: MockInputSigner
    let mockScriptBuilder: MockScriptBuilder
    let mockTransactionSizeCalculator: MockTransactionSizeCalculator
    let mockUnspentOutputSelector: MockUnspentOutputSelector
    let mockUnspentOutputProvider: MockUnspentOutputProvider

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
        mockPeerIpManager = MockPeerIpManager(network: mockNetwork, realmFactory: mockRealmFactory)

        stub(mockPeerIpManager) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
        }

        mockPeerGroup = MockPeerGroup(network: mockNetwork, peerIpManager: mockPeerIpManager, bloomFilters: [Data]())
        mockSyncer = MockSyncer(realmFactory: mockRealmFactory)
        mockFactory = MockFactory()

        mockInitialSyncer = MockInitialSyncer(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, stateManager: mockStateManager, apiManager: mockApiManager, factory: mockFactory, peerGroup: mockPeerGroup, network: mockNetwork)
        mockProgressSyncer = MockProgressSyncer(realmFactory: mockRealmFactory)
        mockAddressManager = MockAddressManager(realmFactory: mockRealmFactory, hdWallet: mockHdWallet, peerGroup: mockPeerGroup)

        mockValidatedBlockFactory = MockValidatedBlockFactory(realmFactory: mockRealmFactory, factory: mockFactory, network: mockNetwork)

        mockHeaderSyncer = MockHeaderSyncer(realmFactory: mockRealmFactory, network: mockNetwork)
        mockHeaderHandler = MockHeaderHandler(realmFactory: mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, peerGroup: mockPeerGroup)

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
        mockTransactionHandler = MockTransactionHandler(realmFactory: mockRealmFactory, processor: mockTransactionProcessor, progressSyncer: mockProgressSyncer, validateBlockFactory: mockValidatedBlockFactory)
        mockTransactionBuilder = MockTransactionBuilder(unspentOutputSelector: mockUnspentOutputSelector, unspentOutputProvider: mockUnspentOutputProvider, transactionSizeCalculator: mockTransactionSizeCalculator, addressConverter: mockAddressConverter, inputSigner: mockInputSigner, scriptBuilder: mockScriptBuilder, factory: mockFactory)
        mockTransactionCreator = MockTransactionCreator(realmFactory: mockRealmFactory, transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup, addressManager: mockAddressManager)

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }
    }

}
