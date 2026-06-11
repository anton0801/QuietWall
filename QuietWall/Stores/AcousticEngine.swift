//
//  AcousticEngine.swift
//  QuietWall
//
//  The core domain logic: a transparent, stateless HEURISTIC that estimates the
//  airborne (Rw / STC) and impact (Ln,w / IIC) performance of a layered
//  assembly, distributes attenuation per layer for the wave visualization, and
//  flags acoustic bridges / weak points. Estimative — not a lab measurement.
//  iOS 14 safe (Foundation math only).
//

import Foundation

// MARK: - Result value types

struct AttenStep: Identifiable {
    let id: UUID
    let layerID: UUID
    let name: String
    let category: LayerCategory
    let deltaDB: Double      // signed: + attenuates, − leaks (a bridge)
    let remainingDB: Double  // sound energy still passing after this layer (starts at Rw)
    let isLeak: Bool
}

struct WeakPoint: Identifiable {
    let id = UUID()
    let severity: WeakSeverity
    var layerID: UUID? = nil
    let title: String
    let fix: String
}

struct BreakdownLine: Identifiable {
    let id = UUID()
    let label: String
    let valueDB: Double      // signed contribution
}

struct AcousticResult {
    var rw: Double = 0
    var stc: Double = 0
    var lnw: Double = 0
    var iic: Double = 0
    var totalThicknessMM: Double = 0
    var totalSurfaceMass: Double = 0
    var totalCostPerM2: Double = 0
    var attenuationProfile: [AttenStep] = []
    var weakPoints: [WeakPoint] = []
    var breakdown: [BreakdownLine] = []
    var surface: SurfaceType = .wall
    var noiseType: NoiseType = .airborne

    /// Impact rating only matters on floors/ceilings.
    var impactRelevant: Bool { surface.supportsImpact }
    /// Which index the gauge compares to the goal.
    var primaryIsImpact: Bool { impactRelevant && noiseType == .impact }
    var primaryIndex: Double { primaryIsImpact ? iic : rw }

    var bridgeCount: Int { weakPoints.filter { $0.severity == .bridge }.count }
    var weakCount: Int { weakPoints.filter { $0.severity == .weak }.count }

    func meetsTarget(_ build: WallBuild) -> Bool {
        primaryIndex >= build.targetIndex
    }
    func status(_ build: WallBuild) -> WeakSeverity {
        if bridgeCount > 0 { return .bridge }
        if meetsTarget(build) && weakCount == 0 { return .ok }
        return .weak
    }
}

// MARK: - Engine

enum AcousticEngine {

    static let minRw: Double = 20
    static let maxRw: Double = 75
    static let bonusCap: Double = 30

    // MARK: Public entry

