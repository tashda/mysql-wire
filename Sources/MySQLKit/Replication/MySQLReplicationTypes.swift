public struct MySQLReplicationStatus: Sendable, Hashable {
    public let rawValues: [String: String?]

    public init(rawValues: [String: String?]) {
        self.rawValues = rawValues
    }
}
