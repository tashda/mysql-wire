public extension MySQLAdminClient {
    func backupCommand(
        host: String,
        port: Int,
        username: String,
        database: String,
        outputPath: String
    ) -> [String] {
        [
            "mysqldump",
            "--host=\(host)",
            "--port=\(port)",
            "--user=\(username)",
            "--result-file=\(outputPath)",
            database
        ]
    }

    func restoreCommand(
        host: String,
        port: Int,
        username: String,
        database: String,
        inputPath: String
    ) -> [String] {
        [
            "mysql",
            "--host=\(host)",
            "--port=\(port)",
            "--user=\(username)",
            database,
            "<",
            inputPath
        ]
    }
}
