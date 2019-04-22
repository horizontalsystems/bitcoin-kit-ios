import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import DashKit

class MasternodeSortedListTests: QuickSpec {

    override func spec() {
        var list: MasternodeSortedList!

        beforeEach {
            list = MasternodeSortedList()
        }

        afterEach {
            list = nil
        }

        describe("#add") {
            let masternode1 = DashTestData.masternode(proRegTxHash: Data(repeating: 1, count: 2))
            let masternode2 = DashTestData.masternode(proRegTxHash: Data(repeating: 2, count: 2))
            let masternode3 = DashTestData.masternode(proRegTxHash: Data(repeating: 3, count: 2))

            it("adds to empty list") {
                list.add(masternodes: [masternode3, masternode1, masternode2])

                expect(list.masternodes).to(equal([masternode1, masternode2, masternode3]))
            }

            beforeEach {
                list.removeAll()

                list.add(masternodes: [masternode1, masternode2, masternode3])
            }

            it("adds to list new masternode") {
                let masternode = DashTestData.masternode(proRegTxHash: Data(repeating: 4, count: 2))
                list.add(masternodes: [masternode])

                expect(list.masternodes).to(equal([masternode1, masternode2, masternode3, masternode]))
            }

            it("updates masternode in list") {
                let masternode = DashTestData.masternode(proRegTxHash: Data(repeating: 1, count: 2), isValid: false)
                list.add(masternodes: [masternode])

                expect(list.masternodes).to(equal([masternode1, masternode2, masternode3]))
                expect(list.masternodes[0].isValid).to(equal(false))
            }

            it("removes masternode in list") {
                list.remove(masternodes: [masternode1])

                expect(list.masternodes).to(equal([masternode2, masternode3]))
            }

            it("removes masternode by hash in list") {
                list.remove(by: [Data(repeating: 2, count: 2), Data(repeating: 3, count: 2)])

                expect(list.masternodes).to(equal([masternode1]))
            }
        }
    }

}
