public struct MySQLStatusVariable: Sendable, Hashable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct MySQLGlobalVariable: Sendable, Hashable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct MySQLProcess: Sendable, Hashable {
    public let id: UInt32
    public let user: String
    public let host: String?
    public let database: String?
    public let command: String
    public let timeSeconds: Int
    public let state: String?
    public let info: String?

    public init(
        id: UInt32,
        user: String,
        host: String?,
        database: String?,
        command: String,
        timeSeconds: Int,
        state: String?,
        info: String?
    ) {
        self.id = id
        self.user = user
        self.host = host
        self.database = database
        self.command = command
        self.timeSeconds = timeSeconds
        self.state = state
        self.info = info
    }
}

public struct MySQLMaintenanceResult: Sendable, Hashable {
    public let operation: String
    public let messages: [String]

    public init(operation: String, messages: [String]) {
        self.operation = operation
        self.messages = messages
    }
}

public struct MySQLLogDestination: Sendable, Hashable {
    public let kind: String
    public let value: String

    public init(kind: String, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct MySQLServerVariableMutation: Sendable, Hashable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public struct MySQLDumpOptions: Sendable, Hashable {
    public let includeRoutines: Bool
    public let includeTriggers: Bool
    public let includeEvents: Bool
    public let includeData: Bool
    public let includeSchema: Bool
    public let singleTransaction: Bool
    public let lockTables: Bool
    public let compressConnection: Bool
    public let useExtendedInsert: Bool
    public let whereClause: String?
    public let tables: [String]

    public init(
        includeRoutines: Bool = true,
        includeTriggers: Bool = true,
        includeEvents: Bool = true,
        includeData: Bool = true,
        includeSchema: Bool = true,
        singleTransaction: Bool = true,
        lockTables: Bool = false,
        compressConnection: Bool = false,
        useExtendedInsert: Bool = true,
        whereClause: String? = nil,
        tables: [String] = []
    ) {
        self.includeRoutines = includeRoutines
        self.includeTriggers = includeTriggers
        self.includeEvents = includeEvents
        self.includeData = includeData
        self.includeSchema = includeSchema
        self.singleTransaction = singleTransaction
        self.lockTables = lockTables
        self.compressConnection = compressConnection
        self.useExtendedInsert = useExtendedInsert
        self.whereClause = whereClause
        self.tables = tables
    }
}

public enum MySQLRoutineKind: String, Sendable, Hashable {
    case procedure = "PROCEDURE"
    case function = "FUNCTION"
}

public enum MySQLTriggerTiming: String, Sendable, Hashable {
    case before = "BEFORE"
    case after = "AFTER"
}

public enum MySQLTriggerEvent: String, Sendable, Hashable {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
}
