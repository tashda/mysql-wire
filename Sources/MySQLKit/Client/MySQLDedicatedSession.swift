import Logging
import MySQLWire

public struct MySQLDedicatedSession: Sendable {
    private let connection: any MySQLConnectionSession

    init(connection: any MySQLConnectionSession) {
        self.connection = connection
    }

    public static func open(
        configuration: MySQLConfiguration,
        logger: Logger = Logger(label: "mysql-kit.dedicated-session")
    ) async throws -> MySQLDedicatedSession {
        let connection = try await MySQLWireConnection.connect(configuration: configuration, logger: logger)
        return MySQLDedicatedSession(connection: connection)
    }

    public func simpleQuery(_ sql: String) async throws -> [MySQLRow] {
        try await connection.simpleQuery(sql)
    }

    public func query(_ sql: String, binds: [MySQLData] = []) async throws -> MySQLWireQueryResult {
        try await connection.query(sql, binds: binds)
    }

    public func stream(_ sql: String) async throws -> AsyncThrowingStream<MySQLRow, Error> {
        try await connection.stream(sql)
    }

    public func close() async {
        await connection.close()
    }
}
