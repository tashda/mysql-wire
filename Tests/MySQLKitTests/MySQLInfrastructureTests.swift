import Foundation
import MySQLKit
import MySQLKitTesting
import MySQLWire
import Testing

struct MySQLInfrastructureTests {
    @Test
    func preparedStatementCacheEvictsLeastRecentlyUsed() async {
        let cache = PreparedStatementCache(capacity: 2)

        await cache.touch("SELECT 1", now: Date(timeIntervalSince1970: 1))
        await cache.touch("SELECT 2", now: Date(timeIntervalSince1970: 2))
        await cache.touch("SELECT 1", now: Date(timeIntervalSince1970: 3))
        await cache.touch("SELECT 3", now: Date(timeIntervalSince1970: 4))

        let entries = await cache.cachedStatements()

        #expect(entries.map(\.sql) == ["SELECT 1", "SELECT 3"])
        #expect(await cache.contains("SELECT 2") == false)
    }

    @Test
    func connectionHealthPolicyClassifiesReconnectErrors() {
        struct SampleError: LocalizedError {
            let message: String
            var errorDescription: String? { message }
        }

        let policy = MySQLConnectionHealthPolicy()

        #expect(policy.action(for: SampleError(message: "MySQL server has gone away")) == .reconnectRequired)
        #expect(policy.action(for: SampleError(message: "broken pipe")) == .closeRequired)
        #expect(policy.action(for: SampleError(message: "syntax error")) == .noAction)
    }

    @Test
    func serverConnectionTracksPreparedStatements() async throws {
        let connection = MockConnectionSession()
        let serverConnection = MySQLServerConnection(
            configuration: MySQLConfiguration(host: "localhost", username: "root"),
            connectionFactory: { _, _ in
                connection
            }
        )

        await serverConnection.recordPreparedStatement("SELECT 1")
        await serverConnection.recordPreparedStatement("SELECT 2")

        let cached = await serverConnection.cachedPreparedStatements()
        await serverConnection.resetPreparedStatements()

        #expect(cached.map { $0.sql } == ["SELECT 1", "SELECT 2"])
        #expect(await serverConnection.cachedPreparedStatements().isEmpty)
    }

    @Test
    func testConfigurationBuildsFixtureConfiguration() {
        let testConfiguration = MySQLTestConfiguration(
            host: "db.internal",
            port: 3307,
            username: "echo",
            password: "secret",
            database: "sakila"
        )

        let fixture = MySQLFixture(configuration: testConfiguration.mysqlConfiguration)

        #expect(fixture.configuration.host == "db.internal")
        #expect(fixture.configuration.port == 3307)
        #expect(fixture.configuration.database == "sakila")
    }
}
