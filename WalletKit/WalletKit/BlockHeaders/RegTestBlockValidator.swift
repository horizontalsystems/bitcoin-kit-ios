import Foundation

class RegTestBlockValidator: BlockValidator {

    override func validate(block: Block) throws {
        try validateHash(block: block)
        // all blocks has equal bits.
    }

}
