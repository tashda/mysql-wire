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
            column_type,
            is_nullable,
            column_key,
            character_maximum_length,
            column_default,
            generation_expression,
            extra,
            collation_name,
            character_set_name,
            ordinal_position
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
            let fullDataType = row.column("column_type")?.string ?? dataType
            let generationExpression = row.column("generation_expression")?.string?.nilIfEmpty
            let extra = row.column("extra")?.string?.lowercased() ?? ""
            let ordinalPosition = row.column("ordinal_position")?.string.flatMap(Int.init) ?? 0

            return MySQLColumnInfo(
                name: name,
                dataType: dataType,
                fullDataType: fullDataType,
                isNullable: nullable.uppercased() != "NO",
                isPrimaryKey: key == "PRI",
                maxLength: maxLength,
                defaultValue: row.column("column_default")?.string,
                generationExpression: generationExpression,
                isAutoIncrement: extra.contains("auto_increment"),
                collation: row.column("collation_name")?.string,
                characterSet: row.column("character_set_name")?.string,
                ordinalPosition: ordinalPosition
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
