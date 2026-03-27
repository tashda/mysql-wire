import MySQLWire

public extension MySQLAdminClient {
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
}
