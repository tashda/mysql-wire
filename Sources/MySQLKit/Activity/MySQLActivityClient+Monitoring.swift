import Foundation

public extension MySQLActivityClient {
    func snapshot() async throws -> MySQLActivitySnapshot {
        let processes = try await MySQLAdminClient(serverConnection: serverConnection).processList()
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
