import Logging
import MySQLWire
import NIOCore
import Testing
@testable import MySQLKit

actor MockConnectionSession: MySQLConnectionSession {
    private(set) var simpleQueries: [String] = []
    private(set) var changedDatabases: [String] = []
    private(set) var preparedQueries: [(sql: String, binds: [String?])] = []
    private let databaseName: String?
    private let simpleQueryResults: [String: [MySQLRow]]
    private let preparedQueryResults: [String: MySQLWireQueryResult]

    init(
        databaseName: String? = "echo",
        simpleQueryResults: [String: [MySQLRow]] = [:],
        preparedQueryResults: [String: MySQLWireQueryResult] = [:]
    ) {
        self.databaseName = databaseName
        self.simpleQueryResults = simpleQueryResults
        self.preparedQueryResults = preparedQueryResults
    }

    func simpleQuery(_ sql: String) async throws -> [MySQLRow] {
        simpleQueries.append(sql)
        return simpleQueryResults[sql, default: []]
    }

    func query(_ sql: String, binds: [MySQLData]) async throws -> MySQLWireQueryResult {
        preparedQueries.append((sql, binds.map(\.string)))
        return preparedQueryResults[sql, default: MySQLWireQueryResult(rows: [], metadata: nil)]
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

    @Test
    func metadataQueriesReturnTypedResults() async throws {
        let tablesSQL = """
        SELECT
            table_name,
            table_type
        FROM information_schema.tables
        WHERE table_schema = ?
        ORDER BY table_name;
        """
        let columnsSQL = """
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

        let metadata = MockConnectionSession(
            databaseName: "sakila",
            simpleQueryResults: [
                "SHOW CREATE TABLE `sakila`.`actor`": [
                    Self.textRow([
                        ("Table", "actor"),
                        ("Create Table", "CREATE TABLE `actor` (`actor_id` int NOT NULL)")
                    ])
                ]
            ],
            preparedQueryResults: [
                tablesSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([("table_name", "actor"), ("table_type", "BASE TABLE")]),
                        Self.textRow([("table_name", "actor_info"), ("table_type", "VIEW")])
                    ],
                    metadata: nil
                ),
                columnsSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("column_name", "actor_id"),
                            ("data_type", "int"),
                            ("is_nullable", "NO"),
                            ("column_key", "PRI"),
                            ("character_maximum_length", nil)
                        ]),
                        Self.textRow([
                            ("column_name", "first_name"),
                            ("data_type", "varchar"),
                            ("is_nullable", "NO"),
                            ("column_key", ""),
                            ("character_maximum_length", "45")
                        ])
                    ],
                    metadata: nil
                )
            ]
        )
        let counter = ConnectionFactoryCounter()

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
                logger: Logger(label: "tests.mysql-kit.metadata"),
                connectionFactory: { _, _ in
                    _ = await counter.next()
                    return metadata
                }
            )
        )

        let objects = try await client.metadata.listTablesAndViews(in: "sakila")
        let columns = try await client.metadata.listColumns(in: "actor", schema: "sakila")
        let definition = try await client.metadata.objectDefinition(named: "actor", schema: "sakila", kind: .table)

        #expect(objects.map(\.name) == ["actor", "actor_info"])
        #expect(objects.map(\.kind) == [.table, .view])
        #expect(columns.map(\.name) == ["actor_id", "first_name"])
        #expect(columns.first?.isPrimaryKey == true)
        #expect(columns.last?.maxLength == 45)
        #expect(definition.contains("CREATE TABLE `actor`"))
        #expect(await counter.current() == 1)
        #expect(await metadata.preparedQueries.count == 2)
    }

    private static func textRow(_ values: [(String, String?)]) -> MySQLRow {
        let columnDefinitions = values.map { name, _ in columnDefinition(named: name) }

        let rowValues = values.map { _, value -> ByteBuffer? in
            guard let value else { return nil }
            var buffer = ByteBufferAllocator().buffer(capacity: value.utf8.count)
            buffer.writeString(value)
            return buffer
        }

        return MySQLRow(format: .text, columnDefinitions: columnDefinitions, values: rowValues)
    }

    private static func columnDefinition(named name: String) -> MySQLProtocol.ColumnDefinition41 {
        var payload = ByteBufferAllocator().buffer(capacity: 64)
        writeLengthEncodedString("def", into: &payload)
        writeLengthEncodedString("test", into: &payload)
        writeLengthEncodedString("test", into: &payload)
        writeLengthEncodedString("test", into: &payload)
        writeLengthEncodedString(name, into: &payload)
        writeLengthEncodedString(name, into: &payload)
        payload.writeInteger(UInt8(0x0c))
        payload.writeInteger(MySQLProtocol.CharacterSet.utf8mb4.rawValue)
        payload.writeInteger(UInt8(0))
        payload.writeInteger(UInt32(255), endianness: .little)
        payload.writeInteger(MySQLProtocol.DataType.varString.rawValue)
        payload.writeInteger(UInt16(0), endianness: .little)
        payload.writeInteger(UInt8(0))
        payload.writeInteger(UInt16(0))

        var packet = MySQLPacket(payload: payload)
        return try! packet.decode(MySQLProtocol.ColumnDefinition41.self, capabilities: [])
    }

    private static func writeLengthEncodedString(_ value: String, into buffer: inout ByteBuffer) {
        let utf8Count = value.utf8.count
        precondition(utf8Count < 251)
        buffer.writeInteger(UInt8(utf8Count))
        buffer.writeString(value)
    }
}
