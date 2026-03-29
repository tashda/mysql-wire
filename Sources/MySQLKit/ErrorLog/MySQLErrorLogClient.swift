import MySQLWire

public struct MySQLErrorLogClient: Sendable {
    let serverConnection: MySQLServerConnection

    public func logDestinations() async throws -> [MySQLLogDestination] {
        let variables = try await MySQLServerConfigClient(serverConnection: serverConnection).globalVariables()
        let targetNames = ["log_error", "slow_query_log_file", "general_log_file", "log_output"]
        return variables
            .filter { targetNames.contains($0.name.lowercased()) }
            .map { MySQLLogDestination(kind: $0.name, value: $0.value) }
    }

    public func readTableLog(named tableName: String, limit: Int = 100) async throws -> [[String: String?]] {
        let connection = try await serverConnection.activity()
        let sql = "SELECT * FROM mysql.\(tableName) ORDER BY event_time DESC LIMIT \(limit)"
        let rows = try await connection.simpleQuery(sql)
        return rows.map { row in
            Dictionary(uniqueKeysWithValues: row.columnDefinitions.map { column in
                (column.name, row.column(column.name)?.string)
            })
        }
    }
}
