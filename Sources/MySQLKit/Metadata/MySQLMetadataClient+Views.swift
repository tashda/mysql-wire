public extension MySQLMetadataClient {
    func listViews(in schema: String? = nil) async throws -> [MySQLSchemaObject] {
        try await listTablesAndViews(in: schema).filter { $0.kind == .view }
    }

    func listTables(in schema: String? = nil) async throws -> [MySQLSchemaObject] {
        try await listTablesAndViews(in: schema).filter { $0.kind == .table }
    }

    func listFunctions(in schema: String? = nil) async throws -> [MySQLRoutineInfo] {
        try await listRoutines(in: schema).filter { $0.type.uppercased() == "FUNCTION" }
    }

    func listProcedures(in schema: String? = nil) async throws -> [MySQLRoutineInfo] {
        try await listRoutines(in: schema).filter { $0.type.uppercased() == "PROCEDURE" }
    }
}
