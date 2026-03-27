import MySQLWire

public extension MySQLPerformanceClient {
    func topRuntimeStatements(limit: Int = 10) async throws -> MySQLPerformanceReport {
        try await runReport(
            """
            SELECT * FROM sys.statements_with_runtimes_in_95th_percentile
            LIMIT \(limit)
            """,
            name: "statements_with_runtimes_in_95th_percentile"
        )
    }

    func fullTableScans(limit: Int = 10) async throws -> MySQLPerformanceReport {
        try await runReport(
            """
            SELECT * FROM sys.statements_with_full_table_scans
            LIMIT \(limit)
            """,
            name: "statements_with_full_table_scans"
        )
    }

    func innodbStatus() async throws -> MySQLInnoDBStatus {
        let connection = try await serverConnection.activity()
        let rows = try await connection.simpleQuery("SHOW ENGINE INNODB STATUS")
        let status = rows.first?.column("Status")?.string ?? ""
        return MySQLInnoDBStatus(statusText: status)
    }
}
