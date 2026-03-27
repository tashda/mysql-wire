import Foundation
import MySQLWire

public struct MySQLPreparedStatementClient: Sendable {
    let serverConnection: MySQLServerConnection

    public func query(_ sql: String, binds: [MySQLData]) async throws -> MySQLWireQueryResult {
        let connection = try await serverConnection.primary()
        let statement = try await serverConnection.preparedStatement(for: sql, on: connection)

        for (index, bind) in binds.enumerated() {
            let variableName = "@mw_p\(index + 1)"
            let literal = try MySQLBindRenderer.renderLiteral(bind)
            _ = try await connection.simpleQuery("SET \(variableName) = \(literal)")
        }

        let usingClause = binds.isEmpty ? "" : " USING " + binds.indices.map { "@mw_p\($0 + 1)" }.joined(separator: ", ")
        let rows = try await connection.simpleQuery("EXECUTE \(statement.statementName)\(usingClause)")
        return MySQLWireQueryResult(rows: rows, metadata: nil)
    }
}
