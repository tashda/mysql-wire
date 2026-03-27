# mysql-wire

A Swift package providing a typed MySQL client for macOS and iOS applications. Built on top of [mysql-nio](https://github.com/vapor/mysql-nio), it offers a high-level, namespaced API for MySQL database operations.

## Modules

- **MySQLWire** — Low-level connection management and query execution, wrapping mysql-nio.
- **MySQLKit** — High-level typed client with namespaced APIs for metadata, admin, security, replication, performance, and session management.
- **MySQLKitTesting** — Test fixtures and configuration helpers.

## Requirements

- Swift 6.2+
- macOS 13+ / iOS 16+

## Usage

Add the package dependency:

```swift
.package(url: "https://github.com/tashda/mysql-wire.git", branch: "dev")
```

Then import the module you need:

```swift
import MySQLKit

let config = MySQLConfiguration(
    hostname: "localhost",
    port: 3306,
    username: "root",
    password: "password",
    database: "mydb"
)
let client = try await MySQLClient(configuration: config)

// Typed metadata API
let tables = try await client.metadata.listTables(database: "mydb")

// Typed admin API
let status = try await client.admin.serverStatus()
```

## License

Private — all rights reserved.
