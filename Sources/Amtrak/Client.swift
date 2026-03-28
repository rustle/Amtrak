import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif // canImport(FoundationNetworking)
#if canImport(FoundationEssentials)
import FoundationEssentials
#endif // canImport(FoundationEssentials)
#if canImport(FoundationInternationalization)
import FoundationInternationalization
#endif // canImport(FoundationInternationalization)

// AsyncHTTPClient is available on server (Linux/macOS/Windows) but not on iOS and friends
// canImport(AsyncHTTPClient) tells us the AsyncHTTPClient trait has been set for the
// the package and the type aliases, fetch implementations, and decoder logic follow
#if canImport(AsyncHTTPClient)
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import NIOHTTP1
#endif // canImport(AsyncHTTPClient)

@available(macOS 15.0.0, iOS 18.0.0, *)
public enum AmtrakClientEndpoint: Sendable {
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

// AmtrakClientHTTPRequest and AmtrakClientHTTPResponse resolve to
// appropriate platform types without per-call #if guards.
//
// AsyncHTTPClient (Linux/macOS/Windows):
//   AmtrakClientHTTPRequest  = HTTPClientRequest
//   AmtrakClientHTTPResponse = HTTPClientResponse (body is an AsyncSequence<ByteBuffer>)
//
// URLSession (Linux/macOS/iOS/Windows):
//   Default package configuration
//   Only (built in) option on iOS
//   Available on other platforms
//   AmtrakClientHTTPRequest  = URLRequest
//   AmtrakClientHTTPResponse = Data + HTTPURLResponse struct
#if canImport(AsyncHTTPClient)
@available(macOS 15.0.0, iOS 18.0.0, *)
public typealias AmtrakClientHTTPRequest = HTTPClientRequest
@available(macOS 15.0.0, iOS 18.0.0, *)
public typealias AmtrakClientHTTPResponse = HTTPClientResponse
#else
@available(macOS 15.0.0, iOS 18.0.0, *)
public typealias AmtrakClientHTTPRequest = URLRequest
@available(macOS 15.0.0, iOS 18.0.0, *)
public struct AmtrakClientHTTPResponse {
    public let data: Data
    public let response: HTTPURLResponse
    public init(data: Data,
                response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}
#endif

// AmtrakClientFetch is passed as a closure rather than hardcoded as a URLSession/HTTPClient call.
// This keeps the HTTP layer swappable — useful for things like testing, supplying a pre-configured
// HTTPClient instance (e.g. one managed by swift-server's HTTPClient.withHTTPClient lifecycle).
// proving a URLSession other than shared or doing application lifecycle bookkeeping like requesting
// more background execution time
@available(macOS 15.0.0, iOS 18.0.0, *)
public typealias AmtrakClientFetch = @Sendable (AmtrakClientHTTPRequest) async throws -> AmtrakClientHTTPResponse

// AmtrakClientDecoder is a protocol rather than a concrete type so that the decoding strategy
// can be swapped independently of the HTTP layer. On platforms where AsyncHTTPClient is
// available, the response body is an AsyncSequence<ByteBuffer>, which opens the door to a
// streaming decoder that processes chunks incrementally rather than buffering the full response.
@available(macOS 15.0.0, iOS 18.0.0, *)
public protocol AmtrakClientDecoder: Sendable {
    func decode<DecodedType>(
        _ type: DecodedType.Type,
        _ response: AmtrakClientHTTPResponse
    ) async throws -> DecodedType where DecodedType: Decodable, DecodedType: Sendable
}

// AmtrakClientJSONDecoder is the default AmtrakClientDecoder. It buffers the full response
// body before decoding with Foundation's JSONDecoder.
@available(macOS 15.0.0, iOS 18.0.0, *)
public struct AmtrakClientJSONDecoder: AmtrakClientDecoder {
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
    // This is private now but it is a good candidate to make public if future
    // versions of JSONDecoder add direct support for AsyncStream<ByteBuffer>
    // Making Formatters public is not completely out of the question but hasn't
    // been given much thought.
    private static func defaultJSONDecoder() -> JSONDecoder {
        let formatters = Formatters()
        let decoder = JSONDecoder()
        // A single formatter with [.withInternetDateTime, .withFractionalSeconds] cannot
        // cover both formats: .withFractionalSeconds requires fractional seconds to be
        // present, so it rejects strings like "2026-03-01T21:30:00-06:00". Two formatters
        // with a fallback are necessary to also handle "2026-03-02T16:24:22.000Z".
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatters.withOffset.date(from: string) {
                return date
            }
            if let date = formatters.withFractionalSeconds.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return decoder
    }
    private let decoder: JSONDecoder
    public init() {
        decoder = Self.defaultJSONDecoder()
    }
    public func decode<DecodedType>(
        _ type: DecodedType.Type,
        _ response: AmtrakClientHTTPResponse
    ) async throws -> DecodedType where DecodedType: Decodable, DecodedType: Sendable {
        #if canImport(AsyncHTTPClient)
        try decoder.decode(type,
                           from: try await response.body.collect(upTo: 10 * 1024 * 1024))
        #else
        try decoder.decode(type,
                           from: response.data)
        #endif
    }
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public struct AmtrakClientConfig: Sendable {
    #if canImport(AsyncHTTPClient)
    @inlinable
    public static func defaultFetch(httpClient: HTTPClient = .shared) -> AmtrakClientFetch {
        return { request in
            let response = try await httpClient.execute(
                request,
                timeout: .seconds(10)
            )
            guard response.status.code / 100 == 2 else {
                throw URLError(.badServerResponse)
            }
            return response
        }
    }
    #else
    @inlinable
    public static func defaultFetch(session: URLSession = .shared) -> AmtrakClientFetch {
        return { urlRequest in
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: NSURLErrorDomain,
                              code: NSURLErrorUnknown,
                              userInfo: urlRequest.url.flatMap({[NSURLErrorFailingURLErrorKey: $0]}))
            }
            guard httpResponse.statusCode / 100 == 2 else {
                throw NSError(domain: NSURLErrorDomain,
                              code: NSURLErrorBadServerResponse,
                              userInfo: urlRequest.url.flatMap({[NSURLErrorFailingURLErrorKey: $0,
                                                                 "statusCode": httpResponse.statusCode]}))
            }
            return AmtrakClientHTTPResponse(data: data,
                                            response: httpResponse)
        }
    }
    #endif
    public static let defaultBaseURL = URL(string: "https://api-v3.amtraker.com/v3/")!
    let baseURL: URL
    let fetch: AmtrakClientFetch
    let decoder: any AmtrakClientDecoder
    public init(baseURL: URL = Self.defaultBaseURL,
                fetch: @escaping AmtrakClientFetch = Self.defaultFetch(),
                decoder: AmtrakClientDecoder = AmtrakClientJSONDecoder()) {
        self.baseURL = baseURL
        self.fetch = fetch
        self.decoder = decoder
    }
    // TODO: Request customization
    public func requestForEndpoint(_ endpoint: AmtrakClientEndpoint) -> AmtrakClientHTTPRequest {
        let url = switch endpoint {
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
        #if canImport(AsyncHTTPClient)
        return HTTPClientRequest(url: url.absoluteString)
        #else
        return URLRequest(url: url)
        #endif
    }
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public enum AmtrakClientError: Error, Equatable {
    case noStationFound(id: String)
    case noTrainFound(id: String)
    case noTrainsFound(number: String)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
public final class AmtrakClient: Sendable {
    let config: AmtrakClientConfig
    public init(config: AmtrakClientConfig = .init()) {
        self.config = config
    }
    private func fetch<DecodedType>(
        _ endpoint: AmtrakClientEndpoint,
        _ type: DecodedType.Type
    ) async throws -> DecodedType where DecodedType: Decodable, DecodedType: Sendable {
        try await config.decoder.decode(type,
                                        try await config.fetch(config.requestForEndpoint(endpoint)))
    }
    public func fetchAllStations() async throws -> StationMetadataResponse {
        try await fetch(.stations,
                        StationMetadataResponse.self)
    }
    public func fetchStation(id: String) async throws -> StationMetadata {
        let stations = try await fetch(.station(id: id),
                                       StationMetadataResponse.self)
        guard let station = stations[id] else {
            throw AmtrakClientError.noStationFound(id: id)
        }
        return station
    }
    public func fetchAllTrains() async throws -> TrainResponse {
        try await fetch(.trains,
                        TrainResponse.self)
    }
    public func fetchTrain(id: String) async throws -> Train {
        let trainResponse = try await fetch(.train(idOrNumber: id),
                                            TrainResponse.self)

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
            throw AmtrakClientError.noTrainFound(id: id)
        }
        return trains[0]
    }
    public func fetchTrains(number: String) async throws -> [Train] {
        let trainResponse = try await fetch(.train(idOrNumber: number),
                                            TrainResponse.self)

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
            throw AmtrakClientError.noTrainsFound(number: number)
        }
        return trains
    }
    public func fetchStale() async throws -> StaleData {
        try await fetch(.stale,
                        StaleData.self)
    }
}
