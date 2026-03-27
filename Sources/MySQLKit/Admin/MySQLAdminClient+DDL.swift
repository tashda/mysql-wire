public extension MySQLAdminClient {
    func executeDDL(_ sql: String) async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery(sql)
    }

    func renameTable(schema: String, from oldName: String, to newName: String) async throws {
        try await executeDDL(
            "RENAME TABLE `\(escapedIdentifier(schema))`.`\(escapedIdentifier(oldName))` TO `\(escapedIdentifier(schema))`.`\(escapedIdentifier(newName))`"
        )
    }

    func dropTable(schema: String, name: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP TABLE \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }

    func escapedIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "``")
    }
}
