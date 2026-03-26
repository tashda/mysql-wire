import Logging
import MySQLWire

public actor MySQLServerConnection: Sendable {
    private let configuration: MySQLConfiguration
    private let logger: Logger
    private let connectionFactory: @Sendable (MySQLConfiguration, Logger) async throws -> any MySQLConnectionSession

    private var primaryConnection: (any MySQLConnectionSession)?
    private var metadataConnection: (any MySQLConnectionSession)?

    public init(
        configuration: MySQLConfiguration,
        logger: Logger = Logger(label: "mysql-kit.server-connection"),
        connectionFactory: @escaping @Sendable (MySQLConfiguration, Logger) async throws -> any MySQLConnectionSession = { configuration, logger in
            try await MySQLWireConnection.connect(configuration: configuration, logger: logger)
        }
    ) {
        self.configuration = configuration
        self.logger = logger
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

    public func ping() async throws {
        if let primaryConnection {
            try await primaryConnection.validate()
        }
        if let metadataConnection {
            try await metadataConnection.validate()
        }
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
    }
}
