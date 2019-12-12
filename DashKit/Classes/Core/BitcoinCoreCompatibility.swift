import BitcoinCore

extension DifficultyEncoder: IDashDifficultyEncoder {}
extension BlockValidatorHelper: IDashBlockValidatorHelper {}
extension TransactionSizeCalculator: IDashTransactionSizeCalculator {}
extension TransactionSyncer: IDashTransactionSyncer {}

extension DoubleShaHasher: IDashHasher{}
