import Foundation

class BlockSyncerState {
    private(set) var iterationHasPartialBlocks: Bool = false

    func iteration(hasPartialBlocks state: Bool) {
        iterationHasPartialBlocks = state
    }
}
