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

    /// Optional count; omission and explicit null are both admitted.
    let count: Int?

    let mode: JSONSchemaMacroProbeMode
    let tags: [String]
}

private let jsonschemaMacroProbeValue: JSONValue =
    JSONSchemaMacroProbe
        .jsonschema
        .jsonvalue
