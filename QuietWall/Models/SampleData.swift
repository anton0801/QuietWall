//
//  SampleData.swift
//  QuietWall
//
//  Seeds the editable material library (16 realistic acoustic materials) and a
//  few demo assemblies so every screen has content on first launch. Numbers are
//  tuned against AcousticEngine: a single board ≈ Rw 23, a decoupled wall ≈ 50,
//  a studio wall ≈ 65. iOS 14 safe.
//

import Foundation

enum SampleData {

    // MARK: - Material library

    static func library() -> [Material] {
        [
            // Mass boards
            Material(name: "Gypsum Board 12.5", category: .massBoard, defaultThicknessMM: 12.5, density: 700,
                     costPerM2: 6, suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),
            Material(name: "Acoustic Gypsum 15", category: .massBoard, defaultThicknessMM: 15, density: 850,
                     costPerM2: 11, suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),
            Material(name: "Cement Particle Board 12", category: .massBoard, defaultThicknessMM: 12, density: 1150,
                     costPerM2: 14, suitsWall: true, suitsFloor: true, suitsCeiling: false, isSeed: true),
            Material(name: "Plywood / OSB 18", category: .massBoard, defaultThicknessMM: 18, density: 650,
                     costPerM2: 9, suitsWall: true, suitsFloor: true, suitsCeiling: false, isSeed: true),

            // Absorbers
            Material(name: "Mineral Wool 50", category: .absorber, defaultThicknessMM: 50, density: 40,
                     costPerM2: 7, suitsWall: true, suitsFloor: true, suitsCeiling: true, isSeed: true),
            Material(name: "Mineral Wool 100", category: .absorber, defaultThicknessMM: 100, density: 45,
                     costPerM2: 12, suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),
            Material(name: "Acoustic Foam 30", category: .absorber, defaultThicknessMM: 30, density: 30,
                     costPerM2: 8, suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),

            // Membranes
            Material(name: "Mass-Loaded Vinyl 2mm", category: .membrane, defaultThicknessMM: 2, density: 0,
                     surfaceMassOverride: 5.0, costPerM2: 22, suitsWall: true, suitsFloor: true, suitsCeiling: true, isSeed: true),
            Material(name: "Bitumen Membrane 4mm", category: .membrane, defaultThicknessMM: 4, density: 0,
                     surfaceMassOverride: 4.0, costPerM2: 10, suitsWall: true, suitsFloor: true, suitsCeiling: false, isSeed: true),

            // Damper
            Material(name: "Damping Compound 1mm", category: .damper, defaultThicknessMM: 1, density: 0,
                     costPerM2: 18, suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),

            // Decouplers
            Material(name: "Resilient Channel", category: .decoupler, defaultThicknessMM: 16, density: 0,
                     costPerM2: 5, decouplerKind: .resilientChannel,
                     suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),
            Material(name: "Isolation Clip + Furring", category: .decoupler, defaultThicknessMM: 50, density: 0,
                     costPerM2: 16, decouplerKind: .isolationClip,
                     suitsWall: true, suitsFloor: false, suitsCeiling: true, isSeed: true),
            Material(name: "Independent Stud Frame", category: .decoupler, defaultThicknessMM: 70, density: 0,
                     costPerM2: 13, decouplerKind: .independentFrame,
                     suitsWall: true, suitsFloor: false, suitsCeiling: false, isSeed: true),
            Material(name: "Resilient Floor Underlay 10", category: .decoupler, defaultThicknessMM: 10, density: 0,
                     costPerM2: 9, decouplerKind: .floorUnderlay,
                     suitsWall: false, suitsFloor: true, suitsCeiling: false, isSeed: true),

            // Air gap & sealant
            Material(name: "Air Gap (Cavity) 50", category: .airGap, defaultThicknessMM: 50, density: 0,
                     costPerM2: 0, suitsWall: true, suitsFloor: true, suitsCeiling: true, isSeed: true),
            Material(name: "Acoustic Sealant Bead", category: .sealant, defaultThicknessMM: 0, density: 0,
                     costPerM2: 2, suitsWall: true, suitsFloor: true, suitsCeiling: true, isSeed: true)
        ]
    }

    // MARK: - Helper

    private static func layers(_ mats: [Material]) -> [Layer] {
        mats.enumerated().map { Layer(material: $0.element, order: $0.offset) }
    }

    private static func material(_ lib: [Material], _ name: String) -> Material {
        lib.first { $0.name == name }!
    }

