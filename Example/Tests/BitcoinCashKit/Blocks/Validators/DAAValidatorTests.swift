import XCTest
import Cuckoo
@testable import BitcoinCore
@testable import BitcoinCashKit

class DAAValidatorTests: XCTestCase {
    private let bitsArray = [402767433, 402767160, 402767859, 402769255, 402769073, 402768230, 402768938, 402770129, 402769178, 402768431, 402768344, 402768058, 402770579, 402770265, 402769425, 402770133, 402770219, 402770568, 402769751, 402771344,
                             402774815, 402776069, 402775738, 402776029, 402776668, 402776963, 402777030, 402777486, 402777676, 402777850, 402778389, 402777853, 402777917, 402778925, 402778150, 402776959, 402777541, 402777275, 402776614, 402776265,
                             402775085, 402776388, 402776022, 402781121, 402779383, 402780026, 402780560, 402781377, 402781639, 402782369, 402782262, 402782501, 402781920, 402778431, 402777875, 402778488, 402778162, 402782064, 402781536, 402780576,
                             402780417, 402779271, 402779413, 402779788, 402780701, 402779986, 402781638, 402780582, 402782111, 402782023, 402781298, 402782926, 402782587, 402782374, 402782451, 402783036, 402782787, 402782866, 402785537, 402785404,
                             402785252, 402784800, 402784388, 402784384, 402786868, 402788360, 402788623, 402788330, 402788717, 402789228, 402789871, 402790079, 402790023, 402789814, 402789044, 402788470, 402788538, 402789725, 402789457, 402789246,
                             402789231, 402789817, 402789385, 402788616, 402789043, 402788902, 402787857, 402785442, 402784682, 402785035, 402786724, 402787705, 402790426, 402792855, 402793573, 402793315, 402792921, 402792516, 402792972, 402791014,
                             402789795, 402789735, 402789753, 402788776, 402788733, 402788222, 402787366, 402787077, 402785903, 402785470, 402785407, 402785746, 402786248, 402785956, 402784777, 402779948, 402779736, 402779667, 402781944, 402783593,
                             402784052, 402784620, 402786084, 402784457, 402782480, 402782849, 402781867, 402780446, 402780490, 402780410, 402779819, 402779544, 402780526, 402779837, 402780226, 402781418, 402778933, 402780586, 402780729, 402780332,
                             402780383, 402778461, 402778469, 402779123, 402775348, 402775650, 402777259, 402776904, 402778138, 402779910, 402781496, 402782315, 402781953, 402784546, 402782688, 402784672, 402785706, 402785254, 402790104, 402791738,
                             402792541, 402792952, 402792917, 402794729, 402794723, 402793392, 402793524, 402788688, 402791629, 402792162, 402792893, 402793340, 402794146, 402795886, 402796014, 402794823, 402794627, 402795020, 402794758, 402795508]

    private let timestampArray = [1534692576, 1534693663, 1534693995, 1534694138, 1534695348, 1534696396, 1534696419, 1534696941, 1534697105, 1534697149, 1534699039, 1534699259, 1534699320, 1534699919, 1534700218, 1534701579, 1534701682, 1534703052, 1534705846, 1534706820,
                                  1534706916, 1534707344, 1534708220, 1534708496, 1534708760, 1534709180, 1534709647, 1534709970, 1534711721, 1534711835, 1534712110, 1534712958, 1534713719, 1534714227, 1534714820, 1534714964, 1534715189, 1534715317, 1534715540, 1534716543,
                                  1534716620, 1534720460, 1534720507, 1534720953, 1534721684, 1534722494, 1534722680, 1534723189, 1534723220, 1534724252, 1534724596, 1534724909, 1534725260, 1534725847, 1534725973, 1534728904, 1534729325, 1534729900, 1534730155, 1534730317,
                                  1534730900, 1534731800, 1534732502, 1534732549, 1534733804, 1534734537, 1534735934, 1534737036, 1534737121, 1534738423, 1534738611, 1534739296, 1534739444, 1534739859, 1534739960, 1534740549, 1534742748, 1534742792, 1534742886, 1534743800,
                                  1534744431, 1534744450, 1534746241, 1534748488, 1534748581, 1534749377, 1534750209, 1534750609, 1534751075, 1534751148, 1534751183, 1534751344, 1534751379, 1534752873, 1534752888, 1534753741, 1534754135, 1534754719, 1534754806, 1534755196,
                                  1534755374, 1534755557, 1534755827, 1534755924, 1534756357, 1534756456, 1534756520, 1534756864, 1534758162, 1534758945, 1534761518, 1534763240, 1534764480, 1534764958, 1534765043, 1534765130, 1534765387, 1534765868, 1534766168, 1534767148,
                                  1534767633, 1534767653, 1534768040, 1534768520, 1534768580, 1534769111, 1534769654, 1534769757, 1534769793, 1534770036, 1534770327, 1534770411, 1534772903, 1534772944, 1534773192, 1534773280, 1534774833, 1534776308, 1534776682, 1534777031,
                                  1534778060, 1534778536, 1534778717, 1534779080, 1534779236, 1534779285, 1534779574, 1534779606, 1534780360, 1534781160, 1534781785, 1534781797, 1534782163, 1534782945, 1534783111, 1534784367, 1534784480, 1534784761, 1534785036, 1534785064,
                                  1534785121, 1534786886, 1534787123, 1534788260, 1534789423, 1534789617, 1534791306, 1534792756, 1534794067, 1534795017, 1534795222, 1534797244, 1534797740, 1534799140, 1534800080, 1534800595, 1534804536, 1534806096, 1534807163, 1534807507,
                                  1534807636, 1534808886, 1534809025, 1534809060, 1534809128, 1534809700, 1534811600, 1534812360, 1534813513, 1534814559, 1534815216, 1534816810, 1534816866, 1534817055, 1534817207, 1534817720, 1534817840, 1534818838, 1534819474, 1534820021] // 544319

