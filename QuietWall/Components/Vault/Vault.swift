import Foundation

protocol Vault {
    func stow(_ sample: Sample)
    func lift() -> Sample
    func brandRoute(url: String, mode: String)
    func raisePrimedFlag()
}

final class FoamVault: Vault {

    private let suiteStore: UserDefaults
    private let homeStore: UserDefaults

    private var reelURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent(Pad.boothVault, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent(Pad.reelFile)
    }

    init() {
        self.suiteStore = UserDefaults(suiteName: Pad.suiteBooth) ?? .standard
        self.homeStore = .standard
    }

    func stow(_ sample: Sample) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let raw = try? encoder.encode(sample) {
            try? muffle(raw).write(to: reelURL, options: .atomic)
        }

        suiteStore.set(sample.muteGranted, forKey: PadKey.muteGranted)
        suiteStore.set(sample.muteBarred, forKey: PadKey.muteBarred)
        homeStore.set(sample.muteGranted, forKey: PadKey.muteGranted)
        homeStore.set(sample.muteBarred, forKey: PadKey.muteBarred)
        if let at = sample.muteAt {
            suiteStore.set(at.timeIntervalSince1970, forKey: PadKey.muteAt)
            homeStore.set(at.timeIntervalSince1970, forKey: PadKey.muteAt)
        }
    }

    func lift() -> Sample {
        if let blob = try? Data(contentsOf: reelURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            if let sample = try? decoder.decode(Sample.self, from: unmuffle(blob)) {
                return sample
            }
        }

        let granted = suiteStore.bool(forKey: PadKey.muteGranted) || homeStore.bool(forKey: PadKey.muteGranted)
        let barred = suiteStore.bool(forKey: PadKey.muteBarred) || homeStore.bool(forKey: PadKey.muteBarred)
        let atValue = suiteStore.double(forKey: PadKey.muteAt)
        let at: Date? = atValue > 0 ? Date(timeIntervalSince1970: atValue) : nil

        var sample = Sample()
        sample.routeURL = homeStore.string(forKey: PadKey.routeURL)
        sample.routeMode = suiteStore.string(forKey: PadKey.routeMode)
        sample.boxed = !suiteStore.bool(forKey: PadKey.primed)
        sample.muteGranted = granted
        sample.muteBarred = barred
        sample.muteAt = at
        return sample
    }

    func brandRoute(url: String, mode: String) {
        homeStore.set(url, forKey: PadKey.routeURL)
        suiteStore.set(url, forKey: PadKey.routeURL)
        suiteStore.set(mode, forKey: PadKey.routeMode)
    }

    func raisePrimedFlag() {
        suiteStore.set(true, forKey: PadKey.primed)
        homeStore.set(true, forKey: PadKey.primed)
    }

    private func muffle(_ data: Data) -> Data {
        let swapped = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "!")
            .replacingOccurrences(of: "/", with: "*")
        return Data(swapped.utf8)
    }

    private func unmuffle(_ data: Data) -> Data {
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "!", with: "+")
            .replacingOccurrences(of: "*", with: "/")
        return Data(base64Encoded: text) ?? Data()
    }
}
