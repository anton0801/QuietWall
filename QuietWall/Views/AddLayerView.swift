//
//  AddLayerView.swift  (02 — Add Layer)
//  QuietWall
//
//  Pick a material from the library (filtered to the build's surface). Each row
//  previews the projected Rw change, thickness and cost it adds before you
//  commit it to the assembly. iOS 14 safe.
//

import SwiftUI

struct AddLayerView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter: LayerCategory? = nil
    @State private var lastAdded: String? = nil

    var body: some View {
        Group {
            if let build = store.activeBuild {
                content(build)
            } else {
                ScreenScaffold("Add Layer", subtitle: "Material library") { NoBuildCard() }
            }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        let materials = store.materials(for: build.surface)
            .filter { filter == nil || $0.category == filter }
            .sorted { $0.category.rawValue < $1.category.rawValue }

        return ScreenScaffold("Add Layer", subtitle: "Tap a material to add it to “\(build.name)”") {
            // live state
            CardView {
                HStack {
                    statBlock("Rw", "\(Int(r.rw))", Theme.accent)
                    Divider().frame(height: 34).background(Theme.stroke)
                    statBlock("Thickness", store.thickness(r.totalThicknessMM), Theme.textPrimary)
                    Divider().frame(height: 34).background(Theme.stroke)
                    statBlock("Cost/m²", store.money(r.totalCostPerM2), Theme.textPrimary)
                }
            }

            if let added = lastAdded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.success)
                    Text("Added \(added)").font(Theme.caption(12)).foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.success.opacity(0.14)))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(nil, "All")
                    ForEach(LayerCategory.allCases) { c in filterChip(c, c.displayName) }
                }
            }

            if materials.isEmpty {
                CardView { EmptyStateView(systemImage: "tray", title: "No materials",
                                          message: "No library materials match this surface & filter. Add one in Settings → Material Library.") }
            } else {
                VStack(spacing: 10) {
                    ForEach(materials) { material in
                        materialCard(material, build: build, baseRw: r.rw)
                    }
                }
            }
            DisclaimerBanner()
        }
    }

    private func statBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.heading(16)).foregroundColor(color)
            Text(label).font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
        }.frame(maxWidth: .infinity)
    }

    private func filterChip(_ c: LayerCategory?, _ label: String) -> some View {
        let selected = filter == c
        return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = c } }) {
            Text(label).font(Theme.caption(12))
                .foregroundColor(selected ? Theme.textOnAccent : Theme.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Group {
                    if selected { Capsule().fill(Theme.accentGradient) } else { Capsule().fill(Theme.surface) }
                })
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.stroke, lineWidth: 1))
        }.buttonStyle(PlainButtonStyle())
    }

    private func materialCard(_ material: Material, build: WallBuild, baseRw: Double) -> some View {
        let projected = AcousticEngine.projectedRw(build, adding: material)
        let delta = projected - baseRw
        return CardView {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(material.category.color.opacity(0.18)).frame(width: 44, height: 44)
                    Image(systemName: material.category.icon).foregroundColor(material.category.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(material.name).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    Text(spec(material)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    HStack(spacing: 6) {
                        TagChip(text: deltaText(delta), color: delta > 0 ? Theme.success : (delta < 0 ? Theme.danger : Theme.textSecondary))
                        TagChip(text: store.money(material.costPerM2) + "/m²", color: Theme.accent)
                    }
                }
                Spacer()
                Button(action: { add(material, to: build.id) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(Theme.textOnAccent)
                        .frame(width: 40, height: 40).background(Circle().fill(Theme.accentGradient))
                        .shadow(color: Theme.violetGlow, radius: 8)
                }.buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func spec(_ m: Material) -> String {
        var parts = ["\(Int(m.defaultThicknessMM))mm"]
        if m.category.contributesMass { parts.append(Formatters.decimal(m.defaultSurfaceMass, digits: 1) + " kg/m²") }
        if let k = m.decouplerKind { parts.append(k.displayName) }
        return parts.joined(separator: " · ")
    }

    private func deltaText(_ d: Double) -> String {
        if d > 0 { return "+\(Int(d)) dB Rw" }
        if d < 0 { return "\(Int(d)) dB Rw" }
        return "no Rw change"
    }

    private func add(_ material: Material, to buildID: UUID) {
        store.addLayer(material, to: buildID)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { lastAdded = material.name }
    }
}
