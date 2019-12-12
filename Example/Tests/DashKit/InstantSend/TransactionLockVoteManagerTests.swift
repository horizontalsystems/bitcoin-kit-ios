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
                expect(manager.checkedLockVotes).to(equal([]))
            }
            it("adds same lockVotes") {
                manager.add(relayed: lockVotes[0])
                manager.add(relayed: lockVotes[0])

                expect(manager.relayedLockVotes.contains(lockVotes[0])).to(equal(true))
            }
            it("adds different lockVotes") {
                manager.add(relayed: lockVotes[0])
                manager.add(relayed: lockVotes[1])

                expect(manager.relayedLockVotes).to(equal([lockVotes[0], lockVotes[1]]))
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
                let txHash = Data(repeating: 0, count: 2)
                let votes = manager.takeRelayedLockVotes(for: txHash)

                expect(votes).to(equal([lockVotes[0], lockVotes[1]]))
            }
            // sorting and return for same elements checked in #add method
        }
        describe("#processed(lvHash: Data) -> Bool") {
            let relayed = [lockVotes[0], lockVotes[1]]
            let checked = [lockVotes[2], lockVotes[3]]
            beforeEach {
                relayed.forEach {
                    manager.add(relayed: $0)
                }
                checked.forEach {
                    manager.add(checked: $0)
                }
            }

            it("checks processed") {
                lockVotes.forEach {
                    let votes = manager.processed(lvHash: $0.hash)
                    expect(votes).to(equal(true))
                }
            }
            it("checks not processed") {
                let lvHash = Data(repeating: 4, count: 2)

                let votes = manager.processed(lvHash: lvHash)
                expect(votes).to(equal(false))
            }
        }
        describe("#add(checked: TransactionLockVoteMessage)") {
            it("adds same lockVotes") {
                manager.add(checked: lockVotes[0])
                manager.add(checked: lockVotes[0])

                expect(manager.checkedLockVotes.contains(lockVotes[0])).to(equal(true))
            }
            it("adds different lockVotes") {
                manager.add(checked: lockVotes[0])
                manager.add(checked: lockVotes[1])

                expect(manager.checkedLockVotes.contains(lockVotes[0])).to(equal(true))
                expect(manager.checkedLockVotes.contains(lockVotes[1])).to(equal(true))
            }
        }

        describe("#validate(lockVote: TransactionLockVoteMessage)") {
            it("checks call validate method") {
                stub(mockLockVoteValidator) { mock in
                    when(mock.validate(lockVote: equal(to: lockVotes[0]))).thenDoNothing()
                }
                try? manager.validate(lockVote: lockVotes[0])
                verify(mockLockVoteValidator).validate(lockVote: equal(to: lockVotes[0]))
            }
        }

    }

}
