import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct JSONSchemaMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try rejectCustomCoding(declaration)

        let schema: String
        if let value = declaration.as(StructDeclSyntax.self) {
            schema = try structSchema(value)
        } else if let value = declaration.as(EnumDeclSyntax.self) {
            schema = try enumSchema(value)
        } else {
            throw MacroExpansionErrorMessage(
                "@JSONSchema supports structs and String raw-value enums."
            )
        }

        let source = """
        extension \(type.trimmedDescription): JSONSchemaProviding {
            \(access(declaration))static var jsonschema: JSONSchema {
        \(indent(schema, by: 8))
            }
        }
        """

        guard let value = DeclSyntax(stringLiteral: source)
            .as(ExtensionDeclSyntax.self)
        else {
            throw MacroExpansionErrorMessage(
                "@JSONSchema failed to form its generated extension."
            )
        }

        return [value]
    }
}

private extension JSONSchemaMacro {
    struct Field {
        let name: String
        let type: String
        let required: Bool
        let description: String?
    }

    struct SchemaMetadata {
        let required: Bool?
    }

    static func structSchema(
        _ declaration: StructDeclSyntax
    ) throws -> String {
        guard declaration.genericParameterClause == nil else {
            throw MacroExpansionErrorMessage(
                "Generic structs require manual JSONSchemaProviding conformance."
            )
        }

        let keys = try codingKeys(in: declaration.memberBlock.members)
        var fields: [Field] = []

        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            if variable.modifiers.contains(where: {
                $0.name.text == "static" || $0.name.text == "class"
            }) {
                continue
            }

            let schemaMetadata = try schemaMetadata(
                variable.attributes
            )

            guard variable.bindings.count == 1,
                  let binding = variable.bindings.first
            else {
                throw MacroExpansionErrorMessage(
                    "@JSONSchema requires one stored property per declaration."
                )
            }

            if binding.accessorBlock != nil {
                continue
            }

            guard binding.initializer == nil else {
                throw MacroExpansionErrorMessage(
                    "Stored-property defaults require manual JSONSchemaProviding conformance."
                )
            }

            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type
            else {
                throw MacroExpansionErrorMessage(
                    "@JSONSchema requires explicitly typed stored properties."
                )
            }

            let sourceName = pattern.identifier.text
            let name: String

            if let keys {
                guard let codingName = keys[sourceName] else {
                    continue
                }
                name = codingName
            } else {
                name = sourceName
            }

            guard !type.trimmedDescription.hasSuffix("!") else {
                throw MacroExpansionErrorMessage(
                    "Implicitly unwrapped optionals require manual JSONSchemaProviding conformance."
                )
            }

            fields.append(
                .init(
                    name: name,
                    type: schemaPropertyType(type),
                    required:
                        schemaMetadata.required
                            ?? !isOptional(type),
                    description: docs(variable.leadingTrivia)
                )
            )
        }

        let description = optionalString(docs(declaration.leadingTrivia))

        guard !fields.isEmpty else {
            return "JSONSchema.object(description: \(description))"
        }

        let properties = fields.map {
            """
            JSONSchema.Property(
                name: \(literal($0.name)),
                schema: \($0.type).jsonschema,
                required: \($0.required),
                description: \(optionalString($0.description))
            )
            """
        }
        .joined(separator: "\n")

        return """
        JSONSchema.object(description: \(description)) {
        \(indent(properties, by: 4))
        }
        """
    }

    static func enumSchema(
        _ declaration: EnumDeclSyntax
    ) throws -> String {
        guard declaration.genericParameterClause == nil else {
            throw MacroExpansionErrorMessage(
                "Generic enums require manual JSONSchemaProviding conformance."
            )
        }

        let inherited = declaration.inheritanceClause?
            .inheritedTypes
            .map { $0.type.trimmedDescription } ?? []

        guard inherited.contains("String") else {
            throw MacroExpansionErrorMessage(
                "@JSONSchema enum synthesis requires a String raw value."
            )
        }

        var values: [String] = []

        for member in declaration.memberBlock.members {
            guard let cases = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            for element in cases.elements {
                guard element.parameterClause == nil else {
                    throw MacroExpansionErrorMessage(
                        "Associated-value enums require manual JSONSchemaProviding conformance."
                    )
                }

                if let expression = element.rawValue?.value {
                    guard let raw = simpleLiteral(expression) else {
                        throw MacroExpansionErrorMessage(
                            "@JSONSchema requires simple literal String enum raw values."
                        )
                    }
                    values.append(raw)
                } else {
                    values.append(element.name.text)
                }
            }
        }

        return """
        JSONSchema.string(
            description: \(optionalString(docs(declaration.leadingTrivia))),
            cases: [\(values.map(literal).joined(separator: ", "))]
        )
        """
    }
}

private extension JSONSchemaMacro {
    static func rejectCustomCoding(
        _ declaration: some DeclGroupSyntax
    ) throws {
        for member in declaration.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self),
               function.name.text == "encode" {
                throw MacroExpansionErrorMessage(
                    "Custom encode(to:) requires manual JSONSchemaProviding conformance."
                )
            }

