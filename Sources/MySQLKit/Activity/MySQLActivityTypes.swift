public struct MySQLActivitySnapshot: Sendable, Hashable {
    public let processes: [MySQLProcess]

    public init(processes: [MySQLProcess]) {
        self.processes = processes
    }
}
