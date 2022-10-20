import XCTest
import Cuckoo
@testable import BitcoinCore

class ConnectionTimeoutManagerTests:XCTestCase {

    private var generatedDate: Date!
    private var dateIsGenerated: Bool!
    private var dateGenerator: (() -> Date)!

    private var maxIdleTime = 60.0
    private var pingTimeout = 5.0
    private var mockPeer: MockIPeer!

    private var manager: ConnectionTimeoutManager!

    override func setUp() {
        super.setUp()

        dateIsGenerated = false
        generatedDate = Date()
        dateGenerator = {
            self.dateIsGenerated = true
            return self.generatedDate
        }
        mockPeer = MockIPeer()
        stub(mockPeer) { mock in
            when(mock.sendPing(nonce: any())).thenDoNothing()
            when(mock.disconnect(error: any())).thenDoNothing()
        }

        manager = ConnectionTimeoutManager(dateGenerator: dateGenerator, logger: nil)
    }

    override func tearDown() {
        generatedDate = nil
        dateIsGenerated = nil
        dateGenerator = nil
        mockPeer = nil
        manager = nil

        super.tearDown()
    }

    func testReset() {
        manager.reset()
        XCTAssertTrue(dateIsGenerated)
    }

    func testTimePeriodPassed_maxIdleTime_NotElapsed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        manager.reset()

        generatedDate = Date(timeIntervalSince1970: 1000000 + 1)
        manager.timePeriodPassed(peer: mockPeer)

        verifyNoMoreInteractions(mockPeer)
    }

    func testTimePeriodPassed_maxIdleTime_Elapsed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        manager.reset()

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxIdleTime + 1)
        manager.timePeriodPassed(peer: mockPeer)

        verify(mockPeer).sendPing(nonce: any())
    }

    func testTimePeriodPassed_maxIdleTime_Elapsed_pingTimeout_NotElapsed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        manager.reset()

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxIdleTime + 1)
        manager.timePeriodPassed(peer: mockPeer)

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxIdleTime + 1 + pingTimeout - 1)
        manager.timePeriodPassed(peer: mockPeer)

        verify(mockPeer, never()).disconnect(error: any())
    }

    func testTimePeriodPassed_maxIdleTime_Elapsed_pingTimeout_Elapsed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        manager.reset()

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxIdleTime + 1)
        manager.timePeriodPassed(peer: mockPeer)

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxIdleTime + 1 + pingTimeout + 1)
        manager.timePeriodPassed(peer: mockPeer)

        verify(mockPeer).disconnect(error: equal(to: ConnectionTimeoutManager.TimeoutError.pingTimedOut, equalWhen: { type(of: $0) == type(of: $1) }))
    }

}
