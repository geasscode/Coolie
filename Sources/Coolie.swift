//
//  Coolie.swift
//  Coolie
//
//  Created by NIX on 16/1/23.
//  Copyright © 2016年 nixWork. All rights reserved.
//

import Foundation

final public class Coolie {

    private let scanner: Scanner

    public init(_ jsonString: String) {
        scanner = Scanner(string: jsonString)
    }

    public enum ModelType: String {

        case `struct`
        case `class`
    }

    public func generateModel(name: String, type: ModelType, constructorName: String? = nil, debug: Bool = false) -> String? {

        if let value = parse() {
            var string = ""

            switch type {
            case .struct:
                value.generateStruct(fromLevel: 0, withModelName: name, constructorName: constructorName, debug: debug, into: &string)
            case .class:
                value.generateClass(fromLevel: 0, withModelName: name, debug: debug, into: &string)
            }

            return string

        } else {
            print("Coolie parse failed!")
        }

        return nil
    }

    fileprivate enum Token {

        case beginObject(String)    // {
        case endObject(String)      // }

        case beginArray(String)     // [
        case endArray(String)       // ]

        case colon(String)          // :
        case comma(String)          // ,

        case bool(Bool)             // true or false
        enum NumberType {
            case int(Int)
            case double(Double)
        }
        case number(NumberType)     // 42, 99.99
        case string(String)         // "nix", ...

        case null                   // null
    }

    fileprivate enum Value {

        case bool(Bool)
        enum NumberType {
            case int(Int)
            case double(Double)
        }
        case number(NumberType)
        case string(String)

        case null

        indirect case dictionary([String: Value])
        indirect case array(name: String?, values: [Value])
    }

    lazy var numberScanningSet: CharacterSet = {
        var symbolSet = CharacterSet.decimalDigits
        symbolSet.formUnion(CharacterSet(charactersIn: ".-"))
        return symbolSet
    }()

    lazy var stringScanningSet: CharacterSet = {
        var symbolSet = CharacterSet.alphanumerics
        symbolSet.formUnion(CharacterSet.punctuationCharacters)
        symbolSet.formUnion(CharacterSet.symbols)
        symbolSet.formUnion(CharacterSet.whitespacesAndNewlines)
        symbolSet.remove(charactersIn: "\"")
        return symbolSet
    }()

    private func generateTokens() -> [Token] {

        func scanBeginObject() -> Token? {

            if scanner.scanString("{", into: nil) {
                return .beginObject("{")
            }

            return nil
        }

        func scanEndObject() -> Token? {

            if scanner.scanString("}", into: nil) {
                return .endObject("}")
            }

            return nil
        }

        func scanBeginArray() -> Token? {

            if scanner.scanString("[", into: nil) {
                return .beginArray("[")
            }

            return nil
        }

        func scanEndArray() -> Token? {

            if scanner.scanString("]", into: nil) {
                return .endArray("]")
            }

            return nil
        }

        func scanColon() -> Token? {

            if scanner.scanString(":", into: nil) {
                return .colon(":")
            }

            return nil
        }

        func scanComma() -> Token? {

            if scanner.scanString(",", into: nil) {
                return .comma(",")
            }

            return nil
        }

        func scanBool() -> Token? {

            if scanner.scanString("true", into: nil) {
                return .bool(true)
            }

            if scanner.scanString("false", into: nil) {
                return .bool(false)
            }

            return nil
        }

        func scanNumber() -> Token? {

            var string: NSString?

            if scanner.scanCharacters(from: numberScanningSet, into: &string) {

                if let string = string as? String {

                    if let number = Int(string) {
                        return .number(.int(number))

                    } else if let number = Double(string) {
                        return .number(.double(number))
                    }
                }
            }

            return nil
        }

        func scanString() -> Token? {

            var string: NSString?

            if scanner.scanString("\"\"", into: nil) {
                return .string("")
            }

            if scanner.scanString("\"", into: nil) &&
                scanner.scanCharacters(from: stringScanningSet, into: &string) &&
                scanner.scanString("\"", into: nil) {

                if let string = string as? String {
                    return .string(string)
                }
            }

            return nil
        }

        func scanNull() -> Token? {

            if scanner.scanString("null", into: nil) {
                return .null
            }

            return nil
        }

        var tokens = [Token]()

        while !scanner.isAtEnd {

            let previousScanLocation = scanner.scanLocation

            if let token = scanBeginObject() {
                tokens.append(token)
            }

            if let token = scanEndObject() {
                tokens.append(token)
            }

            if let token = scanBeginArray() {
                tokens.append(token)
            }

            if let token = scanEndArray() {
                tokens.append(token)
            }

            if let token = scanColon() {
                tokens.append(token)
            }

            if let token = scanComma() {
                tokens.append(token)
            }

            if let token = scanBool() {
                tokens.append(token)
            }

            if let token = scanNumber() {
                tokens.append(token)
            }

            if let token = scanString() {
                tokens.append(token)
            }

            if let token = scanNull() {
                tokens.append(token)
            }

            let currentScanLocation = scanner.scanLocation
            guard currentScanLocation > previousScanLocation else {
                print("Not found valid token")
                break
            }
        }

        return tokens
    }

