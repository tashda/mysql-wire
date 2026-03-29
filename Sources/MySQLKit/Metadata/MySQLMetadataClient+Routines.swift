import MySQLWire

public extension MySQLMetadataClient {
    func listRoutines(in schema: String? = nil) async throws -> [MySQLRoutineInfo] {
        guard let schemaName = try await resolvedSchemaName(schema) else { return [] }

        let sql = """
        SELECT
            routine_schema,
            routine_name,
            routine_type,
            routine_definition
        FROM information_schema.routines
        WHERE routine_schema = ?
        ORDER BY routine_name;
        """

        let connection = try await serverConnection.metadata()
        let result = try await connection.query(sql, binds: [MySQLData(string: schemaName)])
        return result.rows.compactMap { row in
            guard
                let schema = row.column("routine_schema")?.string,
                let name = row.column("routine_name")?.string,
                let type = row.column("routine_type")?.string
            else { return nil }

            return MySQLRoutineInfo(
                schema: schema,
                name: name,
                type: type,
                definition: row.column("routine_definition")?.string
            )
        }
    }
}
