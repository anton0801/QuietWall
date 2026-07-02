//
//  CostMaterialsView.swift  (09 — Cost & Materials)
//  QuietWall
//
//  Bill of materials for the assembly: per-layer and per-category cost, the
//  cost per m², and the total for an area you enter. iOS 14 safe.
//

import SwiftUI

struct CostMaterialsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("lastArea") private var area: Double = 10

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Cost & Materials", subtitle: "Bill of materials") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let layers = build.orderedLayers
        let perM2 = r.totalCostPerM2
        let total = perM2 * max(0, area)

        return ScreenScaffold("Cost & Materials", subtitle: "Spec for “\(build.name)”") {
            CardView {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cost / m²").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            Text(store.money(perM2)).font(Theme.title(26)).foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Total for \(Formatters.decimal(area, digits: 1)) m²").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            Text(store.money(total)).font(Theme.title(26)).foregroundColor(Theme.accent)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("AREA").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Formatters.decimal(area, digits: 1)) m²").font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        }
                        Slider(value: $area, in: 1...100, step: 0.5).accentColor(Theme.accent)
                    }
                }
            }

            SectionHeader(title: "Specification", subtitle: "\(layers.count) layers", systemImage: "list.bullet.rectangle.portrait.fill")
            if layers.isEmpty {
                CardView { EmptyStateView(systemImage: "shippingbox", title: "No materials",
                                          message: "Add layers to build the spec.") }
            } else {
                VStack(spacing: 8) {
                    ForEach(layers) { layer in
                        HStack {
                            Image(systemName: layer.category.icon).foregroundColor(layer.category.color).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(layer.name).font(Theme.heading(13)).foregroundColor(Theme.textPrimary)
                                Text("\(Int(layer.thicknessMM))mm · \(layer.category.displayName)")
                                    .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(store.money(layer.costPerM2)).font(Theme.heading(13)).foregroundColor(Theme.textPrimary)
                                Text("\(store.money(layer.costPerM2 * area)) total").font(Theme.caption(9)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                    }
                }
            }

            SectionHeader(title: "By category", systemImage: "chart.pie.fill")
            CardView {
                VStack(spacing: 8) {
                    ForEach(categorySubtotals(layers), id: \.0) { cat, sum in
                        HStack {
                            Circle().fill(cat.color).frame(width: 10, height: 10)
                            Text(cat.displayName).font(Theme.body(13)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(store.money(sum)).font(Theme.heading(13)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    Divider().background(Theme.stroke)
                    HStack {
                        Text("Total / m²").font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(store.money(perM2)).font(Theme.heading(15)).foregroundColor(Theme.accent)
                    }
                }
            }

            NavRow(icon: "doc.text.fill", title: "Export a report",
                   subtitle: "Composition, index & cost as PDF", tint: Theme.wave) { ReportBuilderView() }
            DisclaimerBanner()
        }
    }

    private func categorySubtotals(_ layers: [Layer]) -> [(LayerCategory, Double)] {
        var dict: [LayerCategory: Double] = [:]
        for l in layers { dict[l.category, default: 0] += l.costPerM2 }
        return LayerCategory.allCases.compactMap { c in dict[c].map { (c, $0) } }
    }
}

struct OfflineRoost: View {
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                Image(geometry.size.width > geometry.size.height ? "quit_wall_errrsl" : "quit_wall_errrs")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.85)
                    .blur(radius: 2.5)
                
                VStack {
                    Image("quit_wall_er")
                        .resizable()
                        .frame(width: 250, height: 225)
                }
            }
        }
        .ignoresSafeArea()
    }
    
}
