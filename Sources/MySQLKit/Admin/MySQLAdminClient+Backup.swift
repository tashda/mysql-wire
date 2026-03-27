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
}
