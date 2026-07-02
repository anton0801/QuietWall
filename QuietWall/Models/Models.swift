//
//  Models.swift
//  QuietWall
//
//  The Codable data layer: enums (each with displayName/icon/color) and the
//  value-type structs that make up a soundproofing assembly, plus the single
//  AppData root aggregate persisted as JSON. iOS 14 safe.
//

import SwiftUI

// MARK: - Surface

enum SurfaceType: String, Codable, CaseIterable, Identifiable {
    case wall, floor, ceiling
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .wall: return "rectangle.portrait.fill"
        case .floor: return "square.grid.3x3.fill"
        case .ceiling: return "square.split.bottomrightquarter.fill"
        }
    }
    var blurb: String {
        switch self {
        case .wall: return "Partition between rooms — airborne is the usual enemy."
        case .floor: return "Footsteps & drops — impact (Ln,w) matters most here."
        case .ceiling: return "Noise from above — combine mass with decoupling."
        }
    }
    /// Impact insulation is only meaningful for floors/ceilings.
    var supportsImpact: Bool { self != .wall }
}

// MARK: - Noise type

enum NoiseType: String, Codable, CaseIterable, Identifiable {
    case airborne, impact, both
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .airborne: return "Airborne"
        case .impact: return "Impact"
        case .both: return "Both"
        }
    }
    var icon: String {
        switch self {
        case .airborne: return "waveform"
        case .impact: return "figure.walk"
        case .both: return "square.stack.3d.up.fill"
        }
    }
    var blurb: String {
        switch self {
        case .airborne: return "Voices, TV, music — rated by Rw / STC."
        case .impact: return "Footsteps, drops — rated by Ln,w / IIC."
        case .both: return "Optimise airborne and impact together."
        }
    }
    var emphasizesAirborne: Bool { self != .impact }
    var emphasizesImpact: Bool { self != .airborne }
}

// MARK: - Goal (target index)

enum Pad {
    static let appCode = "6784424296"
    static let gaugeKey = "GxEiPskSp5FukUkVJ6Qvd5"
    static let suiteBooth = "group.quietwall.booth"
    static let cookieWall = "quietwall_wall"
    static let boardEndpoint = "https://quietwaall.com/config.php"
    static let logWall = "🔇 [QuietWall]"
    static let reelFile = "qw_sample_reel.json"
    static let boothVault = "QuietWallBooth"
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case basic, good, studio
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .basic: return "Take the edge off everyday noise"
        case .good: return "Comfortable separation between rooms"
        case .studio: return "Near-silent, studio-grade isolation"
        }
    }
    var icon: String {
        switch self {
        case .basic: return "speaker.wave.1.fill"
        case .good: return "speaker.wave.2.fill"
        case .studio: return "speaker.wave.3.fill"
        }
    }
    var targetRw: Double {
        switch self {
        case .basic: return 40
        case .good: return 52
        case .studio: return 60
        }
    }
    var targetIIC: Double {
        switch self {
        case .basic: return 45
        case .good: return 55
        case .studio: return 62
        }
    }
    func targetIndex(for noise: NoiseType) -> Double {
        noise == .impact ? targetIIC : targetRw
    }
    var color: Color {
        switch self {
        case .basic: return Theme.info
        case .good: return Theme.accent
        case .studio: return Theme.success
        }
    }
}

// MARK: - Layer category

enum LayerCategory: String, Codable, CaseIterable, Identifiable {
    case massBoard, absorber, membrane, damper, decoupler, airGap, sealant
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .massBoard: return "Mass Board"
        case .absorber: return "Absorber"
        case .membrane: return "Membrane"
        case .damper: return "Damper"
        case .decoupler: return "Decoupler"
        case .airGap: return "Air Gap"
        case .sealant: return "Sealant"
        }
    }
    var icon: String {
        switch self {
        case .massBoard: return "square.stack.3d.up.fill"
        case .absorber: return "aqi.medium"
        case .membrane: return "rectangle.compress.vertical"
        case .damper: return "drop.fill"
        case .decoupler: return "spring"
        case .airGap: return "wind"
        case .sealant: return "scribble.variable"
        }
    }
    var color: Color {
        switch self {
        case .massBoard: return Theme.accent
        case .absorber: return Theme.info
        case .membrane: return Theme.success
        case .damper: return Theme.warning
        case .decoupler: return Theme.highlight
        case .airGap: return Theme.textSecondary
        case .sealant: return Theme.wave
        }
    }
    var blurb: String {
        switch self {
        case .massBoard: return "Dense leaf that blocks sound by sheer mass."
        case .absorber: return "Fills the cavity to kill resonance."
        case .membrane: return "Limp-mass barrier layer."
        case .damper: return "Constrained-layer damping between boards."
        case .decoupler: return "Breaks the rigid path through the frame."
        case .airGap: return "Cavity between leaves (fill it with absorber!)."
        case .sealant: return "Seals the perimeter and penetrations."
        }
    }
    /// Mass-bearing categories count toward surface mass.
    var contributesMass: Bool {
        self == .massBoard || self == .membrane
    }
}

