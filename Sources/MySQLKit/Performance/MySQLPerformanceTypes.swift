public struct MySQLExplainPlan: Sendable, Hashable {
    public let rows: [[String: String?]]

    public init(rows: [[String: String?]]) {
        self.rows = rows
    }
}

public struct MySQLInnoDBStatus: Sendable, Hashable {
    public let statusText: String

    public init(statusText: String) {
        self.statusText = statusText
    }
}
