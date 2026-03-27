import MySQLWire

public extension MySQLMetadataClient {
    func listEvents(in schema: String? = nil) async throws -> [MySQLEventInfo] {
        guard let schemaName = try await resolvedSchemaName(schema) else { return [] }

        let sql = """
        SELECT
            event_schema,
            event_name,
            status,
            interval_value,
            interval_field,
            event_definition
        FROM information_schema.events
        WHERE event_schema = ?
        ORDER BY event_name;
        """

        let connection = try await serverConnection.metadata()
        let result = try await connection.query(sql, binds: [MySQLData(string: schemaName)])
        return result.rows.compactMap { row in
            guard
                let schema = row.column("event_schema")?.string,
                let name = row.column("event_name")?.string
            else { return nil }

            let intervalValue = row.column("interval_value")?.string
            let intervalField = row.column("interval_field")?.string
            let schedule = [intervalValue, intervalField].compactMap { $0 }.joined(separator: " ")

            return MySQLEventInfo(
                schema: schema,
                name: name,
                status: row.column("status")?.string,
                schedule: schedule.isEmpty ? nil : schedule,
                definition: row.column("event_definition")?.string
            )
        }
    }
}
