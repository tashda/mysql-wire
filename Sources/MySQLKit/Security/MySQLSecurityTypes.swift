public struct MySQLUserAccount: Sendable, Hashable {
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
}

public struct MySQLRoleDefinition: Sendable, Hashable {
    public let name: String
    public let host: String

    public init(name: String, host: String) {
        self.name = name
        self.host = host
    }
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
