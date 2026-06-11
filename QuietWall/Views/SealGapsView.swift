//
//  SealGapsView.swift  (07 — Seal & Gaps)
//  QuietWall
//
//  Air-tightness controls: perimeter sealing, outlets and penetrations. Small
//  gaps wreck isolation — toggles write back live and the potential gain from
//  full sealing is shown. iOS 14 safe.
//

import SwiftUI

struct SealGapsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Seal & Gaps", subtitle: "Air-tightness") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        var sealed = build
        sealed.perimeterSealed = true
        sealed.backBoxed = true
        let sealedRw = store.result(for: sealed).rw
        let potential = sealedRw - r.rw

        return ScreenScaffold("Seal & Gaps", subtitle: "A 1% gap can cost you 5 dB") {
            CardView(tint: (potential > 0 ? Theme.warning : Theme.success).opacity(0.4)) {
                HStack(spacing: 12) {
                    Image(systemName: potential > 0 ? "wind" : "checkmark.seal.fill")
                        .font(.system(size: 26)).foregroundColor(potential > 0 ? Theme.warning : Theme.success)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(potential > 0 ? "Sealing could add ~\(Int(potential)) dB" : "Fully sealed — nice")
                            .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Text("Air-tightness sets the ceiling on everything else you build.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
            }

            SectionHeader(title: "Perimeter", systemImage: "rectangle.dashed")
            CardView {
                Toggle(isOn: Binding(get: { build.perimeterSealed },
                                     set: { store.setPerimeterSealed($0, for: build.id) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Perimeter sealed").font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        Text("Continuous acoustic sealant bead at floor, ceiling and wall junctions.")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }.toggleStyle(SwitchToggleStyle(tint: Theme.success))
            }

            SectionHeader(title: "Penetrations", systemImage: "powerplug.fill")
            CardView {
                VStack(spacing: 12) {
                    StepperRow(label: "Outlets & penetrations", value: Binding(
                        get: { build.outletCount },
                        set: { store.setOutletCount($0, for: build.id) }), range: 0...12, tint: Theme.warning)
                    if build.outletCount > 0 {
                        Divider().background(Theme.stroke)
                        Toggle(isOn: Binding(get: { build.backBoxed },
                                             set: { store.setBackBoxed($0, for: build.id) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Back-boxed & putty-padded").font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                Text("Sealed boxes; never mount sockets back-to-back across the wall.")
                                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            }
                        }.toggleStyle(SwitchToggleStyle(tint: Theme.success))
                    }
                }
            }

            SectionHeader(title: "Where sound sneaks through", systemImage: "magnifyingglass")
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    tip("scribble.variable", "Perimeter junctions", "Seal every edge before boarding over — you can't fix it later.")
                    tip("powerplug.fill", "Electrical boxes", "Offset and seal; back-to-back outlets are a direct sound path.")
                    tip("pipe.and.drop.fill", "Service penetrations", "Pack and seal around pipes, ducts and conduits.")
                    tip("door.left.hand.open", "Doors & thresholds", "A door is only as good as its seals and threshold drop.")
                }
            }
            DisclaimerBanner()
        }
    }

    private func tip(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.warning).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.heading(13)).foregroundColor(Theme.textPrimary)
                Text(text).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
        }
    }
}
