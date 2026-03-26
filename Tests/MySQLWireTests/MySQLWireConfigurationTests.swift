import Testing
@testable import MySQLWire

struct MySQLWireConfigurationTests {
    @Test
    func defaultsMatchExpectedDesktopClientBehavior() {
        let configuration = MySQLWireConfiguration(host: "db.example.com", username: "echo")

        #expect(configuration.port == 3306)
        #expect(configuration.useTLS)
        #expect(configuration.connectTimeoutSeconds == 10)
        #expect(configuration.keepAliveInterval == .seconds(300))
    }
}
