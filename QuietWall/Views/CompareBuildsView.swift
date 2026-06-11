//
//  CompareBuildsView.swift  (08 — Compare Builds)
//  QuietWall
//
//  Select 2–3 assemblies and compare index, thickness and cost side by side.
//  Manage builds (set active, duplicate, new) and jump to the cost spec.
//  iOS 14 safe.
//

import SwiftUI

struct CompareBuildsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selected: Set<UUID> = []

    var body: some View {
        ScreenScaffold("Compare Builds", subtitle: "Index vs thickness vs price") {
            if store.builds.isEmpty {
                NoBuildCard()
            } else {
                pickRow
                let chosen = orderedChosen()
                if chosen.count < 2 {
                    CardView {
                        EmptyStateView(systemImage: "rectangle.split.3x1",
                                       title: "Pick at least two",
                                       message: "Select 2–3 builds above to compare them.")
                    }
                } else {
                    comparisonTable(chosen)
                }

                SectionHeader(title: "Manage", systemImage: "slider.horizontal.3")
                VStack(spacing: 12) {
                    ActionButton(title: "New Build", systemImage: "plus") { let b = store.newBuild(); selected.insert(b.id) }
                    NavRow(icon: "list.bullet.rectangle.portrait.fill", title: "Cost & Materials",
                           subtitle: "Spec & price of the active build", tint: Theme.success) { CostMaterialsView() }
                }
            }
            DisclaimerBanner()
        }
        .onAppear { if selected.isEmpty { selected = Set(store.builds.prefix(2).map { $0.id }) } }
    }

    private func orderedChosen() -> [WallBuild] {
        store.builds.filter { selected.contains($0.id) }.prefix(3).map { $0 }
    }

    private var pickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.builds) { b in
                    let on = selected.contains(b.id)
                    Button(action: { toggle(b.id) }) {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            Text(b.name).lineLimit(1)
                        }
                        .font(Theme.caption(12))
                        .foregroundColor(on ? Theme.textOnAccent : Theme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Group {
                            if on { Capsule().fill(Theme.accentGradient) } else { Capsule().fill(Theme.surface) }
                        })
                        .overlay(Capsule().stroke(on ? Color.clear : Theme.stroke, lineWidth: 1))
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) }
        else { if selected.count >= 3 { selected.remove(selected.first!) }; selected.insert(id) }
    }

    private func comparisonTable(_ builds: [WallBuild]) -> some View {
        let results = builds.map { ($0, store.result(for: $0)) }
        let bestRw = results.map { $0.1.rw }.max() ?? 0
        let minThick = results.map { $0.1.totalThicknessMM }.min() ?? 0
        let minCost = results.map { $0.1.totalCostPerM2 }.min() ?? 0

        return CardView {
            VStack(spacing: 10) {
                // header
                HStack(spacing: 6) {
                    Text("").frame(width: 84, alignment: .leading)
                    ForEach(results, id: \.0.id) { build, _ in
                        VStack(spacing: 3) {
                            Image(systemName: build.surface.icon).foregroundColor(Theme.accent).font(.system(size: 13))
                            Text(build.name).font(Theme.caption(11)).foregroundColor(Theme.textPrimary)
                                .lineLimit(2).multilineTextAlignment(.center)
                            if store.activeBuild?.id == build.id {
                                TagChip(text: "Active", color: Theme.accent, filled: true)
                            } else {
                                Button("Set active") { store.setActiveBuild(build.id) }
                                    .font(Theme.caption(9)).foregroundColor(Theme.accent)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }
                Divider().background(Theme.stroke)

                metricRow("Rw / STC", results, value: { "\(Int($0.rw)) / \(Int($0.stc))" }, highlight: { $0.rw == bestRw }, color: Theme.success)
                metricRow("Impact IIC", results, value: { $0.impactRelevant ? "\(Int($0.iic))" : "—" })
                metricRow("Thickness", results, value: { store.thickness($0.totalThicknessMM) }, highlight: { $0.totalThicknessMM == minThick }, color: Theme.info)
                metricRow("Cost / m²", results, value: { store.money($0.totalCostPerM2) }, highlight: { $0.totalCostPerM2 == minCost }, color: Theme.success)
                metricRow("Layers", results, value: { "\($0.attenuationProfile.count)" })
                statusRow(results, builds: builds)
            }
        }
    }

    private func metricRow(_ label: String, _ results: [(WallBuild, AcousticResult)],
                           value: @escaping (AcousticResult) -> String,
                           highlight: ((AcousticResult) -> Bool)? = nil,
                           color: Color = Theme.accent) -> some View {
        HStack(spacing: 6) {
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary).frame(width: 84, alignment: .leading)
            ForEach(results, id: \.0.id) { _, r in
                let isBest = highlight?(r) ?? false
                Text(value(r))
                    .font(Theme.heading(13))
                    .foregroundColor(isBest ? color : Theme.textPrimary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusRow(_ results: [(WallBuild, AcousticResult)], builds: [WallBuild]) -> some View {
        HStack(spacing: 6) {
            Text("Status").font(Theme.caption(11)).foregroundColor(Theme.textSecondary).frame(width: 84, alignment: .leading)
            ForEach(Array(results.enumerated()), id: \.offset) { idx, pair in
                let st = pair.1.status(pair.0)
                Image(systemName: st.icon).foregroundColor(st.color).frame(maxWidth: .infinity)
            }
        }.padding(.vertical, 4)
    }
}
