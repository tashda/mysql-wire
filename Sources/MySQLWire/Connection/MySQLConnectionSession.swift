import Foundation

public protocol MySQLConnectionSession: Sendable {
    func simpleQuery(_ sql: String) async throws -> [MySQLRow]
    func query(_ sql: String, binds: [MySQLData]) async throws -> MySQLWireQueryResult
    func stream(_ sql: String) async throws -> AsyncThrowingStream<MySQLRow, Error>
    func changeDatabase(_ database: String) async throws
    func currentDatabase() async throws -> String?
    func validate() async throws
    func close() async
}
