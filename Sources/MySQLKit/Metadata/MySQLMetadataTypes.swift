public enum MySQLSchemaObjectKind: String, Sendable, Hashable {
    case table
    case view
    case function
    case procedure
    case trigger
    case event

    init?(tableType: String) {
        switch tableType.uppercased() {
        case "BASE TABLE":
            self = .table
        case "VIEW":
            self = .view
        default:
            return nil
        }
    }
}

public struct MySQLSchemaObject: Sendable, Hashable {
    public let name: String
    public let schema: String
    public let kind: MySQLSchemaObjectKind

    public init(name: String, schema: String, kind: MySQLSchemaObjectKind) {
        self.name = name
        self.schema = schema
        self.kind = kind
    }
}

public struct MySQLColumnInfo: Sendable, Hashable {
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let maxLength: Int?

    public init(
        name: String,
        dataType: String,
        isNullable: Bool,
        isPrimaryKey: Bool,
        maxLength: Int?
    ) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.maxLength = maxLength
    }
}
