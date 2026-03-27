import MySQLWire

public extension MySQLMetadataClient {
    func listColumns(in table: String, schema: String? = nil) async throws -> [MySQLColumnInfo] {
        guard let schemaName = try await resolvedSchemaName(schema) else {
            return []
        }

        let sql = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_key,
            character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = ? AND table_name = ?
        ORDER BY ordinal_position;
        """

        let connection = try await serverConnection.metadata()
        let result = try await connection.query(
            sql,
            binds: [
                MySQLData(string: schemaName),
                MySQLData(string: table)
            ]
        )
        return result.rows.compactMap { row in
            guard
                let name = row.column("column_name")?.string,
                let dataType = row.column("data_type")?.string,
                let nullable = row.column("is_nullable")?.string
            else {
                return nil
            }

            let key = row.column("column_key")?.string
            let maxLength = row.column("character_maximum_length")?.string.flatMap(Int.init)

            return MySQLColumnInfo(
                name: name,
                dataType: dataType,
                isNullable: nullable.uppercased() != "NO",
                isPrimaryKey: key == "PRI",
                maxLength: maxLength
            )
        }
    }
}
