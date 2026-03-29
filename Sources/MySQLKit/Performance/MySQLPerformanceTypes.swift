public struct MySQLExplainPlan: Sendable, Hashable {
    public let rows: [[String: String?]]

    public init(rows: [[String: String?]]) {
        self.rows = rows
    }
}

public struct MySQLExplainJSONPlan: Sendable, Hashable {
    public let json: String

    public init(json: String) {
        self.json = json
    }
}

public struct MySQLExplainAnalyzePlan: Sendable, Hashable {
    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }
}

public struct MySQLInnoDBStatus: Sendable, Hashable {
    public let statusText: String

    public init(statusText: String) {
        self.statusText = statusText
    }
}
