public struct MySQLSessionVariable: Sendable, Hashable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public enum MySQLTransactionIsolationLevel: String, Sendable, Hashable, CaseIterable {
    case readUncommitted = "READ UNCOMMITTED"
    case readCommitted = "READ COMMITTED"
    case repeatableRead = "REPEATABLE READ"
    case serializable = "SERIALIZABLE"
}

public struct MySQLNamedLockResult: Sendable, Hashable {
    public let name: String
    public let acquired: Bool

    public init(name: String, acquired: Bool) {
        self.name = name
        self.acquired = acquired
    }
}
