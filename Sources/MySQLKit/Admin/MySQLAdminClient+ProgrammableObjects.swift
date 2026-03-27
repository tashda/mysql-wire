public extension MySQLAdminClient {
    func createView(
        schema: String,
        name: String,
        definitionSQL: String,
        replace: Bool = false
    ) async throws {
        let createVerb = replace ? "CREATE OR REPLACE" : "CREATE"
        try await executeDDL(
            "\(createVerb) VIEW `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` AS \(definitionSQL)"
        )
    }

    func alterView(
        schema: String,
        name: String,
        definitionSQL: String
    ) async throws {
        try await executeDDL(
            "ALTER VIEW `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` AS \(definitionSQL)"
        )
    }

    func dropView(schema: String, name: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP VIEW \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }

    func createRoutine(
        schema: String,
        name: String,
        kind: MySQLRoutineKind,
        parametersSQL: String = "",
        returnsSQL: String? = nil,
        characteristicsSQL: String? = nil,
        bodySQL: String
    ) async throws {
        var statement = "CREATE \(kind.rawValue) `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`(\(parametersSQL))"
        if kind == .function, let returnsSQL, !returnsSQL.isEmpty {
            statement += " RETURNS \(returnsSQL)"
        }
        if let characteristicsSQL, !characteristicsSQL.isEmpty {
            statement += " \(characteristicsSQL)"
        }
        statement += " \(bodySQL)"
        try await executeDDL(statement)
    }

    func dropRoutine(
        schema: String,
        name: String,
        kind: MySQLRoutineKind,
        ifExists: Bool = true
    ) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP \(kind.rawValue) \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }

    func createTrigger(
        schema: String,
        name: String,
        timing: MySQLTriggerTiming,
        event: MySQLTriggerEvent,
        table: String,
        bodySQL: String
    ) async throws {
        try await executeDDL(
            "CREATE TRIGGER `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` \(timing.rawValue) \(event.rawValue) ON `\(escapedIdentifier(schema))`.`\(escapedIdentifier(table))` FOR EACH ROW \(bodySQL)"
        )
    }

    func dropTrigger(schema: String, name: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP TRIGGER \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }

    func createEvent(
        schema: String,
        name: String,
        scheduleSQL: String,
        bodySQL: String,
        preserveOnCompletion: Bool = true,
        enabled: Bool = true
    ) async throws {
        let completionClause = preserveOnCompletion ? "ON COMPLETION PRESERVE" : "ON COMPLETION NOT PRESERVE"
        let stateClause = enabled ? "ENABLE" : "DISABLE"
        try await executeDDL(
            "CREATE EVENT `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` ON SCHEDULE \(scheduleSQL) \(completionClause) \(stateClause) DO \(bodySQL)"
        )
    }

    func alterEvent(
        schema: String,
        name: String,
        scheduleSQL: String? = nil,
        bodySQL: String? = nil,
        enabled: Bool? = nil
    ) async throws {
        var clauses: [String] = []
        if let scheduleSQL, !scheduleSQL.isEmpty {
            clauses.append("ON SCHEDULE \(scheduleSQL)")
        }
        if let enabled {
            clauses.append(enabled ? "ENABLE" : "DISABLE")
        }
        if let bodySQL, !bodySQL.isEmpty {
            clauses.append("DO \(bodySQL)")
        }

        try await executeDDL(
            "ALTER EVENT `\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))` \(clauses.joined(separator: " "))"
        )
    }

    func dropEvent(schema: String, name: String, ifExists: Bool = true) async throws {
        let existsClause = ifExists ? "IF EXISTS " : ""
        try await executeDDL(
            "DROP EVENT \(existsClause)`\(escapedIdentifier(schema))`.`\(escapedIdentifier(name))`"
        )
    }
}
