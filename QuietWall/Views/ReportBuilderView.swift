//
//  ReportBuilderView.swift  (11 — Reports)
//  QuietWall
//
//  Compose a report (composition, estimate, materials, weak points) for the
//  active build and export a real PDF via UIGraphicsPDFRenderer + share sheet.
//  iOS 14 safe (NSAttributedString drawing).
//

import SwiftUI
import UIKit

enum ReportSection: String, CaseIterable, Identifiable {
    case overview, composition, estimate, materials, weakpoints
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .composition: return "Layer Composition"
        case .estimate: return "Sound Estimate"
        case .materials: return "Materials & Cost"
        case .weakpoints: return "Weak Points"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "doc.text.fill"
        case .composition: return "square.stack.3d.up.fill"
        case .estimate: return "waveform"
        case .materials: return "shippingbox.fill"
        case .weakpoints: return "bolt.trianglebadge.exclamationmark.fill"
        }
    }
}

final class ReportBuilderViewModel: ObservableObject {
    @Published var selected: Set<ReportSection> = Set(ReportSection.allCases)
    @Published var generated = false

    func toggle(_ s: ReportSection) {
        if selected.contains(s) { selected.remove(s) } else { selected.insert(s) }
        generated = false
    }

    func content(_ store: AppStore, _ build: WallBuild) -> [(ReportSection, [String])] {
        let r = store.result(for: build)
        return ReportSection.allCases.filter { selected.contains($0) }.map { ($0, lines(for: $0, store: store, build: build, r: r)) }
    }

    private func lines(for s: ReportSection, store: AppStore, build: WallBuild, r: AcousticResult) -> [String] {
        switch s {
        case .overview:
            return [
                "Build: \(build.name)",
                "Surface: \(build.surface.displayName) · Noise: \(build.noiseType.displayName)",
                "Goal: \(build.goal.displayName) (target \(Int(build.targetIndex)) \(r.primaryIsImpact ? "IIC" : "Rw"))",
                "Result: Rw \(Int(r.rw)) / STC \(Int(r.stc))" + (r.impactRelevant ? " · IIC \(Int(r.iic)) / Ln,w \(Int(r.lnw))" : ""),
                "Thickness: \(store.thickness(r.totalThicknessMM)) (limit \(store.thickness(build.spaceLimitMM)))",
                "Cost: \(store.money(r.totalCostPerM2)) / m²",
                "Status: " + (r.bridgeCount > 0 ? "\(r.bridgeCount) acoustic bridge(s)" : (r.meetsTarget(build) ? "Target met" : "\(Int(build.targetIndex - r.primaryIndex)) below target"))
            ]
        case .composition:
            return build.orderedLayers.map { l in
                "\(l.name) — \(Int(l.thicknessMM))mm · \(l.category.displayName)" +
                (l.category.contributesMass ? " · \(Formatters.decimal(l.surfaceMass, digits: 1)) kg/m²" : "") +
                (l.rigidlyFixed ? " · RIGID" : "")
            }
        case .estimate:
            return r.breakdown.map { ($0.valueDB >= 0 ? "+" : "") + Formatters.decimal($0.valueDB, digits: 1) + " dB — \($0.label)" }
                + ["= Estimated Rw \(Int(r.rw)) dB"]
        case .materials:
            return build.orderedLayers.map { "\($0.name): \(store.money($0.costPerM2)) / m²" }
                + ["Total: \(store.money(r.totalCostPerM2)) / m²"]
        case .weakpoints:
            return r.weakPoints.map { "[\($0.severity.label)] \($0.title) — \($0.fix)" }
        }
    }

    func makePDF(_ store: AppStore, _ build: WallBuild) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuietWall-Report.pdf")

        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor(hex: 0x1E1B33)]
        let sectionAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: UIColor(hex: 0x7C3AED)]
        let bodyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11.5), .foregroundColor: UIColor(hex: 0x222222)]
        let metaAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(hex: 0x888888)]

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()
                func ensure(_ h: CGFloat) { if y + h > pageH - margin { ctx.beginPage(); y = margin } }
                func draw(_ text: String, _ attr: [NSAttributedString.Key: Any], _ height: CGFloat) {
                    let rect = CGRect(x: margin, y: y, width: pageW - margin * 2, height: height)
                    let bounding = (text as NSString).boundingRect(with: CGSize(width: pageW - margin * 2, height: .greatestFiniteMagnitude),
                                                                   options: [.usesLineFragmentOrigin], attributes: attr, context: nil)
                    let h = max(height, ceil(bounding.height) + 4)
                    ensure(h)
                    (text as NSString).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: h), withAttributes: attr)
                    y += h
                }

                draw("Quiet Wall — Assembly Report", titleAttr, 32)
                draw("Generated \(Formatters.date(Date())) · \(build.name)", metaAttr, 16)
                y += 6
                ctx.cgContext.setStrokeColor(UIColor(hex: 0xCCCCCC).cgColor)
                ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageW - margin, y: y)); ctx.cgContext.strokePath()
                y += 12

                for (section, lines) in content(store, build) {
                    draw(section.title, sectionAttr, 22)
                    if lines.isEmpty { draw("•  (none)", bodyAttr, 16) }
                    for line in lines { draw("•  " + line, bodyAttr, 16) }
                    y += 10
                }
                draw("Estimative guidance only — not a laboratory measurement. Created with Quiet Wall.", metaAttr, 16)
            }
            return url
        } catch { return nil }
    }
}

struct ReportBuilderView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var vm = ReportBuilderViewModel()
    @State private var shareURL: ShareURL?
    @State private var exportFailed = false
    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Reports", subtitle: "Export PDF") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        ScreenScaffold("Reports", subtitle: "Document “\(build.name)”") {
            HStack(spacing: 12) {
                ActionButton(title: "Generate", systemImage: "doc.badge.gearshape") { withAnimation { vm.generated = true } }
                ActionButton(title: "Export PDF", systemImage: "square.and.arrow.up", kind: .secondary) { exportPDF(build) }
            }

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Include sections", systemImage: "checklist")
                    ForEach(ReportSection.allCases) { section in
                        Toggle(isOn: Binding(get: { vm.selected.contains(section) },
                                             set: { _ in vm.toggle(section) })) {
                            Label(section.title, systemImage: section.icon).font(Theme.body()).foregroundColor(Theme.textPrimary)
                        }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    }
                }
            }

            if vm.generated { preview(build) }
            DisclaimerBanner()
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .alert(isPresented: $exportFailed) {
            Alert(title: Text("Export failed"), message: Text("Couldn't build the PDF. Try again."), dismissButton: .default(Text("OK")))
        }
    }

    private func preview(_ build: WallBuild) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Preview", subtitle: "Tap Export PDF to share", systemImage: "doc.text.magnifyingglass")
            ForEach(vm.content(store, build), id: \.0) { section, lines in
                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Image(systemName: section.icon).foregroundColor(Theme.accent)
                            Text(section.title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary) }
                        if lines.isEmpty {
                            Text("• (none)").font(Theme.caption()).foregroundColor(Theme.textSecondary)
                        } else {
                            ForEach(lines, id: \.self) { line in
                                Text("• " + line).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func exportPDF(_ build: WallBuild) {
        if let url = vm.makePDF(store, build) {
            shareURL = ShareURL(url: url)
            store.appendHistory(for: build, action: "Exported")
        } else { exportFailed = true }
    }
}
