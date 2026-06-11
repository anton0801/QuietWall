//
//  AppStore.swift
//  QuietWall
//
//  The single source of truth (@EnvironmentObject). Holds AppData, exposes
//  uniform CRUD for materials / builds / layers / reminders / history and routes
//  every assembly through AcousticEngine so the numbers stay identical
//  everywhere. iOS 14 safe.
//

import SwiftUI

final class AppStore: ObservableObject {
    @Published private(set) var data: AppData

    private let persistence = PersistenceManager.shared
    private let photos = PhotoStore.shared
    private let notifications = NotificationManager.shared

    init() {
        self.data = persistence.load()
    }

    // MARK: - Generic CRUD helpers

    private func upsert<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        if let i = data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            data[keyPath: keyPath][i] = item
        } else {
            data[keyPath: keyPath].append(item)
        }
        save()
    }

    private func remove<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>) where T.ID == UUID {
        data[keyPath: keyPath].removeAll { $0.id == item.id }
        save()
    }

    // MARK: - Settings accessors (live in UserDefaults via @AppStorage)

    var currency: CurrencyCode {
        CurrencyCode(rawValue: UserDefaults.standard.string(forKey: "currencyCode") ?? "usd") ?? .usd
    }
    var unit: MeasureUnit {
        MeasureUnit(rawValue: UserDefaults.standard.string(forKey: "measureUnit") ?? "metric") ?? .metric
    }
    func money(_ value: Double) -> String {
        Formatters.currency(value, code: currency.code, symbol: currency.symbol)
    }
    func thickness(_ mm: Double) -> String { unit.thicknessString(mm) }
    func mass(_ kgm2: Double) -> String { unit.massString(kgm2) }

    // MARK: - Collections

    var materials: [Material] { data.materials }
    var builds: [WallBuild] { data.builds.sorted { $0.updatedAt > $1.updatedAt } }
    var reminders: [Reminder] { data.reminders.sorted { $0.fireDate < $1.fireDate } }
    var history: [HistoryEntry] { data.history.sorted { $0.createdAt > $1.createdAt } }

    func materials(for surface: SurfaceType) -> [Material] {
        data.materials.filter { $0.suits(surface) }
    }
    func material(_ id: UUID) -> Material? { data.materials.first { $0.id == id } }

    // MARK: - Active build

    var activeBuild: WallBuild? {
        if let id = data.activeBuildID, let b = data.builds.first(where: { $0.id == id }) { return b }
        return data.builds.first
    }
    var activeResult: AcousticResult? { activeBuild.map { AcousticEngine.evaluate($0) } }
    var activeBridgeCount: Int { activeResult?.bridgeCount ?? 0 }

    func build(_ id: UUID?) -> WallBuild? {
        guard let id = id else { return nil }
        return data.builds.first { $0.id == id }
    }
    func setActiveBuild(_ id: UUID) { data.activeBuildID = id; save() }
    func result(for build: WallBuild) -> AcousticResult { AcousticEngine.evaluate(build) }

    // MARK: - Build mutation

    private func mutateBuild(_ id: UUID, _ change: (inout WallBuild) -> Void) {
        guard let i = data.builds.firstIndex(where: { $0.id == id }) else { return }
        change(&data.builds[i])
        data.builds[i].updatedAt = Date()
        save()
    }

    private func reindex(_ build: inout WallBuild) {
        let ordered = build.orderedLayers
        var copy = ordered
        for i in copy.indices { copy[i].order = i }
        build.layers = copy
    }

    func saveBuild(_ b: WallBuild) {
        if let i = data.builds.firstIndex(where: { $0.id == b.id }) {
            var c = b; c.updatedAt = Date(); data.builds[i] = c
        } else {
            data.builds.append(b)
            data.activeBuildID = b.id
        }
        save()
    }

    func renameBuild(_ id: UUID, to name: String) {
        mutateBuild(id) { $0.name = name.isEmpty ? "Untitled build" : name }
    }

    func deleteBuild(_ id: UUID) {
        if let b = build(id) { b.notes.forEach { photos.delete(named: $0.imageFileName) } }
        data.builds.removeAll { $0.id == id }
        data.history.removeAll { $0.buildID == id }
        if data.activeBuildID == id { data.activeBuildID = data.builds.first?.id }
        save()
    }

    @discardableResult
    func duplicateBuild(_ id: UUID) -> WallBuild? {
        guard let src = build(id) else { return nil }
        var copy = src
        copy.id = UUID()
        copy.name = src.name + " Copy"
        copy.createdAt = Date(); copy.updatedAt = Date()
        copy.layers = src.orderedLayers.enumerated().map { i, l in var n = l; n.id = UUID(); n.order = i; return n }
        copy.notes = src.notes.map { var n = $0; n.id = UUID(); return n }
        data.builds.append(copy)
        data.activeBuildID = copy.id
        appendHistory(for: copy, action: "Duplicated")
        save()
        return copy
    }

    @discardableResult
    func newBuild(name: String = "New Build") -> WallBuild {
        var b = WallBuild(name: name, surface: data.defaultSurface, noiseType: data.defaultNoiseType,
                          goal: data.defaultGoal, spaceLimitMM: data.defaultSpaceLimitMM)
        if let starter = data.materials.first(where: { $0.category == .massBoard && $0.suits(b.surface) }) {
            b.layers = [Layer(material: starter, order: 0)]
        }
        data.builds.append(b)
        data.activeBuildID = b.id
        appendHistory(for: b, action: "Created")
        save()
        return b
    }

    // Build attribute setters
    func setSurface(_ s: SurfaceType, for id: UUID) { mutateBuild(id) { $0.surface = s } }
    func setNoiseType(_ n: NoiseType, for id: UUID) { mutateBuild(id) { $0.noiseType = n } }
    func setGoal(_ g: Goal, for id: UUID) { mutateBuild(id) { $0.goal = g } }
    func setSpaceLimit(_ mm: Double, for id: UUID) { mutateBuild(id) { $0.spaceLimitMM = mm } }
    func setOutletCount(_ n: Int, for id: UUID) { mutateBuild(id) { $0.outletCount = max(0, n) } }
    func setBackBoxed(_ on: Bool, for id: UUID) { mutateBuild(id) { $0.backBoxed = on } }
    func setPerimeterSealed(_ on: Bool, for id: UUID) { mutateBuild(id) { $0.perimeterSealed = on } }

    // MARK: - Layer mutation

    func addLayer(_ material: Material, to id: UUID) {
        mutateBuild(id) { b in
            let next = (b.layers.map { $0.order }.max() ?? -1) + 1
            b.layers.append(Layer(material: material, order: next))
        }
    }
    func insertLayer(_ layer: Layer, to id: UUID) {
        mutateBuild(id) { b in
            let next = (b.layers.map { $0.order }.max() ?? -1) + 1
            var l = layer; l.order = next
            b.layers.append(l)
        }
    }
    func removeLayer(_ layerID: UUID, from id: UUID) {
        mutateBuild(id) { b in b.layers.removeAll { $0.id == layerID }; reindex(&b) }
    }
    func updateLayer(_ layer: Layer, in id: UUID) {
        mutateBuild(id) { b in if let i = b.layers.firstIndex(where: { $0.id == layer.id }) { b.layers[i] = layer } }
    }
    func moveLayer(_ layerID: UUID, up: Bool, in id: UUID) {
        mutateBuild(id) { b in
            var ls = b.orderedLayers
            guard let idx = ls.firstIndex(where: { $0.id == layerID }) else { return }
            let target = up ? idx - 1 : idx + 1
            guard target >= 0 && target < ls.count else { return }
            ls.swapAt(idx, target)
            for i in ls.indices { ls[i].order = i }
            b.layers = ls
        }
    }
    func toggleRigidFixing(_ layerID: UUID, in id: UUID) {
        mutateBuild(id) { b in if let i = b.layers.firstIndex(where: { $0.id == layerID }) { b.layers[i].rigidlyFixed.toggle() } }
    }
    func toggleCavityFilled(_ layerID: UUID, in id: UUID) {
        mutateBuild(id) { b in if let i = b.layers.firstIndex(where: { $0.id == layerID }) { b.layers[i].cavityFilled.toggle() } }
    }

    // MARK: - Notes (per build)

    func addNote(_ note: Note, to id: UUID) { mutateBuild(id) { $0.notes.append(note) } }
    func updateNote(_ note: Note, in id: UUID) {
        mutateBuild(id) { b in if let i = b.notes.firstIndex(where: { $0.id == note.id }) { b.notes[i] = note } }
    }
    func deleteNote(_ note: Note, from id: UUID) {
        photos.delete(named: note.imageFileName)
        mutateBuild(id) { $0.notes.removeAll { $0.id == note.id } }
    }

    // MARK: - Materials (library)

    func saveMaterial(_ m: Material) { upsert(m, \.materials) }
    func deleteMaterial(_ m: Material) { remove(m, \.materials) }
    func resetLibrary() { data.materials = SampleData.library(); save() }

    // MARK: - Reminders

    func saveReminder(_ r: Reminder) {
        upsert(r, \.reminders)
        notifications.schedule(r)
    }
    func deleteReminder(_ r: Reminder) {
        notifications.cancel(r)
        remove(r, \.reminders)
    }
    func toggleReminder(_ r: Reminder) {
        var c = r; c.isEnabled.toggle(); saveReminder(c)
    }

    // MARK: - History

    func appendHistory(for b: WallBuild, action: String) {
        let r = AcousticEngine.evaluate(b)
        let entry = HistoryEntry(buildID: b.id, buildName: b.name, surface: b.surface,
                                 rw: r.rw, stc: r.stc, lnw: r.lnw,
                                 thicknessMM: r.totalThicknessMM, costPerM2: r.totalCostPerM2,
                                 action: action)
        data.history.insert(entry, at: 0)
        if data.history.count > 120 { data.history = Array(data.history.prefix(120)) }
        save()
    }
    func clearHistory() { data.history.removeAll(); save() }

    // MARK: - Onboarding

    func applyOnboarding(surface: SurfaceType, noise: NoiseType, limit: Double, goal: Goal) {
        data.defaultSurface = surface
        data.defaultNoiseType = noise
        data.defaultSpaceLimitMM = limit
        data.defaultGoal = goal
        // Create a fresh starter build tailored to the choices and open it.
        newBuild(name: "My \(surface.displayName)")
    }

    // MARK: - Lifecycle

    private func save() { persistence.save(data) }
    func flush() { persistence.flush(data) }
    func exportBackupURL() -> URL? { persistence.exportURL(data) }

    func resetToSampleData() {
        photos.clearAll()
        data = SampleData.make()
        persistence.saveNow(data)
        notifications.sync(data.reminders)
        objectWillChange.send()
    }

    func wipeAll() {
        photos.clearAll()
        var fresh = AppData()
        fresh.materials = SampleData.library()   // library is required to build anything
        data = fresh
        persistence.saveNow(data)
        objectWillChange.send()
    }
}
