//
//  MassCalcView.swift  (06 — Mass Calc)
//  QuietWall
//
//  Surface mass (mass law) of the assembly with a per-leaf breakdown and
//  "add mass" coaching. Doubling mass ≈ +6 dB. iOS 14 safe.
//

import SwiftUI

struct MassCalcView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Mass Calc", subtitle: "Law of mass") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let massLeaves = build.orderedLayers.filter { $0.category.contributesMass }
        let M = r.totalSurfaceMass
        let advice = AcousticEngine.massAdvice(M)

        return ScreenScaffold("Mass Calc", subtitle: "Surface mass & the law of mass") {
            CardView(tint: advice.severity.color.opacity(0.4)) {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Formatters.decimal(store.unit.massValue(M), digits: 1))
                            .font(Theme.title(40)).foregroundColor(Theme.textPrimary)
                        Text(store.unit.massSuffix).font(Theme.heading(16)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        StatusPill(severity: advice.severity, text: advice.headline)
                    }
                    HStack {
                        Text("Mass-law base ≈ \(massBase(M)) dB before bonuses")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        Spacer()
                    }
                }
            }

            CardView {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill").foregroundColor(Theme.warning)
                    Text(advice.detail).font(Theme.body(13)).foregroundColor(Theme.textSecondary)
                }
            }

            SectionHeader(title: "Mass per leaf", subtitle: "\(massLeaves.count) mass-bearing layer(s)", systemImage: "scalemass.fill")
            if massLeaves.isEmpty {
                CardView { EmptyStateView(systemImage: "scalemass", title: "No mass yet",
                                          message: "Add a mass board (gypsum, cement board, OSB) to build mass.") }
            } else {
                VStack(spacing: 8) {
                    ForEach(massLeaves) { leaf in
                        HStack {
                            Rectangle().fill(leaf.category.color).frame(width: 5).cornerRadius(2.5)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(leaf.name).font(Theme.heading(13)).foregroundColor(Theme.textPrimary)
                                Text("\(Int(leaf.thicknessMM))mm · \(Formatters.decimal(leaf.density, digits: 0)) kg/m³")
                                    .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Text(store.mass(leaf.surfaceMass)).font(Theme.mono(13)).foregroundColor(Theme.accent)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                    }
                    HStack {
                        Text("Total surface mass").font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(store.mass(M)).font(Theme.heading(15)).foregroundColor(Theme.accent)
                    }.padding(.top, 4)
                }
            }

            // doubling demonstration
            SectionHeader(title: "The 6 dB rule", systemImage: "function")
            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Each doubling of surface mass raises Rw by roughly 6 dB.")
                        .font(Theme.body(13)).foregroundColor(Theme.textSecondary)
                    HStack {
                        doubleStep("Now", M, Theme.accent)
                        Image(systemName: "arrow.right").foregroundColor(Theme.textSecondary)
                        doubleStep("Doubled", M * 2, Theme.success)
                        Image(systemName: "arrow.right").foregroundColor(Theme.textSecondary)
                        doubleStep("×4", M * 4, Theme.highlight)
                    }
                }
            }

            NavRow(icon: "plus.square.on.square", title: "Add a mass board",
                   subtitle: "Open the material library", tint: Theme.accent) { AddLayerView() }
            DisclaimerBanner()
        }
    }

    private func massBase(_ M: Double) -> Int {
        Int((20 * log10(max(1, M)) + 10).rounded())
    }

    private func doubleStep(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(store.mass(value)).font(Theme.heading(13)).foregroundColor(color)
            Text(label).font(Theme.caption(9)).foregroundColor(Theme.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}
