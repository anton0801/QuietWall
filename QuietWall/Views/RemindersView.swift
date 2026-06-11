//
//  RemindersView.swift  (13 — Reminders)
//  QuietWall
//
//  Local reminders to buy materials or check sealing. Real UNUserNotification
//  scheduling via the NotificationManager; toggles enable/cancel each one.
//  iOS 14 safe.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @State private var editing: Reminder?
    @State private var showNew = false
    @State private var testSent = false

    var body: some View {
        ScreenScaffold("Reminders", subtitle: "Buy materials · check sealing") {
            if !notifications.isAuthorized {
                CardView(tint: Theme.warning.opacity(0.4)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill").foregroundColor(Theme.warning)
                            Text("Notifications are off").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        }
                        Text("Allow notifications so Quiet Wall can remind you at the right time.")
                            .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        ActionButton(title: "Enable Notifications", systemImage: "bell.fill") {
                            notifications.requestAuthorization { granted in
                                if granted { notifications.sync(store.reminders) }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                ActionButton(title: "Add Reminder", systemImage: "plus") { showNew = true }
                ActionButton(title: "Test", systemImage: "paperplane.fill", kind: .secondary) {
                    notifications.sendTestNotification(body: "This is how your reminders will look.")
                    withAnimation { testSent = true }
                }
            }
            if testSent {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.success)
                    Text("Test notification scheduled (arrives in ~3s).").font(Theme.caption(11)).foregroundColor(Theme.textPrimary)
                    Spacer()
                }.padding(10).background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.success.opacity(0.14)))
            }

            if store.reminders.isEmpty {
                CardView { EmptyStateView(systemImage: "bell.badge",
                                          title: "No reminders",
                                          message: "Add a reminder to buy a material or to check the perimeter seal.") }
            } else {
                VStack(spacing: 10) {
                    ForEach(store.reminders) { reminder in reminderCard(reminder) }
                }
            }
            DisclaimerBanner()
        }
        .sheet(isPresented: $showNew) { ReminderEditorSheet(reminder: nil).environmentObject(store) }
        .sheet(item: $editing) { r in ReminderEditorSheet(reminder: r).environmentObject(store) }
        .onAppear { notifications.refreshStatus() }
    }

    private func reminderCard(_ r: Reminder) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(r.kind.color.opacity(0.18)).frame(width: 42, height: 42)
                    Image(systemName: r.kind.icon).foregroundColor(r.kind.color)
                }
                Button(action: { editing = r }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title.isEmpty ? r.kind.displayName : r.title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary).lineLimit(1)
                        Text(Formatters.dateTime(r.fireDate)).font(Theme.caption(11)).foregroundColor(r.fireDate < Date() ? Theme.danger : Theme.textSecondary)
                        if let bid = r.buildID, let b = store.build(bid) {
                            Text(b.name).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())
                Toggle("", isOn: Binding(get: { r.isEnabled }, set: { _ in store.toggleReminder(r) }))
                    .labelsHidden().toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                Button(action: { store.deleteReminder(r) }) {
                    Image(systemName: "trash").foregroundColor(Theme.danger)
                }.buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Editor sheet

struct ReminderEditorSheet: View {
    @EnvironmentObject var store: AppStore
    let reminder: Reminder?
    @Environment(\.presentationMode) private var presentationMode

    @State private var kind: ReminderKind = .buyMaterials
    @State private var title = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var buildID: UUID?
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TYPE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                SegmentBar(options: ReminderKind.allCases, selection: $kind,
                                           label: { $0.displayName })
                            }
                            LabeledField(label: "Title", text: $title, placeholder: titlePlaceholder)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("WHEN").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                DatePicker("", selection: $date, in: Date()...).labelsHidden().accentColor(Theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("LINK TO BUILD (OPTIONAL)").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                Menu {
                                    Button("None") { buildID = nil }
                                    ForEach(store.builds) { b in Button(b.name) { buildID = b.id } }
                                } label: {
                                    HStack {
                                        Text(buildID.flatMap { store.build($0)?.name } ?? "None")
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down").foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                                }
                            }
                        }
                    }
                    ActionButton(title: "Save Reminder", systemImage: "checkmark") { save() }
                    if reminder != nil {
                        ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                            if let r = reminder { store.deleteReminder(r) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .acousticScreen(showWave: false)
            .navigationBarTitle(reminder == nil ? "New Reminder" : "Edit Reminder", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                UIApplication.shared.dismissKeyboard()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(Theme.accent))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let r = reminder { kind = r.kind; title = r.title; date = r.fireDate; buildID = r.buildID }
            loaded = true
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .buyMaterials: return "e.g. Buy mineral wool batts"
        case .installLayer: return "e.g. Fit resilient channel"
        case .sealGaps: return "e.g. Seal perimeter junctions"
        case .custom: return "Reminder"
        }
    }

    private func save() {
        var r = reminder ?? Reminder(kind: kind, title: "", fireDate: date)
        r.kind = kind
        r.title = title.isEmpty ? kind.displayName : title
        r.fireDate = date
        r.buildID = buildID
        r.isEnabled = true
        store.saveReminder(r)
        presentationMode.wrappedValue.dismiss()
    }
}
