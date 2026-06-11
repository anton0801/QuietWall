//
//  SoundEstimateView.swift  (03 — Sound Estimate, primary)
//  QuietWall
//
//  The estimated index vs the goal, the animated layer-by-layer wave
//  attenuation, and a transparent "why this number" breakdown. iOS 14 safe.
//

import SwiftUI

struct SoundEstimateView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let build = store.activeBuild {
                content(build)
            } else {
                ScreenScaffold("Sound Estimate", subtitle: "Estimated insulation") { NoBuildCard() }
            }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let status = r.status(build)
        let showBoth = build.surface.supportsImpact && build.noiseType == .both

        return ScreenScaffold("Sound Estimate", subtitle: "“\(build.name)” vs \(build.goal.displayName) target") {
            BuildSwitcherBar()

            // gauges
            CardView(tint: status.color.opacity(0.4)) {
                VStack(spacing: 14) {
                    if showBoth {
                        HStack(spacing: 10) {
                            IndexGauge(value: r.rw, target: build.goal.targetRw, label: "Rw",
                                       secondary: "STC \(Int(r.stc))", tint: gaugeTint(r.rw, build.goal.targetRw), size: 132, lineWidth: 12)
                            IndexGauge(value: r.iic, target: build.goal.targetIIC, label: "IIC",
                                       secondary: "Ln,w \(Int(r.lnw))", tint: gaugeTint(r.iic, build.goal.targetIIC), size: 132, lineWidth: 12)
                        }
                    } else {
                        IndexGauge(value: r.primaryIndex, target: build.targetIndex,
                                   label: r.primaryIsImpact ? "IIC" : "Rw",
                                   secondary: r.primaryIsImpact ? "Ln,w \(Int(r.lnw))" : "STC \(Int(r.stc))",
                                   tint: status.color, size: 176, lineWidth: 17)
                    }
                    StatusPill(severity: status, text: headline(r, build))
                    targetBar(r, build)
                }
            }

            // wave cross-section
            SectionHeader(title: "Attenuation through the wall", subtitle: "How the wave loses energy, layer by layer", systemImage: "waveform.path.ecg")
            CardView {
                if build.orderedLayers.isEmpty {
                    EmptyStateView(systemImage: "waveform.slash", title: "Nothing to show",
                                   message: "Add layers in the Build tab to see attenuation.")
                } else {
                    WaveCrossSectionView(layers: build.orderedLayers, result: r, height: 156)
                }
            }

            // breakdown
            SectionHeader(title: "Why this number", subtitle: "Estimated dB contributions", systemImage: "list.number")
            CardView {
                VStack(spacing: 0) {
                    ForEach(Array(r.breakdown.enumerated()), id: \.offset) { i, line in
                        HStack {
                            Text(line.label).font(Theme.body(13)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(signed(line.valueDB))
                                .font(Theme.mono(13))
                                .foregroundColor(i == 0 ? Theme.textSecondary : (line.valueDB >= 0 ? Theme.success : Theme.danger))
                        }
                        .padding(.vertical, 7)
                        if i < r.breakdown.count - 1 { Divider().background(Theme.stroke.opacity(0.6)) }
                    }
                    Divider().background(Theme.stroke)
                    HStack {
                        Text("Estimated Rw").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("\(Int(r.rw)) dB").font(Theme.heading(16)).foregroundColor(Theme.accent)
                    }.padding(.top, 8)
                }
            }

            VStack(spacing: 12) {
                NavRow(icon: "bolt.trianglebadge.exclamationmark.fill", title: "Weak Point Finder",
                       subtitle: "\(r.bridgeCount) bridges · \(r.weakCount) weak spots", tint: Theme.danger,
                       badge: r.bridgeCount) { WeakPointView() }
                NavRow(icon: "spring", title: "Decoupling Advisor",
                       subtitle: "Break the rigid path to the frame", tint: Theme.highlight) { DecouplingAdvisorView() }
            }
            DisclaimerBanner()
        }
    }

    private func gaugeTint(_ value: Double, _ target: Double) -> Color {
        value >= target ? Theme.success : (value >= target - 6 ? Theme.accent : Theme.warning)
    }

    private func headline(_ r: AcousticResult, _ build: WallBuild) -> String {
        if r.bridgeCount > 0 { return "Fix \(r.bridgeCount) bridge\(r.bridgeCount > 1 ? "s" : "")" }
        if r.meetsTarget(build) { return "Target met" }
        return "\(Int(build.targetIndex - r.primaryIndex)) below target"
    }

    private func signed(_ v: Double) -> String {
        (v >= 0 ? "+" : "") + Formatters.decimal(v, digits: 1) + " dB"
    }

    private func targetBar(_ r: AcousticResult, _ build: WallBuild) -> some View {
        let maxS = 75.0
        let valFrac = min(max(r.primaryIndex / maxS, 0), 1)
        let tgtFrac = min(max(build.targetIndex / maxS, 0), 1)
        return VStack(spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceAlt).frame(height: 12)
                    Capsule().fill(Theme.accentGradient).frame(width: g.size.width * CGFloat(valFrac), height: 12)
                    Rectangle().fill(Theme.textPrimary).frame(width: 2, height: 20)
                        .offset(x: g.size.width * CGFloat(tgtFrac) - 1)
                }
            }.frame(height: 20)
            HStack {
                Text("Now \(Int(r.primaryIndex))").font(Theme.caption(10)).foregroundColor(Theme.accent)
                Spacer()
                Text("Target \(Int(build.targetIndex))").font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
        }
    }
}
