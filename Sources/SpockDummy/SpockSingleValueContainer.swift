//
//  SpockSingleValueContainer.swift
//  SpockSwift-Unit-Tests
//
//  Created by Francisco Javier Saldivar Rubio on 07/08/22.
//

struct SpockSingleValueContainer: SingleValueDecodingContainer {
    let decoder: SpockDecoder
    let codingPath: [CodingKey] = []
    
    init(decoder: SpockDecoder) {
        self.decoder = decoder
    }
    
    func decodeNil() -> Bool {
        false
    }
    
    func decode(_: Bool.Type) throws -> Bool {
       Bool()
    }
    
    func decode(_: String.Type) throws -> String {
        String()
    }
    
    func decode(_: Double.Type) throws -> Double {
        0
    }
    
    func decode(_: Float.Type) throws -> Float {
        0
    }
    
    func decode(_: Int.Type) throws -> Int {
        0
    }
    
    func decode(_: Int8.Type) throws -> Int8 {
        0
    }
    
    func decode(_: Int16.Type) throws -> Int16 {
        0
    }
    
    func decode(_: Int32.Type) throws -> Int32 {
        0
    }
    
    func decode(_: Int64.Type) throws -> Int64 {
        0
    }
    
    func decode(_: UInt.Type) throws -> UInt {
        0
    }
    
    func decode(_: UInt8.Type) throws -> UInt8 {
        0
    }
    
    func decode(_: UInt16.Type) throws -> UInt16 {
        0
    }
    
    func decode(_: UInt32.Type) throws -> UInt32 {
        0
    }
    
    func decode(_: UInt64.Type) throws -> UInt64 {
        0
    }
    
    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        let decoder = SpockDecoder(whit: decoder.mainkey,
                                   at: "\(T.self)_value",
                                   values: (decoder.dumyValues, decoder.defaultNil))
        return try .init(from: decoder)
    }
}
