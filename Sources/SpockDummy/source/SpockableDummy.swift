
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
