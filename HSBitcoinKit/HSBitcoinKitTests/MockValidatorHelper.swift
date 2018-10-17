import Foundation
import Cuckoo
@testable import HSBitcoinKit

class MockValidatorHelper {

    var mockFactory: MockBlockValidatorFactory

    var mockHeaderValidator: MockIBlockValidator
    var mockBitsValidator: MockIBlockValidator
    var mockLegacyValidator: MockIBlockValidator
    var mockLegacyTestNetValidator: MockIBlockValidator
    var mockDAAValidator: MockIBlockValidator
    var mockEDAValidator: MockIBlockValidator

    init(mockBitcoinKit: MockBitcoinKit) {
        mockFactory = mockBitcoinKit.mockValidatorFactory

        mockHeaderValidator = MockIBlockValidator()
        stub(mockHeaderValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        mockBitsValidator = MockIBlockValidator()
        stub(mockBitsValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        mockLegacyValidator = MockIBlockValidator()
        stub(mockLegacyValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        mockLegacyTestNetValidator = MockIBlockValidator()
        stub(mockLegacyTestNetValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        mockDAAValidator = MockIBlockValidator()
        stub(mockDAAValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        mockEDAValidator = MockIBlockValidator()
        stub(mockEDAValidator) { mock in
            when(mock.validate(candidate: any(), block: any(), network: any())).thenDoNothing()
        }
        stub(mockFactory) { mock in
            when(mock.validator(for: equal(to: .header))).thenReturn(mockHeaderValidator)
            when(mock.validator(for: equal(to: .bits))).thenReturn(mockBitsValidator)
            when(mock.validator(for: equal(to: .legacy))).thenReturn(mockLegacyValidator)
            when(mock.validator(for: equal(to: .testNet))).thenReturn(mockLegacyTestNetValidator)
            when(mock.validator(for: equal(to: .EDA))).thenReturn(mockEDAValidator)
            when(mock.validator(for: equal(to: .DAA))).thenReturn(mockDAAValidator)
        }

    }

}
