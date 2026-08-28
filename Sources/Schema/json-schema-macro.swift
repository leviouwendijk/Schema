@attached(
    extension,
    conformances: JSONSchemaProviding,
    names: named(jsonSchema)
)
public macro JSONSchema() =
    #externalMacro(
        module: "SchemaMacros",
        type: "JSONSchemaMacro"
    )
