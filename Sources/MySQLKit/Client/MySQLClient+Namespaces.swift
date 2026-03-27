public extension MySQLClient {
    var query: MySQLQueryClient {
        MySQLQueryClient(serverConnection: serverConnection)
    }

    var metadata: MySQLMetadataClient {
        MySQLMetadataClient(serverConnection: serverConnection)
    }

    var admin: MySQLAdminClient {
        MySQLAdminClient(serverConnection: serverConnection)
    }

    var security: MySQLSecurityClient {
        MySQLSecurityClient(serverConnection: serverConnection)
    }
}
