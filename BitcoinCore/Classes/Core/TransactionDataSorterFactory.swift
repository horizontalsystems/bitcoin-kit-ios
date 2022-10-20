import Foundation

class TransactionDataSorterFactory: ITransactionDataSorterFactory {

    func sorter(for type: TransactionDataSortType) -> ITransactionDataSorter {
        switch type {
        case .none: return StraightSorter()
        case .shuffle: return ShuffleSorter()
        case .bip69: return Bip69Sorter()
        }
    }

}
