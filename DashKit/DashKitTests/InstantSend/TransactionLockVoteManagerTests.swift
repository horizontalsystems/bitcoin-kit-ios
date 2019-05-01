import Foundation
import XCTest
import Quick
import Nimble
import Cuckoo
@testable import BitcoinCore
@testable import DashKit

class TransactionLockVoteManagerTests: QuickSpec {

    override func spec() {
        let mockLockVoteValidator = MockITransactionLockVoteValidator()
        var manager: TransactionLockVoteManager!

        beforeEach {
            manager = TransactionLockVoteManager(transactionLockVoteValidator: mockLockVoteValidator)
        }

        afterEach {
            manager = nil
        }

        let lockVotes = [DashTestData.transactionLockVote(txHash: Data(repeating: 0, count: 2), hash: Data(repeating: 5, count: 2)),
                     DashTestData.transactionLockVote(txHash: Data(repeating: 0, count: 2), hash: Data(repeating: 6, count: 2)),
                     DashTestData.transactionLockVote(txHash: Data(repeating: 2, count: 2), hash: Data(repeating: 7, count: 2)),
                     DashTestData.transactionLockVote(txHash: Data(repeating: 3, count: 2), hash: Data(repeating: 8, count: 2)),
        ]

        describe("#add(relayed: TransactionLockVoteMessage)") {
            it("has initially empty set") {
                let relayed = manager.takeRelayedLockVotes(for: lockVotes[0].txHash)

                expect(relayed).to(equal([]))
            }
            it("adds same lockVotes") {
                manager.add(relayed: lockVotes[0])
                manager.add(relayed: lockVotes[0])

                let relayed = manager.takeRelayedLockVotes(for: lockVotes[0].txHash)
                expect(relayed).to(equal([lockVotes[0]]))
            }
            it("adds different lockVotes") {
                manager.add(relayed: lockVotes[0])
                manager.add(relayed: lockVotes[1])

                let relayed = manager.takeRelayedLockVotes(for: lockVotes[0].txHash)
                expect(relayed).to(equal([lockVotes[0], lockVotes[1]]))
            }
        }
        describe("#takeRelayedLockVotes(for txHash: Data)") {
            beforeEach {
                lockVotes.forEach {
                    manager.add(relayed: $0)
                }
            }

            it("returns empty array") {
                let txHash = Data(repeating: 4, count: 2)
                let votes = manager.takeRelayedLockVotes(for: txHash)

                expect(votes).to(equal([]))
            }
            it("returns one element and remove it") {
                let txHash = Data(repeating: 3, count: 2)
                let votes = manager.takeRelayedLockVotes(for: txHash)

                expect(votes).to(equal([lockVotes[3]]))
                expect(manager.inRelayed(lvHash: lockVotes[3].hash)).to(equal(false))
            }
            // sorting and return for same elements checked in #add method
        }
        describe("#inRelayed(lvHash: Data) -> Bool") {
            beforeEach {
                lockVotes.forEach {
                    manager.add(relayed: $0)
                }
            }

            it("checks relayed") {
                let lvHash = Data(repeating: 5, count: 2)

                let votes = manager.inRelayed(lvHash: lvHash)
                expect(votes).to(equal(true))
            }
            it("checks not relayed") {
                let lvHash = Data(repeating: 4, count: 2)

                let votes = manager.inRelayed(lvHash: lvHash)
                expect(votes).to(equal(false))
            }
        }
        describe("#add(checked: TransactionLockVoteMessage)") {
            it("adds same lockVotes") {
                manager.add(checked: lockVotes[0])
                manager.add(checked: lockVotes[0])

                expect(manager.inChecked(lvHash: lockVotes[0].hash)).to(equal(true))
            }
            it("adds different lockVotes") {
                manager.add(checked: lockVotes[0])
                manager.add(checked: lockVotes[1])

                expect(manager.inChecked(lvHash: lockVotes[0].hash)).to(equal(true))
                expect(manager.inChecked(lvHash: lockVotes[1].hash)).to(equal(true))
            }
        }

        describe("#inChecked(lvHash: Data) -> Bool") {
            beforeEach {
                lockVotes.forEach {
                    manager.add(checked: $0)
                }
            }
            it("checks relayed") {
                let lvHash = Data(repeating: 5, count: 2)
                expect(manager.inChecked(lvHash: lvHash)).to(equal(true))
            }
            it("checks not relayed") {
                let lvHash = Data(repeating: 4, count: 2)
                expect(manager.inChecked(lvHash: lvHash)).to(equal(false))
            }
        }
        describe("#removeCheckedLockVotes(for txHash: Data)") {
            beforeEach {
                lockVotes.forEach {
                    manager.add(checked: $0)
                }
            }
            it("returns remove all elements for txHash but leave others") {
                let txHashForRemoving = lockVotes[0].txHash
                expect(manager.inChecked(lvHash: lockVotes[0].hash)).to(equal(true))
                expect(manager.inChecked(lvHash: lockVotes[1].hash)).to(equal(true))

                manager.removeCheckedLockVotes(for: txHashForRemoving)

                expect(manager.inChecked(lvHash: lockVotes[0].hash)).to(equal(false))
                expect(manager.inChecked(lvHash: lockVotes[1].hash)).to(equal(false))
            }
        }

    }

}
