import Primitives

@JSONSchema
internal enum JSONSchemaMacroProbeMode:
    String,
    Codable
{
    case first
    case second = "second-value"
}

@JSONSchema
internal struct JSONSchemaMacroProbe:
    Codable
{
    /// Human-readable probe name.
    let name: String

    /// Optional count.
    let count: Int?

    /// Non-optional value that remains omittable on the wire.
    @Schema(required: false)
    let mode: JSONSchemaMacroProbeMode

    let tags: [String]
}

/// Probe for the compiler-synthesized Codable shape of associated-value enums.
@JSONSchema
internal enum JSONSchemaAssociatedEnumProbe:
    Codable
{
    /// Select one labeled pair.
    case pair(
        name: String,
        count: Int
    )

    /// Select one unlabeled value.
    case value(String)

    /// Select one value with an optional associated field.
    case optional(
        value: String,
        note: String?
    )

    /// Select the payloadless case.
    case none
}

private let jsonschemaMacroProbeValue: JSONValue =
    JSONSchemaMacroProbe
        .jsonschema
        .jsonvalue

private let jsonschemaAssociatedEnumProbeValue: JSONValue =
    JSONSchemaAssociatedEnumProbe
        .jsonschema
        .jsonvalue
