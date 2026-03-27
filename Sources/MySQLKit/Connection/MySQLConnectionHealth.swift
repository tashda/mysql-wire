import Foundation

public enum MySQLConnectionFailureAction: Sendable, Hashable {
    case noAction
    case reconnectRequired
    case closeRequired
}

public struct MySQLConnectionHealthPolicy: Sendable, Hashable {
    public let keepAliveInterval: Duration?
    public let reconnectErrorMarkers: [String]
    public let closeErrorMarkers: [String]

    public init(
        keepAliveInterval: Duration? = .seconds(300),
        reconnectErrorMarkers: [String] = [
            "MySQL server has gone away",
            "Lost connection to MySQL server",
            "Lost connection during query",
            "Connection reset by peer"
        ],
        closeErrorMarkers: [String] = [
            "closed",
            "broken pipe"
        ]
    ) {
        self.keepAliveInterval = keepAliveInterval
        self.reconnectErrorMarkers = reconnectErrorMarkers
        self.closeErrorMarkers = closeErrorMarkers
    }

    public func action(for error: any Error) -> MySQLConnectionFailureAction {
        let description = String(describing: error).lowercased()

        if reconnectErrorMarkers.contains(where: { description.contains($0.lowercased()) }) {
            return .reconnectRequired
        }

        if closeErrorMarkers.contains(where: { description.contains($0.lowercased()) }) {
            return .closeRequired
        }

        return .noAction
    }
}
