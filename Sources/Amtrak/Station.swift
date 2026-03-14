import Foundation

///
public struct Station: Codable, Equatable, Sendable {
    /// Name of the station in plain english
    public let name: String
    /// Station code
    public let code: String
    /// Timezone of the station
    public let tz: String?
    /// Whether or not the station is a bus stop
    public let bus: Bool?
    /// Scheduled arrival time
    public let schArr: Date
    /// Scheduled departure time
    public let schDep: Date
    /// Actual arrival time
    public let arr: Date?
    /// Actual departure time
    public let dep: Date?
    /// Platform name/number, if available
    public let platform: String?
    /// One of "Enroute", "Station", "Departed", or "Unknown"
    public let status: StationStatus?
}

public enum StationStatus: String, Codable, Sendable, Equatable {
    ///
    case enroute = "Enroute"
    ///
    case station = "Station"
    ///
    case Departed = "Departed"
    ///
    case Unknown = "Unknown"
}

///
public struct StationMetadata: Codable, Equatable, Sendable {
    ///
    public let name: String?
    ///
    public let code: String
    ///
    public let tz: String?
    ///
    public let lat: Double?
    ///
    public let lon: Double?
    ///
    public let address1: String?
    ///
    public let address2: String?
    ///
    public let city: String?
    ///
    public let zip: String?
    ///
    public let trains: [String]
}

///
public typealias StationMetadataResponse = [String: StationMetadata]
