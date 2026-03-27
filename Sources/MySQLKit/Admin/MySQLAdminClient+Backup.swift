public extension MySQLAdminClient {
    func backupCommand(
        host: String,
        port: Int,
        username: String,
        database: String,
        outputPath: String
    ) -> [String] {
        backupCommand(
            host: host,
            port: port,
            username: username,
            database: database,
            outputPath: outputPath,
            options: MySQLDumpOptions()
        )
    }

    func backupCommand(
        host: String,
        port: Int,
        username: String,
        database: String,
        outputPath: String,
        options: MySQLDumpOptions
    ) -> [String] {
        var command = [
            "mysqldump",
            "--host=\(host)",
            "--port=\(port)",
            "--user=\(username)",
            "--result-file=\(outputPath)",
        ]

        if options.singleTransaction {
            command.append("--single-transaction")
        }
        if options.includeRoutines {
            command.append("--routines")
        }
        if options.includeTriggers {
            command.append("--triggers")
        }
        if options.includeEvents {
            command.append("--events")
        }
        if !options.includeData {
            command.append("--no-data")
        }
        if let whereClause = options.whereClause, !whereClause.isEmpty {
            command.append("--where=\(whereClause)")
        }

        command.append(database)
        if !options.tables.isEmpty {
            command.append(contentsOf: options.tables)
        }

        return command
    }

    func restoreCommand(
        host: String,
        port: Int,
        username: String,
        database: String,
        inputPath: String,
        defaultCharacterSet: String? = nil,
        force: Bool = false
    ) -> [String] {
        var command = [
            "mysql",
            "--host=\(host)",
            "--port=\(port)",
            "--user=\(username)",
        ]

        if let defaultCharacterSet, !defaultCharacterSet.isEmpty {
            command.append("--default-character-set=\(defaultCharacterSet)")
        }
        if force {
            command.append("--force")
        }

        command.append(contentsOf: [
            database,
            "<",
            inputPath
        ]
        )

        return command
    }
}