    private var validator: DAAValidator!
    private var mockBlockHelper: MockIBitcoinCashBlockValidatorHelper!

    private var blocks = [Block]()

    override func setUp() {
        super.setUp()

        mockBlockHelper = MockIBitcoinCashBlockValidatorHelper()

        blocks.append(Block(
            withHeader: BlockHeader(
                    version: 536870912,
                    headerHash: Data(),
                    previousBlockHeaderHash: "000000000000000000c27f91198eb5505005a0863d8deb696a27e2f5bfffe70b".reversedData!,
                    merkleRoot: "1530edf433fdfd7252bda07bf38629e2c31f31560dbd30dd7f496c4b6fe7e27d".reversedData!,
                    timestamp: 1534820198,
                    bits: 402796414,
                    nonce: 1748283264
            ),
            height: 544320)
        )

        for i in 0..<147 {
            let block = Block(
                    withHeader: BlockHeader(version: 536870912, headerHash: Data(from: i), previousBlockHeaderHash: Data(from: i), merkleRoot: Data(), timestamp: timestampArray[timestampArray.count - i - 1], bits: bitsArray[bitsArray.count - i - 1], nonce: 0),
                    height: blocks[0].height - i - 1
            )
            blocks.append(block)
        }
        stub(mockBlockHelper) { mock in
            when(mock.previousWindow(for: equal(to: blocks[1]), count: 146)).thenReturn(Array(blocks[2...147].reversed()))
            when(mock.suitableBlockIndex(for: equal(to: [blocks[145], blocks[146], blocks[147]].reversed()))).thenReturn(1)
            when(mock.suitableBlockIndex(for: equal(to: [blocks[1], blocks[2], blocks[3]].reversed()))).thenReturn(1)
        }

        validator = DAAValidator(encoder: DifficultyEncoder(), blockHelper: mockBlockHelper, targetSpacing: 600, heightInterval: 144)
    }

    override func tearDown() {
        validator = nil
        mockBlockHelper = nil

        blocks.removeAll()

        super.tearDown()
    }

    // MAKE real test data from bitcoin cash mainnet
    func testValidate() {
        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testTrustFirstBlocks() {
        blocks[1].height = 544320 - 1 - 1 // previous block nearly than 148 blocks to checkpoint height

        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNoPreviousBlock() {
        stub(mockBlockHelper) { mock in
            when(mock.previousWindow(for: equal(to: blocks[1]), count: 146)).thenReturn(nil)
        }

        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }

    }

    func testNoPreviousBlock_FirstSuitable() {
        stub(mockBlockHelper) { mock in
            when(mock.suitableBlockIndex(for: equal(to: [blocks[145], blocks[146], blocks[147]].reversed()))).thenReturn(nil)
        }

        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }

    }

    func testNoPreviousBlock_SecondSuitable() {
        stub(mockBlockHelper) { mock in
            when(mock.suitableBlockIndex(for: equal(to: [blocks[1], blocks[2], blocks[3]].reversed()))).thenReturn(nil)
        }

        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }

    }

}
