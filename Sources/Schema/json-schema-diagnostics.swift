import Primitives

public extension JSONSchema {
    /// Inspect one concrete JSON value against this semantic schema and
    /// return every independently discoverable validation issue.
    ///
    /// Unlike `validate(_:)`, diagnostics do not stop at the first mismatch.
    func diagnostics(
        _ value: JSONValue
    ) -> JSONDiagnostics {
        JSONDiagnostics(
            issues(
                in: value,
                definitions: definitions,
                path: JSONCodingPath([])
            )
        )
    }
}

private extension JSONSchema {
    func issues(
        in value: JSONValue,
        definitions inheritedDefinitions: [String: JSONSchema],
        path: JSONCodingPath
    ) -> [JSONIssue] {
        let availableDefinitions =
            inheritedDefinitions.merging(
                definitions
            ) { _, new in
                new
            }

        switch form {
        case .any:
            return []

        case .null:
            guard case .null = value else {
                return mismatch(
                    path: path,
                    expected: "null"
                )
            }

            return []

        case .boolean:
            guard case .bool = value else {
                return mismatch(
                    path: path,
                    expected: "boolean"
                )
            }

            return []

        case .integer(let cases):
            guard case .int(let actual) = value else {
                return mismatch(
                    path: path,
                    expected: "integer"
                )
            }

            guard cases.isEmpty || cases.contains(actual) else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Expected one of the declared integer values."
                )
            }

            return []

        case .number(let cases):
            let actual: Double

            switch value {
            case .int(let value):
                actual = Double(value)

            case .double(let value):
                actual = value

            default:
                return mismatch(
                    path: path,
                    expected: "number"
                )
            }

            guard cases.isEmpty || cases.contains(actual) else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Expected one of the declared number values."
                )
            }

            return []

        case .string(let cases):
            guard case .string(let actual) = value else {
                return mismatch(
                    path: path,
                    expected: "string"
                )
            }

            guard cases.isEmpty || cases.contains(actual) else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Expected one of the declared string values."
                )
            }

            return []

        case let .array(
            items,
            minItems,
            maxItems,
            uniqueItems
        ):
            guard case .array(let values) = value else {
                return mismatch(
                    path: path,
                    expected: "array"
                )
            }

            var result: [JSONIssue] = []

            if let minItems,
               values.count < minItems
            {
                result.append(
                    JSONIssue(
                        kind: .invalidValue,
                        path: path,
                        reason: "Expected at least \(minItems) item(s)."
                    )
                )
            }

            if let maxItems,
               values.count > maxItems
            {
                result.append(
                    JSONIssue(
                        kind: .invalidValue,
                        path: path,
                        reason: "Expected at most \(maxItems) item(s)."
                    )
                )
            }

            if uniqueItems,
               hasDuplicate(values)
            {
                result.append(
                    JSONIssue(
                        kind: .invalidValue,
                        path: path,
                        reason: "Expected unique array items."
                    )
                )
            }

            for (
                index,
                item
            ) in values.enumerated() {
                result.append(
                    contentsOf: items.issues(
                        in: item,
                        definitions: availableDefinitions,
                        path: appending(
                            .index(index),
                            to: path
                        )
                    )
                )
            }

            return result

        case let .object(
            properties,
            additionalProperties
        ):
            guard case .object(let values) = value else {
                return mismatch(
                    path: path,
                    expected: "object"
                )
            }

            var result: [JSONIssue] = []
            let propertiesByName = Dictionary(
                uniqueKeysWithValues: properties.map {
                    ($0.name, $0)
                }
            )

            for property in properties
            where property.required
                && values[property.name] == nil
            {
                result.append(
                    JSONIssue(
                        kind: .missing,
                        path: appending(
                            .key(property.name),
                            to: path
                        ),
                        reason: "Missing required property '\(property.name)'."
                    )
                )
            }

            for property in properties {
                guard let propertyValue = values[property.name] else {
                    continue
                }

                result.append(
                    contentsOf: property.schema.issues(
                        in: propertyValue,
                        definitions: availableDefinitions,
                        path: appending(
                            .key(property.name),
                            to: path
                        )
                    )
                )
            }

            let additionalNames = values.keys
                .filter {
                    propertiesByName[$0] == nil
                }
                .sorted()

            switch additionalProperties {
            case .allowed:
                break

            case .disallowed:
                for name in additionalNames {
                    result.append(
                        JSONIssue(
                            kind: .unexpected,
                            path: appending(
                                .key(name),
                                to: path
                            ),
                            reason: "Unexpected property '\(name)'."
                        )
                    )
                }

            case .schema(let schema):
                for name in additionalNames {
                    guard let additionalValue = values[name] else {
                        continue
                    }

                    result.append(
                        contentsOf: schema.issues(
                            in: additionalValue,
                            definitions: availableDefinitions,
                            path: appending(
                                .key(name),
                                to: path
                            )
                        )
                    )
                }
            }

            return result

        case .oneOf(let schemas):
            let branches = schemas.map {
                $0.issues(
                    in: value,
                    definitions: availableDefinitions,
                    path: path
                )
            }
            let matches = branches.filter(\.isEmpty).count

            guard matches == 1 else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Expected exactly one oneOf branch to match; matched \(matches)."
                )
            }

            return []

        case .constant(let expected):
            guard value == expected else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Value does not match the declared constant."
                )
            }

            return []

        case .reference(let reference):
            let prefix = "#/$defs/"

            guard reference.hasPrefix(prefix) else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Unsupported non-local schema reference '\(reference)'."
                )
            }

            let encodedName = String(
                reference.dropFirst(
                    prefix.count
                )
            )
            let name = encodedName
                .replacingOccurrences(
                    of: "~1",
                    with: "/"
                )
                .replacingOccurrences(
                    of: "~0",
                    with: "~"
                )

            guard let resolved = availableDefinitions[name] else {
                return issue(
                    .invalidValue,
                    path: path,
                    reason: "Unresolved schema definition '\(name)'."
                )
            }

            return resolved.issues(
                in: value,
                definitions: availableDefinitions,
                path: path
            )
        }
    }

    func mismatch(
        path: JSONCodingPath,
        expected: String
    ) -> [JSONIssue] {
        issue(
            .typeMismatch,
            path: path,
            reason: "Expected \(expected)."
        )
    }

    func issue(
        _ kind: JSONIssue.Kind,
        path: JSONCodingPath,
        reason: String
    ) -> [JSONIssue] {
        [
            JSONIssue(
                kind: kind,
                path: path,
                reason: reason
            ),
        ]
    }

    func appending(
        _ component: JSONCodingPath.Component,
        to path: JSONCodingPath
    ) -> JSONCodingPath {
        JSONCodingPath(
            path.components + [component]
        )
    }

    func hasDuplicate(
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
