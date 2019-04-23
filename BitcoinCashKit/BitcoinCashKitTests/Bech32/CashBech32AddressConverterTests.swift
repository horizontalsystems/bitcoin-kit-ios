//
//  CashAddrBech32Tests.swift
//
//  Copyright © 2018 BitcoinCashKit developers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
import Cuckoo
@testable import BitcoinCore
@testable import BitcoinCashKit

class CashBech32AddressConverterTests: XCTestCase {
    private var cashBech32Converter: CashBech32AddressConverter!

    override func setUp() {
        super.setUp()
        cashBech32Converter = CashBech32AddressConverter(prefix: "bitcoincash")
    }

    override func tearDown() {
        cashBech32Converter = nil

        super.tearDown()
    }

    func testAll() {
        // invalid strings
        // empty string
        checkError(prefix: "bitcoincash", address: "")
        checkError(prefix: "bitcoincash", address: " ")
        // invalid upper and lower case at the same time "Q" "zdvr2hn0xrz99fcp6hkjxzk848rjvvhgytv4fket8"
        checkError(prefix: "bitcoincash", address: "bitcoincash:Qzdvr2hn0xrz99fcp6hkjxzk848rjvvhgytv4fket8")
        // invalid prefix "bitcoincash012345"
        checkError(prefix: "bitcoincash", address: "bitcoincash012345:qzdvr2hn0xrz99fcp6hkjxzk848rjvvhgytv4fket8")
        // invalid character "1"
        checkError(prefix: "bitcoincash", address: "bitcoincash:111112hn0xrz99fcp6hkjxzk848rjvvhgytv411111")
        // unexpected character "💦😆"
        checkError(prefix: "bitcoincash", address: "bitcoincash:qzdvr2hn0xrz99fcp6hkjxzk848rjvvhgytv4fket8💦😆")
        // invalid checksum
        checkError(prefix: "bitcoincash", address: "bitcoincash:zzzzz2hn0xrz99fcp6hkjxzk848rjvvhgytv4zzzzz")


        // The following test cases are from the spec about cashaddr
        // https://github.com/bitcoincashorg/bitcoincash.org/blob/master/spec/cashaddr.md

        cashBech32Converter = CashBech32AddressConverter(prefix: "bitcoincash")
        let bchTestConverter = CashBech32AddressConverter(prefix: "bchtest")
        let prefConverter = CashBech32AddressConverter(prefix: "pref")
        HexEncodesToBech32(hex: "F5BF48B397DAE70BE82B3CCA4793F8EB2B6CDAC9", converter: cashBech32Converter, cashBech32: "bitcoincash:qr6m7j9njldwwzlg9v7v53unlr4jkmx6eylep8ekg2", version: 0, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "F5BF48B397DAE70BE82B3CCA4793F8EB2B6CDAC9", converter: bchTestConverter, cashBech32: "bchtest:pr6m7j9njldwwzlg9v7v53unlr4jkmx6eyvwc0uz5t", version: 8, scriptType: .p2sh)
        HexEncodesToBech32(hex: "F5BF48B397DAE70BE82B3CCA4793F8EB2B6CDAC9", converter: prefConverter, cashBech32: "pref:pr6m7j9njldwwzlg9v7v53unlr4jkmx6ey65nvtks5", version: 8, scriptType: .p2sh)

        HexEncodesToBech32(hex: "7ADBF6C17084BC86C1706827B41A56F5CA32865925E946EA", converter: cashBech32Converter, cashBech32: "bitcoincash:q9adhakpwzztepkpwp5z0dq62m6u5v5xtyj7j3h2ws4mr9g0", version: 1, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "7ADBF6C17084BC86C1706827B41A56F5CA32865925E946EA", converter: bchTestConverter, cashBech32: "bchtest:p9adhakpwzztepkpwp5z0dq62m6u5v5xtyj7j3h2u94tsynr", version: 9, scriptType: .p2sh)
        HexEncodesToBech32(hex: "7ADBF6C17084BC86C1706827B41A56F5CA32865925E946EA", converter: prefConverter, cashBech32: "pref:p9adhakpwzztepkpwp5z0dq62m6u5v5xtyj7j3h2khlwwk5v", version: 9, scriptType: .p2sh)

        HexEncodesToBech32(hex: "3A84F9CF51AAE98A3BB3A78BF16A6183790B18719126325BFC0C075B", converter: cashBech32Converter, cashBech32: "bitcoincash:qgagf7w02x4wnz3mkwnchut2vxphjzccwxgjvvjmlsxqwkcw59jxxuz", version: 2, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "3A84F9CF51AAE98A3BB3A78BF16A6183790B18719126325BFC0C075B", converter: bchTestConverter, cashBech32: "bchtest:pgagf7w02x4wnz3mkwnchut2vxphjzccwxgjvvjmlsxqwkcvs7md7wt", version: 10, scriptType: .p2sh)
        HexEncodesToBech32(hex: "3A84F9CF51AAE98A3BB3A78BF16A6183790B18719126325BFC0C075B", converter: prefConverter, cashBech32: "pref:pgagf7w02x4wnz3mkwnchut2vxphjzccwxgjvvjmlsxqwkcrsr6gzkn", version: 10, scriptType: .p2sh)

        HexEncodesToBech32(hex: "3173EF6623C6B48FFD1A3DCC0CC6489B0A07BB47A37F47CFEF4FE69DE825C060", converter: cashBech32Converter, cashBech32: "bitcoincash:qvch8mmxy0rtfrlarg7ucrxxfzds5pamg73h7370aa87d80gyhqxq5nlegake", version: 3, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "3173EF6623C6B48FFD1A3DCC0CC6489B0A07BB47A37F47CFEF4FE69DE825C060", converter: bchTestConverter, cashBech32: "bchtest:pvch8mmxy0rtfrlarg7ucrxxfzds5pamg73h7370aa87d80gyhqxq7fqng6m6", version: 11, scriptType: .p2sh)
        HexEncodesToBech32(hex: "3173EF6623C6B48FFD1A3DCC0CC6489B0A07BB47A37F47CFEF4FE69DE825C060", converter: prefConverter, cashBech32: "pref:pvch8mmxy0rtfrlarg7ucrxxfzds5pamg73h7370aa87d80gyhqxq4k9m7qf9", version: 11, scriptType: .p2sh)

        HexEncodesToBech32(hex: "C07138323E00FA4FC122D3B85B9628EA810B3F381706385E289B0B25631197D194B5C238BEB136FB", converter: cashBech32Converter, cashBech32: "bitcoincash:qnq8zwpj8cq05n7pytfmskuk9r4gzzel8qtsvwz79zdskftrzxtar994cgutavfklv39gr3uvz", version: 4, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "C07138323E00FA4FC122D3B85B9628EA810B3F381706385E289B0B25631197D194B5C238BEB136FB", converter: bchTestConverter, cashBech32: "bchtest:pnq8zwpj8cq05n7pytfmskuk9r4gzzel8qtsvwz79zdskftrzxtar994cgutavfklvmgm6ynej", version: 12, scriptType: .p2sh)
        HexEncodesToBech32(hex: "C07138323E00FA4FC122D3B85B9628EA810B3F381706385E289B0B25631197D194B5C238BEB136FB", converter: prefConverter, cashBech32: "pref:pnq8zwpj8cq05n7pytfmskuk9r4gzzel8qtsvwz79zdskftrzxtar994cgutavfklv0vx5z0w3", version: 12, scriptType: .p2sh)

        HexEncodesToBech32(hex: "E361CA9A7F99107C17A622E047E3745D3E19CF804ED63C5C40C6BA763696B98241223D8CE62AD48D863F4CB18C930E4C", converter: cashBech32Converter, cashBech32: "bitcoincash:qh3krj5607v3qlqh5c3wq3lrw3wnuxw0sp8dv0zugrrt5a3kj6ucysfz8kxwv2k53krr7n933jfsunqex2w82sl", version: 5, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "E361CA9A7F99107C17A622E047E3745D3E19CF804ED63C5C40C6BA763696B98241223D8CE62AD48D863F4CB18C930E4C", converter: bchTestConverter, cashBech32: "bchtest:ph3krj5607v3qlqh5c3wq3lrw3wnuxw0sp8dv0zugrrt5a3kj6ucysfz8kxwv2k53krr7n933jfsunqnzf7mt6x", version: 13, scriptType: .p2sh)
        HexEncodesToBech32(hex: "E361CA9A7F99107C17A622E047E3745D3E19CF804ED63C5C40C6BA763696B98241223D8CE62AD48D863F4CB18C930E4C", converter: prefConverter, cashBech32: "pref:ph3krj5607v3qlqh5c3wq3lrw3wnuxw0sp8dv0zugrrt5a3kj6ucysfz8kxwv2k53krr7n933jfsunqjntdfcwg", version: 13, scriptType: .p2sh)

        HexEncodesToBech32(hex: "D9FA7C4C6EF56DC4FF423BAAE6D495DBFF663D034A72D1DC7D52CBFE7D1E6858F9D523AC0A7A5C34077638E4DD1A701BD017842789982041", converter: cashBech32Converter, cashBech32: "bitcoincash:qmvl5lzvdm6km38lgga64ek5jhdl7e3aqd9895wu04fvhlnare5937w4ywkq57juxsrhvw8ym5d8qx7sz7zz0zvcypqscw8jd03f", version: 6, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "D9FA7C4C6EF56DC4FF423BAAE6D495DBFF663D034A72D1DC7D52CBFE7D1E6858F9D523AC0A7A5C34077638E4DD1A701BD017842789982041", converter: bchTestConverter, cashBech32: "bchtest:pmvl5lzvdm6km38lgga64ek5jhdl7e3aqd9895wu04fvhlnare5937w4ywkq57juxsrhvw8ym5d8qx7sz7zz0zvcypqs6kgdsg2g", version: 14, scriptType: .p2sh)
        HexEncodesToBech32(hex: "D9FA7C4C6EF56DC4FF423BAAE6D495DBFF663D034A72D1DC7D52CBFE7D1E6858F9D523AC0A7A5C34077638E4DD1A701BD017842789982041", converter: prefConverter, cashBech32: "pref:pmvl5lzvdm6km38lgga64ek5jhdl7e3aqd9895wu04fvhlnare5937w4ywkq57juxsrhvw8ym5d8qx7sz7zz0zvcypqsammyqffl", version: 14, scriptType: .p2sh)

        HexEncodesToBech32(hex: "D0F346310D5513D9E01E299978624BA883E6BDA8F4C60883C10F28C2967E67EC77ECC7EEEAEAFC6DA89FAD72D11AC961E164678B868AEEEC5F2C1DA08884175B", converter: cashBech32Converter, cashBech32: "bitcoincash:qlg0x333p4238k0qrc5ej7rzfw5g8e4a4r6vvzyrcy8j3s5k0en7calvclhw46hudk5flttj6ydvjc0pv3nchp52amk97tqa5zygg96mtky5sv5w", version: 7, scriptType: .p2pkh)
        HexEncodesToBech32(hex: "D0F346310D5513D9E01E299978624BA883E6BDA8F4C60883C10F28C2967E67EC77ECC7EEEAEAFC6DA89FAD72D11AC961E164678B868AEEEC5F2C1DA08884175B", converter: bchTestConverter, cashBech32: "bchtest:plg0x333p4238k0qrc5ej7rzfw5g8e4a4r6vvzyrcy8j3s5k0en7calvclhw46hudk5flttj6ydvjc0pv3nchp52amk97tqa5zygg96mc773cwez", version: 15, scriptType: .p2sh)
        HexEncodesToBech32(hex: "D0F346310D5513D9E01E299978624BA883E6BDA8F4C60883C10F28C2967E67EC77ECC7EEEAEAFC6DA89FAD72D11AC961E164678B868AEEEC5F2C1DA08884175B", converter: prefConverter, cashBech32: "pref:plg0x333p4238k0qrc5ej7rzfw5g8e4a4r6vvzyrcy8j3s5k0en7calvclhw46hudk5flttj6ydvjc0pv3nchp52amk97tqa5zygg96mg7pj3lh8", version: 15, scriptType: .p2sh)
    }

    func checkError(prefix: String, address: String) {
        do {
            let _ = try cashBech32Converter.convert(address: address)
            XCTFail("No error found!")
        } catch let error as BitcoinCoreErrors.AddressConversion {
            XCTAssertEqual(error, BitcoinCoreErrors.AddressConversion.unknownAddressType)
        } catch {
            XCTFail("Wrong \(error) exception")
        }

    }

    func HexEncodesToBech32(hex: String, converter: IAddressConverter, cashBech32: String, version: UInt8, scriptType: ScriptType) {
        //Encode
        let data = Data(hex: hex)!
        do {
            let address = try converter.convert(keyHash: data, type: scriptType)
            XCTAssertEqual(address.scriptType, scriptType)
            XCTAssertEqual(address.keyHash, data)
            XCTAssertEqual(address.stringValue, cashBech32)
            XCTAssertEqual(address.type, version >= 8 ? .scriptHash : .pubKeyHash)
            if let address = address as? CashAddress {
                XCTAssertEqual(address.version, version)
            } else {
                XCTFail("Not cash address")
            }
        } catch {
            XCTFail("Exception \(error)")
        }
    }

}
