import Foundation

public extension String {
    func appendLine(to path: String) throws {
        let line = self + "\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let fileHandle = FileHandle(forWritingAtPath: path) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try data.write(to: URL(fileURLWithPath: path))
            }
        }
    }
}
