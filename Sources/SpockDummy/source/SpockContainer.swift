//
//  SpockContainer.swift
//  SpockSwift
//
//  Created by Francisco Javier Saldivar Rubio on 08/08/22.
//

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

