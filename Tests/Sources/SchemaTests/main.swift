import Foundation
import Primitives
import Schema

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

func check_format(
    _ schema: JSONSchema,
    expected: String
) throws {
    let lowered = try schema.jsonvalue.objectValue
    check(lowered["type"] == .string("string"), "Expected string schema")
    check(lowered["format"] == .string(expected), "Expected format \(expected)")
}

func run_schema_tests() throws {
    let nullable_any = Optional<JSONValue>.jsonschema
    check(nullable_any.accepts(.null), "Optional JSONValue must accept null")
    check(nullable_any.accepts(.bool(true)), "Optional JSONValue must accept boolean")
    check(nullable_any.accepts(.object([:])), "Optional JSONValue must accept objects")

    let nullable_string = Optional<String>.jsonschema
    check(nullable_string.accepts(.null), "Optional String must accept null")
    check(nullable_string.accepts(.string("value")), "Optional String must accept string")
    check(!nullable_string.accepts(.int(1)), "Optional String must reject integer")

    let nested_optional = Optional<Optional<JSONValue>>.jsonschema
    check(nested_optional.accepts(.null), "Nested optional must accept null")
    check(nested_optional.accepts(.int(7)), "Nested optional must accept integer")

    let overlap = JSONSchema.anyOf([.any, .null])
    check(overlap.accepts(.null), "anyOf must accept overlapping branches")
    check(overlap.accepts(.int(1)), "anyOf must accept matching values")
    try overlap.validate(.null)
    check(overlap.diagnostics(.null).issues.isEmpty, "anyOf diagnostics must accept overlap")

    let strict_union = JSONSchema.oneOf([.any, .null])
    check(!strict_union.accepts(.null), "oneOf must reject multiple matches")

    let disjoint = JSONSchema.anyOf([.string(), .boolean()])
    check(disjoint.accepts(.string("x")), "anyOf must accept first branch")
    check(disjoint.accepts(.bool(false)), "anyOf must accept second branch")
    check(!disjoint.accepts(.int(1)), "anyOf must reject unmatched values")
    check(!disjoint.diagnostics(.int(1)).issues.isEmpty, "anyOf diagnostics must reject unmatched values")

    let lowered_union = try overlap.jsonvalue.objectValue
    check(lowered_union["oneOf"] == nil, "anyOf must not lower to oneOf")
    check(lowered_union["anyOf"] != nil, "anyOf must lower to anyOf")

    try check_format(UUID.jsonschema, expected: "uuid")
    try check_format(URL.jsonschema, expected: "uri")
    try check_format(.string(format: .date_time), expected: "date-time")

    for format in [
        JSONSchema.StringFormat.uuid,
        .uri,
        .date_time,
    ] {
        let encoded = try JSONEncoder().encode(format)
        let decoded = try JSONDecoder().decode(
            JSONSchema.StringFormat.self,
            from: encoded
        )
        check(decoded == format, "StringFormat Codable round-trip failed")
    }

    let date_time_data = try JSONEncoder().encode(
        JSONSchema.StringFormat.date_time
    )
    check(
        String(data: date_time_data, encoding: .utf8) == "\"date-time\"",
        "date_time must encode as date-time"
    )

    let decoded_date_time = try JSONDecoder().decode(
        JSONSchema.StringFormat.self,
        from: Data("\"date-time\"".utf8)
    )
    check(decoded_date_time == .date_time, "date-time must decode as date_time")

    do {
        _ = try JSONDecoder().decode(
            JSONSchema.StringFormat.self,
            from: Data("\"datetime\"".utf8)
        )
        check(false, "Unknown format spelling must not decode")
    } catch is DecodingError {
    }

    let composed = JSONSchema.string(format: .uuid)
        .described("Identifier")
        .defining("unused", as: .string())
    try check_format(composed, expected: "uuid")

    let property = JSONSchema.string(
        "identifier",
        required: true,
        format: .uuid
    )
    let object = JSONSchema.object(properties: [property])
    let object_schema = try object.jsonvalue.objectValue

    guard let properties_value = object_schema["properties"] else {
        fatalError("Missing properties schema")
    }
    let properties = try properties_value.objectValue

    guard let identifier_value = properties["identifier"] else {
        fatalError("Missing identifier schema")
    }
    let identifier = try identifier_value.objectValue

    check(
        identifier["format"] == .string("uuid"),
        "Property must preserve format"
    )
    check(
        object_schema["required"] == .array([.string("identifier")]),
        "Requiredness must be independent of format"
    )

    let plain_string = try JSONSchema.string().jsonvalue.objectValue
    check(plain_string["format"] == nil, "Plain strings have no implicit format")

    check(
        JSONSchema.string(format: .uuid).accepts(.string("not-a-uuid")),
        "Formats remain annotations, not validation assertions"
    )
    check(
        Date.jsonschema.accepts(.double(1.0)),
        "Existing Date strategy remains numeric"
    )

    let documented = JSONSchema.string(
        description: "Where a constraint comes from.",
        cases: ["stated", "assumed"],
        caseDescriptions: [
            "assumed": "Not verified.",
            "stated": "The user said it.",
        ]
    )
    let lowered_enum = try documented.jsonvalue.objectValue
    check(
        lowered_enum["enum"] == .array([.string("stated"), .string("assumed")]),
        "Documented enums keep their enum values"
    )
    check(
        lowered_enum["description"] == .string(
            "Where a constraint comes from.\n- stated: The user said it.\n- assumed: Not verified."
        ),
        "Case descriptions fold into the description in declared order"
    )
    check(
        documented.described("Provenance.").caseDescriptions == documented.caseDescriptions,
        "A property description keeps the type's case descriptions"
    )

    let legacy_schema = try JSONDecoder().decode(
        JSONSchema.self,
        from: try JSONEncoder().encode(JSONSchema.string(cases: ["a"]))
    )
    check(legacy_schema.caseDescriptions.isEmpty, "Undocumented schemas round-trip")

    let legacy_payload = Data(
        #"{"form":{"string":{"cases":["a"]}},"definitions":{}}"#.utf8
    )
    check(
        (try? JSONDecoder().decode(JSONSchema.self, from: legacy_payload))?.caseDescriptions == [:],
        "Schemas encoded before case descriptions still decode"
    )
}

func run_conforming_tests() {
    let report = JSONSchema.object {
        JSONSchema.property("summary", schema: .string(), required: true)
    }
    let conforming = try? JSONSchemaConforming(.init(value: .object(["summary": .string("ok")]), schema: report))
    check(conforming?.value == .object(["summary": .string("ok")]), "A conforming value is constructed")
    check(
        (try? JSONSchemaConforming(.init(value: .array([]), schema: report))) == nil,
        "A value of the wrong shape cannot be constructed"
    )
    check(
        (try? JSONSchemaConforming(.init(value: .object([:]), schema: report))) == nil,
        "A value missing a required field cannot be constructed"
    )
}

try run_schema_tests()
run_conforming_tests()
print("Schema regression tests passed")
