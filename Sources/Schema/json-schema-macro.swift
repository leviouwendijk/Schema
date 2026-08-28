@attached(
    extension,
    conformances: JSONSchemaProviding,
    names: named(jsonschema)
)
public macro JSONSchema() =
    #externalMacro(
        module: "SchemaMacros",
        type: "JSONSchemaMacro"
    )

@attached(peer, names: arbitrary)
public macro Schema(
    required: Bool? = nil
) =
    #externalMacro(
        module: "SchemaMacros",
        type: "SchemaPropertyMacro"
    )
