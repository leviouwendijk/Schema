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

private let jsonschemaMacroProbeValue: JSONValue =
    JSONSchemaMacroProbe
        .jsonschema
        .jsonvalue
