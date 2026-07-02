import Foundation

struct Sample: Codable {
    var pads: [String: String] = [:]
    var taps: [String: String] = [:]
    var routeURL: String?
    var routeMode: String?
    var boxed: Bool = true
    var hushed: Bool = false
    var damped: Bool = false
    var muteGranted: Bool = false
    var muteBarred: Bool = false
    var muteAt: Date?

    var hasPads: Bool {
        !pads.isEmpty
    }

    var organicHiss: Bool {
        (pads["af_status"] ?? "").caseInsensitiveCompare("Organic") == .orderedSame
    }

    var muteDue: Bool {
        guard !muteGranted && !muteBarred else { return false }
        if let at = muteAt {
            return Date().timeIntervalSince(at) / 86_400 >= 3
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case pads, taps, routeURL, routeMode, boxed, damped, muteGranted, muteBarred, muteAt
    }
}

enum Tone {
    case murmur
    case cue
    case air
    case feedback
}
