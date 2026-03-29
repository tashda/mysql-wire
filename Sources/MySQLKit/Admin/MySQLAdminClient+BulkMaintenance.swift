import MySQLWire

public extension MySQLAdminClient {
    /// Runs CHECK TABLE on multiple tables at once, returning a combined result.
    func checkTables(schema: String, tables: [String]) async throws -> MySQLMaintenanceResult {
        guard !tables.isEmpty else {
            return MySQLMaintenanceResult(operation: "CHECK TABLE", messages: ["No tables specified."])
        }

        let qualified = tables.map { "`\(escapedIdentifier(schema))`.`\(escapedIdentifier($0))`" }
            .joined(separator: ", ")
        let connection = try await serverConnection.primary()
        let rows = try await connection.simpleQuery("CHECK TABLE \(qualified)")
        let messages = rows.compactMap { row in
            row.column("Msg_text")?.string ?? row.column("msg_text")?.string
        }
        return MySQLMaintenanceResult(operation: "CHECK TABLE", messages: messages)
    }
}
