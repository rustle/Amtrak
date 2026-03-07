public struct StaleData: Codable {
    /// Average time in milliseconds since train data was last updated in Amtrak's database
    public let avgLastUpdate: Double
    /// Number of trains that are currently active
    public let activeTrains: Int
    /// Whether or not the data is stale
    public let stale: Bool
}
