import Foundation
import Testing
@testable import Amtrak

@available(macOS 15.0.0, iOS 18.0.0, *)
let testClient = Client(
    config: .init(
        baseURL: URL(string: "https://api-v3.amtraker.com/v3/")!,
        fetch: { url in
            func fixture(name: String) throws -> (data: Data, response: HTTPURLResponse) {
                guard let fixture = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
                    throw NSError(domain: NSCocoaErrorDomain, code: 0)
                }
                let data = try Data(contentsOf: fixture)
                return (data, HTTPURLResponse(url: url, mimeType: "app/json", expectedContentLength: data.count, textEncodingName: "utf8"))
            }
            switch url.lastPathComponent {
            case "stations":
                return try fixture(name: "stations")
            case "UCA":
                return try fixture(name: "station-UCA")
            case "trains":
                return try fixture(name: "trains")
            case "48":
                return try fixture(name: "train-48")
            case "stale":
                return try fixture(name: "stale")
            default:
                throw NSError(domain: NSCocoaErrorDomain, code: 0)
            }
        }
    )
)

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func stations() async throws {
    let stations = try await testClient.fetchAllStations()
    #expect(stations["UCA"] != nil)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func station() async throws {
    _ = try await testClient.fetchStation(id: "UCA")
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func trains() async throws {
    let trainResponse = try await testClient.fetchAllTrains()
    let trains = trainResponse["48"]
    #expect(trains != nil)
    #expect(trains?.count == 1)
    #expect(trains?[0].stations.count == 20)
    #expect(trains?[0].stations[0].schArr == Date(timeIntervalSinceReferenceDate: 794115000.0))
    #expect(trains?[0].stations[0].schDep == Date(timeIntervalSinceReferenceDate: 794115000.0))
    #expect(trains?[0].createdAt == Date(timeIntervalSinceReferenceDate: 794161278.0))
    #expect(trains?[0].updatedAt == Date(timeIntervalSinceReferenceDate: 794161278.0))
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func train() async throws {
    _ = try await testClient.fetchTrain(id: "48")
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func stale() async throws {
    _ = try await testClient.fetchStale()
}
