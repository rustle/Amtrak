import Foundation
import Testing
@testable import Amtrak

enum AmtrakTestsError: Error {
    case missingFixture(String)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
private let fixtureClient = AmtrakClient(
    config: .init(
        baseURL: AmtrakClientConfig.defaultBaseURL,
        fetch: { urlRequest in
            func fixture(name: String) throws -> AmtrakClientHTTPResponse {
                guard let fixtureURL = Bundle.module.url(forResource: name,
                                                         withExtension: "json",
                                                         subdirectory: "Fixtures") else {
                    throw AmtrakTestsError.missingFixture(name)
                }
                let data = try Data(contentsOf: fixtureURL)
                return AmtrakClientHTTPResponse(
                    data: data,
                    response: HTTPURLResponse(
                        url: url,
                        mimeType: "application/json",
                        expectedContentLength: data.count,
                        textEncodingName: "utf8"
                    )
                )
            }
            let url = urlRequest.url!
            switch url.lastPathComponent {
            case "stations":
                return try fixture(name: "stations")
            case "UCA":
                return try fixture(name: "station-UCA")
            case "trains":
                return try fixture(name: "trains")
            case "48", "48-1":
                return try fixture(name: "train-48")
            case "stale":
                return try fixture(name: "stale")
            default:
                throw AmtrakTestsError.missingFixture(url.lastPathComponent)
            }
        },
        decoder: AmtrakClientJSONDecoder()
    )
)

@available(macOS 15.0.0, iOS 18.0.0, *)
private let emptyClient = AmtrakClient(
    config: .init(
        baseURL: AmtrakClientConfig.defaultBaseURL,
        fetch: { urlRequest in
            let data = Data("{}".utf8)
            return AmtrakClientHTTPResponse(
                data: data,
                response: HTTPURLResponse(
                    url: urlRequest.url!,
                    mimeType: "application/json",
                    expectedContentLength: data.count,
                    textEncodingName: "utf8"
                )
            )
        },
        decoder: AmtrakClientJSONDecoder()
    )
)

@available(macOS 15.0.0, iOS 18.0.0, *)
private let dateFormatCient = AmtrakClient(config: .init(
    baseURL: AmtrakClientConfig.defaultBaseURL,
    fetch: { urlRequest in
        let fixtureURL = try #require(
            Bundle.module.url(
                forResource: "dateFormatWithFractionalSecondsIsParsed",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let data = try Data(contentsOf: fixtureURL)
        return AmtrakClientHTTPResponse(
            data: data,
            response: HTTPURLResponse(
                url: urlRequest.url!,
                mimeType: "application/json",
                expectedContentLength: data.count,
                textEncodingName: "utf8"
            )
        )
    },
    decoder: AmtrakClientJSONDecoder()
))

// MARK: - Station metadata

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchAllStationsContainsUCA() async throws {
    let stations = try await fixtureClient.fetchAllStations()
    #expect(stations["UCA"] == .ucaFixture)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchStationUCA() async throws {
    let station = try await fixtureClient.fetchStation(id: "UCA")
    #expect(station == .ucaFixture)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchStationUnknownThrowsNoStationFound() async throws {
    // emptyClient returns {} so "XYZ" is absent and noStationFound is thrown.
    await #expect(throws: AmtrakClientError.noStationFound(id: "XYZ")) {
        try await emptyClient.fetchStation(id: "XYZ")
    }
}

// MARK: - Train

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchAllTrainsContainsTrain48() async throws {
    // trains.json is a different API snapshot than train-48.json (the train moved),
    // so compare identifying fields rather than the full fixture.
    let response = try await fixtureClient.fetchAllTrains()
    let trains = try #require(response["48"])
    #expect(trains.count == 1)
    #expect(trains[0].trainNum == "48")
    #expect(trains[0].trainID == "48-1")
    #expect(trains[0].routeName == "Lake Shore Limited")
    #expect(trains[0].stations.count == 20)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrain48ByID() async throws {
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    #expect(train == .train48Fixture)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrains48ByNumber() async throws {
    let trains = try await fixtureClient.fetchTrains(number: "48")
    #expect(trains == [.train48Fixture])
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainDecodesScalarFields() async throws {
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    #expect(train.routeName == "Lake Shore Limited")
    #expect(train.trainNum == "48")
    #expect(train.trainNumRaw == "48")
    #expect(train.trainID == "48-1")
    #expect(train.lat == 43.054249778598034)
    #expect(train.lon == -76.63167817214746)
    #expect(train.iconColor == "#509e24")
    #expect(train.heading == .E)
    #expect(train.eventCode == "SYR")
    #expect(train.eventTZ == "America/New_York")
    #expect(train.eventName == "Syracuse")
    #expect(train.origCode == "CHI")
    #expect(train.originTZ == "America/Chicago")
    #expect(train.origName == "Chicago Union")
    #expect(train.destCode == "NYP")
    #expect(train.destTZ == "America/New_York")
    #expect(train.destName == "New York Penn")
    #expect(train.trainState == .active)
    #expect(train.velocity == 76.8858642578125)
    #expect(train.statusMsg == " ")
    #expect(train.objectID == 27)
    #expect(train.provider == "Amtrak")
    #expect(train.providerShort == "AMTK")
    #expect(train.onlyOfTrainNum == true)
    #expect(train.alerts == [])
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainDecodesAllStations() async throws {
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    #expect(train.stations.count == 20)
    #expect(train.stations == Train.train48Fixture.stations)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainDecodesFirstStation() async throws {
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    let chi = try #require(train.stations.first)
    #expect(chi.name == "Chicago Union")
    #expect(chi.code == "CHI")
    #expect(chi.tz == "America/Chicago")
    #expect(chi.bus == false)
    #expect(chi.schArr == iso8601("2026-03-01T21:30:00-06:00"))
    #expect(chi.schDep == iso8601("2026-03-01T21:30:00-06:00"))
    #expect(chi.arr == iso8601("2026-03-01T21:30:00-06:00"))
    #expect(chi.dep == iso8601("2026-03-01T21:30:00-06:00"))
    #expect(chi.platform == "")
    #expect(chi.status == .Departed)
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainDecodesEnrouteStationStatus() async throws {
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    // SYR is index 12, status "Enroute"
    let syr = train.stations[12]
    #expect(syr.code == "SYR")
    #expect(syr.status == .enroute)
}

// MARK: - Date parsing

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func dateFormatWithTimezoneOffsetIsParsed() async throws {
    // createdAt in train-48.json uses the timezone-offset format: "2026-03-02T11:24:22-05:00"
    let train = try await fixtureClient.fetchTrain(id: "48-1")
    #expect(train.createdAt == iso8601("2026-03-02T11:24:22-05:00"))
    #expect(train.updatedAt == iso8601("2026-03-02T11:24:22-05:00"))
    #expect(train.lastValTS == iso8601("2026-03-02T11:23:59-05:00"))
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func dateFormatWithFractionalSecondsIsParsed() async throws {
    // Verify the second ISO8601 formatter handles the ".000Z" fractional-seconds format.
    // These UTC timestamps are the same instants as the fixture's timezone-offset timestamps.
    let train = try await dateFormatCient.fetchTrain(id: "48-1")
    #expect(train.createdAt == iso8601("2026-03-02T11:24:22-05:00"))
    #expect(train.stations[0].schArr == iso8601("2026-03-01T21:30:00-06:00"))
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainUnknownThrowsNoTrainFound() async throws {
    await #expect(throws: AmtrakClientError.noTrainFound(id: "99-1")) {
        try await emptyClient.fetchTrain(id: "99-1")
    }
}

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchTrainsUnknownThrowsNoTrainsFound() async throws {
    await #expect(throws: AmtrakClientError.noTrainsFound(number: "99")) {
        try await emptyClient.fetchTrains(number: "99")
    }
}

// MARK: - Stale

@available(macOS 15.0.0, iOS 18.0.0, *)
@Test func fetchStaleDecodesAllFields() async throws {
    let stale = try await fixtureClient.fetchStale()
    #expect(stale == .fixture)
    #expect(stale.avgLastUpdate == 247211.03164556963)
    #expect(stale.activeTrains == 158)
    #expect(stale.stale == false)
}
