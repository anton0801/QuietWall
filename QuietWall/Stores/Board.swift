import Foundation
import WebKit
import FirebaseCore
import FirebaseMessaging
import AppsFlyerLib

protocol Board {
    func relay(load: [String: Any]) async throws -> String
}

final class HouseBoard: Board {

    private let session: URLSession
    private let gaps: [TimeInterval] = [104, 208, 416]

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func relay(load: [String: Any]) async throws -> String {
        let request = try await wire(load)
        let gaps = self.gaps
        var carried: Error = Rasp.crackle(stage: "board")

        let schedule = sequence(state: 0) { (step: inout Int) -> (Int, TimeInterval)? in
            guard step < gaps.count else { return nil }
            defer { step += 1 }
            return (step, gaps[step])
        }

        for (idx, gap) in schedule {
            do {
                return try await tap(request)
            } catch let rasp as Rasp where rasp.isSealed {
                throw rasp
            } catch {
                carried = error
                guard idx < gaps.count - 1 else { break }
                try await lull(coolFor(error) ?? gap)
            }
        }

        throw carried
    }

    private func tap(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Rasp.crackle(stage: "board.response")
        }

        if http.statusCode == 404 {
            throw Rasp.deadAir(httpCode: 404)
        }

        if http.statusCode == 429 {
            let cool = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw Rasp.overdrive(cooldown: cool)
        }

        guard (200...299).contains(http.statusCode) else {
            throw Rasp.crackle(stage: "board.status")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Rasp.garbled(at: "board.json")
        }

        guard let ok = json["ok"] as? Bool else {
            throw Rasp.garbled(at: "board.ok")
        }

        if !ok {
            throw Rasp.cutOff(reason: "okFalse")
        }

        guard let url = json["url"] as? String, !url.isEmpty else {
            throw Rasp.garbled(at: "board.url")
        }

        return url
    }

    private func coolFor(_ error: Error) -> TimeInterval? {
        if let rasp = error as? Rasp, case .overdrive(let cool) = rasp {
            return cool
        }
        return nil
    }

    @MainActor
    private func wire(_ load: [String: Any]) throws -> URLRequest {
        guard let endpoint = URL(string: Pad.boardEndpoint) else {
            throw Rasp.skewPort(at: "board.endpoint")
        }

        var body = load
        body["os"] = "iOS"
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"] = "id\(Pad.appCode)"
        body["push_token"] = UserDefaults.standard.string(forKey: PadKey.push) ?? Messaging.messaging().fcmToken
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(WKWebView().value(forKey: "userAgent") as? String ?? "", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func lull(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
