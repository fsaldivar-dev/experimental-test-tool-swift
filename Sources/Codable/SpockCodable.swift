
protocol SpockagbleDummy {}

protocol SpockDecodable: Decoder {}

extension SpockDecodable {
    
}
extension SpockDecoder {
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        .init(SpockContainer<Key>(decoder: self))
    }
}

final class SpockDecoder: SpockDecodable {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    var dumyValues: [String: Any] = [:]
    var className: String
    
    init(object type: Decodable.Type) {
        className = String(describing: type)
    }
    
    init(parent: String, object type: Decodable.Type, values: [String: Any] ) {
        className = "\(parent):\(String(describing: type))"
        self.dumyValues = values
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("Not implement")
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError("Not implement")
    }
    
    @discardableResult
    func setDummiValue(named attributed: String, fake value: Any) -> SpockDecoder {
        dumyValues["\(className):\(attributed)"] = value
        return self
    }
    
    func getDummyValue<T>(key: String) -> T? {
        dumyValues["\(className):\(key)"] as? T
    }
    
}

struct SpockCodinKey: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        self.intValue = intValue
        stringValue = .init()
    }
}

struct SpockContainer<SpockCodinKey>: KeyedDecodingContainerProtocol where SpockCodinKey: CodingKey  {
    typealias Key = SpockCodinKey
    
    var codingPath: [CodingKey] = []
    
    var allKeys: [SpockCodinKey] = []
    var decoder: SpockDecoder
    
    init(decoder: SpockDecoder) {
        self.decoder = decoder
    }
    
    func contains(_ key: SpockCodinKey) -> Bool {
        true
    }
    
    func decodeNil(forKey key: SpockCodinKey) throws -> Bool {
        true
    }
    
    func decode(_ type: Bool.Type, forKey key: SpockCodinKey) throws -> Bool {
        .init()
    }
    
    func decode(_ type: String.Type, forKey key: SpockCodinKey) throws -> String {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Double.Type, forKey key: SpockCodinKey) throws -> Double {
        .init()
    }
    
    func decode(_ type: Float.Type, forKey key: SpockCodinKey) throws -> Float {
        .init()
    }
    
    func decode(_ type: Int.Type, forKey key: SpockCodinKey) throws -> Int {
        .init()
    }
    
    func decode(_ type: Int8.Type, forKey key: SpockCodinKey) throws -> Int8 {
        .init()
    }
    
    func decode(_ type: Int16.Type, forKey key: SpockCodinKey) throws -> Int16 {
        .init()
    }
    
    func decode(_ type: Int32.Type, forKey key: SpockCodinKey) throws -> Int32 {
        .init()
    }
    
    func decode(_ type: Int64.Type, forKey key: SpockCodinKey) throws -> Int64 {
        .init()
    }
    
    func decode(_ type: UInt.Type, forKey key: SpockCodinKey) throws -> UInt {
        .init()
    }
    
    func decode(_ type: UInt8.Type, forKey key: SpockCodinKey) throws -> UInt8 {
        .init()
    }
    
    func decode(_ type: UInt16.Type, forKey key: SpockCodinKey) throws -> UInt16 {
        0
    }
    
    func decode(_ type: UInt32.Type, forKey key: SpockCodinKey) throws -> UInt32 {
        0
    }
    
    func decode(_ type: UInt64.Type, forKey key: SpockCodinKey) throws -> UInt64 {
        0
    }
    
    func decode<T>(_ type: T.Type, forKey key: SpockCodinKey) throws -> T where T : Decodable {
        let decoder = SpockDecoder(parent: decoder.className, object: type, values: decoder.dumyValues)
        return try .init(from: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                    forKey key: SpockCodinKey) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        fatalError("")
    }
    
    func nestedUnkeyedContainer(forKey key: SpockCodinKey) throws -> UnkeyedDecodingContainer {
        fatalError("")
    }
    
    func superDecoder() throws -> Decoder {
        decoder
    }
    
    func superDecoder(forKey key: SpockCodinKey) throws -> Decoder {
        decoder
    }
    
}

