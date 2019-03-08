class BlockValidatorFactory {
    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(difficultyEncoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        self.difficultyEncoder = difficultyEncoder
        self.blockHelper = blockHelper
    }
}

extension BlockValidatorFactory: IBlockValidatorFactory {

    func validator(for validatorType: BlockValidatorType) -> IBlockValidator {
        switch validatorType {
        case .header: return HeaderValidator(encoder: difficultyEncoder)
        case .bits: return BitsValidator()
        case .testNet: return LegacyTestNetDifficultyValidator()
        case .legacy: return LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        case .EDA: return EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        case .DAA: return DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        case .DGW: return DarkGravityWaveValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        }
    }

}
