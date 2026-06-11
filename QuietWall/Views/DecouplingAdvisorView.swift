//
//  DecouplingAdvisorView.swift  (05 — Decoupling Advisor)
//  QuietWall
//
//  Recommends decouplers (resilient channel, isolation clips, independent frame,
//  underlay) to break the rigid path through the frame, with the projected Rw
//  gain for each, addable in one tap. iOS 14 safe.
//

import SwiftUI

struct DecouplingAdvisorView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Decoupling", subtitle: "Break the bridge") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let decouplers = build.orderedLayers.filter { $0.category == .decoupler }
        let isDecoupled = !decouplers.isEmpty
        let options = store.materials(for: build.surface).filter { $0.category == .decoupler }

        return ScreenScaffold("Decoupling Advisor", subtitle: "Vibration breaks for “\(build.name)”") {
            CardView(tint: (isDecoupled ? Theme.success : Theme.warning).opacity(0.4)) {
                HStack(spacing: 12) {
                    Image(systemName: isDecoupled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 26)).foregroundColor(isDecoupled ? Theme.success : Theme.warning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isDecoupled ? "This assembly is decoupled" : "Rigidly coupled to the frame")
                            .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Text(isDecoupled
                             ? "Using \(decouplers.map { $0.decouplerKind?.displayName ?? "" }.joined(separator: ", "))."
                             : "Sound travels straight through the studs. Add a decoupler below.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
            }

            SectionHeader(title: "How decoupling works", systemImage: "spring")
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    bullet("Mount the leaf on resilient channel, isolation clips + furring, or an independent frame so vibration can't pass directly.")
                    bullet("Combine decoupling with a filled cavity — they multiply, not just add.")
                    bullet("One rigid screw can erase the entire benefit. Keep fixings off the structure.")
                    bullet("On floors, a resilient underlay or floating screed tackles impact (Ln,w).")
                }
            }

            SectionHeader(title: "Add a decoupler", subtitle: "Projected Rw shown for your current build", systemImage: "plus.circle.fill")
            if options.isEmpty {
                CardView { EmptyStateView(systemImage: "spring", title: "No decouplers for this surface",
                                          message: "Add one in Settings → Material Library.") }
            } else {
                VStack(spacing: 10) {
                    ForEach(options) { material in
                        optionCard(material, build: build, baseRw: r.rw)
                    }
                }
            }
            DisclaimerBanner()
        }
    }

    private func optionCard(_ material: Material, build: WallBuild, baseRw: Double) -> some View {
        let projected = AcousticEngine.projectedRw(build, adding: material)
        let delta = projected - baseRw
        return CardView {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.highlight.opacity(0.18)).frame(width: 44, height: 44)
                    Image(systemName: material.decouplerKind?.icon ?? "spring").foregroundColor(Theme.highlight)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(material.name).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    Text("Airborne +\(Int(material.decouplerKind?.airborneBonusDB ?? 0)) dB · Impact −\(Int(material.decouplerKind?.impactReductionDB ?? 0)) dB")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    TagChip(text: delta > 0 ? "+\(Int(delta)) dB on this build" : "no change here",
                            color: delta > 0 ? Theme.success : Theme.textSecondary)
                }
                Spacer()
                Button(action: { store.addLayer(material, to: build.id) }) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 40, height: 40).background(Circle().fill(Theme.highlight))
                }.buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(Theme.highlight).padding(.top, 6)
            Text(text).font(Theme.body(13)).foregroundColor(Theme.textSecondary)
        }
    }
}
