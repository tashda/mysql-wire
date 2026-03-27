import MySQLWire

public struct MySQLQueryClient: Sendable {
    let serverConnection: MySQLServerConnection

    public func simpleQuery(_ sql: String) async throws -> [MySQLRow] {
        let connection = try await serverConnection.primary()
        return try await connection.simpleQuery(sql)
    }

    public func query(_ sql: String, binds: [MySQLData] = []) async throws -> MySQLWireQueryResult {
        let connection = try await serverConnection.primary()
        return try await connection.query(sql, binds: binds)
    }

    public func stream(_ sql: String) async throws -> AsyncThrowingStream<MySQLRow, Error> {
        let connection = try await serverConnection.primary()
        return try await connection.stream(sql)
    }

    var transaction: MySQLTransactionClient {
        MySQLTransactionClient(serverConnection: serverConnection)
    }
}
