//
//  HistoryView.swift  (12 — History)
//  QuietWall
//
//  A timeline of build snapshots — created, updated, duplicated, exported —
//  each capturing the index, thickness and cost at that moment. iOS 14 safe.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var confirmClear = false

    var body: some View {
        ScreenScaffold("History", subtitle: "Built · changed · exported") {
            if store.history.isEmpty {
                CardView { EmptyStateView(systemImage: "clock.arrow.circlepath",
                                          title: "No history yet",
                                          message: "Create or edit a build and snapshots will appear here.") }
            } else {
                HStack {
                    Text("\(store.history.count) entries").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button(action: { confirmClear = true }) {
                        Label("Clear", systemImage: "trash").font(Theme.caption(12)).foregroundColor(Theme.danger)
                    }.buttonStyle(PlainButtonStyle())
                }
                VStack(spacing: 10) {
                    ForEach(store.history) { entry in entryCard(entry) }
                }
            }
            DisclaimerBanner()
        }
        .alert(isPresented: $confirmClear) {
            Alert(title: Text("Clear all history?"),
                  message: Text("This removes every snapshot. Builds themselves are kept."),
                  primaryButton: .destructive(Text("Clear")) { store.clearHistory() },
                  secondaryButton: .cancel())
        }
    }

    private func entryCard(_ e: HistoryEntry) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(actionColor(e.action).opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: actionIcon(e.action)).foregroundColor(actionColor(e.action))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(e.buildName).font(Theme.heading(14)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        TagChip(text: e.action, color: actionColor(e.action))
                    }
                    Text("Rw \(Int(e.rw)) · STC \(Int(e.stc)) · \(store.thickness(e.thicknessMM)) · \(store.money(e.costPerM2))/m²")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Text(Formatters.dateTime(e.createdAt)).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                }
                Spacer()
                Image(systemName: e.surface.icon).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func actionIcon(_ a: String) -> String {
        switch a {
        case "Created": return "plus.circle.fill"
        case "Updated": return "pencil.circle.fill"
        case "Duplicated": return "doc.on.doc.fill"
        case "Exported": return "square.and.arrow.up.circle.fill"
        default: return "circle.fill"
        }
    }
    private func actionColor(_ a: String) -> Color {
        switch a {
        case "Created": return Theme.success
        case "Updated": return Theme.accent
        case "Duplicated": return Theme.info
        case "Exported": return Theme.wave
        default: return Theme.textSecondary
        }
    }
}
