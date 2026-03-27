import Logging
import MySQLWire

public actor MySQLServerConnection: Sendable {
    private let configuration: MySQLConfiguration
    private let logger: Logger
    private let healthPolicy: MySQLConnectionHealthPolicy
    private let connectionFactory: @Sendable (MySQLConfiguration, Logger) async throws -> any MySQLConnectionSession

    private var primaryConnection: (any MySQLConnectionSession)?
    private var metadataConnection: (any MySQLConnectionSession)?
    private var activityConnection: (any MySQLConnectionSession)?
    private let preparedStatementCache: PreparedStatementCache

    public init(
        configuration: MySQLConfiguration,
        logger: Logger = Logger(label: "mysql-kit.server-connection"),
        healthPolicy: MySQLConnectionHealthPolicy? = nil,
        preparedStatementCache: PreparedStatementCache = PreparedStatementCache(),
        connectionFactory: @escaping @Sendable (MySQLConfiguration, Logger) async throws -> any MySQLConnectionSession = { configuration, logger in
            try await MySQLWireConnection.connect(configuration: configuration, logger: logger)
        }
    ) {
        self.configuration = configuration
        self.logger = logger
        self.healthPolicy = healthPolicy ?? MySQLConnectionHealthPolicy(keepAliveInterval: configuration.keepAliveInterval)
        self.preparedStatementCache = preparedStatementCache
        self.connectionFactory = connectionFactory
    }

    public func primary() async throws -> any MySQLConnectionSession {
        if let primaryConnection {
            return primaryConnection
        }
        let connection = try await connectionFactory(configuration, logger)
        primaryConnection = connection
        return connection
    }

    public func metadata() async throws -> any MySQLConnectionSession {
        if let metadataConnection {
            return metadataConnection
        }
        let connection = try await connectionFactory(configuration, logger)
        metadataConnection = connection
        return connection
    }

    public func activity() async throws -> any MySQLConnectionSession {
        if let activityConnection {
            return activityConnection
        }
        let connection = try await connectionFactory(configuration, logger)
        activityConnection = connection
        return connection
    }

    public func newDedicatedConnection() async throws -> any MySQLConnectionSession {
        try await connectionFactory(configuration, logger)
    }

    public func cancelQuery(threadID: UInt32) async throws {
        let connection = try await newDedicatedConnection()
        do {
            _ = try await connection.simpleQuery("KILL QUERY \(threadID)")
            await connection.close()
        } catch {
            await connection.close()
            throw error
        }
    }

    public func ping() async throws {
        if let primaryConnection {
            try await validate(primaryConnection, role: .primary)
        }
        if let metadataConnection {
            try await validate(metadataConnection, role: .metadata)
        }
        if let activityConnection {
            try await validate(activityConnection, role: .activity)
        }
    }

    public func recordPreparedStatement(_ sql: String) async {
        let statementName = "mw_stmt_\(abs(sql.hashValue))"
        _ = await preparedStatementCache.touch(sql, statementName: statementName)
    }

    public func cachedPreparedStatements() async -> [PreparedStatementCache.Entry] {
        await preparedStatementCache.cachedStatements()
    }

    public func resetPreparedStatements() async {
        await preparedStatementCache.removeAll()
    }

    public func failureAction(for error: any Error) -> MySQLConnectionFailureAction {
        healthPolicy.action(for: error)
    }

    public func preparedStatement(
        for sql: String,
        on connection: any MySQLConnectionSession
    ) async throws -> PreparedStatementCache.Entry {
        if let existing = await preparedStatementCache.entry(for: sql) {
            _ = await preparedStatementCache.touch(sql, statementName: existing.statementName)
            return existing
        }

        let statementName = "mw_stmt_fixed"
        let escapedSQL = MySQLBindRenderer.escapeStringLiteral(sql)
        _ = try await connection.simpleQuery("PREPARE \(statementName) FROM '\(escapedSQL)'")
        if let evicted = await preparedStatementCache.touch(sql, statementName: statementName) {
            _ = try? await connection.simpleQuery("DEALLOCATE PREPARE \(evicted.statementName)")
        }
        return await preparedStatementCache.entry(for: sql)
            ?? PreparedStatementCache.Entry(sql: sql, statementName: statementName, lastAccessedAt: Date())
    }

    public func close() async {
        if let primaryConnection {
            await primaryConnection.close()
            self.primaryConnection = nil
        }
        if let metadataConnection {
            await metadataConnection.close()
            self.metadataConnection = nil
        }
        if let activityConnection {
            await activityConnection.close()
            self.activityConnection = nil
        }
        await preparedStatementCache.removeAll()
    }

    private enum ConnectionRole {
        case primary
        case metadata
        case activity
    }

    private func validate(_ connection: any MySQLConnectionSession, role: ConnectionRole) async throws {
        do {
            try await connection.validate()
        } catch {
            switch healthPolicy.action(for: error) {
            case .reconnectRequired, .closeRequired:
                await connection.close()
                switch role {
                case .primary: primaryConnection = nil
                case .metadata: metadataConnection = nil
                case .activity: activityConnection = nil
                }
            case .noAction:
                break
            }
            throw error
        }
    }
}
