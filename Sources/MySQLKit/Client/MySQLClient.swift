import Logging

public struct MySQLClient: Sendable {
    public let configuration: MySQLConfiguration
    let serverConnection: MySQLServerConnection

    public init(
        configuration: MySQLConfiguration,
        logger: Logger = Logger(label: "mysql-kit.client")
    ) {
        self.configuration = configuration
        self.serverConnection = MySQLServerConnection(configuration: configuration, logger: logger)
    }

    init(configuration: MySQLConfiguration, serverConnection: MySQLServerConnection) {
        self.configuration = configuration
        self.serverConnection = serverConnection
    }

    public func close() async {
        await serverConnection.close()
    }
}
