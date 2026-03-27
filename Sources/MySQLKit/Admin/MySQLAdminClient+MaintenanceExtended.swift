public extension MySQLAdminClient {
    func repairTable(schema: String, table: String) async throws -> MySQLMaintenanceResult {
        let connection = try await serverConnection.primary()
        let sql = "REPAIR TABLE `\(escapedIdentifierForExtendedMaintenance(schema))`.`\(escapedIdentifierForExtendedMaintenance(table))`"
        let rows = try await connection.simpleQuery(sql)
        let messages = rows.compactMap { row in
            row.column("Msg_text")?.string ?? row.column("msg_text")?.string
        }
        return MySQLMaintenanceResult(operation: "REPAIR TABLE", messages: messages)
    }

    func flushTables() async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("FLUSH TABLES")
    }

    private func escapedIdentifierForExtendedMaintenance(_ value: String) -> String {
        value.replacingOccurrences(of: "`", with: "``")
    }
}
