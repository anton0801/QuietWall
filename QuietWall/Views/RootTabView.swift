//
//  RootTabView.swift
//  QuietWall
//
//  Main app shell: custom tab bar + per-tab NavigationView stacks. Build =
//  the layer constructor, Estimate = the sound estimate, Compare = build
//  comparison, Docs and More are hubs. iOS 14 safe.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .build

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .build:    stack { LayerStackView() }
                case .estimate: stack { SoundEstimateView() }
                case .compare:  stack { CompareBuildsView() }
                case .docs:     stack { DocsHubView() }
                case .more:     stack { MoreView() }
                }
            }
            CustomTabBar(selection: $tab, badge: store.activeBridgeCount)
        }
    }

    private func stack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        NavigationView { content() }
            .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Reusable navigation row (card style)

struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var tint: Color = Theme.accent
    var badge: Int = 0
    let destination: Destination

    init(icon: String, title: String, subtitle: String = "", tint: Color = Theme.accent,
         badge: Int = 0, @ViewBuilder destination: () -> Destination) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.tint = tint; self.badge = badge; self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: icon).foregroundColor(tint).font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                if badge > 0 { TagChip(text: "\(badge)", color: Theme.danger, filled: true) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty "no build" prompt

struct NoBuildCard: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        CardView {
            VStack(spacing: 14) {
                EmptyStateView(systemImage: "square.stack.3d.up.badge.a",
                               title: "No assembly yet",
                               message: "Create a build to start stacking soundproofing layers.")
                ActionButton(title: "Create a build", systemImage: "plus") { store.newBuild() }
            }
        }
    }
}

// MARK: - Build switcher (horizontal chips)

struct BuildSwitcherBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.builds) { b in
                    let active = store.activeBuild?.id == b.id
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.setActiveBuild(b.id) } }) {
                        HStack(spacing: 6) {
                            Image(systemName: b.surface.icon).font(.system(size: 11, weight: .semibold))
                            Text(b.name).font(Theme.caption(12)).lineLimit(1)
                        }
                        .foregroundColor(active ? Theme.textOnAccent : Theme.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(
                            Group {
                                if active { Capsule().fill(Theme.accentGradient) }
                                else { Capsule().fill(Theme.surface) }
                            }
                        )
                        .overlay(Capsule().stroke(active ? Color.clear : Theme.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button(action: { store.newBuild() }) {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text("New") }
                        .font(Theme.caption(12)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent.opacity(0.14)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Docs hub

struct DocsHubView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScreenScaffold("Docs", subtitle: "Capture, report & track your builds") {
            BuildSwitcherBar()
            if let build = store.activeBuild {
                let r = store.result(for: build)
                CardView {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(build.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                            Text("Rw \(Int(r.rw)) · \(store.thickness(r.totalThicknessMM)) · \(store.money(r.totalCostPerM2))/m²")
                                .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: build.surface.icon).foregroundColor(Theme.accent)
                    }
                }
            }
            VStack(spacing: 12) {
                NavRow(icon: "camera.fill", title: "Photo / Notes",
                       subtitle: "\(store.activeBuild?.notes.count ?? 0) node photos & notes", tint: Theme.accent) { NoteCaptureView() }
                NavRow(icon: "doc.text.fill", title: "Reports",
                       subtitle: "Composition, index & cost · Export PDF", tint: Theme.wave) { ReportBuilderView() }
                NavRow(icon: "clock.arrow.circlepath", title: "History",
                       subtitle: "\(store.history.count) entries", tint: Theme.info) { HistoryView() }
            }
            DisclaimerBanner()
        }
    }
}

// MARK: - More hub

struct MoreView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    var body: some View {
        ScreenScaffold("More", subtitle: "Reminders, settings & about") {
            VStack(spacing: 12) {
                NavRow(icon: "bell.badge.fill", title: "Reminders",
                       subtitle: "\(store.reminders.count) scheduled", tint: Theme.warning,
                       badge: 0) { RemindersView() }
                NavRow(icon: "gearshape.fill", title: "Settings",
                       subtitle: "Theme, units, currency, library, backup", tint: Theme.accent) { SettingsView() }
            }

            SectionHeader(title: "About Quiet Wall", systemImage: "info.circle.fill")
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quiet Wall estimates the airborne (Rw / STC) and impact (Ln,w / IIC) performance of a layered soundproofing assembly, shows how sound attenuates layer-by-layer, and flags acoustic bridges.")
                        .font(Theme.body(14)).foregroundColor(Theme.textSecondary)
                    Divider().background(Theme.stroke)
                    Text("All data is stored locally on this device. No account, no cloud, no tracking.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
            }
            DisclaimerBanner()
        }
    }
}
