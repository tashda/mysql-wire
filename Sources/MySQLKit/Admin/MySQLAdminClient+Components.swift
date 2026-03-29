public extension MySQLAdminClient {
    /// Installs a MySQL component (e.g. `"file://component_validate_password"`).
    func installComponent(_ componentURN: String) async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("INSTALL COMPONENT '\(componentURN)'")
    }

    /// Uninstalls a MySQL component.
    func uninstallComponent(_ componentURN: String) async throws {
        let connection = try await serverConnection.primary()
        _ = try await connection.simpleQuery("UNINSTALL COMPONENT '\(componentURN)'")
    }
}
