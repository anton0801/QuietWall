//
//  WeakPointView.swift  (04 — Weak Point Finder)
//  QuietWall
//
//  Surfaces acoustic bridges (rigid fixings, unsealed perimeter, outlets) and
//  weak spots, each with a concrete fix. Quick-fix controls write straight back
//  to the build and the estimate updates live. iOS 14 safe.
//

import SwiftUI

struct WeakPointView: View {
    @EnvironmentObject var store: AppStore
    @State private var highlight: UUID? = nil

    var body: some View {
        Group {
            if let build = store.activeBuild {
                content(build)
            } else {
                ScreenScaffold("Weak Points", subtitle: "Acoustic bridges") { NoBuildCard() }
            }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let status = r.status(build)
        return ScreenScaffold("Weak Points", subtitle: "Where the isolation leaks") {
            CardView(tint: status.color.opacity(0.4)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        StatusPill(severity: status, text: status == .ok ? "No bridges found" : "\(r.bridgeCount) bridges · \(r.weakCount) weak")
                        Text("Bridges short-circuit even a well-built wall. Fix red items first.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
            }

            // Quick fixes (live write-back)
            SectionHeader(title: "Quick fixes", subtitle: "Toggle to see the impact instantly", systemImage: "wrench.adjustable.fill")
            CardView {
                VStack(spacing: 12) {
                    Toggle(isOn: Binding(get: { build.perimeterSealed },
                                         set: { store.setPerimeterSealed($0, for: build.id) })) {
                        toggleLabel("Perimeter sealed", "Acoustic sealant around all edges", Theme.success)
                    }.toggleStyle(SwitchToggleStyle(tint: Theme.success))

                    Divider().background(Theme.stroke)

                    StepperRow(label: "Outlets / penetrations", value: Binding(
                        get: { build.outletCount },
                        set: { store.setOutletCount($0, for: build.id) }), range: 0...12, tint: Theme.warning)

                    if build.outletCount > 0 {
                        Divider().background(Theme.stroke)
                        Toggle(isOn: Binding(get: { build.backBoxed },
                                             set: { store.setBackBoxed($0, for: build.id) })) {
                            toggleLabel("Outlets back-boxed / putty-padded", "Sealed boxes, never mounted back-to-back", Theme.success)
                        }.toggleStyle(SwitchToggleStyle(tint: Theme.success))
                    }
                }
            }

            // The findings
            SectionHeader(title: "Findings", subtitle: "\(r.weakPoints.count) item(s)", systemImage: "magnifyingglass")
            VStack(spacing: 10) {
                ForEach(r.weakPoints) { wp in
                    weakCard(wp, build: build)
                }
            }

            // section with highlight
            if !build.orderedLayers.isEmpty {
                SectionHeader(title: "Section", systemImage: "square.stack.3d.up.fill")
                LayerStackBar(layers: build.orderedLayers, highlightID: highlight, height: 220)
            }
            DisclaimerBanner()
        }
    }

    private func weakCard(_ wp: WeakPoint, build: WallBuild) -> some View {
        CardView(tint: wp.severity.color.opacity(0.45)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: wp.severity.icon).foregroundColor(wp.severity.color)
                    Text(wp.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    TagChip(text: wp.severity.label, color: wp.severity.color, filled: true)
                }
                Text(wp.fix).font(Theme.body(13)).foregroundColor(Theme.textSecondary)
                HStack(spacing: 10) {
                    if let lid = wp.layerID, build.orderedLayers.contains(where: { $0.id == lid }) {
                        Button(action: { withAnimation { highlight = lid } }) {
                            Label("Show layer", systemImage: "scope").font(Theme.caption(12)).foregroundColor(Theme.accent)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    if let lid = wp.layerID, isRigidBridge(wp, build: build) {
                        Button(action: { store.toggleRigidFixing(lid, in: build.id) }) {
                            Label("Mark decoupled", systemImage: "spring").font(Theme.caption(12)).foregroundColor(Theme.success)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    if wp.title.contains("perimeter") {
                        Button(action: { store.setPerimeterSealed(true, for: build.id) }) {
                            Label("Seal now", systemImage: "checkmark.seal.fill").font(Theme.caption(12)).foregroundColor(Theme.success)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    if wp.title.contains("outlets") {
                        Button(action: { store.setBackBoxed(true, for: build.id) }) {
                            Label("Add back-boxes", systemImage: "checkmark.seal.fill").font(Theme.caption(12)).foregroundColor(Theme.success)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func isRigidBridge(_ wp: WeakPoint, build: WallBuild) -> Bool {
        wp.severity == .bridge && wp.title.contains("Rigid")
    }

    private func toggleLabel(_ title: String, _ subtitle: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
            Text(subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }
    }
}
