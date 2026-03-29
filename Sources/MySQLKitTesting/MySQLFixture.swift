import Foundation
import MySQLKit

public struct MySQLFixture: Sendable, Hashable {
    public let configuration: MySQLConfiguration

    public init(configuration: MySQLConfiguration) {
        self.configuration = configuration
    }
}