            if let initializer = member.decl.as(InitializerDeclSyntax.self),
               initializer.signature.parameterClause.parameters.first?
                .firstName.text == "from" {
                throw MacroExpansionErrorMessage(
                    "Custom init(from:) requires manual JSONSchemaProviding conformance."
                )
            }
        }
    }

    static func codingKeys(
        in members: MemberBlockItemListSyntax
    ) throws -> [String: String]? {
        guard let declaration = members.compactMap({
            $0.decl.as(EnumDeclSyntax.self)
        })
        .first(where: { $0.name.text == "CodingKeys" })
        else {
            return nil
        }

        let inherited = declaration.inheritanceClause?
            .inheritedTypes
            .map { $0.type.trimmedDescription } ?? []

        guard inherited.contains("String"),
              inherited.contains("CodingKey")
        else {
            throw MacroExpansionErrorMessage(
                "@JSONSchema understands only CodingKeys: String, CodingKey."
            )
        }

        var result: [String: String] = [:]

        for member in declaration.memberBlock.members {
            guard let cases = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            for element in cases.elements {
                let source = element.name.text
                if let expression = element.rawValue?.value {
                    guard let value = simpleLiteral(expression) else {
                        throw MacroExpansionErrorMessage(
                            "CodingKeys raw values must be simple String literals."
                        )
                    }
                    result[source] = value
                } else {
                    result[source] = source
                }
            }
        }

        return result
    }

    static func schemaMetadata(
        _ attributes: AttributeListSyntax
    ) throws -> SchemaMetadata {
        let source = attributes
            .trimmedDescription
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")

        switch source {
        case "":
            return .init(required: nil)

        case "@Schema", "@Schema()":
            return .init(required: nil)

        case "@Schema(required:true)":
            return .init(required: true)

        case "@Schema(required:false)":
            return .init(required: false)

        default:
            throw MacroExpansionErrorMessage(
                "@JSONSchema stored properties support only @Schema(required:) metadata; other attributes or wrappers require manual JSONSchemaProviding conformance."
            )
        }
    }

    static func isOptional(_ type: TypeSyntax) -> Bool {
        if type.is(OptionalTypeSyntax.self) {
            return true
        }

        let text = type.trimmedDescription
        return text.hasPrefix("Optional<") && text.hasSuffix(">")
    }

    static func schemaPropertyType(
        _ type: TypeSyntax
    ) -> String {
        let value = schemaType(type)

        guard value.hasPrefix("Optional<"),
              value.hasSuffix(">")
        else {
            return value
        }

        return String(
            value
                .dropFirst("Optional<".count)
                .dropLast()
        )
    }

    static func schemaType(_ type: TypeSyntax) -> String {
        if let value = type.as(OptionalTypeSyntax.self) {
            return "Optional<\(schemaType(value.wrappedType))>"
        }

        if let value = type.as(ArrayTypeSyntax.self) {
            return "Array<\(schemaType(value.element))>"
        }

        if let value = type.as(DictionaryTypeSyntax.self) {
            return "Dictionary<\(schemaType(value.key)), \(schemaType(value.value))>"
        }

        return type.trimmedDescription
    }

    static func simpleLiteral(_ expression: ExprSyntax) -> String? {
        guard let value = expression.as(StringLiteralExprSyntax.self),
              value.segments.count == 1,
              let segment = value.segments.first?.as(StringSegmentSyntax.self)
        else {
            return nil
        }

        let text = segment.content.text
        return text.contains("\\") ? nil : text
    }
}

private extension JSONSchemaMacro {
    static func access(_ declaration: some DeclGroupSyntax) -> String {
        if declaration.modifiers.contains(where: {
            $0.name.text == "public" || $0.name.text == "open"
        }) {
            return "public "
        }

        if declaration.modifiers.contains(where: {
            $0.name.text == "package"
        }) {
            return "package "
        }

        return ""
    }

    static func docs(_ trivia: Trivia) -> String? {
        var lines: [String] = []

        for piece in trivia {
            switch piece {
            case .docLineComment(let text):
                lines.append(
                    String(text.dropFirst(3))
                        .trimmingCharacters(in: .whitespaces)
                )

            case .docBlockComment(let text):
                var text = text
                if text.hasPrefix("/**") { text.removeFirst(3) }
                if text.hasSuffix("*/") { text.removeLast(2) }

                lines += text.components(separatedBy: .newlines).map {
                    var line = $0.trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("*") { line.removeFirst() }
                    return line.trimmingCharacters(in: .whitespaces)
                }

            default:
                continue
            }
        }

        let value = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return value.isEmpty ? nil : value
    }

    static func optionalString(_ value: String?) -> String {
        value.map(literal) ?? "nil"
    }

    static func literal(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        return "\"\(escaped)\""
    }

    static func indent(_ value: String, by spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return value.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map { prefix + $0 }
        .joined(separator: "\n")
    }
}

public struct SchemaPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

@main
struct SchemaPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        JSONSchemaMacro.self,
        SchemaPropertyMacro.self,
    ]
}
