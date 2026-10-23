import Primitives

public struct JSONSchema: Sendable, Codable, Hashable {
    public struct Property: Sendable, Codable, Hashable {
        public let name: String
        public let schema: JSONSchema
        public let required: Bool
        public let description: String?

        public init(
            name: String,
            schema: JSONSchema,
            required: Bool = false,
            description: String? = nil
        ) {
            self.name = name
            self.schema = schema
            self.required = required
            self.description = description
        }
    }

    public indirect enum AdditionalProperties: Sendable, Codable, Hashable {
        case allowed
        case disallowed
        case schema(JSONSchema)
    }

    public enum StringFormat: Codable, Sendable, Hashable {
        case uuid
        case uri
        case date_time

        var codingValue: String {
            switch self {
            case .uuid:
                "uuid"
            case .uri:
                "uri"
            case .date_time:
                "date-time"
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            switch value {
            case "uuid":
                self = .uuid
            case "uri":
                self = .uri
            case "date-time":
                self = .date_time
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown string format: \(value)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(codingValue)
        }
    }

    public indirect enum Form: Sendable, Codable, Hashable {
        case any
        case null
        case boolean
        case integer(cases: [Int])
        case number(cases: [Double])
        case string(cases: [String])
        case array(
            items: JSONSchema,
            minItems: Int?,
            maxItems: Int?,
            uniqueItems: Bool
        )
        case object(
            properties: [Property],
            additionalProperties: AdditionalProperties
        )
        case oneOf([JSONSchema])
        case anyOf([JSONSchema])
        case constant(JSONValue)
        case reference(String)
    }

    public let form: Form
    public let description: String?
    public let definitions: [String: JSONSchema]
    public let stringFormat: StringFormat?

    public init(
        form: Form,
        description: String? = nil,
        definitions: [String: JSONSchema] = [:],
        stringFormat: StringFormat? = nil
    ) {
        self.form = form
        self.description = description
        self.definitions = definitions
        self.stringFormat = stringFormat
    }
}

public extension JSONSchema {
    static var any: Self {
        .init(form: .any)
    }

    static var null: Self {
        .init(form: .null)
    }

    static func boolean(description: String? = nil) -> Self {
        .init(form: .boolean, description: description)
    }

    static func integer(
        description: String? = nil,
        cases: [Int] = []
    ) -> Self {
        .init(form: .integer(cases: cases), description: description)
    }

    static func number(
        description: String? = nil,
        cases: [Double] = []
    ) -> Self {
        .init(form: .number(cases: cases), description: description)
    }

    static func double(
        description: String? = nil,
        cases: [Double] = []
    ) -> Self {
        number(description: description, cases: cases)
    }

    static func string(
        description: String? = nil,
        cases: [String] = [],
        format: StringFormat? = nil
    ) -> Self {
        .init(
            form: .string(cases: cases),
            description: description,
            stringFormat: format
        )
    }

    static func array(
        description: String? = nil,
        items: JSONSchema,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        uniqueItems: Bool = false
    ) -> Self {
        .init(
            form: .array(
                items: items,
                minItems: minItems,
                maxItems: maxItems,
                uniqueItems: uniqueItems
            ),
            description: description
        )
    }

    static func object(
        description: String? = nil,
        properties: [Property] = [],
        additionalProperties: AdditionalProperties = .allowed
    ) -> Self {
        .init(
            form: .object(
                properties: properties,
                additionalProperties: additionalProperties
            ),
            description: description
        )
    }

    static func object(
        description: String? = nil,
        additionalProperties: AdditionalProperties = .allowed,
        @Properties _ properties: () -> [Property]
    ) -> Self {
        object(
            description: description,
            properties: properties(),
            additionalProperties: additionalProperties
        )
    }

    static func oneOf(
        _ schemas: [JSONSchema],
        description: String? = nil
    ) -> Self {
        .init(form: .oneOf(schemas), description: description)
    }

    static func anyOf(
        _ schemas: [JSONSchema],
        description: String? = nil
    ) -> Self {
        .init(form: .anyOf(schemas), description: description)
    }

