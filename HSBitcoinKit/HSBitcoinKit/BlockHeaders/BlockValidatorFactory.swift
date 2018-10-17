import Foundation

class BlockValidatorFactory {
    enum ValidatorType { case header, bits, legacy, testNet, EDA, DAA }

    let difficultyEncoder: DifficultyEncoder
    let blockHelper: BlockHelper

    init(difficultyEncoder: DifficultyEncoder, blockHelper: BlockHelper) {
        self.difficultyEncoder = difficultyEncoder
        self.blockHelper = blockHelper
    }

    func validator(for validatorType: ValidatorType) -> IBlockValidator {
        switch validatorType {
            case .header: return HeaderValidator()
            case .bits: return BitsValidator()
            case .testNet: return LegacyTestNetDifficultyValidator()
            case .legacy: return LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
            case .EDA: return EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
            case .DAA: return DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        }
    }

}
