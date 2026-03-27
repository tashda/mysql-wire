public extension MySQLSecurityClient {
    func createUser(
        username: String,
        host: String,
        password: String? = nil,
        authenticationPlugin: String? = nil
    ) async throws {
        var statement = "CREATE USER '\(escapedLiteral(username))'@'\(escapedLiteral(host))'"
        if let authenticationPlugin, !authenticationPlugin.isEmpty {
            statement += " IDENTIFIED WITH \(authenticationPlugin)"
        }
        if let password {
            statement += " BY '\(escapedLiteral(password))'"
        }
        try await executeSecurityStatement(statement)
    }

    func dropUser(username: String, host: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeSecurityStatement(
            "DROP USER \(existsClause)'\(escapedLiteral(username))'@'\(escapedLiteral(host))'"
        )
    }

    func grant(
        _ privilege: String,
        on object: String,
        to username: String,
        host: String
    ) async throws {
        try await executeSecurityStatement(
            "GRANT \(privilege) ON \(object) TO '\(escapedLiteral(username))'@'\(escapedLiteral(host))'"
        )
    }

    func revoke(
        _ privilege: String,
        on object: String,
        from username: String,
        host: String
    ) async throws {
        try await executeSecurityStatement(
            "REVOKE \(privilege) ON \(object) FROM '\(escapedLiteral(username))'@'\(escapedLiteral(host))'"
        )
    }

    func createRole(name: String, host: String = "%") async throws {
        try await executeSecurityStatement("CREATE ROLE '\(escapedLiteral(name))'@'\(escapedLiteral(host))'")
    }

    func dropRole(name: String, host: String = "%") async throws {
        try await executeSecurityStatement("DROP ROLE '\(escapedLiteral(name))'@'\(escapedLiteral(host))'")
    }

    private func executeSecurityStatement(_ sql: String) async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery(sql)
    }

    private func escapedLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
