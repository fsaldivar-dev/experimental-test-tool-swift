//
//  UnkeyedDecodingContainer.swift
//  Spockwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//
extension Array where Element: Comparable {
    public func containsSameElements(as other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }
    
    public func equals(as other: [Element]) -> Bool {
        return zip(self, other).enumerated().filter { $1.0 == $1.1 }.count == 0
    }
}

struct SpockUnkeyedContainer: UnkeyedDecodingContainer {
    var count: Int? = 2
    
    var isAtEnd: Bool = false
    
    var currentIndex: Int = 0
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        self
    }
    
    mutating func superDecoder() throws -> Decoder {
        decoder
    }
    
    let codingPath: [CodingKey] = []
    var decoder: SpockDecoder
    init(decoder: SpockDecoder) {
        self.decoder = decoder
    }
    
    mutating func decodeNil() throws -> Bool {
        return false
    }
    
    mutating func decode(_ type: Bool.Type) throws -> Bool {
        return true
    }
    
    mutating func decode(_ type: String.Type) throws -> String {
        String()
    }
    
    mutating func decode(_: Double.Type) throws -> Double {
        0
    }
    
    mutating func decode(_: Float.Type) throws -> Float {
        0
    }
    
    mutating func decode(_: Int.Type) throws -> Int {
        0
    }
    
    mutating func decode(_: Int8.Type) throws -> Int8 {
        0
    }
    
    mutating func decode(_: Int16.Type) throws -> Int16 {
        0
    }
    
    mutating func decode(_: Int32.Type) throws -> Int32 {
        0
    }
    
    mutating func decode(_: Int64.Type) throws -> Int64 {
        0
    }
    
    mutating func decode(_: UInt.Type) throws -> UInt {
        0
    }
    
    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        0
    }
    
    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        0
    }
    
    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        0
    }
    
    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        0
    }
    
    mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
        
        let decoder = SpockDecoder(whit: decoder.mainkey,
                                   at: "\(T.self)_value",
                                   values: (decoder.dumyValues, decoder.defaultNil))
        nextIndex()
        return try .init(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try decoder.container(keyedBy: type)
    }
    
    mutating func nextIndex() {
        currentIndex += 1
        isAtEnd = currentIndex >= count ?? 0
    }
}
