import Foundation

public struct MySQLWireConfiguration: Sendable, Hashable {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String?
    public let database: String?
    public let useTLS: Bool
    public let connectTimeoutSeconds: Int
    public let keepAliveInterval: Duration?

    public init(
        host: String,
        port: Int = 3306,
        username: String,
        password: String? = nil,
        database: String? = nil,
        useTLS: Bool = true,
        connectTimeoutSeconds: Int = 10,
        keepAliveInterval: Duration? = .seconds(300)
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.useTLS = useTLS
        self.connectTimeoutSeconds = connectTimeoutSeconds
        self.keepAliveInterval = keepAliveInterval
    }
}
