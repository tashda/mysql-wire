public struct MySQLExplainPlan: Sendable, Hashable {
    public let rows: [[String: String?]]

    public init(rows: [[String: String?]]) {
        self.rows = rows
    }
}