    private func parse() -> Value? {

        let tokens = generateTokens()

        guard !tokens.isEmpty else {
            print("No tokens")
            return nil
        }

        var next = 0

        func parseValue() -> Value? {

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseValue")
                return nil
            }

            switch token {

            case .beginArray:

                var arrayName: String?
                let nameIndex = next - 2
                if nameIndex >= 0 {
                    if let nameToken = tokens[coolie_safe: nameIndex] {
                        if case .string(let name) = nameToken {
                            arrayName = name.capitalized
                        }
                    }
                }

                next += 1
                return parseArray(name: arrayName)

            case .beginObject:
                next += 1
                return parseObject()

            case .bool:
                return parseBool()

            case .number:
                return parseNumber()

            case .string:
                return parseString()

            case .null:
                return parseNull()

            default:
                return nil
            }
        }

        func parseArray(name: String? = nil) -> Value? {

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseArray")
                return nil
            }

            var array = [Value]()

            if case .endArray = token {
                next += 1
                return .array(name: name, values: array)

            } else {
                while true {
                    guard let value = parseValue() else {
                        break
                    }

                    array.append(value)

                    if let token = tokens[coolie_safe: next] {

                        if case .endArray = token {
                            next += 1
                            return .array(name: name, values: array)

                        } else {
                            guard let _ = parseComma() else {
                                print("Expect comma")
                                break
                            }

                            guard let nextToken = tokens[coolie_safe: next], nextToken.isNotEndArray else {
                                print("Invalid JSON, comma at end of array")
                                break
                            }
                        }
                    }
                }

                return nil
            }
        }

        func parseObject() -> Value? {

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseObject")
                return nil
            }

            var dictionary = [String: Value]()

            if case .endObject = token {
                next += 1
                return .dictionary(dictionary)

            } else {
                while true {
                    guard let key = parseString(), let _ = parseColon(), let value = parseValue() else {
                        print("Expect key : value")
                        break
                    }

                    if case .string(let key) = key {
                        dictionary[key] = value
                    }

                    if let token = tokens[coolie_safe: next] {

                        if case .endObject = token {
                            next += 1
                            return .dictionary(dictionary)

                        } else {
                            guard let _ = parseComma() else {
                                print("Expect comma")
                                break
                            }

                            guard let nextToken = tokens[coolie_safe: next], nextToken.isNotEndObject else {
                                print("Invalid JSON, comma at end of object")
                                break
                            }
                        }
                    }
                }
            }

            return nil
        }

        func parseColon() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseColon")
                return nil
            }

            if case .colon(let string) = token {
                return .string(string)
            }

            return nil
        }

        func parseComma() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseComma")
                return nil
            }

            if case .comma(let string) = token {
                return .string(string)
            }

            return nil
        }

        func parseBool() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseBool")
                return nil
            }

            if case .bool(let bool) = token {
                return .bool(bool)
            }

            return nil
        }

        func parseNumber() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseNumber")
                return nil
            }

            if case .number(let number) = token {
                switch number {
                case .int(let int):
                    return .number(.int(int))
                case .double(let double):
                    return .number(.double(double))
                }
            }

            return nil
        }

        func parseString() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseString")
                return nil
            }

            if case .string(let string) = token {
                return .string(string)
            }

            return nil
        }

        func parseNull() -> Value? {

            defer {
                next += 1
            }

            guard let token = tokens[coolie_safe: next] else {
                print("No token for parseNull")
                return nil
            }

            if case .null = token {
                return .null
            }

            return nil
        }

        return parseValue()
    }
}

