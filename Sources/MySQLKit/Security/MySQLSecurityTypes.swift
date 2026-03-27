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