    static func evaluate(_ build: WallBuild) -> AcousticResult {
        let layers = build.orderedLayers
        var r = AcousticResult()
        r.surface = build.surface
        r.noiseType = build.noiseType

        // Totals
        r.totalThicknessMM = layers.reduce(0) { $0 + $1.thicknessMM }
        r.totalCostPerM2 = layers.reduce(0) { $0 + $1.costPerM2 }

        // Feature detection
        let massLeaves = layers.filter { $0.category == .massBoard }
        let membranes  = layers.filter { $0.category == .membrane }
        let absorbers  = layers.filter { $0.category == .absorber }
        let dampers    = layers.filter { $0.category == .damper }
        let decouplers = layers.filter { $0.category == .decoupler }
        let airGaps    = layers.filter { $0.category == .airGap }

        // Surface mass (mass law)
        let M = max(1, layers.filter { $0.category.contributesMass }.reduce(0) { $0 + $1.surfaceMass })
        r.totalSurfaceMass = layers.filter { $0.category.contributesMass }.reduce(0) { $0 + $1.surfaceMass }

        let hasAbsorber = !absorbers.isEmpty
        let hasCavity = !airGaps.isEmpty || !decouplers.isEmpty
        let cavityFilled = hasAbsorber || airGaps.contains { $0.cavityFilled }
        let bestDecouple = decouplers.compactMap { $0.decouplerKind?.airborneBonusDB }.max() ?? 0
        let damperConstrained = isDamperConstrained(layers)

        // ---- Airborne Rw ----
        var breakdown: [BreakdownLine] = []
        let baseRw = 20 * log10(M) + 10
        breakdown.append(BreakdownLine(label: "Mass law base (\(Formatters.decimal(M, digits: 1)) kg/m²)", valueDB: baseRw))

        var bonus: Double = 0
        func addBonus(_ v: Double, _ label: String) {
            guard v != 0 else { return }
            bonus += v
            breakdown.append(BreakdownLine(label: label, valueDB: v))
        }

        if bestDecouple > 0, let kind = decouplers.compactMap({ $0.decouplerKind }).max(by: { $0.airborneBonusDB < $1.airborneBonusDB }) {
            addBonus(bestDecouple, "Decoupling — \(kind.displayName)")
        }
        if cavityFilled {
            addBonus(5, "Filled cavity (absorber)")
        } else if hasCavity {
            addBonus(2, "Cavity (empty)")
        }
        // air-gap depth scaling
        if let maxGap = airGaps.map({ $0.thicknessMM }).max(), maxGap > 25 {
            let extra = min(4, floor((maxGap - 25) / 25))
            addBonus(extra, "Deep cavity (+\(Int(extra)) dB)")
        }
        // additional decoupled leaves
        if hasCavity && massLeaves.count >= 3 {
            addBonus(6, "Multiple decoupled leaves")
        } else if hasCavity && massLeaves.count >= 2 {
            addBonus(4, "Second decoupled leaf")
        }
        if !membranes.isEmpty {
            addBonus(3, "Limp-mass membrane")
        }
        if !dampers.isEmpty {
            addBonus(damperConstrained ? 4 : 1, damperConstrained ? "Constrained-layer damping" : "Damping (not constrained)")
        }

        // Penalties
        var penalty: Double = 0
        func addPenalty(_ v: Double, _ label: String) {
            guard v != 0 else { return }
            penalty += v
            breakdown.append(BreakdownLine(label: label, valueDB: -v))
        }
        let hasRigidBridge = hasCavity && massLeaves.contains { $0.rigidlyFixed }
        if hasRigidBridge { addPenalty(6, "Rigid fixing bridge") }
        if hasCavity && !cavityFilled { addPenalty(2, "Unfilled cavity") }
        if build.outletCount > 0 && !build.backBoxed {
            addPenalty(min(6, Double(build.outletCount) * 3), "Unsealed outlets")
        }
        if !build.perimeterSealed { addPenalty(4, "Unsealed perimeter") }
        if massLeaves.count <= 1 && M < 5 { addPenalty(4, "Very light single leaf") }
        if build.surface == .wall && massLeaves.count <= 1 && bestDecouple == 0 {
            addPenalty(2, "Flanking (single rigid leaf)")
        }

        let cappedBonus = min(bonus, bonusCap)
        let rw = clamp(baseRw + cappedBonus - penalty, minRw, maxRw)
        r.rw = rw.rounded()
        r.stc = (rw - 1).rounded()
        r.breakdown = breakdown

        // ---- Impact Ln,w ----
        let impactDecouple = decouplers.compactMap { $0.decouplerKind?.impactReductionDB }.max() ?? 0
        let cavityAbsorberImpact: Double = hasAbsorber ? 4 : 0
        let massImpact = min(6, 0.05 * M)
        let lnw = clamp(80 - impactDecouple - cavityAbsorberImpact - massImpact, 35, 85)
        r.lnw = lnw.rounded()
        r.iic = (110 - lnw).rounded()

        // ---- Attenuation profile (visualization) ----
        r.attenuationProfile = buildProfile(layers: layers, rw: r.rw,
                                            cavityFilled: cavityFilled,
                                            damperConstrained: damperConstrained,
                                            hasRigidBridge: hasRigidBridge,
                                            perimeterSealed: build.perimeterSealed)

        // ---- Weak points ----
        r.weakPoints = weakPoints(build: build, layers: layers, M: M,
                                  hasCavity: hasCavity, cavityFilled: cavityFilled,
                                  massLeaves: massLeaves, dampers: dampers,
                                  damperConstrained: damperConstrained,
                                  bestDecouple: bestDecouple)
        return r
    }

    // MARK: Mass advice

    static func surfaceMass(_ build: WallBuild) -> Double {
        build.orderedLayers.filter { $0.category.contributesMass }.reduce(0) { $0 + $1.surfaceMass }
    }

    static func massAdvice(_ M: Double) -> (headline: String, detail: String, severity: WeakSeverity) {
        if M < 10 {
            return ("Very light — expect ~30 dB", "Add a dense board. Doubling surface mass raises Rw by roughly 6 dB.", .bridge)
        } else if M < 20 {
            return ("Add a second board", "You're on the mass-law curve. Another leaf adds ~+6 dB per doubling of mass.", .weak)
        } else if M <= 40 {
            return ("Good mass base", "Mass is solid — the biggest wins now come from decoupling and sealing.", .ok)
        } else {
            return ("Mass is sufficient", "Diminishing returns from more mass. Decouple the leaves and seal the perimeter instead.", .ok)
        }
    }

    /// Projected Rw if a candidate material were appended to the assembly.
    static func projectedRw(_ build: WallBuild, adding material: Material) -> Double {
        var copy = build
        copy.layers.append(Layer(material: material, order: (build.layers.map { $0.order }.max() ?? 0) + 1))
        return evaluate(copy).rw
    }

