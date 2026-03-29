import MySQLWire

public extension MySQLMetadataClient {
    func listTriggers(in schema: String? = nil) async throws -> [MySQLTriggerInfo] {
        guard let schemaName = try await resolvedSchemaName(schema) else { return [] }

        let sql = """
        SELECT
            trigger_schema,
            trigger_name,
            event_object_table,
            action_timing,
            event_manipulation,
            action_statement
        FROM information_schema.triggers
        WHERE trigger_schema = ?
        ORDER BY trigger_name;
        """

        let connection = try await serverConnection.metadata()
        let result = try await connection.query(sql, binds: [MySQLData(string: schemaName)])
        return result.rows.compactMap { row in
            guard
                let schema = row.column("trigger_schema")?.string,
                let name = row.column("trigger_name")?.string,
                let table = row.column("event_object_table")?.string,
                let timing = row.column("action_timing")?.string,
                let event = row.column("event_manipulation")?.string
            else { return nil }

            return MySQLTriggerInfo(
                schema: schema,
                name: name,
                table: table,
                timing: timing,
                event: event,
                statement: row.column("action_statement")?.string
            )
        }
    }
}
