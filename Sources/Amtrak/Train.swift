import Foundation

///
public struct Train: Codable {
    /// Name of the train route
    public let routeName: String?
    /// Train number
    public let trainNum: String
    /// Train number, minus any prefix (ie v for via rail and b for brightline)
    public let trainNumRaw: String
    /// Train ID
    public let trainID: String
    /// Latitude of the train
    public let lat: Double?
    /// Longitude of the train
    public let lon: Double?
    /// Calculated icon color for the frontend
    public let iconColor: String?
    /// List of stations the train has and will pass through/
    public let stations: [Station]
    /// Direction the train is heading in the 8 cardinal directions/
    public let heading: Heading?
    /// Upcoming/current station
    public let eventCode: String?
    /// Timezone of the upcoming/current station
    public let eventTZ: String?
    /// Name of the upcoming/current station
    public let eventName: String?
    /// Origin station code
    public let origCode: String?
    /// Timezone of the origin station
    public let originTZ: String?
    /// Name of the origin station
    public let origName: String?
    /// Destination station code
    public let destCode: String?
    /// Timezone of the destination station
    public let destTZ: String?
    /// Name of the destination station
    public let destName: String?
    /// Either "Predeparture", "Active", or "Complete"
    public let trainState: TrainState?
    /// Speed of the train in MPH
    public let velocity: Double?
    /// Status message associated with the train, if any
    public let statusMsg: String?
    /// Timestamp of when the train data was stored in Amtrak's DB
    public let createdAt: Date
    /// Timestamp of when the train data was last updated
    public let updatedAt: Date
    /// Timestamp of when the train data was last received
    public let lastValTS: Date
    /// ID of the train data in Amtrak's DB
    public let objectID: Int?
    /// The provider of this train, either "Amtrak", "Via", or "Brightline"
    public let provider: String?
    /// A shortened version of `provider`, 4 or less characters, either "AMTK", "VIA", or "BLNE"
    public let providerShort: String?
    /// If this is the only train with its number (IE if there is only a single 3 active)
    public let onlyOfTrainNum: Bool?
    /// Array of alerts
    public let alerts: [TrainAlert]
}

public enum Heading: String, Codable, Sendable, Equatable {
    case N
    case NE
    case NW
    case S
    case SE
    case SW
    case E
    case W
}

public enum TrainState: String, Codable, Sendable {
    case active = "Active"
    case predeparture = "Predeparture"
    case completed = "Completed"
}

public struct TrainAlert: Codable, Sendable, Equatable {
    public let message: String
}

///
public typealias TrainResponse = [String: [Train]]