private extension Coolie.Value {

    var type: String {
        switch self {
        case .bool:
            return "Bool"
        case .number(let number):
            switch number {
            case .int:
                return "Int"
            case .double:
                return "Double"
            }
        case .string:
            return "String"
        case .null:
            return "UnknownType?"
        default:
            fatalError("Unknown type")
        }
    }

    var isDictionaryOrArray: Bool {
        switch self {
        case .dictionary:
            return true
        case .array:
            return true
        default:
            return false
        }
    }

    var isDictionary: Bool {
        switch self {
        case .dictionary:
            return true
        default:
            return false
        }
    }

    var isArray: Bool {
        switch self {
        case .array:
            return true
        default:
            return false
        }
    }

    var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }
}

private extension Coolie.Token {

    var isNotEndObject: Bool {
        switch self {
        case .endObject:
            return false
        default:
            return true
        }
    }

    var isNotEndArray: Bool {
        switch self {
        case .endArray:
            return false
        default:
            return true
        }
    }
}

private extension Coolie.Value {

    func unionValues(_ values: [Coolie.Value]) -> Coolie.Value? {

        guard values.count > 1 else {
            return values.first
        }

        if let first = values.first, case .dictionary(let firstInfo) = first {

            var info: [String: Coolie.Value] = firstInfo

            let keys = firstInfo.keys

            for i in 1..<values.count {
                let next = values[i]
                if case .dictionary(let nextInfo) = next {
                    for key in keys {
                        if let value = nextInfo[key], !value.isNull {
                            info[key] = value
                        }
                    }
                }
            }

            return .dictionary(info)
        }

        return values.first
    }
}

private extension Coolie.Value {

