import OpenSslKit

public class DoubleShaHasher: IHasher {

    public init() {}

    public func hash(data: Data) -> Data {
        Kit.sha256sha256(data)
    }

}
