public extension MySQLAdminClient {
    func setGlobalVariable(_ name: String, to value: String) async throws -> MySQLServerVariableMutation {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("SET GLOBAL \(name) = \(value)")
        return MySQLServerVariableMutation(name: name, value: value)
    }

    func resetGlobalVariable(_ name: String) async throws -> MySQLServerVariableMutation {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("SET GLOBAL \(name) = DEFAULT")
        return MySQLServerVariableMutation(name: name, value: nil)
    }
}
