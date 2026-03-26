import Foundation

public enum MySQLWireError: LocalizedError, Sendable {
    case connectionAlreadyClosed
    case missingDatabaseName

    public var errorDescription: String? {
        switch self {
        case .connectionAlreadyClosed:
            return "The MySQL connection is already closed."
        case .missingDatabaseName:
            return "A database name is required for this operation."
        }
    }
}
