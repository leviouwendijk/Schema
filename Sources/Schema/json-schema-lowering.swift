import Primitives

public extension JSONSchema {
    var jsonvalue: JSONValue {
        var value = lowered

        if let description {
            value["description"] = .string(description)
        }

        if !definitions.isEmpty {
            value["$defs"] = .object(
                definitions.mapValues(\.jsonvalue)
            )
        }

        return .object(value)
    }
}

private extension JSONSchema {
    var lowered: [String: JSONValue] {
        switch form {
        case .any:
            return [:]

        case .null:
            return ["type": .string("null")]

        case .boolean:
            return ["type": .string("boolean")]

        case .integer(let cases):
            var value: [String: JSONValue] = ["type": .string("integer")]
            if !cases.isEmpty {
                value["enum"] = .array(cases.map(JSONValue.int))
            }
            return value

        case .number(let cases):
            var value: [String: JSONValue] = ["type": .string("number")]
            if !cases.isEmpty {
                value["enum"] = .array(cases.map(JSONValue.double))
            }
            return value

        case .string(let cases):
            var value: [String: JSONValue] = ["type": .string("string")]
            if !cases.isEmpty {
                value["enum"] = .array(cases.map(JSONValue.string))
            }
            return value

        case let .array(items, minItems, maxItems, uniqueItems):
            var value: [String: JSONValue] = [
                "type": .string("array"),
                "items": items.jsonvalue,
            ]

            if let minItems {
                value["minItems"] = .int(minItems)
            }
            if let maxItems {
                value["maxItems"] = .int(maxItems)
            }
            if uniqueItems {
                value["uniqueItems"] = .bool(true)
            }

            return value

        case let .object(properties, additionalProperties):
            var values: [String: JSONValue] = [:]
            var required: [JSONValue] = []

            for property in properties {
                let schema = property.description.map {
                    property.schema.described($0)
                } ?? property.schema

                values[property.name] = schema.jsonvalue

                if property.required {
                    required.append(.string(property.name))
                }
            }

            var value: [String: JSONValue] = [
                "type": .string("object"),
                "properties": .object(values),
                "additionalProperties": additionalProperties.jsonvalue,
            ]

            if !required.isEmpty {
                value["required"] = .array(required)
            }

            return value

        case .oneOf(let schemas):
            return ["oneOf": .array(schemas.map(\.jsonvalue))]

        case .constant(let value):
            return ["const": value]

        case .reference(let reference):
            return ["$ref": .string(reference)]
        }
    }
}

private extension JSONSchema.AdditionalProperties {
    var jsonvalue: JSONValue {
        switch self {
        case .allowed:
            return .bool(true)
        case .disallowed:
            return .bool(false)
        case .schema(let schema):
            return schema.jsonvalue
        }
    }
}
