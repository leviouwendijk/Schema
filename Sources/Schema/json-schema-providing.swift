import Primitives

public protocol JSONSchemaProviding {
    static var jsonschema: JSONSchema { get }
}

extension JSONValue: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .any }
}

extension String: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .string() }
}

extension Bool: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .boolean() }
}

extension Int: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension Int8: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension Int16: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension Int32: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension Int64: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension UInt: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension UInt8: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension UInt16: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension UInt32: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension UInt64: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .integer() }
}

extension Float: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .number() }
}

extension Double: JSONSchemaProviding {
    public static var jsonschema: JSONSchema { .number() }
}

extension Optional: JSONSchemaProviding where Wrapped: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .oneOf([Wrapped.jsonschema, .null])
    }
}

extension Array: JSONSchemaProviding where Element: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .array(items: Element.jsonschema)
    }
}

extension Dictionary: JSONSchemaProviding
where Key == String, Value: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            additionalProperties: .schema(Value.jsonschema)
        )
    }
}
