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
    public let fullDataType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let maxLength: Int?
    public let defaultValue: String?
    public let generationExpression: String?
    public let isAutoIncrement: Bool
    public let collation: String?
    public let characterSet: String?
    public let ordinalPosition: Int

    public init(
        name: String,
        dataType: String,
        fullDataType: String,
        isNullable: Bool,
        isPrimaryKey: Bool,
        maxLength: Int?,
        defaultValue: String?,
        generationExpression: String?,
        isAutoIncrement: Bool,
        collation: String?,
        characterSet: String?,
        ordinalPosition: Int
    ) {
        self.name = name
        self.dataType = dataType
        self.fullDataType = fullDataType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.maxLength = maxLength
        self.defaultValue = defaultValue
        self.generationExpression = generationExpression
        self.isAutoIncrement = isAutoIncrement
        self.collation = collation
        self.characterSet = characterSet
        self.ordinalPosition = ordinalPosition
    }
}

public struct MySQLPrimaryKeyInfo: Sendable, Hashable {
    public let name: String
    public let columns: [String]

    public init(name: String, columns: [String]) {
        self.name = name
        self.columns = columns
    }
}

public struct MySQLIndexColumnInfo: Sendable, Hashable {
    public enum SortOrder: String, Sendable, Hashable {
        case ascending
        case descending
    }

    public let name: String
    public let position: Int
    public let sortOrder: SortOrder

    public init(name: String, position: Int, sortOrder: SortOrder) {
        self.name = name
        self.position = position
        self.sortOrder = sortOrder
    }
}

public struct MySQLIndexInfo: Sendable, Hashable {
    public let name: String
    public let columns: [MySQLIndexColumnInfo]
    public let isUnique: Bool
    public let indexType: String?

    public init(name: String, columns: [MySQLIndexColumnInfo], isUnique: Bool, indexType: String? = nil) {
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
        self.indexType = indexType
    }
}

public struct MySQLForeignKeyInfo: Sendable, Hashable {
    public let name: String
    public let columns: [String]
    public let referencedSchema: String
    public let referencedTable: String
    public let referencedColumns: [String]
    public let onUpdate: String?
    public let onDelete: String?

    public init(
        name: String,
        columns: [String],
        referencedSchema: String,
        referencedTable: String,
        referencedColumns: [String],
        onUpdate: String?,
        onDelete: String?
    ) {
        self.name = name
        self.columns = columns
        self.referencedSchema = referencedSchema
        self.referencedTable = referencedTable
        self.referencedColumns = referencedColumns
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
}

public struct MySQLDependencyInfo: Sendable, Hashable {
    public let name: String
    public let baseColumns: [String]
    public let referencedTable: String
    public let referencedColumns: [String]
    public let onUpdate: String?
    public let onDelete: String?

    public init(
        name: String,
        baseColumns: [String],
        referencedTable: String,
        referencedColumns: [String],
        onUpdate: String?,
        onDelete: String?
    ) {
        self.name = name
        self.baseColumns = baseColumns
        self.referencedTable = referencedTable
        self.referencedColumns = referencedColumns
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }
}

public struct MySQLTableStructure: Sendable, Hashable {
    public let columns: [MySQLColumnInfo]
    public let primaryKey: MySQLPrimaryKeyInfo?
    public let indexes: [MySQLIndexInfo]
    public let foreignKeys: [MySQLForeignKeyInfo]
    public let dependencies: [MySQLDependencyInfo]

    public init(
        columns: [MySQLColumnInfo],
        primaryKey: MySQLPrimaryKeyInfo?,
        indexes: [MySQLIndexInfo],
        foreignKeys: [MySQLForeignKeyInfo],
        dependencies: [MySQLDependencyInfo]
    ) {
        self.columns = columns
        self.primaryKey = primaryKey
        self.indexes = indexes
        self.foreignKeys = foreignKeys
        self.dependencies = dependencies
    }
}

public struct MySQLRoutineInfo: Sendable, Hashable {
    public let schema: String
    public let name: String
    public let type: String
    public let definition: String?

    public init(schema: String, name: String, type: String, definition: String?) {
        self.schema = schema
        self.name = name
        self.type = type
        self.definition = definition
    }
}

public struct MySQLTriggerInfo: Sendable, Hashable {
    public let schema: String
    public let name: String
    public let table: String
    public let timing: String
    public let event: String
    public let statement: String?

    public init(schema: String, name: String, table: String, timing: String, event: String, statement: String?) {
        self.schema = schema
        self.name = name
        self.table = table
        self.timing = timing
        self.event = event
        self.statement = statement
    }
}

public struct MySQLEventInfo: Sendable, Hashable {
    public let schema: String
    public let name: String
    public let status: String?
    public let schedule: String?
    public let definition: String?

    public init(schema: String, name: String, status: String?, schedule: String?, definition: String?) {
        self.schema = schema
        self.name = name
        self.status = status
        self.schedule = schedule
        self.definition = definition
    }
}

public struct MySQLMetadataSearchResult: Sendable, Hashable {
    public let schema: String
    public let name: String
    public let kind: String

    public init(schema: String, name: String, kind: String) {
        self.schema = schema
        self.name = name
        self.kind = kind
    }
}
