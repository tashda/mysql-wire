import Logging
import MySQLWire
import NIOCore
import Testing
@testable import MySQLKit

actor MockConnectionSession: MySQLConnectionSession {
    private(set) var simpleQueries: [String] = []
    private(set) var changedDatabases: [String] = []
    private(set) var preparedQueries: [(sql: String, binds: [String?])] = []
    private(set) var validateCalls = 0
    private(set) var closeCalls = 0
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

    func validate() async throws {
        validateCalls += 1
    }

    func close() async {
        closeCalls += 1
    }
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

    @Test
    func tableStructureAggregatesMetadataQueries() async throws {
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
        let primaryKeySQL = """
        SELECT k.constraint_name, k.column_name
        FROM information_schema.table_constraints t
        JOIN information_schema.key_column_usage k
          ON k.constraint_name = t.constraint_name
         AND k.table_schema = t.table_schema
        WHERE t.table_schema = ?
          AND t.table_name = ?
          AND t.constraint_type = 'PRIMARY KEY'
        ORDER BY k.ordinal_position;
        """
        let indexesSQL = """
        SELECT
            index_name,
            non_unique,
            seq_in_index,
            column_name,
            collation
        FROM information_schema.statistics
        WHERE table_schema = ? AND table_name = ?
        ORDER BY index_name, seq_in_index;
        """
        let foreignKeysSQL = """
        SELECT
            rc.constraint_name,
            kcu.column_name,
            kcu.referenced_table_schema,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.referential_constraints rc
        JOIN information_schema.key_column_usage kcu
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE rc.constraint_schema = ?
          AND rc.table_name = ?
        ORDER BY rc.constraint_name, kcu.ordinal_position;
        """
        let dependenciesSQL = """
        SELECT
            kcu.constraint_name,
            kcu.column_name,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule
        FROM information_schema.key_column_usage kcu
        JOIN information_schema.referential_constraints rc
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE kcu.referenced_table_schema = ?
          AND kcu.referenced_table_name = ?
        ORDER BY kcu.constraint_name, kcu.ordinal_position;
        """

        let metadata = MockConnectionSession(
            databaseName: "sakila",
            preparedQueryResults: [
                columnsSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("column_name", "actor_id"),
                            ("data_type", "int"),
                            ("is_nullable", "NO"),
                            ("column_key", "PRI"),
                            ("character_maximum_length", nil)
                        ])
                    ],
                    metadata: nil
                ),
                primaryKeySQL: MySQLWireQueryResult(
                    rows: [Self.textRow([("constraint_name", "PRIMARY"), ("column_name", "actor_id")])],
                    metadata: nil
                ),
                indexesSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("index_name", "idx_last_name"),
                            ("non_unique", "1"),
                            ("seq_in_index", "1"),
                            ("column_name", "last_name"),
                            ("collation", "A")
                        ])
                    ],
                    metadata: nil
                ),
                foreignKeysSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("constraint_name", "fk_actor_film"),
                            ("column_name", "actor_id"),
                            ("referenced_table_schema", "sakila"),
                            ("referenced_table_name", "film_actor"),
                            ("referenced_column_name", "actor_id"),
                            ("update_rule", "CASCADE"),
                            ("delete_rule", "CASCADE"),
                            ("ordinal_position", "1")
                        ])
                    ],
                    metadata: nil
                ),
                dependenciesSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("constraint_name", "fk_film_actor_actor"),
                            ("column_name", "actor_id"),
                            ("referenced_table_name", "film_actor"),
                            ("referenced_column_name", "actor_id"),
                            ("update_rule", "CASCADE"),
                            ("delete_rule", "CASCADE")
                        ])
                    ],
                    metadata: nil
                )
            ]
        )

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
                logger: Logger(label: "tests.mysql-kit.structure"),
                connectionFactory: { _, _ in metadata }
            )
        )

        let structure = try await client.metadata.tableStructure(for: "actor", schema: "sakila")

        #expect(structure.columns.map(\.name) == ["actor_id"])
        #expect(structure.primaryKey?.name == "PRIMARY")
        #expect(structure.indexes.map(\.name) == ["idx_last_name"])
        #expect(structure.foreignKeys.map(\.name) == ["fk_actor_film"])
        #expect(structure.dependencies.map(\.name) == ["fk_film_actor_actor"])
        #expect(await metadata.preparedQueries.count == 5)
    }

    @Test
    func adminUsesActivityAndDedicatedConnections() async throws {
        let primary = MockConnectionSession(
            simpleQueryResults: [
                "ANALYZE TABLE `sakila`.`actor`": [Self.textRow([("Msg_text", "OK")])]
            ]
        )
        let activity = MockConnectionSession(
            preparedQueryResults: [
                "SHOW GLOBAL STATUS": MySQLWireQueryResult(
                    rows: [Self.textRow([("Variable_name", "Threads_connected"), ("Value", "12")])],
                    metadata: nil
                ),
                "SHOW GLOBAL VARIABLES LIKE ?": MySQLWireQueryResult(
                    rows: [Self.textRow([("Variable_name", "max_connections"), ("Value", "151")])],
                    metadata: nil
                ),
                "SHOW FULL PROCESSLIST": MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("Id", "42"),
                            ("User", "echo"),
                            ("Host", "localhost:51234"),
                            ("db", "sakila"),
                            ("Command", "Query"),
                            ("Time", "3"),
                            ("State", "executing"),
                            ("Info", "SELECT 1")
                        ])
                    ],
                    metadata: nil
                )
            ]
        )
        let cancel = MockConnectionSession()
        let counter = ConnectionFactoryCounter()

        let serverConnection = MySQLServerConnection(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            logger: Logger(label: "tests.mysql-kit.admin"),
            connectionFactory: { _, _ in
                let index = await counter.next()
                switch index {
                case 1: return activity
                case 2: return cancel
                default: return primary
                }
            }
        )
        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            serverConnection: serverConnection
        )

        let status = try await client.admin.globalStatus()
        let variables = try await client.admin.globalVariables(named: "max_connections")
        let processes = try await client.admin.processList()
        try await client.admin.killQuery(threadID: 42)
        let maintenance = try await client.admin.analyzeTable(schema: "sakila", table: "actor")
        try await serverConnection.ping()
        await serverConnection.close()

        #expect(status.first?.name == "Threads_connected")
        #expect(variables.first?.value == "151")
        #expect(processes.first?.id == 42)
        #expect(maintenance.messages == ["OK"])
        #expect(await cancel.simpleQueries == ["KILL QUERY 42"])
        #expect(await cancel.closeCalls == 1)
        #expect(await primary.validateCalls == 1)
        #expect(await activity.validateCalls == 1)
        #expect(await primary.closeCalls == 1)
        #expect(await activity.closeCalls == 1)
    }

    @Test
    func securityReturnsUsersAndGrants() async throws {
        let listUsersSQL = """
        SELECT
            User,
            Host,
            plugin,
            account_locked,
            password_expired
        FROM mysql.user
        ORDER BY User, Host;
        """

        let metadata = MockConnectionSession(
            simpleQueryResults: [
                "SHOW GRANTS FOR 'echo'@'localhost'": [
                    Self.textRow([("Grants for echo@localhost", "GRANT ALL PRIVILEGES ON *.* TO `echo`@`localhost`")])
                ]
            ],
            preparedQueryResults: [
                listUsersSQL: MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("User", "echo"),
                            ("Host", "localhost"),
                            ("plugin", "caching_sha2_password"),
                            ("account_locked", "N"),
                            ("password_expired", "N")
                        ]),
                        Self.textRow([
                            ("User", "reporter"),
                            ("Host", "%"),
                            ("plugin", "mysql_native_password"),
                            ("account_locked", "Y"),
                            ("password_expired", "N")
                        ])
                    ],
                    metadata: nil
                )
            ]
        )

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root"),
                logger: Logger(label: "tests.mysql-kit.security"),
                connectionFactory: { _, _ in metadata }
            )
        )

        let users = try await client.security.listUsers()
        let grants = try await client.security.showGrants(for: "echo", host: "localhost")

        #expect(users.map(\.username) == ["echo", "reporter"])
        #expect(users.last?.accountLocked == true)
        #expect(grants == ["GRANT ALL PRIVILEGES ON *.* TO `echo`@`localhost`"])
        #expect(await metadata.preparedQueries.count == 1)
        #expect(await metadata.simpleQueries == ["SHOW GRANTS FOR 'echo'@'localhost'"])
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
