import Logging
import MySQLWire
import Testing
@testable import MySQLKit

actor MockConnectionSession: MySQLConnectionSession {
    private(set) var simpleQueries: [String] = []
    private(set) var changedDatabases: [String] = []
    private let databaseName: String?

    init(databaseName: String? = "echo") {
        self.databaseName = databaseName
    }

    func simpleQuery(_ sql: String) async throws -> [MySQLRow] {
        simpleQueries.append(sql)
        return []
    }

    func query(_ sql: String, binds: [MySQLData]) async throws -> MySQLWireQueryResult {
        simpleQueries.append(sql)
        return MySQLWireQueryResult(rows: [], metadata: nil)
    }

    func stream(_ sql: String) async throws -> AsyncThrowingStream<MySQLRow, Error> {
        simpleQueries.append(sql)
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func changeDatabase(_ database: String) async throws {
        changedDatabases.append(database)
    }

    func currentDatabase() async throws -> String? {
        databaseName
    }

    func validate() async throws {}

    func close() async {}
}

actor ConnectionFactoryCounter {
    private var value = 0

    func next() -> Int {
        value += 1
        return value
    }

    func current() -> Int {
        value
    }
}

struct MySQLClientTests {
    @Test
    func namespacesUseExpectedConnections() async throws {
        let primary = MockConnectionSession(databaseName: "primary_db")
        let metadata = MockConnectionSession(databaseName: "metadata_db")
        let counter = ConnectionFactoryCounter()

        let serverConnection = MySQLServerConnection(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            logger: Logger(label: "tests.mysql-kit"),
            connectionFactory: { _, _ in
                let createdConnections = await counter.next()
                return createdConnections == 1 ? primary : metadata
            }
        )
        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: serverConnection
        )

        _ = try await client.query.simpleQuery("SELECT 1")
        _ = try await client.metadata.listDatabases()
        let currentDatabase = try await client.metadata.currentDatabase()
        try await client.metadata.selectDatabase("analytics")

        #expect(await counter.current() == 2)
        #expect(currentDatabase == "primary_db")
        #expect(await primary.simpleQueries == ["SELECT 1"])
        #expect(await metadata.simpleQueries == ["SHOW DATABASES"])
        #expect(await primary.changedDatabases == ["analytics"])
    }
}
