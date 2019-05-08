public class DirectoryHelper {

    public static func directoryURL(for directoryName: String) throws -> URL {
        let fileManager = FileManager.default

        let url = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(directoryName, isDirectory: true)

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    public static func removeDirectory(_ name: String) throws {
        try FileManager.default.removeItem(at: directoryURL(for: name))
    }

}