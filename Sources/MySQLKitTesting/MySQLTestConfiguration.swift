import Foundation
import MySQLKit

public struct MySQLTestConfiguration: Sendable, Hashable {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String?
    public let database: String

    public init(
        host: String = "127.0.0.1",
        port: Int = 3306,
        username: String = "root",
        password: String? = nil,
        database: String = "test"
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
    }

    public var mysqlConfiguration: MySQLConfiguration {
        MySQLConfiguration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database
        )
    }
}