//
//struct SpockUnkeyedDecodingContainer: UnkeyedDecodingContainer {
//    mutating func decode(_ type: String.Type) throws -> String {
//        .init()
//    }
//
//    mutating func decode(_ type: Double.Type) throws -> Double {
//        .init()
//    }
//
//    mutating func decode(_ type: Float.Type) throws -> Float {
//        .init()
//    }
//
//    mutating func decode(_ type: Int.Type) throws -> Int {
//        .init()
//    }
//
//    mutating func decode(_ type: Int8.Type) throws -> Int8 {
//        0
//    }
//
//    mutating func decode(_ type: Int16.Type) throws -> Int16 {
//        0
//    }
//
//    mutating func decode(_ type: Int32.Type) throws -> Int32 {
//        0
//    }
//
//    mutating func decode(_ type: Int64.Type) throws -> Int64 {
//        0
//    }
//
//    mutating func decode(_ type: UInt.Type) throws -> UInt {
//        0
//    }
//
//    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
//        0
//    }
//
//    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
//        0
//    }
//
//    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
//        0
//    }
//
//    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
//        0
//    }
//
//    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
//        try .init(from: SpockDecoder())
//    }
//
//
//
//    var codingPath: [CodingKey] = []
//
//    var count: Int? = 0
//
//    var isAtEnd: Bool = false
//
//    var currentIndex: Int = 1
//
//    mutating func decodeNil() throws -> Bool {
//        return true
//    }
//
//    mutating func decode(_ type: Bool.Type) throws -> Bool {
//        return true
//    }
//
//    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
//        return KeyedDecodingContainer<NestedKey>(SpockContainer<NestedKey>())
//    }
//
//    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
//        SpockUnkeyedDecodingContainer()
//    }
//
//    mutating func superDecoder() throws -> Decoder {
//        SpockDecoder()
//    }
//
//
//}
//
//struct SpockSingleValueDecodingContainer: SingleValueDecodingContainer {
//    var codingPath: [CodingKey] = []
//
//    func decodeNil() -> Bool {
//        .init()
//    }
//
//    func decode(_ type: Bool.Type) throws -> Bool {
//        .init()
//    }
//
//    func decode(_ type: String.Type) throws -> String {
//        .init()
//    }
//
//    func decode(_ type: Double.Type) throws -> Double {
//        .init()
//    }
//
//    func decode(_ type: Float.Type) throws -> Float {
//        .init()
//    }
//
//    func decode(_ type: Int.Type) throws -> Int {
//        .init()
//    }
//
//    func decode(_ type: Int8.Type) throws -> Int8 {
//        0
//    }
//
//    func decode(_ type: Int16.Type) throws -> Int16 {
//        0
//    }
//
//    func decode(_ type: Int32.Type) throws -> Int32 {
//        0
//    }
//
//    func decode(_ type: Int64.Type) throws -> Int64 {
//        0
//    }
//
//    func decode(_ type: UInt.Type) throws -> UInt {
//        0
//    }
//
//    func decode(_ type: UInt8.Type) throws -> UInt8 {
//        0
//    }
//
//    func decode(_ type: UInt16.Type) throws -> UInt16 {
//        0
//    }
//
//    func decode(_ type: UInt32.Type) throws -> UInt32 {
//        0
//    }
//
//    func decode(_ type: UInt64.Type) throws -> UInt64 {
//        0
//    }
//
//    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
//        try .init(from: SpockDecoder())
//    }
//
//
//}
//struct SpockKeyedEncodingContainer: KeyedEncodingContainerProtocol {
//    typealias Key = SpockCodinKey
//    var codingPath: [CodingKey] = []
//
//    mutating func encodeNil(forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Bool, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: String, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Double, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Float, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Int, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Int8, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Int16, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Int32, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: Int64, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: UInt, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: UInt8, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: UInt16, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: UInt32, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode(_ value: UInt64, forKey key: SpockCodinKey) throws {}
//
//    mutating func encode<T>(_ value: T, forKey key: SpockCodinKey) throws where T : Encodable {
//    }
//
//    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: SpockCodinKey) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
//        fatalError("")
//    }
//
//    mutating func nestedUnkeyedContainer(forKey key: SpockCodinKey) -> UnkeyedEncodingContainer {
//        fatalError("")
//    }
//
//    mutating func superEncoder() -> Encoder {
//        fatalError("")
//    }
//
//    mutating func superEncoder(forKey key: SpockCodinKey) -> Encoder {
//        fatalError("")
//
//    }
//}
//
//
