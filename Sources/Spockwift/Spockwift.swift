public struct Spockwift {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}



/// A type that can decode itself from an external representation.
public protocol Decoding {

    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    init(from decoder: Decoder) throws
}

extension String: Error {}

extension Decoding {
    init(from decoder: Decoder) throws {
        throw "Not create"
    }
}

struct Algo: Decoding {
    
    var algo: String
}
