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

    @Test
    func transactionClientUsesPrimaryConnection() async throws {
        let primary = MockConnectionSession()
        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root"),
                logger: Logger(label: "tests.mysql-kit.transaction"),
                connectionFactory: { _, _ in primary }
            )
        )

        try await client.query.transaction.begin()
        try await client.query.transaction.commit()
        do {
            _ = try await client.query.transaction.withTransaction {
                struct Expected: Error {}
                throw Expected()
            }
        } catch {}

        #expect(await primary.simpleQueries == [
            "START TRANSACTION",
            "COMMIT",
            "START TRANSACTION",
            "ROLLBACK"
        ])
    }

    @Test
    func activityAndPerformanceUseExpectedSurfaces() async throws {
        let primary = MockConnectionSession(
            simpleQueryResults: [
                "EXPLAIN SELECT * FROM actor": [
                    Self.textRow([
                        ("id", "1"),
                        ("select_type", "SIMPLE"),
                        ("table", "actor")
                    ])
                ]
            ]
        )
        let activity = MockConnectionSession(
            preparedQueryResults: [
                "SHOW FULL PROCESSLIST": MySQLWireQueryResult(
                    rows: [
                        Self.textRow([
                            ("Id", "7"),
                            ("User", "echo"),
                            ("Host", "localhost:1234"),
                            ("db", "sakila"),
                            ("Command", "Query"),
                            ("Time", "1"),
                            ("State", "running"),
                            ("Info", "SELECT * FROM actor")
                        ])
                    ],
                    metadata: nil
                ),
                "SHOW GLOBAL STATUS": MySQLWireQueryResult(
                    rows: [Self.textRow([("Variable_name", "Questions"), ("Value", "99")])],
                    metadata: nil
                )
            ]
        )
        let counter = ConnectionFactoryCounter()
        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root"),
                logger: Logger(label: "tests.mysql-kit.activity"),
                connectionFactory: { _, _ in
                    let index = await counter.next()
                    return index == 1 ? primary : activity
                }
            )
        )

        let explain = try await client.performance.explain("SELECT * FROM actor")
        let dashboard = try await client.performance.dashboardStatus()
        let snapshot = try await client.activity.snapshot()

        #expect(explain.rows.first?["table"]??.description == "actor")
        #expect(dashboard.first?.name == "Questions")
        #expect(snapshot.processes.first?.id == 7)
    }

    @Test
    func metadataSecurityAndReplicationCoverage() async throws {
        let routinesSQL = """
        SELECT
            routine_schema,
            routine_name,
            routine_type,
            routine_definition
        FROM information_schema.routines
        WHERE routine_schema = ?
        ORDER BY routine_name;
        """
        let triggersSQL = """
        SELECT
            trigger_schema,
            trigger_name,
            event_object_table,
            action_timing,
            event_manipulation,
            action_statement
        FROM information_schema.triggers
        WHERE trigger_schema = ?
        ORDER BY trigger_name;
        """
        let eventsSQL = """
        SELECT
            event_schema,
            event_name,
            status,
            interval_value,
            interval_field,
            event_definition
        FROM information_schema.events
        WHERE event_schema = ?
        ORDER BY event_name;
        """
        let searchSQL = """
        SELECT object_schema, object_name, object_type
        FROM (
            SELECT table_schema AS object_schema, table_name AS object_name, table_type AS object_type
            FROM information_schema.tables
            WHERE table_name LIKE ?
            UNION ALL
            SELECT routine_schema AS object_schema, routine_name AS object_name, routine_type AS object_type
            FROM information_schema.routines
            WHERE routine_name LIKE ?
            UNION ALL
            SELECT trigger_schema AS object_schema, trigger_name AS object_name, 'TRIGGER' AS object_type
            FROM information_schema.triggers
            WHERE trigger_name LIKE ?
        ) matches
        WHERE 1 = 1
        
        ORDER BY object_schema, object_name;
        """
        let rolesSQL = """
        SELECT
            FROM_USER,
            FROM_HOST,
            TO_USER,
            TO_HOST
        FROM mysql.role_edges
        ORDER BY TO_USER, FROM_USER;
        """
        let privilegesSQL = """
        SELECT
            grantee,
            table_schema,
            table_name,
            privilege_type,
            is_grantable
        FROM information_schema.table_privileges
        ORDER BY grantee, table_schema, table_name, privilege_type;
        """

        let metadata = MockConnectionSession(
            simpleQueryResults: [
                "SHOW REPLICA STATUS": [
                    Self.textRow([
                        ("Replica_IO_Running", "Yes"),
                        ("Replica_SQL_Running", "Yes")
                    ])
                ]
            ],
            preparedQueryResults: [
                routinesSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("routine_schema", "sakila"),
                        ("routine_name", "inventory_in_stock"),
                        ("routine_type", "FUNCTION"),
                        ("routine_definition", "RETURN 1")
                    ])],
                    metadata: nil
                ),
                triggersSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("trigger_schema", "sakila"),
                        ("trigger_name", "film_ins"),
                        ("event_object_table", "film"),
                        ("action_timing", "AFTER"),
                        ("event_manipulation", "INSERT"),
                        ("action_statement", "SET @x = 1")
                    ])],
                    metadata: nil
                ),
                eventsSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("event_schema", "sakila"),
                        ("event_name", "nightly_refresh"),
                        ("status", "ENABLED"),
                        ("interval_value", "1"),
                        ("interval_field", "DAY"),
                        ("event_definition", "CALL refresh()")
                    ])],
                    metadata: nil
                ),
                searchSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("object_schema", "sakila"),
                        ("object_name", "film"),
                        ("object_type", "BASE TABLE")
                    ])],
                    metadata: nil
                ),
                rolesSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("FROM_USER", "report_reader"),
                        ("FROM_HOST", "%"),
                        ("TO_USER", "echo"),
                        ("TO_HOST", "localhost")
                    ])],
                    metadata: nil
                ),
                privilegesSQL: MySQLWireQueryResult(
                    rows: [Self.textRow([
                        ("grantee", "'echo'@'localhost'"),
                        ("table_schema", "sakila"),
                        ("table_name", "film"),
                        ("privilege_type", "SELECT"),
                        ("is_grantable", "NO")
                    ])],
                    metadata: nil
                )
            ]
        )

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
                logger: Logger(label: "tests.mysql-kit.coverage"),
                connectionFactory: { _, _ in metadata }
            )
        )

        let routines = try await client.metadata.listRoutines(in: "sakila")
        let triggers = try await client.metadata.listTriggers(in: "sakila")
        let events = try await client.metadata.listEvents(in: "sakila")
        let searchResults = try await client.metadata.searchObjects(matching: "%film%")
        let roles = try await client.security.listRoleAssignments()
        let privileges = try await client.security.tablePrivileges()
        let replicaStatus = try await client.replication.replicaStatus()

        #expect(routines.first?.name == "inventory_in_stock")
        #expect(triggers.first?.name == "film_ins")
        #expect(events.first?.schedule == "1 DAY")
        #expect(searchResults.first?.name == "film")
        #expect(roles.first?.roleName == "report_reader")
        #expect(privileges.first?.privilegeType == "SELECT")
        #expect(replicaStatus?.rawValues["Replica_IO_Running"]??.description == "Yes")
    }

    @Test
    func adminMutationSecurityMutationAndPerformanceReports() async throws {
        let activity = MockConnectionSession(
            simpleQueryResults: [
                "SELECT * FROM mysql.general_log ORDER BY event_time DESC LIMIT 100": [
                    Self.textRow([("event_time", "2026-03-27 08:00:00"), ("argument", "SELECT 1")])
                ],
                """
                SELECT * FROM sys.statement_analysis
                ORDER BY avg_latency DESC
                LIMIT 10
                """: [
                    Self.textRow([("query", "SELECT * FROM actor"), ("avg_latency", "10 ms")])
                ],
                """
                SELECT * FROM sys.schema_unused_indexes
                LIMIT 50
                """: [
                    Self.textRow([("object_schema", "sakila"), ("index_name", "idx_old")])
                ]
            ],
            preparedQueryResults: [
                "SHOW GLOBAL VARIABLES": MySQLWireQueryResult(
                    rows: [
                        Self.textRow([("Variable_name", "general_log_file"), ("Value", "/var/log/mysql/general.log")]),
                        Self.textRow([("Variable_name", "log_output"), ("Value", "TABLE")])
                    ],
                    metadata: nil
                )
            ]
        )
        let primary = MockConnectionSession()
        let counter = ConnectionFactoryCounter()

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root", database: "sakila"),
                logger: Logger(label: "tests.mysql-kit.mutation"),
                connectionFactory: { _, _ in
                    let index = await counter.next()
                    return index == 1 ? primary : activity
                }
            )
        )

        try await client.admin.renameTable(schema: "sakila", from: "actor_old", to: "actor_new")
        try await client.admin.dropTable(schema: "sakila", name: "actor_tmp")
        let logDestinations = try await client.admin.logDestinations()
        let generalLog = try await client.admin.readTableLog(named: "general_log")
        let backupCommand = client.admin.backupCommand(
            host: "db.internal",
            port: 3307,
            username: "echo",
            database: "sakila",
            outputPath: "/tmp/sakila.sql"
        )

        try await client.security.createUser(username: "ci", host: "%", password: "secret")
        try await client.security.grant("SELECT", on: "`sakila`.*", to: "ci", host: "%")
        try await client.security.revoke("SELECT", on: "`sakila`.*", from: "ci", host: "%")
        try await client.security.createRole(name: "report_reader")
        try await client.security.dropRole(name: "report_reader")
        try await client.security.dropUser(username: "ci", host: "%")

        let statementAnalysis = try await client.performance.statementAnalysis()
        let unusedIndexes = try await client.performance.unusedIndexes()

        #expect(logDestinations.map(\.kind) == ["general_log_file", "log_output"])
        #expect(generalLog.first?["argument"]??.description == "SELECT 1")
        #expect(backupCommand.first == "mysqldump")
        #expect(statementAnalysis.name == "statement_analysis")
        #expect(unusedIndexes.name == "schema_unused_indexes")
        #expect(await primary.simpleQueries == [
            "RENAME TABLE `sakila`.`actor_old` TO `sakila`.`actor_new`",
            "DROP TABLE IF EXISTS `sakila`.`actor_tmp`",
            "CREATE USER 'ci'@'%' BY 'secret'",
            "GRANT SELECT ON `sakila`.* TO 'ci'@'%'",
            "REVOKE SELECT ON `sakila`.* FROM 'ci'@'%'",
            "CREATE ROLE 'report_reader'@'%'",
            "DROP ROLE 'report_reader'@'%'",
            "DROP USER IF EXISTS 'ci'@'%'"
        ])
    }

    @Test
    func preparedQueriesUsePrepareExecuteLifecycle() async throws {
        let sql = "SELECT * FROM actor WHERE actor_id = ? AND first_name = ?"
        let primary = MockConnectionSession(
            simpleQueryResults: [
                "PREPARE mw_stmt_fixed FROM 'SELECT * FROM actor WHERE actor_id = ? AND first_name = ?'": [],
                "SET @mw_p1 = 7": [],
                "SET @mw_p2 = 'PENELOPE'": [],
                "EXECUTE mw_stmt_fixed USING @mw_p1, @mw_p2": [
                    Self.textRow([
                        ("actor_id", "7"),
                        ("first_name", "PENELOPE")
                    ])
                ]
            ]
        )

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root"),
                connectionFactory: { _, _ in primary }
            )
        )

        let result = try await client.query.prepared.query(
            sql,
            binds: [MySQLData(int: 7), MySQLData(string: "PENELOPE")]
        )
        let recordedQueries = await primary.simpleQueries

        #expect(result.rows.first?.column("actor_id")?.string == "7")
        #expect(recordedQueries.count == 4)
        #expect(recordedQueries.first == "PREPARE mw_stmt_fixed FROM 'SELECT * FROM actor WHERE actor_id = ? AND first_name = ?'")
        #expect(recordedQueries.contains("SET @mw_p1 = '7'"))
        #expect(recordedQueries.contains("SET @mw_p2 = 'PENELOPE'"))
        #expect(recordedQueries.last == "EXECUTE mw_stmt_fixed USING @mw_p1, @mw_p2")
    }

    @Test
    func adminVariableMutationAndExtendedPerformanceReports() async throws {
        let activity = MockConnectionSession(
            simpleQueryResults: [
                """
                SELECT * FROM sys.statements_with_runtimes_in_95th_percentile
                LIMIT 10
                """: [
                    Self.textRow([("query", "SELECT * FROM actor"), ("avg_latency", "100 ms")])
                ],
                """
                SELECT * FROM sys.statements_with_full_table_scans
                LIMIT 10
                """: [
                    Self.textRow([("query", "SELECT * FROM film_text"), ("rows_examined", "1000")])
                ],
                "SHOW ENGINE INNODB STATUS": [
                    Self.textRow([("Status", "BUFFER POOL AND MEMORY")])
                ]
            ]
        )
        let primary = MockConnectionSession()
        let counter = ConnectionFactoryCounter()

        let client = MySQLClient(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            serverConnection: MySQLServerConnection(
                configuration: MySQLConfiguration(host: "localhost", username: "root"),
                connectionFactory: { _, _ in
                    let index = await counter.next()
                    return index == 1 ? primary : activity
                }
            )
        )

        let setResult = try await client.admin.setGlobalVariable("max_connections", to: "200")
        let resetResult = try await client.admin.resetGlobalVariable("max_connections")
        try await client.admin.flushTables()
        let restoreCommand = client.admin.restoreCommand(
            host: "db.internal",
            port: 3307,
            username: "echo",
            database: "sakila",
            inputPath: "/tmp/sakila.sql"
        )
        let topRuntime = try await client.performance.topRuntimeStatements()
        let fullTableScans = try await client.performance.fullTableScans()
        let innodbStatus = try await client.performance.innodbStatus()

        #expect(setResult.value == "200")
        #expect(resetResult.value == nil)
        #expect(restoreCommand.first == "mysql")
        #expect(topRuntime.name == "statements_with_runtimes_in_95th_percentile")
        #expect(fullTableScans.name == "statements_with_full_table_scans")
        #expect(innodbStatus.statusText == "BUFFER POOL AND MEMORY")
        #expect(await primary.simpleQueries == [
            "SET GLOBAL max_connections = 200",
            "SET GLOBAL max_connections = DEFAULT",
            "FLUSH TABLES"
        ])
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