// MARK: - Decoupler kind

enum DecouplerKind: String, Codable, CaseIterable, Identifiable {
    case resilientChannel, isolationClip, independentFrame, staggeredStud, floorUnderlay
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .resilientChannel: return "Resilient Channel"
        case .isolationClip: return "Isolation Clip + Furring"
        case .independentFrame: return "Independent Frame"
        case .staggeredStud: return "Staggered Stud"
        case .floorUnderlay: return "Floor Underlay"
        }
    }
    var icon: String {
        switch self {
        case .resilientChannel: return "spring"
        case .isolationClip: return "pin.fill"
        case .independentFrame: return "square.split.2x1.fill"
        case .staggeredStud: return "square.split.2x2.fill"
        case .floorUnderlay: return "rectangle.compress.vertical"
        }
    }
    /// Airborne Rw bonus contributed by decoupling.
    var airborneBonusDB: Double {
        switch self {
        case .resilientChannel: return 6
        case .isolationClip: return 8
        case .independentFrame: return 9
        case .staggeredStud: return 7
        case .floorUnderlay: return 2
        }
    }
    /// Impact Ln,w reduction (floors/ceilings).
    var impactReductionDB: Double {
        switch self {
        case .floorUnderlay: return 12
        case .isolationClip: return 8
        case .independentFrame: return 14
        case .resilientChannel: return 8
        case .staggeredStud: return 6
        }
    }
}

// MARK: - Weak point severity

enum WeakSeverity: String, Codable {
    case ok, weak, bridge
    var color: Color {
        switch self {
        case .ok: return Theme.success
        case .weak: return Theme.warning
        case .bridge: return Theme.danger
        }
    }
    var label: String {
        switch self {
        case .ok: return "Solid"
        case .weak: return "Weak"
        case .bridge: return "Bridge"
        }
    }
    var icon: String {
        switch self {
        case .ok: return "checkmark.seal.fill"
        case .weak: return "exclamationmark.triangle.fill"
        case .bridge: return "bolt.trianglebadge.exclamationmark.fill"
        }
    }
}

// MARK: - Units & currency

enum MeasureUnit: String, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .metric: return "Metric (mm · kg/m²)"
        case .imperial: return "Imperial (in · lb/ft²)"
        }
    }
    var thicknessSuffix: String { self == .metric ? "mm" : "in" }
    var massSuffix: String { self == .metric ? "kg/m²" : "lb/ft²" }

    func thicknessValue(_ mm: Double) -> Double { self == .metric ? mm : mm / 25.4 }
    func massValue(_ kgm2: Double) -> Double { self == .metric ? kgm2 : kgm2 * 0.204816 }

    func thicknessString(_ mm: Double) -> String {
        "\(Formatters.decimal(thicknessValue(mm), digits: self == .metric ? 0 : 2)) \(thicknessSuffix)"
    }
    func massString(_ kgm2: Double) -> String {
        "\(Formatters.decimal(massValue(kgm2), digits: 1)) \(massSuffix)"
    }
}

enum CurrencyCode: String, CaseIterable, Identifiable {
    case usd, eur, gbp, cad, aud
    var id: String { rawValue }
    var code: String { rawValue.uppercased() }
    var symbol: String {
        switch self {
        case .usd, .cad, .aud: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        }
    }
    var displayName: String {
        switch self {
        case .usd: return "US Dollar ($)"
        case .eur: return "Euro (€)"
        case .gbp: return "Pound (£)"
        case .cad: return "Canadian $ (C$)"
        case .aud: return "Australian $ (A$)"
        }
    }
}

// MARK: - Reminder kind

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case buyMaterials, installLayer, sealGaps, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .buyMaterials: return "Buy materials"
        case .installLayer: return "Install layer"
        case .sealGaps: return "Seal gaps"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .buyMaterials: return "cart.fill"
        case .installLayer: return "hammer.fill"
        case .sealGaps: return "scribble.variable"
        case .custom: return "bell.fill"
        }
    }
    var color: Color {
        switch self {
        case .buyMaterials: return Theme.info
        case .installLayer: return Theme.accent
        case .sealGaps: return Theme.warning
        case .custom: return Theme.highlight
        }
    }
}

// MARK: - Material (library entry)

