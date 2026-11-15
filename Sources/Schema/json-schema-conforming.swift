import Primitives

/// A JSON value that satisfies a schema. The only way to hold one is to
/// construct it, so holding one is the proof.
public struct JSONSchemaConforming: Invariant, Sendable, Hashable {
    public struct Raw: Sendable, Hashable {
        public var value: JSONValue
        public var schema: JSONSchema

        public init(
            value: JSONValue,
            schema: JSONSchema
        ) {
            self.value = value
            self.schema = schema
        }
    }

    public let value: JSONValue
    public let schema: JSONSchema

    public init(
        _ raw: Raw
    ) throws(JSONSchemaValidationError) {
        do {
            try raw.schema.validate(raw.value)
        } catch let error as JSONSchemaValidationError {
            throw error
        } catch {
            throw JSONSchemaValidationError(reason: String(describing: error))
        }
        self.value = raw.value
        self.schema = raw.schema
    }
}
