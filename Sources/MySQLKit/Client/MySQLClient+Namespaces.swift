public extension MySQLClient {
    var query: MySQLQueryClient {
        MySQLQueryClient(serverConnection: serverConnection)
    }

    var metadata: MySQLMetadataClient {
        MySQLMetadataClient(serverConnection: serverConnection)
    }
}