    func generateStruct(fromLevel level: Int, withModelName modelName: String? = nil, constructorName: String? = nil, debug: Bool, into string: inout String) {

        func indentLevel(_ level: Int) {
            for _ in 0..<level {
                string += "\t"
            }
        }

        switch self {

        case .bool, .number, .string, .null:
            string += "\(type)\n"

        case .dictionary(let info):
            // struct name
            indentLevel(level)
            string += "struct \(modelName ?? "Model") {\n"

            // properties
            for key in info.keys.sorted() {
                if let value = info[key] {
                    if value.isDictionaryOrArray {
                        value.generateStruct(fromLevel: level + 1, withModelName: key.capitalized, constructorName: constructorName, debug: debug, into: &string)
                        indentLevel(level + 1)
                        if value.isArray {
                            if case .array(_, let values) = value, let unionValue = unionValues(values), !unionValue.isDictionaryOrArray {
                                string += "let \(key.coolie_lowerCamelCase): [\(unionValue.type)]\n"
                            } else {
                                string += "let \(key.coolie_lowerCamelCase): [\(key.capitalized.coolie_dropLastCharacter)]\n"
                            }
                        } else {
                            string += "let \(key.coolie_lowerCamelCase): \(key.capitalized)\n"
                        }
                    } else {
                        indentLevel(level + 1)
                        string += "let \(key.coolie_lowerCamelCase): "
                        value.generateStruct(fromLevel: level, constructorName: constructorName, debug: debug, into: &string)
                    }
                }
            }

            // generate method
            indentLevel(level + 1)
            if let constructorName = constructorName {
                string += "static func \(constructorName)(_ info: [String: AnyObject]) -> \(modelName ?? "Model")? {\n"
            } else {
                string += "init?(_ info: [String: AnyObject]) {\n"
            }
            for key in info.keys.sorted() {
                if let value = info[key] {
                    if value.isDictionaryOrArray {
                        if value.isDictionary {
                            indentLevel(level + 2)
                            string += "guard let \(key.coolie_lowerCamelCase)JSONDictionary = info[\"\(key)\"] as? [String: AnyObject] else { "
                            string += debug ? "print(\"Not found dictionary key: \(key)\"); return nil }\n" : "return nil }\n"
                            indentLevel(level + 2)
                            if let constructorName = constructorName {
                                string += "guard let \(key.coolie_lowerCamelCase) = \(key.capitalized).\(constructorName)(\(key.coolie_lowerCamelCase)JSONDictionary) else { "
                            } else {
                                string += "guard let \(key.coolie_lowerCamelCase) = \(key.capitalized)(\(key.coolie_lowerCamelCase)JSONDictionary) else { "
                            }
                            string += debug ? "print(\"Failed to generate: \(key.coolie_lowerCamelCase)\"); return nil }\n" : "return nil }\n"
                        } else if value.isArray {
                            if case .array(_, let values) = value, let unionValue = unionValues(values), !unionValue.isDictionaryOrArray {
                                indentLevel(level + 2)
                                if unionValue.isNull {
                                    string += "let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? UnknownType\n"
                                } else {
                                    string += "guard let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? [\(unionValue.type)] else { "
                                    string += debug ? "print(\"Not found array key: \(key)\"); return nil }\n" : "return nil }\n"
                                }
                            } else {
                                indentLevel(level + 2)
                                string += "guard let \(key.coolie_lowerCamelCase)JSONArray = info[\"\(key)\"] as? [[String: AnyObject]] else { "
                                string += debug ? "print(\"Not found array key: \(key)\"); return nil }\n" : "return nil }\n"
                                indentLevel(level + 2)
                                if let constructorName = constructorName {
                                    string += "let \(key.coolie_lowerCamelCase) = \(key.coolie_lowerCamelCase)JSONArray.map({ \(key.capitalized.coolie_dropLastCharacter).\(constructorName)($0) }).flatMap({ $0 })\n"
                                } else {
                                    string += "let \(key.coolie_lowerCamelCase) = \(key.coolie_lowerCamelCase)JSONArray.map({ \(key.capitalized.coolie_dropLastCharacter)($0) }).flatMap({ $0 })\n"
                                }
                            }
                        }
                    } else {
                        indentLevel(level + 2)
                        if value.isNull {
                            string += "let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? UnknownType\n"
                        } else {
                            string += "guard let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? \(value.type) else { "
                            string += debug ? "print(\"Not found key: \(key)\"); return nil }\n" : "return nil }\n"
                        }
                    }
                }
            }

            if let _ = constructorName {
                indentLevel(level + 2)
                string += "return \(modelName ?? "Model")("
                let lastIndex = info.keys.count - 1
                for (index, key) in info.keys.sorted().enumerated() {
                    let suffix = (index == lastIndex) ? ")" : ", "
                    string += "\(key.coolie_lowerCamelCase): \(key.coolie_lowerCamelCase)" + suffix
                }
                string += "\n"

            } else {
                for key in info.keys.sorted() {
                    indentLevel(level + 2)
                    let property = key.coolie_lowerCamelCase
                    string += "self.\(property) = \(property)\n"
                }
            }

            indentLevel(level + 1)
            string += "}\n"

            indentLevel(level)
            string += "}\n"

        case .array(let name, let values):
            if let unionValue = unionValues(values) {
                if unionValue.isDictionaryOrArray {
                    unionValue.generateStruct(fromLevel: level, withModelName: name?.coolie_dropLastCharacter, constructorName: constructorName, debug: debug, into: &string)
                }
            }
        }
    }
}

private extension Coolie.Value {

