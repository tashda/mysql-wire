import MySQLWire

public extension MySQLPerformanceClient {
    func explain(_ sql: String) async throws -> MySQLExplainPlan {
        let connection = try await serverConnection.primary()
        let rows = try await connection.simpleQuery("EXPLAIN \(sql)")
        let planRows = rows.map { row in
            Dictionary(uniqueKeysWithValues: row.columnDefinitions.map { column in
                (column.name, row.column(column.name)?.string)
            })
        }
        return MySQLExplainPlan(rows: planRows)
    }
}
