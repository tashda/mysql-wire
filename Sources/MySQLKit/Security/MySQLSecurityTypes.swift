public struct MySQLUserAccount: Sendable, Hashable, Identifiable {
    public let username: String
    public let host: String
    public let authenticationPlugin: String?
    public let accountLocked: Bool
    public let passwordExpired: Bool

    public init(
        username: String,
        host: String,
        authenticationPlugin: String?,
        accountLocked: Bool,
        passwordExpired: Bool
    ) {
        self.username = username
        self.host = host
        self.authenticationPlugin = authenticationPlugin
        self.accountLocked = accountLocked
        self.passwordExpired = passwordExpired
    }

    /// Stable identifier in MySQL's `'user'@'host'` format.
    public var id: String { "'\(username)'@'\(host)'" }

    /// Display name in MySQL's `'user'@'host'` format. Matches the `grantee` column in information_schema.
    public var accountName: String { "'\(username)'@'\(host)'" }
}

public struct MySQLAccountLimits: Sendable, Hashable {
    public let maxQueriesPerHour: Int
    public let maxUpdatesPerHour: Int
    public let maxConnectionsPerHour: Int
    public let maxUserConnections: Int

    public init(
        maxQueriesPerHour: Int,
        maxUpdatesPerHour: Int,
        maxConnectionsPerHour: Int,
        maxUserConnections: Int
    ) {
        self.maxQueriesPerHour = maxQueriesPerHour
        self.maxUpdatesPerHour = maxUpdatesPerHour
        self.maxConnectionsPerHour = maxConnectionsPerHour
        self.maxUserConnections = maxUserConnections
    }
}

public enum MySQLAdministrativeRole: String, Sendable, Hashable, CaseIterable {
    case dba = "DBA"
    case maintenanceAdmin = "MaintenanceAdmin"
    case processAdmin = "ProcessAdmin"
    case userAdmin = "UserAdmin"
    case securityAdmin = "SecurityAdmin"
    case monitorAdmin = "MonitorAdmin"
    case dbManager = "DBManager"
    case dbDesigner = "DBDesigner"
    case replicationAdmin = "ReplicationAdmin"
    case backupAdmin = "BackupAdmin"
}

public struct MySQLRoleAssignment: Sendable, Hashable {
    public let roleName: String
    public let roleHost: String
    public let grantee: String

    public init(roleName: String, roleHost: String, grantee: String) {
        self.roleName = roleName
        self.roleHost = roleHost
        self.grantee = grantee
    }
}

public struct MySQLPrivilegeGrant: Sendable, Hashable {
    public let grantee: String
    public let tableSchema: String?
    public let tableName: String?
    public let privilegeType: String
    public let isGrantable: Bool

    public init(
        grantee: String,
        tableSchema: String?,
        tableName: String?,
        privilegeType: String,
        isGrantable: Bool
    ) {
        self.grantee = grantee
        self.tableSchema = tableSchema
        self.tableName = tableName
        self.privilegeType = privilegeType
        self.isGrantable = isGrantable
    }

    /// Parses the `grantee` string (MySQL `'user'@'host'` format) into username and host components.
    public var parsedGrantee: (username: String, host: String)? {
        guard grantee.hasPrefix("'") && grantee.hasSuffix("'") else { return nil }
        guard let separatorRange = grantee.range(of: "'@'") else { return nil }
        let username = String(grantee[grantee.index(after: grantee.startIndex)..<separatorRange.lowerBound])
        let host = String(grantee[separatorRange.upperBound..<grantee.index(before: grantee.endIndex)])
        return (username: username, host: host)
    }
}

public struct MySQLRoleDefinition: Sendable, Hashable, Identifiable {
    public let name: String
    public let host: String

    public init(name: String, host: String) {
        self.name = name
        self.host = host
    }

    /// Stable identifier in `name@host` format (no quotes), matching the roleAssignment key format.
    public var id: String { "\(name)@\(host)" }

    /// Display name in MySQL's `'name'@'host'` format.
    public var accountName: String { "'\(name)'@'\(host)'" }
}

public struct MySQLUserMutationResult: Sendable, Hashable {
    public let username: String
    public let host: String
    public let operation: String

    public init(username: String, host: String, operation: String) {
        self.username = username
        self.host = host
        self.operation = operation
    }
}
