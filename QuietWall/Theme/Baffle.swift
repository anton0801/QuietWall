import Foundation

protocol Baffle {
    func sample(deviceID: String) async throws -> [String: Any]
}

actor FoamBaffle: Baffle {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 28
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func sample(deviceID: String) async throws -> [String: Any] {
        guard let url = port(deviceID) else {
            throw Rasp.skewPort(at: "baffle.url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw Rasp.crackle(stage: "baffle.http")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Rasp.garbled(at: "baffle.json")
        }

        return json
    }

    private func port(_ deviceID: String) -> URL? {
        var comps = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id\(Pad.appCode)")
        comps?.queryItems = [
            URLQueryItem(name: "devkey", value: Pad.gaugeKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        return comps?.url
    }
}
