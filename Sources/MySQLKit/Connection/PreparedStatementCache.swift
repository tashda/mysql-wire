import Foundation

public actor PreparedStatementCache: Sendable {
    public struct Entry: Sendable, Hashable {
        public let sql: String
        public let lastAccessedAt: Date

        public init(sql: String, lastAccessedAt: Date) {
            self.sql = sql
            self.lastAccessedAt = lastAccessedAt
        }
    }

    private let capacity: Int
    private var entries: [String: Date] = [:]
    private var order: [String] = []

    public init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    public func touch(_ sql: String, now: Date = Date()) {
        entries[sql] = now
        order.removeAll { $0 == sql }
        order.append(sql)

        while order.count > capacity, let oldest = order.first {
            order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    public func contains(_ sql: String) -> Bool {
        entries[sql] != nil
    }

    public func cachedStatements() -> [Entry] {
        order.compactMap { sql in
            guard let lastAccessedAt = entries[sql] else { return nil }
            return Entry(sql: sql, lastAccessedAt: lastAccessedAt)
        }
    }

    public func removeAll() {
        entries.removeAll()
        order.removeAll()
    }
}
