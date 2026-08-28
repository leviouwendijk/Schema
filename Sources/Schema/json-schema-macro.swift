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
