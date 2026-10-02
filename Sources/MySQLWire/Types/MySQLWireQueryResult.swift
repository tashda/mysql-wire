public struct MySQLWireQueryMetadata: Sendable {
    public let affectedRows: UInt64
    public let lastInsertID: UInt64?

    public init(affectedRows: UInt64, lastInsertID: UInt64?) {
        self.affectedRows = affectedRows
        self.lastInsertID = lastInsertID
    }
}

public struct MySQLWireQueryResult: Sendable {
    public let rows: [MySQLRow]
    public let metadata: MySQLWireQueryMetadata?

    public init(rows: [MySQLRow], metadata: MySQLWireQueryMetadata?) {
        self.rows = rows
        self.metadata = metadata
    }
}
