class BlockValidatorFactory {
    let storage: IStorage
    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(storage: IStorage, difficultyEncoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        self.storage = storage
        self.difficultyEncoder = difficultyEncoder
        self.blockHelper = blockHelper
    }
}

extension BlockValidatorFactory: IBlockValidatorFactory {

    func validator(for validatorType: BlockValidatorType) -> IBlockValidator {
        switch validatorType {
        case .header: return HeaderValidator(encoder: difficultyEncoder)
        case .bits: return BitsValidator()
        case .testNet: return LegacyTestNetDifficultyValidator(storage: storage)
        case .legacy: return LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        case .EDA: return EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper)
        case .DAA: return DAAValidator(storage: storage, encoder: difficultyEncoder, blockHelper: blockHelper)
        }
    }

}