    // MARK: - Private helpers

    private static func isDamperConstrained(_ layers: [Layer]) -> Bool {
        for (i, layer) in layers.enumerated() where layer.category == .damper {
            let before = i > 0 ? layers[i - 1].category == .massBoard : false
            let after = i < layers.count - 1 ? layers[i + 1].category == .massBoard : false
            if before && after { return true }
        }
        return false
    }

    private static func buildProfile(layers: [Layer], rw: Double,
                                     cavityFilled: Bool, damperConstrained: Bool,
                                     hasRigidBridge: Bool, perimeterSealed: Bool) -> [AttenStep] {
        guard !layers.isEmpty else { return [] }

        // raw per-layer weights (positive = blocks, negative = leaks)
        func weight(_ layer: Layer) -> Double {
            switch layer.category {
            case .massBoard:
                let w = 20 * log10(max(1, layer.surfaceMass) + 1)
                return layer.rigidlyFixed ? -3 : w   // a rigid leaf leaks
            case .absorber: return 5
            case .airGap: return layer.cavityFilled ? 4 : 1
            case .decoupler: return layer.decouplerKind?.airborneBonusDB ?? 4
            case .membrane: return 3
            case .damper: return damperConstrained ? 4 : 1
            case .sealant: return perimeterSealed ? 2 : 0
            }
        }
        let weights = layers.map(weight)
        let posSum = weights.filter { $0 > 0 }.reduce(0, +)
        let scale = posSum > 0 ? rw / posSum : 0

        var remaining = rw
        var steps: [AttenStep] = []
        for (i, layer) in layers.enumerated() {
            let w = weights[i]
            var delta: Double
            var leak = false
            if w >= 0 {
                delta = w * scale
                remaining = max(0, remaining - delta)
            } else {
                let amount = min(remaining * 0.4, -w)
                delta = -amount
                remaining = min(rw, remaining + amount)
                leak = true
            }
            steps.append(AttenStep(id: layer.id, layerID: layer.id, name: layer.name,
                                   category: layer.category, deltaDB: delta,
                                   remainingDB: remaining, isLeak: leak))
        }
        return steps
    }

    private static func weakPoints(build: WallBuild, layers: [Layer], M: Double,
                                   hasCavity: Bool, cavityFilled: Bool,
                                   massLeaves: [Layer], dampers: [Layer],
                                   damperConstrained: Bool, bestDecouple: Double) -> [WeakPoint] {
        var wps: [WeakPoint] = []

        // RED — bridges
        if hasCavity, let bridge = massLeaves.first(where: { $0.rigidlyFixed }) {
            wps.append(WeakPoint(severity: .bridge, layerID: bridge.id,
                                 title: "Rigid fixing short-circuits the wall",
                                 fix: "Mount “\(bridge.name)” on resilient channel or isolation clips instead of screwing straight to the frame."))
        }
        if !build.perimeterSealed {
            wps.append(WeakPoint(severity: .bridge,
                                 title: "Unsealed perimeter",
                                 fix: "Run an acoustic sealant bead around the full perimeter and at floor/ceiling junctions before closing up."))
        }
        if build.outletCount > 0 && !build.backBoxed {
            wps.append(WeakPoint(severity: .bridge,
                                 title: "Unsealed outlets / penetrations",
                                 fix: "Add back-boxes or putty pads. Never mount sockets back-to-back across the wall."))
        }

        // AMBER — weak
        if hasCavity && !cavityFilled {
            wps.append(WeakPoint(severity: .weak,
                                 title: "Empty cavity",
                                 fix: "Fill the cavity with mineral wool — typically worth about +5 dB."))
        }
        if massLeaves.count <= 1 {
            wps.append(WeakPoint(severity: .weak,
                                 title: "Single mass leaf",
                                 fix: "Add a second, decoupled leaf — two masses with a damped cavity beat one thick board."))
        }
        if M < 10 {
            wps.append(WeakPoint(severity: .weak,
                                 title: "Assembly is light",
                                 fix: "Add mass. Aim for ≥ 20 kg/m²; doubling mass is roughly +6 dB."))
        }
        if !dampers.isEmpty && !damperConstrained {
            wps.append(WeakPoint(severity: .weak, layerID: dampers.first?.id,
                                 title: "Damping not constrained",
                                 fix: "A damping compound only works sandwiched between a mass board on BOTH faces."))
        }

        if wps.isEmpty {
            wps.append(WeakPoint(severity: .ok,
                                 title: "Well-formed acoustic sandwich",
                                 fix: "Decoupled, cavity filled and perimeter sealed — no obvious bridges. Nicely done."))
        }
        return wps
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
