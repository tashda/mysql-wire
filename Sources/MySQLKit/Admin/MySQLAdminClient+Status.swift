import MySQLWire

public extension MySQLAdminClient {
    func globalStatus(named variableName: String? = nil) async throws -> [MySQLStatusVariable] {
        let sql: String
        let binds: [MySQLData]

        if let variableName, !variableName.isEmpty {
            sql = "SHOW GLOBAL STATUS LIKE ?"
            binds = [MySQLData(string: variableName)]
        } else {
            sql = "SHOW GLOBAL STATUS"
            binds = []
        }

        let connection = try await serverConnection.activity()
        let result = try await connection.query(sql, binds: binds)
        return result.rows.compactMap { row in
            guard
                let name = row.column("Variable_name")?.string,
                let value = row.column("Value")?.string
            else {
                return nil
            }
            return MySQLStatusVariable(name: name, value: value)
        }
    }

    func globalVariables(named variableName: String? = nil) async throws -> [MySQLGlobalVariable] {
        let sql: String
        let binds: [MySQLData]

        if let variableName, !variableName.isEmpty {
            sql = "SHOW GLOBAL VARIABLES LIKE ?"
            binds = [MySQLData(string: variableName)]
        } else {
            sql = "SHOW GLOBAL VARIABLES"
            binds = []
        }

        let connection = try await serverConnection.activity()
        let result = try await connection.query(sql, binds: binds)
        return result.rows.compactMap { row in
            guard
                let name = row.column("Variable_name")?.string,
                let value = row.column("Value")?.string
            else {
                return nil
            }
            return MySQLGlobalVariable(name: name, value: value)
        }
    }
}