    // MARK: - Demo builds

    static func make() -> AppData {
        let lib = library()
        func m(_ n: String) -> Material { material(lib, n) }

        // A — deliberately weak single leaf
        var weak = WallBuild(name: "Starter Single Leaf", surface: .wall, noiseType: .airborne,
                             goal: .basic, spaceLimitMM: 60,
                             layers: layers([m("Gypsum Board 12.5")]),
                             outletCount: 0, backBoxed: false, perimeterSealed: false)
        if let i = weak.layers.indices.first { weak.layers[i].rigidlyFixed = true }

        // B — good decoupled double-leaf wall (just under target — improvable)
        let good = WallBuild(name: "Decoupled Comfort Wall", surface: .wall, noiseType: .airborne,
                             goal: .good, spaceLimitMM: 120,
                             layers: layers([
                                m("Gypsum Board 12.5"),
                                m("Mineral Wool 50"),
                                m("Resilient Channel"),
                                m("Gypsum Board 12.5")
                             ]),
                             outletCount: 0, backBoxed: true, perimeterSealed: true)

        // C — studio-grade wall (meets target)
        var studio = WallBuild(name: "Studio Isolation Wall", surface: .wall, noiseType: .both,
                               goal: .studio, spaceLimitMM: 200,
                               layers: layers([
                                m("Acoustic Gypsum 15"),
                                m("Damping Compound 1mm"),
                                m("Acoustic Gypsum 15"),
                                m("Isolation Clip + Furring"),
                                m("Mineral Wool 100"),
                                m("Acoustic Gypsum 15")
                               ]),
                               outletCount: 0, backBoxed: true, perimeterSealed: true)
        studio.notes = [
            Note(title: "Clip spacing", body: "Isolation clips at 600mm centres, furring channel friction-fit — do not over-tighten or you reintroduce a bridge.", markerX: 0.6, markerY: 0.5),
            Note(title: "Triple board", body: "Stagger board joints between the two damped leaves; tape & mud all seams.", markerX: 0.3, markerY: 0.7)
        ]

        // D — quiet floor (impact focused)
        let floor = WallBuild(name: "Quiet Floor", surface: .floor, noiseType: .impact,
                              goal: .basic, spaceLimitMM: 90,
                              layers: layers([
                                m("Cement Particle Board 12"),
                                m("Mineral Wool 50"),
                                m("Resilient Floor Underlay 10"),
                                m("Plywood / OSB 18")
                              ]),
                              outletCount: 0, backBoxed: false, perimeterSealed: true)

        var data = AppData()
        data.materials = lib
        data.builds = [weak, good, studio, floor]
        data.activeBuildID = good.id
        data.defaultSurface = .wall
        data.defaultNoiseType = .airborne
        data.defaultSpaceLimitMM = 120
        data.defaultGoal = .good

        // Reminders
        data.reminders = [
            Reminder(kind: .buyMaterials, title: "Buy 2× mineral wool batts",
                     fireDate: Date().addingTimeInterval(60 * 60 * 24), buildID: good.id),
            Reminder(kind: .sealGaps, title: "Seal perimeter on studio wall",
                     fireDate: Date().addingTimeInterval(60 * 60 * 24 * 2), buildID: studio.id)
        ]

        // History snapshots
        data.history = [
            snapshot(studio, action: "Created", ago: 60 * 60 * 24 * 3),
            snapshot(good, action: "Updated", ago: 60 * 60 * 24),
            snapshot(weak, action: "Created", ago: 60 * 60 * 24 * 5)
        ]
        return data
    }

    private static func snapshot(_ b: WallBuild, action: String, ago: TimeInterval) -> HistoryEntry {
        let r = AcousticEngine.evaluate(b)
        return HistoryEntry(buildID: b.id, buildName: b.name, surface: b.surface,
                            rw: r.rw, stc: r.stc, lnw: r.lnw,
                            thicknessMM: r.totalThicknessMM, costPerM2: r.totalCostPerM2,
                            action: action, createdAt: Date().addingTimeInterval(-ago))
    }
}

enum Rasp: Error {
    case flatPanel(at: String)
    case skewPort(at: String)
    case crackle(stage: String)
    case overdrive(cooldown: TimeInterval)
    case deadAir(httpCode: Int)
    case cutOff(reason: String)
    case garbled(at: String)

    var isSealed: Bool {
        switch self {
        case .deadAir, .cutOff:
            return true
        default:
            return false
        }
    }
}

