import MySQLWire

public extension MySQLAdminClient {
    func analyzeTable(schema: String, table: String) async throws -> MySQLMaintenanceResult {
        try await maintenanceResult(
            operation: "ANALYZE TABLE",
            sql: "ANALYZE TABLE `\(escapedIdentifier(schema))`.`\(escapedIdentifier(table))`"
        )
    }

    func optimizeTable(schema: String, table: String) async throws -> MySQLMaintenanceResult {
        try await maintenanceResult(
            operation: "OPTIMIZE TABLE",
            sql: "OPTIMIZE TABLE `\(escapedIdentifier(schema))`.`\(escapedIdentifier(table))`"
        )
    }

    func checkTable(schema: String, table: String) async throws -> MySQLMaintenanceResult {
        try await maintenanceResult(
            operation: "CHECK TABLE",
            sql: "CHECK TABLE `\(escapedIdentifier(schema))`.`\(escapedIdentifier(table))`"
        )
    }

    private func maintenanceResult(operation: String, sql: String) async throws -> MySQLMaintenanceResult {
        let connection = try await serverConnection.primary()
        let rows = try await connection.simpleQuery(sql)
        let messages = rows.compactMap { row in
            row.column("Msg_text")?.string ?? row.column("msg_text")?.string
        }
        return MySQLMaintenanceResult(operation: operation, messages: messages)
    }
}
