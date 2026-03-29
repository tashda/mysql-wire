import Foundation

public actor PreparedStatementCache: Sendable {
    public struct Entry: Sendable, Hashable {
        public let sql: String
        public let statementName: String
        public let lastAccessedAt: Date

        public init(sql: String, statementName: String, lastAccessedAt: Date) {
            self.sql = sql
            self.statementName = statementName
            self.lastAccessedAt = lastAccessedAt
        }
    }

    private let capacity: Int
    private var entries: [String: Entry] = [:]
    private var order: [String] = []

    public init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    public func entry(for sql: String) -> Entry? {
        entries[sql]
    }

    @discardableResult
    public func touch(_ sql: String, statementName: String, now: Date = Date()) -> Entry? {
        entries[sql] = Entry(sql: sql, statementName: statementName, lastAccessedAt: now)
        order.removeAll { $0 == sql }
        order.append(sql)

        var evictedEntry: Entry?
        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            evictedEntry = entries.removeValue(forKey: oldest)
        }

        return evictedEntry
    }

    public func contains(_ sql: String) -> Bool {
        entries[sql] != nil
    }

    public func cachedStatements() -> [Entry] {
        order.compactMap { entries[$0] }
    }

    public func removeAll() {
        entries.removeAll()
        order.removeAll()
    }
}
