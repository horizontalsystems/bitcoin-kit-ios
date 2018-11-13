import XCTest
import Cuckoo
import HSHDWalletKit
import RealmSwift
@testable import HSBitcoinKit

class BloomFilterManagerTests: XCTestCase {

    private var mockRealmFactory: MockIRealmFactory!
    private var mockFactory: MockIFactory!

    private var realm: Realm!
    private var hdWallet: IHDWallet!
    private var manager: BloomFilterManager!

    override func setUp() {
        super.setUp()

        mockRealmFactory = MockIRealmFactory()
        mockFactory = MockIFactory()
        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }
        stub(mockRealmFactory) {mock in
            when(mock.realm.get).thenReturn(realm)
        }

        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = BloomFilterManager(realmFactory: mockRealmFactory, factory: mockFactory)
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockFactory = nil
        manager = nil

        super.tearDown()
    }

    func testRegenerateBloomFilter() {

    }


    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(index: index, external: chain == .external)
        return PublicKey(withIndex: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }

}
