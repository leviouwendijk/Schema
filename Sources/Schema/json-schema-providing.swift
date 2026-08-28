import Primitives

public protocol JSONSchemaProviding {
    static var jsonSchema: JSONSchema { get }
}

extension JSONValue: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .any }
}

extension String: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .string() }
}

extension Bool: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .boolean() }
}

extension Int: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension Int8: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension Int16: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension Int32: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension Int64: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt8: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt16: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt32: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension UInt64: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .integer() }
}

extension Float: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .number() }
}

extension Double: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema { .number() }
}

extension Optional: JSONSchemaProviding where Wrapped: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema {
        .oneOf([Wrapped.jsonSchema, .null])
    }
}

extension Array: JSONSchemaProviding where Element: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema {
        .array(items: Element.jsonSchema)
    }
}

extension Dictionary: JSONSchemaProviding
where Key == String, Value: JSONSchemaProviding {
    public static var jsonSchema: JSONSchema {
        .object(
            additionalProperties: .schema(Value.jsonSchema)
        )
    }
}
