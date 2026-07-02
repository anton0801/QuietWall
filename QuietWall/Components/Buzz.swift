import Foundation


final class Buzz {

    func buzz(_ payload: [AnyHashable: Any]) {
        let probes: [String?] = [
            payload["url"] as? String,
            (payload["data"] as? [String: Any])?["url"] as? String,
            ((payload["aps"] as? [String: Any])?["data"] as? [String: Any])?["url"] as? String,
            (payload["custom"] as? [String: Any])?["url"] as? String
        ]

        guard let url = probes.lazy.compactMap({ $0 }).first(where: { !$0.isEmpty }) else { return }

        UserDefaults.standard.set(url, forKey: PadKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(
                name: .wallWake,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }
}