    static func constant(
        _ value: JSONValue,
        description: String? = nil
    ) -> Self {
        .init(form: .constant(value), description: description)
    }

    static func reference(
        _ reference: String,
        description: String? = nil
    ) -> Self {
        .init(form: .reference(reference), description: description)
    }

    func described(_ description: String?) -> Self {
        .init(
            form: form,
            description: description,
            definitions: definitions,
            stringFormat: stringFormat
        )
    }

    func defining(_ name: String, as schema: JSONSchema) -> Self {
        defining([name: schema])
    }

    func defining(_ additional: [String: JSONSchema]) -> Self {
        var definitions = definitions
        definitions.merge(additional) { _, new in new }

        return .init(
            form: form,
            description: description,
            definitions: definitions,
            stringFormat: stringFormat
        )
    }
}

public extension JSONSchema {
    @resultBuilder
    enum Properties {
        public static func buildBlock(_ parts: [Property]...) -> [Property] {
            parts.flatMap { $0 }
        }

        public static func buildExpression(_ value: Property) -> [Property] {
            [value]
        }

        public static func buildExpression(_ value: [Property]) -> [Property] {
            value
        }

        public static func buildOptional(_ value: [Property]?) -> [Property] {
            value ?? []
        }

        public static func buildEither(first value: [Property]) -> [Property] {
            value
        }

        public static func buildEither(second value: [Property]) -> [Property] {
            value
        }

        public static func buildArray(_ values: [[Property]]) -> [Property] {
            values.flatMap { $0 }
        }
    }

    static func property(
        _ name: String,
        schema: JSONSchema,
        required: Bool = false,
        description: String? = nil
    ) -> Property {
        .init(
            name: name,
            schema: schema,
            required: required,
            description: description
        )
    }

    static func string(
        _ name: String,
        required: Bool = false,
        description: String? = nil,
        cases: [String] = [],
        format: StringFormat? = nil
    ) -> Property {
        property(
            name,
            schema: .string(cases: cases, format: format),
            required: required,
            description: description
        )
    }

    static func integer(
        _ name: String,
        required: Bool = false,
        description: String? = nil,
        cases: [Int] = []
    ) -> Property {
        property(
            name,
            schema: .integer(cases: cases),
            required: required,
            description: description
        )
    }

    static func number(
        _ name: String,
        required: Bool = false,
        description: String? = nil,
        cases: [Double] = []
    ) -> Property {
        property(
            name,
            schema: .number(cases: cases),
            required: required,
            description: description
        )
    }

    static func double(
        _ name: String,
        required: Bool = false,
        description: String? = nil,
        cases: [Double] = []
    ) -> Property {
        number(
            name,
            required: required,
            description: description,
            cases: cases
        )
    }

    static func boolean(
        _ name: String,
        required: Bool = false,
        description: String? = nil
    ) -> Property {
        property(
            name,
            schema: .boolean(),
            required: required,
            description: description
        )
    }

    static func array(
        _ name: String,
        required: Bool = false,
        description: String? = nil,
        items: JSONSchema,
        minItems: Int? = nil,
        maxItems: Int? = nil,
        uniqueItems: Bool = false
    ) -> Property {
        property(
            name,
            schema: .array(
                items: items,
                minItems: minItems,
                maxItems: maxItems,
                uniqueItems: uniqueItems
            ),
            required: required,
            description: description
        )
    }

    enum Value {
        public static func any() -> JSONSchema { .any }
        public static func null() -> JSONSchema { .null }
        public static func boolean() -> JSONSchema { .boolean() }
        public static func integer(cases: [Int] = []) -> JSONSchema {
            .integer(cases: cases)
        }
        public static func number(cases: [Double] = []) -> JSONSchema {
            .number(cases: cases)
        }
        public static func double(cases: [Double] = []) -> JSONSchema {
            .number(cases: cases)
        }
        public static func string(
            cases: [String] = [],
            format: StringFormat? = nil
        ) -> JSONSchema {
            .string(cases: cases, format: format)
        }
        public static func array(
            items: JSONSchema,
            minItems: Int? = nil
        ) -> JSONSchema {
            .array(items: items, minItems: minItems)
        }
    }
}
