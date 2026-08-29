import Primitives

/// Failure produced when a concrete JSON value does not satisfy a semantic JSONSchema.
public struct JSONSchemaValidationError:
    Error,
    Sendable,
    Hashable,
    CustomStringConvertible
{
    public let path: String
    public let reason: String

    public init(
        path: String = "$",
        reason: String
    ) {
        self.path = path
        self.reason = reason
    }

    public var description: String {
        "\(path): \(reason)"
    }
}

public extension JSONSchema {
    /// Validate one concrete JSON value against this semantic schema.
    ///
    /// Local references use the schema's `$defs` namespace. External references
    /// are intentionally unsupported so validation remains deterministic.
    func validate(
        _ value: JSONValue
    ) throws {
        try validate(
            value,
            definitions: definitions,
            path: "$"
        )
    }

    /// Return whether one concrete JSON value satisfies this schema.
    func accepts(
        _ value: JSONValue
    ) -> Bool {
        do {
            try validate(
                value
            )
            return true
        } catch {
            return false
        }
    }
}

private extension JSONSchema {
    func validate(
        _ value: JSONValue,
        definitions inheritedDefinitions: [String: JSONSchema],
        path: String
    ) throws {
        let availableDefinitions =
            inheritedDefinitions.merging(
                definitions
            ) { _, new in
                new
            }

        switch form {
        case .any:
            return

        case .null:
            guard case .null = value else {
                throw mismatch(
                    path: path,
                    expected: "null"
                )
            }

        case .boolean:
            guard case .bool = value else {
                throw mismatch(
                    path: path,
                    expected: "boolean"
                )
            }

        case .integer(let cases):
            guard case .int(let actual) = value else {
                throw mismatch(
                    path: path,
                    expected: "integer"
                )
            }

            if !cases.isEmpty,
               !cases.contains(actual)
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected one of the declared integer values."
                )
            }

        case .number(let cases):
            let actual: Double

            switch value {
            case .int(let value):
                actual = Double(value)

            case .double(let value):
                actual = value

            default:
                throw mismatch(
                    path: path,
                    expected: "number"
                )
            }

            if !cases.isEmpty,
               !cases.contains(actual)
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected one of the declared number values."
                )
            }

        case .string(let cases):
            guard case .string(let actual) = value else {
                throw mismatch(
                    path: path,
                    expected: "string"
                )
            }

            if !cases.isEmpty,
               !cases.contains(actual)
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected one of the declared string values."
                )
            }

        case let .array(
            items,
            minItems,
            maxItems,
            uniqueItems
        ):
            guard case .array(let values) = value else {
                throw mismatch(
                    path: path,
                    expected: "array"
                )
            }

            if let minItems,
               values.count < minItems
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected at least \(minItems) item(s)."
                )
            }

            if let maxItems,
               values.count > maxItems
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected at most \(maxItems) item(s)."
                )
            }

            if uniqueItems,
               containsDuplicate(
                    values
               )
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected unique array items."
                )
            }

            for (
                index,
                item
            ) in values.enumerated() {
                try items.validate(
                    item,
                    definitions: availableDefinitions,
                    path: "\(path)[\(index)]"
                )
            }

        case let .object(
            properties,
            additionalProperties
        ):
            guard case .object(let values) = value else {
                throw mismatch(
                    path: path,
                    expected: "object"
                )
            }

            let propertiesByName =
                Dictionary(
                    uniqueKeysWithValues:
                        properties.map {
                            (
                                $0.name,
                                $0
                            )
                        }
                )

            for property in properties
            where property.required
                && values[property.name] == nil
            {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Missing required property '\(property.name)'."
                )
            }

            for (
                name,
                property
            ) in propertiesByName {
                guard let propertyValue =
                    values[name]
                else {
                    continue
                }

                try property.schema.validate(
                    propertyValue,
                    definitions: availableDefinitions,
                    path: propertyPath(
                        name,
                        parent: path
                    )
                )
            }

            let additionalNames =
                values.keys.filter {
                    propertiesByName[$0] == nil
                }

            switch additionalProperties {
            case .allowed:
                break

            case .disallowed:
                guard additionalNames.isEmpty else {
                    throw JSONSchemaValidationError(
                        path: path,
                        reason: "Unexpected property '\(additionalNames.sorted()[0])'."
                    )
                }

            case .schema(let schema):
                for name in additionalNames {
                    guard let additionalValue =
                        values[name]
                    else {
                        continue
                    }

                    try schema.validate(
                        additionalValue,
                        definitions: availableDefinitions,
                        path: propertyPath(
                            name,
                            parent: path
                        )
                    )
                }
            }

        case .oneOf(let schemas):
            var matches = 0

            for schema in schemas {
                if schema.accepts(
                    value,
                    definitions: availableDefinitions,
                    path: path
                ) {
                    matches += 1
                }
            }

            guard matches == 1 else {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Expected exactly one oneOf branch to match; matched \(matches)."
                )
            }

        case .constant(let expected):
            guard value == expected else {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Value does not match the declared constant."
                )
            }

        case .reference(let reference):
            let prefix = "#/$defs/"

            guard reference.hasPrefix(
                prefix
            ) else {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Unsupported non-local schema reference '\(reference)'."
                )
            }

            let encodedName =
                String(
                    reference.dropFirst(
                        prefix.count
                    )
                )
            let name =
                encodedName
                    .replacingOccurrences(
                        of: "~1",
                        with: "/"
                    )
                    .replacingOccurrences(
                        of: "~0",
                        with: "~"
                    )

            guard let resolved =
                availableDefinitions[name]
            else {
                throw JSONSchemaValidationError(
                    path: path,
                    reason: "Unresolved schema definition '\(name)'."
                )
            }

            try resolved.validate(
                value,
                definitions: availableDefinitions,
                path: path
            )
        }
    }

    func accepts(
        _ value: JSONValue,
        definitions: [String: JSONSchema],
        path: String
    ) -> Bool {
        do {
            try validate(
                value,
                definitions: definitions,
                path: path
            )
            return true
        } catch {
            return false
        }
    }

    func mismatch(
        path: String,
        expected: String
    ) -> JSONSchemaValidationError {
        .init(
            path: path,
            reason: "Expected \(expected)."
        )
    }

    func propertyPath(
        _ property: String,
        parent: String
    ) -> String {
        let simple =
            !property.isEmpty
            && property.allSatisfy {
                $0.isLetter
                    || $0.isNumber
                    || $0 == "_"
            }

        if simple {
            return "\(parent).\(property)"
        }

        let escaped =
            property
                .replacingOccurrences(
                    of: "\\",
                    with: "\\\\"
                )
                .replacingOccurrences(
                    of: "\"",
                    with: "\\\""
                )

        return "\(parent)[\"\(escaped)\"]"
    }

    func containsDuplicate(
        _ values: [JSONValue]
    ) -> Bool {
        for index in values.indices {
            for laterIndex in values.indices
            where laterIndex > index {
                if values[index] == values[laterIndex] {
                    return true
                }
            }
        }

        return false
    }
}
