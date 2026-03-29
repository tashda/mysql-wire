import MySQLWire

public extension MySQLAdminClient {
    /// Drops an index by name. Automatically resolves the owning table via `information_schema.statistics`.
    func dropIndex(schema: String, name: String) async throws {
        let connection = try await serverConnection.primary()

        // MySQL DROP INDEX requires ON <table> — resolve it from information_schema
        let lookupSQL = """
        SELECT TABLE_NAME FROM information_schema.statistics
        WHERE TABLE_SCHEMA = ? AND INDEX_NAME = ?
        LIMIT 1;
        """
        let result = try await connection.query(
            lookupSQL,
            binds: [MySQLData(string: schema), MySQLData(string: name)]
        )
        guard let tableName = result.rows.first?.column("TABLE_NAME")?.string else {
            throw MySQLAdminError.indexNotFound(name: name, schema: schema)
        }

        let escaped = "`\(escapedIdentifier(schema))`.`\(escapedIdentifier(tableName))`"
        _ = try await connection.simpleQuery("DROP INDEX `\(escapedIdentifier(name))` ON \(escaped)")
    }

    /// Drops a named index from a specific table.
    func dropIndex(schema: String, table: String, name: String) async throws {
        let escaped = "`\(escapedIdentifier(schema))`.`\(escapedIdentifier(table))`"
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("DROP INDEX `\(escapedIdentifier(name))` ON \(escaped)")
    }
}

public enum MySQLAdminError: Error, Sendable {
    case indexNotFound(name: String, schema: String)
}
