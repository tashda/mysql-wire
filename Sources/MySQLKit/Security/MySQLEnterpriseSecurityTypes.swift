// MARK: - Data Masking

public struct MySQLMaskingRule: Sendable, Hashable {
    public let schema: String
    public let table: String
    public let column: String
    public let function: String

    public init(schema: String, table: String, column: String, function: String) {
        self.schema = schema
        self.table = table
        self.column = column
        self.function = function
    }
}

// MARK: - Encryption

public struct MySQLEncryptedTable: Sendable, Hashable {
    public let schema: String
    public let table: String
    public let createOptions: String?

    public init(schema: String, table: String, createOptions: String?) {
        self.schema = schema
        self.table = table
        self.createOptions = createOptions
    }
}

// MARK: - Audit Log

public struct MySQLAuditLogFilter: Sendable, Hashable {
    public let filterName: String
    public let definition: String?

    public init(filterName: String, definition: String?) {
        self.filterName = filterName
        self.definition = definition
    }
}

public struct MySQLGeneralLogEntry: Sendable, Hashable {
    public let eventTime: String?
    public let userHost: String?
    public let commandType: String?
    public let argument: String?

    public init(eventTime: String?, userHost: String?, commandType: String?, argument: String?) {
        self.eventTime = eventTime
        self.userHost = userHost
        self.commandType = commandType
        self.argument = argument
    }
}

// MARK: - Firewall

public struct MySQLFirewallRule: Sendable, Hashable {
    public let userhost: String
    public let rule: String
    public let mode: String

    public init(userhost: String, rule: String, mode: String) {
        self.userhost = userhost
        self.rule = rule
        self.mode = mode
    }
}