    func generateClass(fromLevel level: Int, withModelName modelName: String? = nil, debug: Bool, into string: inout String) {

        func indentLevel(_ level: Int) {
            for _ in 0..<level {
                string += "\t"
            }
        }

        switch self {

        case .bool, .number, .string, .null:
            string += "\(type)\n"

        case .dictionary(let info):
            // struct name
            indentLevel(level)
            string += "class \(modelName ?? "Model") {\n"

            // properties
            for key in info.keys.sorted() {
                if let value = info[key] {
                    if value.isDictionaryOrArray {
                        value.generateClass(fromLevel: level + 1, withModelName: key.capitalized, debug: debug, into: &string)
                        indentLevel(level + 1)
                        if value.isArray {
                            if case .array(_, let values) = value, let unionValue = unionValues(values), !unionValue.isDictionaryOrArray {
                                string += "var \(key.coolie_lowerCamelCase): [\(unionValue.type)]\n"
                            } else {
                                string += "var \(key.coolie_lowerCamelCase): [\(key.capitalized.coolie_dropLastCharacter)]\n"
                            }
                        } else {
                            string += "var \(key.coolie_lowerCamelCase): \(key.capitalized)\n"
                        }
                    } else {
                        indentLevel(level + 1)
                        string += "var \(key.coolie_lowerCamelCase): "
                        value.generateClass(fromLevel: level, debug: debug, into: &string)
                    }
                }
            }

            // generate method
            indentLevel(level + 1)
            string += "init?(_ info: [String: AnyObject]) {\n"
            for key in info.keys.sorted() {
                if let value = info[key] {
                    if value.isDictionaryOrArray {
                        if value.isDictionary {
                            indentLevel(level + 2)
                            string += "guard let \(key.coolie_lowerCamelCase)JSONDictionary = info[\"\(key)\"] as? [String: AnyObject] else { "
                            string += debug ? "print(\"Not found dictionary: \(key)\"); return nil }\n" : "return nil }\n"
                            indentLevel(level + 2)
                            string += "guard let \(key.coolie_lowerCamelCase) = \(key.capitalized)(\(key.coolie_lowerCamelCase)JSONDictionary) else { "
                            string += debug ? "print(\"Failed to generate: \(key.coolie_lowerCamelCase)\"); return nil }\n" : "return nil }\n"
                        } else if value.isArray {
                            if case .array(_, let values) = value, let unionValue = unionValues(values), !unionValue.isDictionaryOrArray {
                                indentLevel(level + 2)
                                if unionValue.isNull {
                                    string += "let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? UnknownType\n"
                                } else {
                                    string += "guard let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? [\(unionValue.type)] else { "
                                    string += debug ? "print(\"Not found array key: \(key)\"); return nil }\n" : "return nil }\n"
                                }
                            } else {
                                indentLevel(level + 2)
                                string += "guard let \(key.coolie_lowerCamelCase)JSONArray = info[\"\(key)\"] as? [[String: AnyObject]] else { "
                                string += debug ? "print(\"Not found array key: \(key)\"); return nil }\n" : "return nil }\n"
                                indentLevel(level + 2)
                                string += "let \(key.coolie_lowerCamelCase) = \(key.coolie_lowerCamelCase)JSONArray.map({ \(key.capitalized.coolie_dropLastCharacter)($0) }).flatMap({ $0 })\n"
                            }
                        }
                    } else {
                        indentLevel(level + 2)
                        if value.isNull {
                            string += "let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? UnknownType\n"
                        } else {
                            string += "guard let \(key.coolie_lowerCamelCase) = info[\"\(key)\"] as? \(value.type) else { "
                            string += debug ? "print(\"Not found key: \(key)\"); return nil }\n" : "return nil }\n"
                        }
                    }
                }
            }

            for key in info.keys.sorted() {
                indentLevel(level + 2)
                let property = key.coolie_lowerCamelCase
                string += "self.\(property) = \(property)\n"
            }

            indentLevel(level + 1)
            string += "}\n"

            indentLevel(level)
            string += "}\n"

        case .array(let name, let values):
            if let unionValue = unionValues(values) {
                if unionValue.isDictionaryOrArray {
                    unionValue.generateClass(fromLevel: level, withModelName: name?.coolie_dropLastCharacter, debug: debug, into: &string)
                }
            }
        }
    }
}

private extension String {

    var coolie_dropLastCharacter: String {

        if characters.count > 0 {
            return String(characters.dropLast())
        }

        return self
    }

    var coolie_lowerCamelCase: String {

        var symbolSet = CharacterSet.alphanumerics
        symbolSet.formUnion(CharacterSet(charactersIn: "_"))
        symbolSet.invert()

        let validString = self.components(separatedBy: symbolSet).joined(separator: "_")
        let parts = validString.components(separatedBy: "_")

        return parts.enumerated().map({ index, part in
            return index == 0 ? part : part.capitalized
        }).joined(separator: "")
    }
}

private extension Array {

    subscript (coolie_safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
