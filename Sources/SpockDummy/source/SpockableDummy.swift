
public protocol SpockDummy: Decodable { }

extension SpockDummy {
    
    public static func dummy(with dummyValue: SpockDummyValue ...) throws -> Self {
        let spockDummyGenerator = SpockDummyGenerator<Self>()
        dummyValue.forEach { item in
            spockDummyGenerator.setDummyValue(at: item.attribute, with: item.value)
        }
        return try spockDummyGenerator.generate()
    }
    
    public static func dummy() throws -> Self {
        try SpockDummyGenerator<Self>().generate()
    }
    
}

public struct SpockDummyValue {
    var attribute: String
    var value: Any?
    init(at attribute: String, with value: Any?) {
        self.attribute = attribute
        self.value = value
    }
}

public struct SpockDummyGenerator<T: Decodable> {
    let decoder: SpockDecoder
    
    init(with type: Decodable.Type = T.self) {
        decoder = .init(with: String(describing: type))
    }
    
    @discardableResult
    public func setDummyValue(at attribute: String, with value: Any?) -> SpockDummyGenerator<T> {
        decoder.setDummyValue(at: attribute, with: value)
        return self
    }
    
    func generate() throws -> T {
        try T.init(from: decoder)
    }
}

final class SpockDecoder: Decoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    var dumyValues: [String: Any?] = [:]
    var defaultNil: [String] = []
    var mainkey: String
    
    init(with className: String) {
        self.mainkey = className
    }
    
    init(whit parentKey: String,
         at subKey: String,
         values: ([String: Any?], [String]) ) {
        self.mainkey = "\(parentKey):\(subKey)"
        
        self.dumyValues = values.0
        self.defaultNil = values.1
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return SpockUnkeyedContainer(decoder: self)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SpockSingleValueContainer(decoder: self)
    }
    
    @discardableResult
    public func setDummyValue(at attribute: String, with value: Any?) -> SpockDecoder {
        let key = "\(mainkey):\(attribute)"
        if value != nil {
            dumyValues[key] = value
            return self
        }
        guard defaultNil.contains(key) else {
            defaultNil.append(key)
            return self
        }
        
        return self
    }
    
    func getDummyValue<T>(key: String) -> T? {
        dumyValues["\(self.mainkey):\(key)"] as? T
    }
    
    func decodeNil(key: String) -> Bool {
        let key = "\(self.mainkey):\(key)"
        return defaultNil.contains(key)
    }
    
    func container<Key>(keyedBy type: Key.Type) throws ->  KeyedDecodingContainer<Key> where Key : CodingKey {
        
        .init(SpockContainer<Key>(decoder: self))
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
        decoder.decodeNil(key: key.stringValue)
    }
    
    func decode(_ type: Bool.Type, forKey key: SpockCodinKey) throws -> Bool {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: String.Type, forKey key: SpockCodinKey) throws -> String {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Double.Type, forKey key: SpockCodinKey) throws -> Double {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Float.Type, forKey key: SpockCodinKey) throws -> Float {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Int.Type, forKey key: SpockCodinKey) throws -> Int {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Int8.Type, forKey key: SpockCodinKey) throws -> Int8 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Int16.Type, forKey key: SpockCodinKey) throws -> Int16 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Int32.Type, forKey key: SpockCodinKey) throws -> Int32 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: Int64.Type, forKey key: SpockCodinKey) throws -> Int64 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: UInt.Type, forKey key: SpockCodinKey) throws -> UInt {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: UInt8.Type, forKey key: SpockCodinKey) throws -> UInt8 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: UInt16.Type, forKey key: SpockCodinKey) throws -> UInt16 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: UInt32.Type, forKey key: SpockCodinKey) throws -> UInt32 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode(_ type: UInt64.Type, forKey key: SpockCodinKey) throws -> UInt64 {
        decoder.getDummyValue(key: key.stringValue) ?? .init()
    }
    
    func decode<T>(_ type: T.Type, forKey key: SpockCodinKey) throws -> T where T : Decodable {
        if let result: T = decoder.getDummyValue(key: key.stringValue) {
            return result
        }
        
        let decoder = SpockDecoder(whit: decoder.mainkey,
                                   at: key.stringValue,
                                   values: (decoder.dumyValues, decoder.defaultNil))
        return try .init(from: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                    forKey key: SpockCodinKey) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        try decoder.container(keyedBy: type)
    }
    
    func nestedUnkeyedContainer(forKey key: SpockCodinKey) throws -> UnkeyedDecodingContainer {
        fatalError("not implement")
    }
    
    func superDecoder() throws -> Decoder {
        decoder
    }
    
    func superDecoder(forKey key: SpockCodinKey) throws -> Decoder {
        decoder
    }
}