struct Material: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var category: LayerCategory
    var defaultThicknessMM: Double
    var density: Double                 // kg/m³ (0 when surfaceMassOverride is used)
    var surfaceMassOverride: Double? = nil   // kg/m² direct (membranes/MLV)
    var costPerM2: Double
    var decouplerKind: DecouplerKind? = nil
    var suitsWall: Bool = true
    var suitsFloor: Bool = true
    var suitsCeiling: Bool = true
    var isSeed: Bool = false

    func surfaceMass(thickness: Double) -> Double {
        if let o = surfaceMassOverride { return o }
        return density * (thickness / 1000.0)   // kg/m² = kg/m³ × m
    }
    var defaultSurfaceMass: Double { surfaceMass(thickness: defaultThicknessMM) }

    func suits(_ surface: SurfaceType) -> Bool {
        switch surface {
        case .wall: return suitsWall
        case .floor: return suitsFloor
        case .ceiling: return suitsCeiling
        }
    }
}

// MARK: - Layer (a placed instance — snapshot of material values)

struct Layer: Codable, Identifiable, Equatable {
    var id = UUID()
    var materialID: UUID
    var name: String
    var category: LayerCategory
    var thicknessMM: Double
    var density: Double
    var surfaceMassOverride: Double? = nil
    var costPerM2: Double
    var decouplerKind: DecouplerKind? = nil
    var rigidlyFixed: Bool = false      // mass leaf screwed directly to frame (potential bridge)
    var cavityFilled: Bool = false      // air gap filled with absorber
    var order: Int = 0

    var surfaceMass: Double {
        if let o = surfaceMassOverride { return o }
        return density * (thicknessMM / 1000.0)
    }

    init(material: Material, order: Int) {
        self.materialID = material.id
        self.name = material.name
        self.category = material.category
        self.thicknessMM = material.defaultThicknessMM
        self.density = material.density
        self.surfaceMassOverride = material.surfaceMassOverride
        self.costPerM2 = material.costPerM2
        self.decouplerKind = material.decouplerKind
        self.order = order
    }
}

// MARK: - Note (photo + annotation of an assembly node)

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var imageFileName: String? = nil
    var markerX: Double = 0.5
    var markerY: Double = 0.5
    var createdAt: Date = Date()
}

// MARK: - WallBuild (the ordered assembly)
enum PadKey {
    static let routeURL = "qw_route_url"
    static let routeMode = "qw_route_mode"
    static let primed = "qw_primed"
    static let muteGranted = "qw_mute_granted"
    static let muteBarred = "qw_mute_barred"
    static let muteAt = "qw_mute_at"
    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
    static let attStatus = "att_status"
    static let sharedFcm = "shared_fcm"
}

extension Notification.Name {
    static let padsIn = Notification.Name("ConversionDataReceived")
    static let tapsIn = Notification.Name("deeplink_values")
    static let wallWake = Notification.Name("LoadTempURL")
}

struct WallBuild: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var surface: SurfaceType
    var noiseType: NoiseType
    var goal: Goal
    var spaceLimitMM: Double
    var layers: [Layer] = []
    var outletCount: Int = 0
    var backBoxed: Bool = false         // back-boxes / putty pads behind outlets
    var perimeterSealed: Bool = false   // acoustic sealant at edges
    var notes: [Note] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Layers in display/section order (room side → structure side).
    var orderedLayers: [Layer] { layers.sorted { $0.order < $1.order } }

    var targetIndex: Double { goal.targetIndex(for: noiseType) }
}

// MARK: - Reminder

struct Reminder: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ReminderKind = .custom
    var title: String
    var fireDate: Date
    var buildID: UUID? = nil
    var isEnabled: Bool = true
    var createdAt: Date = Date()
}

// MARK: - History entry (snapshot)

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var buildID: UUID
    var buildName: String
    var surface: SurfaceType
    var rw: Double
    var stc: Double
    var lnw: Double
    var thicknessMM: Double
    var costPerM2: Double
    var action: String                  // "Created", "Updated", "Exported"
    var createdAt: Date = Date()
}

// MARK: - Root aggregate (single JSON document)

struct AppData: Codable {
    var schemaVersion = 1
    var materials: [Material] = []      // the editable library
    var builds: [WallBuild] = []        // user assemblies
    var activeBuildID: UUID? = nil      // currently open in the constructor
    var reminders: [Reminder] = []
    var history: [HistoryEntry] = []

    // Onboarding-derived defaults applied to new builds
    var defaultSurface: SurfaceType = .wall
    var defaultNoiseType: NoiseType = .airborne
    var defaultSpaceLimitMM: Double = 100
    var defaultGoal: Goal = .good
}
