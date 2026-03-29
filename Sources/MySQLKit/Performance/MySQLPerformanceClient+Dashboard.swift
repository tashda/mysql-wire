public extension MySQLPerformanceClient {
    func dashboardStatus() async throws -> [MySQLStatusVariable] {
        try await MySQLAdminClient(serverConnection: serverConnection).globalStatus()
    }
}
