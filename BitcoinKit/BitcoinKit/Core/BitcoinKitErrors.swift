public class BitcoinKitErrors {

    public enum AddressConversion: Error {
        case noSegWitAddress
        case noSegWitType
    }

}
