public extension MySQLReplicationClient {
    func replicaStatus() async throws -> MySQLReplicationStatus? {
        let connection = try await serverConnection.activity()
        let rows = try await connection.simpleQuery("SHOW REPLICA STATUS")
        guard let row = rows.first else { return nil }

        let values = Dictionary(uniqueKeysWithValues: row.columnDefinitions.map { column in
            (column.name, row.column(column.name)?.string)
        })
        return MySQLReplicationStatus(rawValues: values)
    }
}
