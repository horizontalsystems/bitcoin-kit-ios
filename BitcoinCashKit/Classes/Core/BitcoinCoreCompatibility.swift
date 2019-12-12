import BitcoinCore

extension DifficultyEncoder: IBitcoinCashDifficultyEncoder {}
extension BlockValidatorHelper: IBlockValidatorHelperWrapper {}
extension DAAValidator: IBitcoinCashBlockValidator {}
extension BlockMedianTimeHelper: IBitcoinCashBlockMedianTimeHelper {}
