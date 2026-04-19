import Foundation

final class CountingInputStream: InputStream, @unchecked Sendable {
    private let backingStream: InputStream
    private(set) var bytesRead: Int64 = 0

    override init?(url: URL) {
        guard let stream = InputStream(url: url) else {
            return nil
        }
        self.backingStream = stream
        super.init(url: url)
    }

    override func open() {
        backingStream.open()
    }

    override func close() {
        backingStream.close()
    }

    override var hasBytesAvailable: Bool {
        backingStream.hasBytesAvailable
    }

    override var streamError: Error? {
        backingStream.streamError
    }

    override var streamStatus: Stream.Status {
        backingStream.streamStatus
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        let count = backingStream.read(buffer, maxLength: len)
        if count > 0 {
            bytesRead += Int64(count)
        }
        return count
    }

    override func property(forKey key: Stream.PropertyKey) -> Any? {
        backingStream.property(forKey: key)
    }

    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        backingStream.setProperty(property, forKey: key)
    }

    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        backingStream.schedule(in: aRunLoop, forMode: mode)
    }

    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
        backingStream.remove(from: aRunLoop, forMode: mode)
    }
}
