public struct MySQLViewClient: Sendable {
    let serverConnection: MySQLServerConnection

    public func createView(
        schema: String,
        name: String,
        definitionSQL: String,
        replace: Bool = false
    ) async throws {
        let createVerb = replace ? "CREATE OR REPLACE" : "CREATE"
        try await executeDDL(
            "\(createVerb) VIEW `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` AS \(definitionSQL)"
        )
    }

    public func alterView(
        schema: String,
        name: String,
        definitionSQL: String
    ) async throws {
        try await executeDDL(
            "ALTER VIEW `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` AS \(definitionSQL)"
        )
    }

    public func dropView(schema: String, name: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP VIEW \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }

    private func executeDDL(_ sql: String) async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery(sql)
    }

    private func escapedIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "``")
    }
}
