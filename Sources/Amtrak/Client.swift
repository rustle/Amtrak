import Foundation

@available(macOS 15.0.0, iOS 18.0.0, *)
public enum Endpoint: Sendable {
    /// https://api-v3.amtraker.com/v3/trains
    case trains
    /// https://api-v3.amtraker.com/v3/trains/:trainId
    case train(idOrNumber: String)
    /// https://api-v3.amtraker.com/v3/stations
    case stations
    /// https://api-v3.amtraker.com/v3/stations/:stationId
    case station(id: String)
    /// https://api-v3.amtraker.com/v3/stale
    case stale
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public struct Config: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> (data: Data, response: HTTPURLResponse)
    public static func defaultFetch() -> @Sendable (_ url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
        return { url in
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: [NSURLErrorFailingURLErrorKey: url])
            }
            guard httpResponse.statusCode == 200 else {
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: url])
            }
            return (data, httpResponse)
        }
    }
    public static let defaultConfig = Self.init(
        baseURL: URL(string: "https://api-v3.amtraker.com/v3/")!,
        fetch: Self.defaultFetch()
    )
    let baseURL: URL
    let fetch: Fetch
    public init(baseURL: URL, fetch: @escaping Fetch) {
        self.baseURL = baseURL
        self.fetch = fetch
    }
    func endpointURL(_ endpoint: Endpoint) -> URL {
        switch endpoint {
        case .trains:
            baseURL.appending(component: "trains")
        case .train(let id):
            baseURL.appending(component: "trains").appending(component: id)
        case .stations:
            baseURL.appending(component: "stations")
        case .station(let id):
            baseURL.appending(component: "stations").appending(component: id)
        case .stale:
            baseURL.appending(component: "stale")
        }
    }
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public enum ClientError: Error, Equatable {
    case noStationFound(id: String)
    case noTrainFound(id: String)
    case noTrainsFound(number: String)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public final class Client: Sendable {
    let config: Config
    public init(config: Config = Config.defaultConfig) {
        self.config = config
    }
    // The API returns two distinct date formats:
    // - Station times (schArr, schDep, arr, dep) use a timezone-offset format
    //   reflecting the local time at that station: "2026-03-02T10:30:00-06:00"
    // - Train-level system timestamps (createdAt, updatedAt, lastValTS) use
    //   fractional-seconds UTC: "2026-03-02T16:24:22.000Z"
    private struct Formatters: @unchecked Sendable {
        // Station times (schArr, schDep, arr, dep): "2026-03-02T10:30:00-06:00"
        let withOffset: ISO8601DateFormatter
        // Train system timestamps (createdAt, updatedAt, lastValTS): "2026-03-02T16:24:22.000Z"
        let withFractionalSeconds: ISO8601DateFormatter
        init() {
            let withOffset = ISO8601DateFormatter()
            withOffset.formatOptions = [.withInternetDateTime]
            self.withOffset = withOffset
            let withFractionalSeconds = ISO8601DateFormatter()
            withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.withFractionalSeconds = withFractionalSeconds
        }
    }
    private let formatters = Formatters()
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // A single formatter with [.withInternetDateTime, .withFractionalSeconds] cannot
        // cover both formats: .withFractionalSeconds requires fractional seconds to be
        // present, so it rejects strings like "2026-03-01T21:30:00-06:00". Two formatters
        // with a fallback are necessary to also handle "2026-03-02T16:24:22.000Z".
        decoder.dateDecodingStrategy = .custom { [unowned self] d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = self.formatters.withOffset.date(from: string) {
                return date
            }
            if let date = self.formatters.withFractionalSeconds.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }
    func fetch(from endpoint: Endpoint) async throws -> (data: Data, response: HTTPURLResponse) {
        return try await config.fetch(config.endpointURL(endpoint))
    }
    public func fetchAllStations() async throws -> StationMetadataResponse {
        let (data, _) = try await fetch(from: .stations)
        return try decoder().decode(StationMetadataResponse.self,
                                    from: data)
    }
    public func fetchStation(id: String) async throws -> StationMetadata {
        let (data, _) = try await fetch(from: .station(id: id))
        let stations = try decoder().decode(StationMetadataResponse.self, from: data)
        guard let station = stations[id] else {
            throw ClientError.noStationFound(id: id)
        }
        return station
    }
    public func fetchAllTrains() async throws -> TrainResponse {
        let (data, _) = try await fetch(from: .trains)
        return try decoder().decode(TrainResponse.self, from: data)
    }
    public func fetchTrain(id: String) async throws -> Train {
        let (data, _) = try await fetch(from: .train(idOrNumber: id))
        let trainResponse = try decoder().decode(TrainResponse.self, from: data)

        // From: https://github.com/piemadd/amtrak?tab=readme-ov-file#fetchtraintrainid-string
        // Fetches a train by its number or ID.
        // Returns TrainResponse with a single key (the train number) and the value is a list of Train objects.
        // If a valid Train ID is provided, the value will be a list of length 1.
        // If the train number/ID is not found, the promise will resolve with an empty array.
        // A train ID is comprised of the train number and the day of the month the train originated.
        // For example, a California Zephyr train (train #5) that originated on 02/09/2023 would have an ID of 5-9;

        // When requesting with a Train ID and getting a response keyed by Train Number,
        // we fall back to relying on getting an array with one Train entry or none
        // [ Train Number: [ Train ] ]

        guard trainResponse.values.count == 1, let trains = trainResponse.first?.value, trains.count == 1 else {
            throw ClientError.noTrainFound(id: id)
        }
        return trains[0]
    }
    public func fetchTrains(number: String) async throws -> [Train] {
        let (data, _) = try await fetch(from: .train(idOrNumber: number))
        let trainResponse = try decoder().decode(TrainResponse.self, from: data)

        // From: https://github.com/piemadd/amtrak?tab=readme-ov-file#fetchtraintrainid-string
        // Fetches a train by its number or ID.
        // Returns TrainResponse with a single key (the train number) and the value is a list of Train objects.
        // If a valid Train ID is provided, the value will be a list of length 1.
        // If the train number/ID is not found, the promise will resolve with an empty array.
        // A train ID is comprised of the train number and the day of the month the train originated.
        // For example, a California Zephyr train (train #5) that originated on 02/09/2023 would have an ID of 5-9;

        // When requesting with a Train Number and getting a response keyed by Train Number,
        // we can just pull out the array of [Train]
        // [ Train Number: [ Train ] ]

        guard let trains = trainResponse[number] else {
            throw ClientError.noTrainsFound(number: number)
        }
        return trains
    }
    public func fetchStale() async throws -> StaleData {
        let (data, _) = try await fetch(from: .stale)
        return try JSONDecoder().decode(StaleData.self, from: data)
    }
}
