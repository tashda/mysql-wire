import Foundation
import MySQLWire

public extension MySQLActivityClient {
    func processList() async throws -> [MySQLProcess] {
        let connection = try await serverConnection.activity()
        let result = try await connection.query("SHOW FULL PROCESSLIST", binds: [])
        return result.rows.compactMap { row in
            guard
                let idString = row.column("Id")?.string,
                let id = UInt32(idString),
                let user = row.column("User")?.string,
                let command = row.column("Command")?.string
            else {
                return nil
            }

            let host = row.column("Host")?.string
            let database = row.column("db")?.string
            let timeSeconds = row.column("Time")?.string.flatMap(Int.init) ?? 0
            let state = row.column("State")?.string
            let info = row.column("Info")?.string

            return MySQLProcess(
                id: id,
                user: user,
                host: host,
                database: database,
                command: command,
                timeSeconds: timeSeconds,
                state: state,
                info: info
            )
        }
    }

    func killQuery(threadID: UInt32) async throws {
        try await serverConnection.cancelQuery(threadID: threadID)
    }

    func snapshot() async throws -> MySQLActivitySnapshot {
        let processes = try await processList()
        return MySQLActivitySnapshot(processes: processes)
    }

    func streamSnapshots(
        every interval: Duration = .seconds(2)
    ) -> AsyncThrowingStream<MySQLActivitySnapshot, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        let snapshot = try await snapshot()
                        continuation.yield(snapshot)
                        try await Task.sleep(for: interval)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
